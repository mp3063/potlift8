# frozen_string_literal: true

# PerformanceMonitor Service
#
# Tracks and logs performance metrics for operations with detailed timing,
# memory usage, and slow operation detection.
#
# Features:
# - Operation timing with high precision
# - Memory usage tracking (optional)
# - Slow operation detection with configurable thresholds
# - Structured logging for monitoring/alerting
# - Nested operation support
# - Statistics aggregation
#
# Usage:
#   # Basic timing
#   result = PerformanceMonitor.track('sync_product') do
#     ProductSyncService.new(product, catalog).sync_to_external_system
#   end
#
#   # With context
#   PerformanceMonitor.track('batch_sync', context: { product_count: 100 }) do
#     BatchProductSyncJob.perform_now(product_ids, catalog_id)
#   end
#
#   # With custom threshold
#   PerformanceMonitor.track('api_call', threshold: 2.0) do
#     HTTParty.post(url, body: data)
#   end
#
# Monitoring:
#   - Logs all operations as structured JSON
#   - Warns on slow operations
#   - Tracks memory usage if enabled
#   - Provides statistics for analysis
#
class PerformanceMonitor
  # Default slow operation threshold in seconds
  DEFAULT_THRESHOLD = 5.0

  # Track memory usage by default
  TRACK_MEMORY = ENV.fetch('TRACK_MEMORY', 'false') == 'true'

  class << self
    # Track an operation's performance
    #
    # @param operation_name [String] Name of the operation
    # @param context [Hash] Additional context for logging
    # @param threshold [Float] Slow operation threshold in seconds
    # @yield Block to execute and measure
    # @return [Object] Result of the yielded block
    #
    def track(operation_name, context: {}, threshold: DEFAULT_THRESHOLD)
      monitor = new(operation_name, context: context, threshold: threshold)
      monitor.track { yield }
    end

    # Get statistics for an operation
    #
    # @param operation_name [String] Name of the operation
    # @return [Hash] Statistics for the operation
    #
    def stats(operation_name)
      stats_key = "perf_stats:#{operation_name}"
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))

      data = redis.hgetall(stats_key)
      return nil if data.empty?

      {
        operation: operation_name,
        count: data['count'].to_i,
        total_duration: data['total_duration'].to_f.round(3),
        avg_duration: data['avg_duration'].to_f.round(3),
        min_duration: data['min_duration'].to_f.round(3),
        max_duration: data['max_duration'].to_f.round(3),
        slow_count: data['slow_count'].to_i,
        last_execution: data['last_execution']
      }
    rescue Redis::BaseError => e
      Rails.logger.error(
        "[PerformanceMonitor] Redis error getting stats for '#{operation_name}': #{e.message}"
      )
      nil
    end

    # Reset statistics for an operation
    #
    # @param operation_name [String] Name of the operation
    #
    def reset_stats(operation_name)
      stats_key = "perf_stats:#{operation_name}"
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
      redis.del(stats_key)
      Rails.logger.info("[PerformanceMonitor] Reset stats for '#{operation_name}'")
    rescue Redis::BaseError => e
      Rails.logger.error(
        "[PerformanceMonitor] Redis error resetting stats for '#{operation_name}': #{e.message}"
      )
    end
  end

  attr_reader :operation_name, :context, :threshold

  # Initialize performance monitor
  #
  # @param operation_name [String] Name of the operation to track
  # @param context [Hash] Additional context information
  # @param threshold [Float] Slow operation threshold in seconds
  #
  def initialize(operation_name, context: {}, threshold: DEFAULT_THRESHOLD)
    @operation_name = operation_name
    @context = context
    @threshold = threshold
    @redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
  end

  # Track operation performance
  #
  # @yield Block to execute and measure
  # @return [Object] Result of the yielded block
  #
  def track
    start_time = Time.current
    start_memory = current_memory if TRACK_MEMORY

    result = yield

    duration = (Time.current - start_time).round(3)
    memory_used = TRACK_MEMORY ? (current_memory - start_memory) : nil

    log_metrics(duration, memory_used, success: true)
    update_stats(duration, success: true)

    result
  rescue StandardError => e
    duration = (Time.current - start_time).round(3)
    memory_used = TRACK_MEMORY ? (current_memory - start_memory) : nil

    log_metrics(duration, memory_used, success: false, error: e)
    update_stats(duration, success: false)

    raise e
  end

  private

  # Log performance metrics
  #
  def log_metrics(duration, memory_used, success:, error: nil)
    is_slow = duration >= @threshold

    metric_data = {
      event: 'performance_metric',
      operation: @operation_name,
      duration_seconds: duration,
      threshold_seconds: @threshold,
      slow: is_slow,
      success: success,
      timestamp: Time.current.iso8601
    }

    metric_data.merge!(@context) if @context.any?
    metric_data[:memory_mb] = (memory_used / 1024.0 / 1024.0).round(2) if memory_used
    metric_data[:error_class] = error.class.name if error
    metric_data[:error_message] = error.message if error

    # Log based on severity
    if !success
      Rails.logger.error(
        "[PerformanceMonitor] FAILED: #{@operation_name} failed after #{duration}s"
      )
    elsif is_slow
      Rails.logger.warn(
        "[PerformanceMonitor] SLOW: #{@operation_name} took #{duration}s " \
        "(threshold: #{@threshold}s)"
      )
    else
      Rails.logger.debug(
        "[PerformanceMonitor] #{@operation_name} completed in #{duration}s"
      )
    end

    # Structured log for monitoring
    Rails.logger.info(metric_data.to_json)
  end

  # Update operation statistics in Redis
  #
  def update_stats(duration, success:)
    stats_key = "perf_stats:#{@operation_name}"

    # Fetch current values before pipeline for conditional logic
    current_min = @redis.hget(stats_key, 'min_duration')
    current_max = @redis.hget(stats_key, 'max_duration')

    @redis.multi do |pipeline|
      pipeline.hincrby(stats_key, 'count', 1)
      pipeline.hincrbyfloat(stats_key, 'total_duration', duration)

      # Track slow operations
      pipeline.hincrby(stats_key, 'slow_count', 1) if duration >= @threshold

      # Update min/max durations (check before pipeline)
      pipeline.hset(stats_key, 'min_duration', duration) if current_min.nil? || duration < current_min.to_f
      pipeline.hset(stats_key, 'max_duration', duration) if current_max.nil? || duration > current_max.to_f

      # Track last execution
      pipeline.hset(stats_key, 'last_execution', Time.current.iso8601)

      # Set expiration (30 days)
      pipeline.expire(stats_key, 30.days.to_i)
    end

    # Calculate and update average after pipeline completes
    # This is more accurate since count and total have been updated
    count = @redis.hget(stats_key, 'count').to_i
    total = @redis.hget(stats_key, 'total_duration').to_f
    avg = total / count if count > 0
    @redis.hset(stats_key, 'avg_duration', avg.round(3)) if avg
  rescue Redis::BaseError => e
    # Don't fail operation if stats update fails
    Rails.logger.error(
      "[PerformanceMonitor] Redis error updating stats for '#{@operation_name}': #{e.message}"
    )
  end

  # Get current memory usage in bytes
  #
  # @return [Integer] Current memory usage
  #
  def current_memory
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  rescue StandardError => e
    Rails.logger.error(
      "[PerformanceMonitor] Error getting memory usage: #{e.message}"
    )
    0
  end
end
