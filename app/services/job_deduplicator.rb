# frozen_string_literal: true

# JobDeduplicator Service
#
# Prevents duplicate job execution using Redis-based distributed locking.
# Ensures that the same job with identical parameters doesn't run multiple times
# within a configurable time window.
#
# Features:
# - Distributed deduplication across multiple workers/servers
# - Configurable deduplication window
# - Atomic operations using Redis NX (set if not exists)
# - Automatic expiration of deduplication keys
# - Detailed logging for monitoring
#
# Algorithm:
# 1. Generate unique key based on job parameters
# 2. Try to set key in Redis with NX flag (only if not exists)
# 3. If set succeeds, job is unique - proceed with execution
# 4. If set fails, job is duplicate - skip execution
# 5. Key expires after window, allowing future execution
#
# Usage:
#   # Basic usage
#   deduplicator = JobDeduplicator.new(
#     job_name: 'ProductSyncJob',
#     params: { product_id: 123, catalog_id: 456 },
#     window: 30 # seconds
#   )
#
#   if deduplicator.unique?
#     # Job is unique, execute
#     ProductSyncService.new(product, catalog).sync_to_external_system
#   else
#     # Job is duplicate, skip
#     Rails.logger.info("Skipping duplicate job")
#   end
#
#   # With block (recommended)
#   deduplicator.execute_once do
#     ProductSyncService.new(product, catalog).sync_to_external_system
#   end
#
# Deduplication Key Format:
#   "job_dedup:{job_name}:{param1_value}:{param2_value}:{time_window}"
#
# Configuration:
#   job_name: Name of the job class (e.g., 'ProductSyncJob')
#   params: Hash of job parameters to include in dedup key
#   window: Deduplication window in seconds (default: 30)
#
class JobDeduplicator
  class DuplicateJobError < StandardError; end

  attr_reader :job_name, :params, :window

  DEFAULT_WINDOW = 30 # seconds

  # Initialize job deduplicator
  #
  # @param job_name [String] Name of the job
  # @param params [Hash] Job parameters for deduplication key
  # @param window [Integer] Deduplication window in seconds
  #
  def initialize(job_name:, params:, window: DEFAULT_WINDOW)
    @job_name = job_name
    @params = params.sort.to_h # Sort for consistent key generation
    @window = window
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
  end

  # Check if job is unique (hasn't run recently)
  #
  # @return [Boolean] true if job is unique and should execute
  #
  def unique?
    dedup_key = build_deduplication_key

    # Try to set key with NX flag (only if not exists)
    # Returns true if key was set (job is unique)
    # Returns false if key already exists (job is duplicate)
    result = @redis.set(dedup_key, '1', ex: @window, nx: true)

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

  # Execute block only if job is unique
  #
  # @yield Block to execute if job is unique
  # @raise [DuplicateJobError] If raise_on_duplicate is true and job is duplicate
  # @return [Object, nil] Result of block or nil if duplicate
  #
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

  # Force clear deduplication key (useful for testing)
  #
  def clear!
    dedup_key = build_deduplication_key
    @redis.del(dedup_key)
    Rails.logger.info("[JobDeduplicator] Cleared deduplication key: #{dedup_key}")
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[JobDeduplicator] Redis error clearing '#{@job_name}': #{e.message}"
    )
  end

  # Check if job has been executed recently
  #
  # @return [Boolean] true if deduplication key exists
  #
  def executed_recently?
    dedup_key = build_deduplication_key
    @redis.exists?(dedup_key)
  rescue Redis::BaseError => e
    Rails.logger.error(
      "[JobDeduplicator] Redis error checking existence for '#{@job_name}': #{e.message}"
    )
    false
  end

  # Get time until deduplication window expires
  #
  # @return [Integer] Seconds until job can be executed again
  #
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

  # Get deduplication info
  #
  # @return [Hash] Current deduplication status
  #
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

  # Build deduplication key
  #
  # Key format: "job_dedup:{job_name}:{param_values}:{time_bucket}"
  # Time bucket groups executions within the same window
  #
  # @return [String] Redis key for deduplication
  #
  def build_deduplication_key
    # Create time bucket to group jobs in same window
    time_bucket = (Time.current.to_i / @window).floor

    # Build param string from sorted params
    param_string = @params.map { |k, v| "#{k}:#{v}" }.join(':')

    "job_dedup:#{@job_name}:#{param_string}:#{time_bucket}"
  end

  # Log when job is unique and will execute
  #
  def log_unique_job(dedup_key)
    Rails.logger.debug(
      "[JobDeduplicator] Unique job detected: '#{@job_name}' with params #{@params.inspect}. " \
      "Dedup key: #{dedup_key}"
    )
  end

  # Log when duplicate job is detected
  #
  def log_duplicate_job(dedup_key)
    ttl = time_until_executable

    Rails.logger.info(
      "[JobDeduplicator] Duplicate job detected: '#{@job_name}' with params #{@params.inspect}. " \
      "Skipping. Window expires in #{ttl}s. Dedup key: #{dedup_key}"
    )

    # Structured log for monitoring
    Rails.logger.info({
      event: 'duplicate_job_skipped',
      job_name: @job_name,
      params: @params,
      window: @window,
      ttl: ttl,
      dedup_key: dedup_key,
      timestamp: Time.current.iso8601
    }.to_json)
  end
end
