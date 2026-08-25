# frozen_string_literal: true

# Prevents duplicate job execution using Redis-based distributed locking.
# Ensures that the same job with identical parameters doesn't run multiple times
# within a configurable time window.
# Algorithm:
# 1. Generate unique key based on job parameters
# 2. Try to set key in Redis with NX flag (only if not exists)
# 3. If set succeeds, job is unique - proceed with execution
# 4. If set fails, job is duplicate - skip execution
# 5. Key expires after window, allowing future execution
class JobDeduplicator
  class DuplicateJobError < StandardError; end

  attr_reader :job_name, :params, :window

  DEFAULT_WINDOW = 30

  def initialize(job_name:, params:, window: DEFAULT_WINDOW)
    @job_name = job_name
    @params = params.sort.to_h
    @window = window
    @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  def unique?
    dedup_key = build_deduplication_key

    result = @redis.set(dedup_key, "1", ex: @window, nx: true)

    if result
      log_unique_job(dedup_key)
      true
    else
      log_duplicate_job(dedup_key)
      false
    end
  rescue Redis::BaseError => e
    # If Redis is unavailable, log error but allow the job
    # This prevents Redis failures from blocking all jobs
    Rails.logger.error(
      "[JobDeduplicator] Redis error for '#{@job_name}': #{e.message}. Allowing job."
    )
    true
  end

  def execute_once(raise_on_duplicate: false)
    if unique?
      yield
    elsif raise_on_duplicate
      raise DuplicateJobError,
            "Duplicate job detected for '#{@job_name}' with params: #{@params.inspect}"
    else
      Rails.logger.info(
        "[JobDeduplicator] Skipping duplicate job '#{@job_name}' with params: #{@params.inspect}"
      )
      nil
    end
  end

  def clear!
    dedup_key = build_deduplication_key
    @redis.del(dedup_key)
    Rails.logger.info("[JobDeduplicator] Cleared deduplication key: #{dedup_key}")
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[JobDeduplicator] Redis error clearing '#{@job_name}': #{e.message}"
    )
  end

  def executed_recently?
    dedup_key = build_deduplication_key
    @redis.exists?(dedup_key)
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[JobDeduplicator] Redis error checking existence for '#{@job_name}': #{e.message}"
    )
    false
  end

  def time_until_executable
    dedup_key = build_deduplication_key
    ttl = @redis.ttl(dedup_key)
    ttl > 0 ? ttl : 0
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[JobDeduplicator] Redis error getting TTL for '#{@job_name}': #{e.message}"
    )
    0
  end

  def info
    {
      job_name: @job_name,
      params: @params,
      window: @window,
      dedup_key: build_deduplication_key,
      executed_recently: executed_recently?,
      time_until_executable: time_until_executable
    }
  end

  private

  def build_deduplication_key
    time_bucket = (Time.current.to_i / @window).floor

    param_string = @params.map { |k, v| "#{k}:#{v}" }.join(":")

    "job_dedup:#{@job_name}:#{param_string}:#{time_bucket}"
  end

  def log_unique_job(dedup_key)
    Rails.logger.debug(
      "[JobDeduplicator] Unique job detected: '#{@job_name}' with params #{@params.inspect}. " \
      "Dedup key: #{dedup_key}"
    )
  end

  def log_duplicate_job(dedup_key)
    ttl = time_until_executable

    Rails.logger.info(
      "[JobDeduplicator] Duplicate job detected: '#{@job_name}' with params #{@params.inspect}. " \
      "Skipping. Window expires in #{ttl}s. Dedup key: #{dedup_key}"
    )

    Rails.logger.info({
      event: "duplicate_job_skipped",
      job_name: @job_name,
      params: @params,
      window: @window,
      ttl: ttl,
      dedup_key: dedup_key,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
