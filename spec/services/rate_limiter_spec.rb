# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RateLimiter, type: :service do
  let(:redis) { Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')) }
  let(:key) { 'test_rate_limit' }
  let(:limit) { 5 }
  let(:period) { 10 }
  let(:rate_limiter) { described_class.new(key, limit: limit, period: period) }

  before do
    # Clean up any existing keys
    redis.keys('rate_limit:*').each { |k| redis.del(k) }
  end

  after do
    # Clean up after each test
    redis.keys('rate_limit:*').each { |k| redis.del(k) }
  end

  describe '#initialize' do
    it 'creates a rate limiter with specified parameters' do
      expect(rate_limiter.key).to eq(key)
      expect(rate_limiter.limit).to eq(limit)
      expect(rate_limiter.period).to eq(period)
    end
  end

  describe '#throttle' do
    context 'when under rate limit' do
      it 'executes the block' do
        result = nil
        expect {
          result = rate_limiter.throttle { 'executed' }
        }.not_to raise_error

        expect(result).to eq('executed')
      end

      it 'allows up to the limit number of requests' do
        results = []
        limit.times do
          results << rate_limiter.throttle { 'ok' }
        end

        expect(results.size).to eq(limit)
        expect(results).to all(eq('ok'))
      end
    end

    context 'when rate limit exceeded' do
      it 'raises RateLimitExceededError' do
        # Execute limit number of requests
        limit.times { rate_limiter.throttle { 'ok' } }

        # Next request should fail
        expect {
          rate_limiter.throttle { 'should fail' }
        }.to raise_error(RateLimiter::RateLimitExceededError, /Rate limit exceeded/)
      end

      it 'includes helpful error message with retry time' do
        limit.times { rate_limiter.throttle { 'ok' } }

        expect {
          rate_limiter.throttle { 'fail' }
        }.to raise_error do |error|
          expect(error.message).to include(key)
          expect(error.message).to include("#{limit + 1}/#{limit}")
          expect(error.message).to include('Retry after')
        end
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow(redis).to receive(:multi).and_raise(Redis::ConnectionError.new('Connection refused'))
        allow_any_instance_of(described_class).to receive(:increment_and_check)
          .and_raise(Redis::ConnectionError.new('Connection refused'))
      end

      it 'allows the request and logs error' do
        expect(Rails.logger).to receive(:error).with(/Redis error/)

        result = nil
        expect {
          result = rate_limiter.throttle { 'executed anyway' }
        }.not_to raise_error

        expect(result).to eq('executed anyway')
      end
    end
  end

  describe '#allowed?' do
    it 'returns true when under limit' do
      expect(rate_limiter.allowed?).to be true
    end

    it 'increments counter' do
      expect {
        rate_limiter.allowed?
      }.to change { rate_limiter.current_usage }.from(0).to(1)
    end

    it 'returns false when limit exceeded' do
      limit.times { rate_limiter.allowed? }
      expect(rate_limiter.allowed?).to be false
    end
  end

  describe '#current_usage' do
    it 'returns 0 initially' do
      expect(rate_limiter.current_usage).to eq(0)
    end

    it 'returns current count' do
      3.times { rate_limiter.allowed? }
      expect(rate_limiter.current_usage).to eq(3)
    end
  end

  describe '#time_until_reset' do
    it 'returns the period initially' do
      rate_limiter.allowed?
      expect(rate_limiter.time_until_reset).to be_between(1, period)
    end

    it 'decreases over time' do
      rate_limiter.allowed?
      initial_ttl = rate_limiter.time_until_reset

      sleep 1

      new_ttl = rate_limiter.time_until_reset
      expect(new_ttl).to be < initial_ttl
    end
  end

  describe '#reset!' do
    it 'clears the rate limit counter' do
      3.times { rate_limiter.allowed? }
      expect(rate_limiter.current_usage).to eq(3)

      rate_limiter.reset!

      expect(rate_limiter.current_usage).to eq(0)
    end
  end

  describe '#info' do
    before do
      3.times { rate_limiter.allowed? }
    end

    it 'returns comprehensive rate limit info' do
      info = rate_limiter.info

      expect(info).to include(
        key: key,
        limit: limit,
        period: period,
        current_usage: 3,
        remaining: 2,
        percentage_used: 60.0
      )
      expect(info[:time_until_reset]).to be > 0
    end
  end

  describe 'sliding window behavior' do
    it 'allows new requests after window expires' do
      # Use very short period for testing
      short_limiter = described_class.new('short_test', limit: 2, period: 1)

      # Use up the limit
      2.times { short_limiter.throttle { 'ok' } }

      # Should be blocked
      expect {
        short_limiter.throttle { 'blocked' }
      }.to raise_error(RateLimiter::RateLimitExceededError)

      # Wait for window to expire
      sleep 1.5

      # Should be allowed again
      expect {
        short_limiter.throttle { 'allowed again' }
      }.not_to raise_error

      # Clean up
      short_limiter.reset!
    end
  end

  describe 'distributed rate limiting' do
    it 'shares rate limit across multiple instances' do
      limiter1 = described_class.new(key, limit: 3, period: 10)
      limiter2 = described_class.new(key, limit: 3, period: 10)

      # Instance 1 uses 2 requests
      2.times { limiter1.throttle { 'ok' } }

      # Instance 2 should see usage from instance 1
      expect(limiter2.current_usage).to eq(2)

      # Instance 2 can use 1 more request
      limiter2.throttle { 'ok' }

      # Both instances should now be at limit
      expect(limiter1.current_usage).to eq(3)
      expect(limiter2.current_usage).to eq(3)

      # Neither should allow more requests
      expect { limiter1.throttle { 'fail' } }.to raise_error(RateLimiter::RateLimitExceededError)
      expect { limiter2.throttle { 'fail' } }.to raise_error(RateLimiter::RateLimitExceededError)
    end
  end

  describe 'logging' do
    context 'when approaching limit' do
      it 'logs warning at 80% usage' do
        # Use 4 out of 5 requests (80%)
        4.times { rate_limiter.throttle { 'ok' } }

        expect(Rails.logger).to receive(:warn).with(/Approaching rate limit/)

        # Fifth request should trigger warning
        rate_limiter.throttle { 'ok' }
      end
    end

    context 'when limit exceeded' do
      it 'logs structured JSON event' do
        limit.times { rate_limiter.throttle { 'ok' } }

        expect(Rails.logger).to receive(:info) do |log|
          data = JSON.parse(log)
          expect(data['event']).to eq('rate_limit_exceeded')
          expect(data['key']).to eq(key)
          expect(data['limit']).to eq(limit)
        end

        expect {
          rate_limiter.throttle { 'fail' }
        }.to raise_error(RateLimiter::RateLimitExceededError)
      end
    end
  end
end
