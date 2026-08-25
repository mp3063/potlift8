# frozen_string_literal: true

# Algorithm:
# Uses sliding window counter algorithm:
# 1. Create a key with current time window
# 2. Increment counter for this window
# 3. Set expiration if new key
# 4. Check if limit exceeded
# Error Handling:
#   Raises RateLimitExceededError when limit is exceeded
#   Falls back gracefully if Redis is unavailable (allows request)
class RateLimiter
  class RateLimitExceededError < StandardError; end

  attr_reader :key, :limit, :period

  def initialize(key, limit:, period:)
    @key = key
    @limit = limit
    @period = period
    @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  def throttle
    unless allowed?
      current_count = current_usage
      wait_time = time_until_reset

      log_rate_limit_exceeded(current_count, wait_time)

      raise RateLimitExceededError,
            "Rate limit exceeded for '#{@key}': #{current_count}/#{@limit} requests in #{@period}s. " \
            "Retry after #{wait_time.round(1)}s"
    end

    log_request_allowed

    yield
  rescue Redis::BaseError => e
    # If Redis is unavailable, log error but allow the request
    # This prevents Redis failures from blocking all operations
    Rails.logger.error(
      "[RateLimiter] Redis error for key '#{@key}': #{e.message}. Allowing request."
    )
    yield
  end

  def allowed?
    increment_and_check
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[RateLimiter] Redis error checking limit for '#{@key}': #{e.message}. Allowing request."
    )
    true
  end

  def current_usage
    window_key = build_window_key
    @redis.get(window_key).to_i
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[RateLimiter] Redis error getting usage for '#{@key}': #{e.message}"
    )
    0
  end

  def time_until_reset
    window_key = build_window_key
    ttl = @redis.ttl(window_key)
    ttl > 0 ? ttl : @period
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[RateLimiter] Redis error getting TTL for '#{@key}': #{e.message}"
    )
    @period
  end

  def reset!
    window_key = build_window_key
    @redis.del(window_key)
    Rails.logger.info("[RateLimiter] Reset counter for '#{@key}'")
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[RateLimiter] Redis error resetting '#{@key}': #{e.message}"
    )
  end

  def info
    {
      key: @key,
      limit: @limit,
      period: @period,
      current_usage: current_usage,
      remaining: [ @limit - current_usage, 0 ].max,
      time_until_reset: time_until_reset,
      percentage_used: (current_usage.to_f / @limit * 100).round(1)
    }
  end

  private

  def increment_and_check
    window_key = build_window_key

    count = @redis.multi do |pipeline|
      pipeline.incr(window_key)
      pipeline.expire(window_key, @period)
    end.first

    count <= @limit
  end

  def build_window_key
    current_window = (Time.current.to_i / @period).floor
    "rate_limit:#{@key}:#{current_window}"
  end

  def log_rate_limit_exceeded(current_count, wait_time)
    Rails.logger.warn(
      "[RateLimiter] Rate limit EXCEEDED for '#{@key}': " \
      "#{current_count}/#{@limit} requests in #{@period}s. " \
      "Reset in #{wait_time.round(1)}s"
    )

    Rails.logger.info({
      event: "rate_limit_exceeded",
      key: @key,
      limit: @limit,
      period: @period,
      current_count: current_count,
      wait_time: wait_time,
      timestamp: Time.current.iso8601
    }.to_json)
  end

  def log_request_allowed
    current_count = current_usage

    Rails.logger.debug(
      "[RateLimiter] Request allowed for '#{@key}': " \
      "#{current_count}/#{@limit} (#{((current_count.to_f / @limit) * 100).round(1)}% used)"
    )

    # Log warning when approaching limit (>80%)
    if current_count.to_f / @limit > 0.8
      Rails.logger.warn(
        "[RateLimiter] Approaching rate limit for '#{@key}': " \
        "#{current_count}/#{@limit} (#{((current_count.to_f / @limit) * 100).round(1)}% used)"
      )
    end
  end
end
