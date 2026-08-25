# frozen_string_literal: true

class PerformanceMonitor
  DEFAULT_THRESHOLD = 5.0

  TRACK_MEMORY = ENV.fetch("TRACK_MEMORY", "false") == "true"

  class << self
    def track(operation_name, context: {}, threshold: DEFAULT_THRESHOLD)
      monitor = new(operation_name, context: context, threshold: threshold)
      monitor.track { yield }
    end

    def stats(operation_name)
      stats_key = "perf_stats:#{operation_name}"
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))

      data = redis.hgetall(stats_key)
      return nil if data.empty?

      {
        operation: operation_name,
        count: data["count"].to_i,
        total_duration: data["total_duration"].to_f.round(3),
        avg_duration: data["avg_duration"].to_f.round(3),
        min_duration: data["min_duration"].to_f.round(3),
        max_duration: data["max_duration"].to_f.round(3),
        slow_count: data["slow_count"].to_i,
        last_execution: data["last_execution"]
      }
    rescue Redis::BaseError => e
      Rails.logger.error(
        "[PerformanceMonitor] Redis error getting stats for '#{operation_name}': #{e.message}"
      )
      nil
    end

    def reset_stats(operation_name)
      stats_key = "perf_stats:#{operation_name}"
      redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
      redis.del(stats_key)
      Rails.logger.info("[PerformanceMonitor] Reset stats for '#{operation_name}'")
    rescue Redis::BaseError => e
      Rails.logger.error(
        "[PerformanceMonitor] Redis error resetting stats for '#{operation_name}': #{e.message}"
      )
    end
  end

  attr_reader :operation_name, :context, :threshold

  def initialize(operation_name, context: {}, threshold: DEFAULT_THRESHOLD)
    @operation_name = operation_name
    @context = context
    @threshold = threshold
    @redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

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

  def log_metrics(duration, memory_used, success:, error: nil)
    is_slow = duration >= @threshold

    metric_data = {
      event: "performance_metric",
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

    Rails.logger.info(metric_data.to_json)
  end

  def update_stats(duration, success:)
    stats_key = "perf_stats:#{@operation_name}"

    current_min = @redis.hget(stats_key, "min_duration")
    current_max = @redis.hget(stats_key, "max_duration")

    @redis.multi do |pipeline|
      pipeline.hincrby(stats_key, "count", 1)
      pipeline.hincrbyfloat(stats_key, "total_duration", duration)

      pipeline.hincrby(stats_key, "slow_count", 1) if duration >= @threshold

      pipeline.hset(stats_key, "min_duration", duration) if current_min.nil? || duration < current_min.to_f
      pipeline.hset(stats_key, "max_duration", duration) if current_max.nil? || duration > current_max.to_f

      pipeline.hset(stats_key, "last_execution", Time.current.iso8601)

      pipeline.expire(stats_key, 30.days.to_i)
    end

    count = @redis.hget(stats_key, "count").to_i
    total = @redis.hget(stats_key, "total_duration").to_f
    avg = total / count if count > 0
    @redis.hset(stats_key, "avg_duration", avg.round(3)) if avg
  rescue Redis::BaseError => e
    # Don't fail operation if stats update fails
    Rails.logger.error(
      "[PerformanceMonitor] Redis error updating stats for '#{@operation_name}': #{e.message}"
    )
  end

  def current_memory
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  rescue StandardError => e
    Rails.logger.error(
      "[PerformanceMonitor] Error getting memory usage: #{e.message}"
    )
    0
  end
end
