# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PerformanceMonitor, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')) }
  let(:operation_name) { 'test_operation' }

  before do
    # Clean up any existing keys
    redis.keys('perf_stats:*').each { |k| redis.del(k) }
  end

  after do
    # Clean up after each test
    redis.keys('perf_stats:*').each { |k| redis.del(k) }
  end

  describe '.track' do
    it 'executes the block and returns result' do
      result = described_class.track(operation_name) { 'success' }
      expect(result).to eq('success')
    end

    it 'measures execution time' do
      expect(Rails.logger).to receive(:info) do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['duration_seconds']).to be > 0
      end

      described_class.track(operation_name) do
        sleep 0.01 # Ensure measurable time
      end
    end

    it 'logs slow operations' do
      expect(Rails.logger).to receive(:warn).with(/SLOW:/)

      described_class.track(operation_name, threshold: 0.01) do
        sleep 0.02 # Exceed threshold
      end
    end

    it 'includes context in logs' do
      context = { product_id: 123, catalog_id: 456 }

      expect(Rails.logger).to receive(:info) do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['product_id']).to eq(123)
        expect(data['catalog_id']).to eq(456)
      end

      described_class.track(operation_name, context: context) { 'ok' }
    end

    context 'when block raises error' do
      it 'propagates the error' do
        expect {
          described_class.track(operation_name) { raise StandardError, 'test error' }
        }.to raise_error(StandardError, 'test error')
      end

      it 'logs failure metrics' do
        expect(Rails.logger).to receive(:error).with(/FAILED:/)
        expect(Rails.logger).to receive(:info) do |log|
          next unless log.is_a?(String) && log.start_with?('{')

          data = JSON.parse(log)
          expect(data['success']).to be false
          expect(data['error_class']).to eq('StandardError')
        end

        expect {
          described_class.track(operation_name) { raise StandardError, 'fail' }
        }.to raise_error(StandardError)
      end
    end
  end

  describe '.stats' do
    before do
      # Execute operation multiple times to generate stats
      5.times do |i|
        described_class.track(operation_name) { sleep 0.001 * (i + 1) }
      end
    end

    it 'returns statistics for the operation' do
      stats = described_class.stats(operation_name)

      expect(stats).to include(
        operation: operation_name,
        count: 5
      )
      expect(stats[:total_duration]).to be > 0
      expect(stats[:avg_duration]).to be > 0
      expect(stats[:min_duration]).to be > 0
      expect(stats[:max_duration]).to be > 0
    end

    it 'returns nil for non-existent operation' do
      stats = described_class.stats('non_existent')
      expect(stats).to be_nil
    end
  end

  describe '.reset_stats' do
    before do
      described_class.track(operation_name) { 'ok' }
    end

    it 'clears statistics for the operation' do
      expect(described_class.stats(operation_name)).not_to be_nil

      described_class.reset_stats(operation_name)

      expect(described_class.stats(operation_name)).to be_nil
    end
  end

  describe '#track' do
    let(:monitor) { described_class.new(operation_name) }

    it 'tracks operation performance' do
      result = monitor.track { 42 }
      expect(result).to eq(42)
    end

    it 'updates statistics in Redis' do
      monitor.track { 'ok' }

      stats = described_class.stats(operation_name)
      expect(stats[:count]).to eq(1)
    end

    it 'accumulates statistics over multiple calls' do
      3.times { monitor.track { 'ok' } }

      stats = described_class.stats(operation_name)
      expect(stats[:count]).to eq(3)
    end
  end

  describe 'slow operation detection' do
    it 'marks operation as slow when exceeding threshold' do
      expect(Rails.logger).to receive(:info) do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['slow']).to be true
      end

      described_class.track(operation_name, threshold: 0.01) do
        sleep 0.02
      end
    end

    it 'tracks slow operation count' do
      # One fast operation
      described_class.track(operation_name, threshold: 1.0) { sleep 0.01 }

      # Two slow operations
      2.times do
        described_class.track(operation_name, threshold: 0.01) { sleep 0.02 }
      end

      stats = described_class.stats(operation_name)
      expect(stats[:count]).to eq(3)
      expect(stats[:slow_count]).to eq(2)
    end
  end

  describe 'min/max duration tracking' do
    it 'tracks minimum and maximum durations' do
      # Fast operation
      described_class.track(operation_name) { sleep 0.001 }

      # Slow operation
      described_class.track(operation_name) { sleep 0.05 }

      # Medium operation
      described_class.track(operation_name) { sleep 0.01 }

      stats = described_class.stats(operation_name)
      expect(stats[:min_duration]).to be < stats[:avg_duration]
      expect(stats[:max_duration]).to be > stats[:avg_duration]
    end
  end

  describe 'average duration calculation' do
    it 'calculates average duration correctly' do
      # Known durations (approximately)
      described_class.track(operation_name) { sleep 0.01 }
      described_class.track(operation_name) { sleep 0.02 }
      described_class.track(operation_name) { sleep 0.03 }

      stats = described_class.stats(operation_name)
      # Allow for timing variance in test environment
      expect(stats[:avg_duration]).to be_between(0.015, 0.035)
    end
  end

  describe 'Redis error handling' do
    before do
      allow_any_instance_of(Redis).to receive(:multi).and_raise(Redis::ConnectionError.new('Connection refused'))
    end

    it 'continues operation even if stats update fails' do
      expect(Rails.logger).to receive(:error).with(/Redis error updating stats/).and_call_original

      result = nil
      expect {
        result = described_class.track(operation_name) { 'ok' }
      }.not_to raise_error

      expect(result).to eq('ok')
    end
  end

  describe 'structured logging' do
    it 'logs metrics as JSON' do
      expect(Rails.logger).to receive(:info) do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data).to include(
          'event' => 'performance_metric',
          'operation' => operation_name,
          'success' => true
        )
        expect(data['duration_seconds']).to be >= 0
        expect(data['timestamp']).to be_present
      end

      described_class.track(operation_name) { sleep 0.001 }
    end
  end

  describe 'context preservation' do
    it 'includes all context fields in logs' do
      context = {
        product_id: 123,
        catalog_id: 456,
        batch_size: 100,
        custom_field: 'test'
      }

      expect(Rails.logger).to receive(:info) do |log|
        next unless log.is_a?(String) && log.start_with?('{')

        data = JSON.parse(log)
        expect(data['product_id']).to eq(123)
        expect(data['catalog_id']).to eq(456)
        expect(data['batch_size']).to eq(100)
        expect(data['custom_field']).to eq('test')
      end

      described_class.track(operation_name, context: context) { 'ok' }
    end
  end

  describe 'last execution tracking' do
    it 'records timestamp of last execution' do
      freeze_time do
        described_class.track(operation_name) { 'ok' }

        stats = described_class.stats(operation_name)
        expect(stats[:last_execution]).to eq(Time.current.iso8601)
      end
    end
  end
end
