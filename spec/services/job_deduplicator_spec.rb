# frozen_string_literal: true

require 'rails_helper'

RSpec.describe JobDeduplicator, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')) }
  let(:job_name) { 'TestJob' }
  let(:params) { { product_id: 123, catalog_id: 456 } }
  let(:window) { 30 }
  let(:deduplicator) { described_class.new(job_name: job_name, params: params, window: window) }

  before do
    # Clean up any existing keys
    redis.keys('job_dedup:*').each { |k| redis.del(k) }
  end

  after do
    # Clean up after each test
    redis.keys('job_dedup:*').each { |k| redis.del(k) }
  end

  describe '#initialize' do
    it 'creates a deduplicator with specified parameters' do
      expect(deduplicator.job_name).to eq(job_name)
      expect(deduplicator.params).to eq(params)
      expect(deduplicator.window).to eq(window)
    end

    it 'sorts params for consistent key generation' do
      unsorted_params = { catalog_id: 456, product_id: 123 }
      dedup = described_class.new(job_name: job_name, params: unsorted_params, window: window)

      expect(dedup.params).to eq({ catalog_id: 456, product_id: 123 })
    end
  end

  describe '#unique?' do
    context 'when job has not been executed recently' do
      it 'returns true' do
        expect(deduplicator.unique?).to be true
      end

      it 'sets deduplication key in Redis' do
        deduplicator.unique?
        expect(deduplicator.executed_recently?).to be true
      end
    end

    context 'when job was executed recently' do
      before do
        deduplicator.unique? # First execution
      end

      it 'returns false' do
        expect(deduplicator.unique?).to be false
      end

      it 'logs duplicate detection' do
        allow(Rails.logger).to receive(:info).and_call_original
        deduplicator.unique?
        # Verify that logger was called (both text and JSON logs)
        expect(Rails.logger).to have_received(:info).at_least(:twice)
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow_any_instance_of(Redis).to receive(:set).and_raise(Redis::ConnectionError.new('Connection refused'))
      end

      it 'allows the job and logs error' do
        expect(Rails.logger).to receive(:error).with(/Redis error/).and_call_original
        expect(deduplicator.unique?).to be true
      end
    end
  end

  describe '#execute_once' do
    context 'when job is unique' do
      it 'executes the block' do
        result = nil
        deduplicator.execute_once do
          result = 'executed'
        end

        expect(result).to eq('executed')
      end

      it 'returns the block result' do
        result = deduplicator.execute_once { 42 }
        expect(result).to eq(42)
      end
    end

    context 'when job is duplicate' do
      before do
        deduplicator.unique? # Mark as executed
      end

      it 'does not execute the block' do
        executed = false
        deduplicator.execute_once { executed = true }
        expect(executed).to be false
      end

      it 'returns nil' do
        result = deduplicator.execute_once { 'should not run' }
        expect(result).to be_nil
      end

      context 'with raise_on_duplicate: true' do
        it 'raises DuplicateJobError' do
          expect {
            deduplicator.execute_once(raise_on_duplicate: true) { 'fail' }
          }.to raise_error(JobDeduplicator::DuplicateJobError, /Duplicate job detected/)
        end
      end
    end

    context 'when block raises error' do
      it 'propagates the error' do
        expect {
          deduplicator.execute_once { raise StandardError, 'test error' }
        }.to raise_error(StandardError, 'test error')
      end

      it 'still sets deduplication key' do
        begin
          deduplicator.execute_once { raise StandardError }
        rescue StandardError
          # Expected
        end

        # Should be marked as executed even though it failed
        expect(deduplicator.executed_recently?).to be true
      end
    end
  end

  describe '#clear!' do
    before do
      deduplicator.unique? # Mark as executed
    end

    it 'removes deduplication key' do
      expect(deduplicator.executed_recently?).to be true

      deduplicator.clear!

      expect(deduplicator.executed_recently?).to be false
    end

    it 'allows job to execute again' do
      deduplicator.clear!
      expect(deduplicator.unique?).to be true
    end
  end

  describe '#executed_recently?' do
    it 'returns false initially' do
      expect(deduplicator.executed_recently?).to be false
    end

    it 'returns true after execution' do
      deduplicator.unique?
      expect(deduplicator.executed_recently?).to be true
    end
  end

  describe '#time_until_executable' do
    it 'returns 0 initially' do
      expect(deduplicator.time_until_executable).to eq(0)
    end

    it 'returns remaining TTL after execution' do
      deduplicator.unique?
      ttl = deduplicator.time_until_executable

      expect(ttl).to be_between(1, window)
    end
  end

  describe '#info' do
    before do
      deduplicator.unique?
    end

    it 'returns comprehensive deduplication info' do
      info = deduplicator.info

      expect(info).to include(
        job_name: job_name,
        params: params,
        window: window,
        executed_recently: true
      )
      expect(info[:dedup_key]).to include('job_dedup')
      expect(info[:time_until_executable]).to be >= 0
    end
  end

  describe 'time window bucketing' do
    it 'groups jobs in same time bucket' do
      dedup1 = described_class.new(job_name: job_name, params: params, window: 30)
      dedup2 = described_class.new(job_name: job_name, params: params, window: 30)

      # Both should generate same key within same window
      dedup1.unique?

      expect(dedup2.executed_recently?).to be true
    end

    it 'allows execution in different time bucket' do
      # Use very short window for testing
      short_dedup = described_class.new(job_name: job_name, params: params, window: 1)

      short_dedup.unique?
      expect(short_dedup.executed_recently?).to be true

      # Wait for window to expire
      sleep 1.5

      # Should be unique again in new time bucket
      expect(short_dedup.unique?).to be true
    end
  end

  describe 'different parameter deduplication' do
    it 'treats different params as different jobs' do
      params1 = { product_id: 123, catalog_id: 456 }
      params2 = { product_id: 789, catalog_id: 456 }

      dedup1 = described_class.new(job_name: job_name, params: params1, window: window)
      dedup2 = described_class.new(job_name: job_name, params: params2, window: window)

      dedup1.unique?

      # Different params should allow execution
      expect(dedup2.unique?).to be true
    end

    it 'treats different job names as different jobs' do
      dedup1 = described_class.new(job_name: 'Job1', params: params, window: window)
      dedup2 = described_class.new(job_name: 'Job2', params: params, window: window)

      dedup1.unique?

      # Different job name should allow execution
      expect(dedup2.unique?).to be true
    end
  end

  describe 'logging' do
    context 'when job is unique' do
      it 'logs debug message' do
        expect(Rails.logger).to receive(:debug).with(/Unique job detected/)
        deduplicator.unique?
      end
    end

    context 'when job is duplicate' do
      before do
        deduplicator.unique?
      end

      it 'logs structured JSON event' do
        expect(Rails.logger).to receive(:info).with(/Duplicate job detected/).and_call_original
        expect(Rails.logger).to receive(:info) do |log|
          next unless log.is_a?(String) && log.start_with?('{')

          data = JSON.parse(log)
          expect(data['event']).to eq('duplicate_job_skipped')
          expect(data['job_name']).to eq(job_name)
          expect(data['params']).to eq(params.stringify_keys)
        end.and_call_original

        deduplicator.unique?
      end
    end
  end
end
