# frozen_string_literal: true

# Job Monitoring Concern
# Provides enhanced monitoring capabilities for background jobs
# including metrics tracking, performance analysis, and error reporting
module JobMonitoring
  extend ActiveSupport::Concern

  included do
    # Track job execution metrics
    around_perform :track_job_metrics
  end

  class_methods do
    # Get statistics for this job type
    def job_statistics(since: 24.hours.ago)
      {
        total_jobs: job_count(since: since),
        successful_jobs: successful_job_count(since: since),
        failed_jobs: failed_job_count(since: since),
        average_duration: average_job_duration(since: since),
        success_rate: job_success_rate(since: since)
      }
    end

    private

    def job_count(since:)
      # This would query Solid Queue's job records
      # Implementation depends on accessing Solid Queue's internal tables
      SolidQueue::Job.where(
        class_name: name,
        created_at: since..Time.current
      ).count
    rescue StandardError
      0
    end

    def successful_job_count(since:)
      SolidQueue::Job.where(
        class_name: name,
        created_at: since..Time.current,
        finished_at: since..Time.current
      ).where.not(failed_at: nil).count
    rescue StandardError
      0
    end

    def failed_job_count(since:)
      SolidQueue::FailedExecution.where(
        job_class: name,
        created_at: since..Time.current
      ).count
    rescue StandardError
      0
    end

    def average_job_duration(since:)
      # Calculate average duration from successful jobs
      jobs = SolidQueue::Job.where(
        class_name: name,
        created_at: since..Time.current
      ).where.not(finished_at: nil)

      return 0 if jobs.empty?

      total_duration = jobs.sum do |job|
        (job.finished_at - job.created_at).to_f
      end

      (total_duration / jobs.count).round(2)
    rescue StandardError
      0
    end

    def job_success_rate(since:)
      total = job_count(since: since)
      return 100.0 if total.zero?

      successful = successful_job_count(since: since)
      ((successful.to_f / total) * 100).round(2)
    rescue StandardError
      0.0
    end
  end

  private

  def track_job_metrics
    start_time = Time.current
    start_memory = memory_usage

    yield

    end_time = Time.current
    end_memory = memory_usage
    duration = (end_time - start_time).round(3)
    memory_delta = end_memory - start_memory

    log_performance_metrics(
      duration: duration,
      memory_delta: memory_delta,
      status: "success"
    )
  rescue StandardError => e
    duration = (Time.current - start_time).round(3)
    log_performance_metrics(
      duration: duration,
      memory_delta: 0,
      status: "failed",
      error: e.class.name
    )
    raise e
  end

  def log_performance_metrics(duration:, memory_delta:, status:, error: nil)
    metrics = {
      job_class: self.class.name,
      job_id: job_id,
      queue_name: queue_name,
      duration: duration,
      memory_delta_mb: (memory_delta / 1024.0 / 1024.0).round(2),
      status: status,
      timestamp: Time.current.iso8601
    }
    metrics[:error] = error if error

    Rails.logger.info("[Job Metrics] #{metrics.to_json}")
  end

  def memory_usage
    # Returns memory usage in bytes
    # This is a basic implementation; can be enhanced with more accurate metrics
    if RUBY_PLATFORM =~ /linux/
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    elsif RUBY_PLATFORM =~ /darwin/
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    else
      0
    end
  rescue StandardError
    0
  end
end
