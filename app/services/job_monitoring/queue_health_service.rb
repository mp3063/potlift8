# frozen_string_literal: true

module JobMonitoring
  # Service to monitor the health of Solid Queue
  # Provides insights into queue depth, processing rates, and worker status
  class QueueHealthService
    QUEUE_NAMES = %w[high_priority default low_priority].freeze

    class << self
      # Get comprehensive queue health report
      def health_report
        {
          timestamp: Time.current.iso8601,
          queues: queue_statistics,
          workers: worker_statistics,
          failed_jobs: failed_job_statistics,
          overall_health: calculate_overall_health
        }
      end

      # Get statistics for all queues
      def queue_statistics
        QUEUE_NAMES.map do |queue_name|
          {
            name: queue_name,
            pending_jobs: pending_jobs_count(queue_name),
            processing_jobs: processing_jobs_count(queue_name),
            scheduled_jobs: scheduled_jobs_count(queue_name),
            oldest_pending_job_age: oldest_pending_job_age(queue_name)
          }
        end
      end

      # Get worker pool statistics
      def worker_statistics
        {
          total_workers: total_workers_count,
          active_workers: active_workers_count,
          idle_workers: idle_workers_count
        }
      end

      # Get failed job statistics
      def failed_job_statistics
        {
          total_failed: total_failed_jobs,
          recent_failures: recent_failed_jobs(1.hour),
          failure_rate: calculate_failure_rate
        }
      end

      # Check if queue is healthy
      def healthy?
        health = calculate_overall_health
        health[:status] == "healthy"
      end

      # Alert if queue depth exceeds threshold
      def queue_depth_alert?(queue_name, threshold: 100)
        pending_jobs_count(queue_name) > threshold
      end

      private

      def pending_jobs_count(queue_name)
        SolidQueue::Job.where(queue_name: queue_name)
                       .where(finished_at: nil)
                       .where("scheduled_at IS NULL OR scheduled_at <= ?", Time.current)
                       .count
      rescue StandardError => e
        Rails.logger.error("Error counting pending jobs: #{e.message}")
        0
      end

      def processing_jobs_count(queue_name)
        SolidQueue::ClaimedExecution.joins(:job)
                                     .where(solid_queue_jobs: { queue_name: queue_name })
                                     .count
      rescue StandardError => e
        Rails.logger.error("Error counting processing jobs: #{e.message}")
        0
      end

      def scheduled_jobs_count(queue_name)
        SolidQueue::ScheduledExecution.joins(:job)
                                       .where(solid_queue_jobs: { queue_name: queue_name })
                                       .count
      rescue StandardError => e
        Rails.logger.error("Error counting scheduled jobs: #{e.message}")
        0
      end

      def oldest_pending_job_age(queue_name)
        oldest_job = SolidQueue::Job.where(queue_name: queue_name)
                                     .where(finished_at: nil)
                                     .order(created_at: :asc)
                                     .first

        return 0 unless oldest_job

        (Time.current - oldest_job.created_at).to_i
      rescue StandardError => e
        Rails.logger.error("Error finding oldest pending job: #{e.message}")
        0
      end

      def total_workers_count
        # This would depend on Solid Queue's worker tracking
        # For now, return configured worker count
        config = YAML.load_file(Rails.root.join("config/queue.yml"))
        env_config = config[Rails.env] || config["default"]
        env_config["workers"]&.sum { |w| w["processes"] || 1 } || 0
      rescue StandardError
        0
      end

      def active_workers_count
        # Count workers currently processing jobs
        SolidQueue::Process.where("last_heartbeat_at > ?", 1.minute.ago).count
      rescue StandardError
        0
      end

      def idle_workers_count
        total_workers_count - active_workers_count
      end

      def total_failed_jobs
        SolidQueue::FailedExecution.count
      rescue StandardError
        0
      end

      def recent_failed_jobs(time_period)
        SolidQueue::FailedExecution.where("created_at > ?", time_period.ago).count
      rescue StandardError
        0
      end

      def calculate_failure_rate
        total_jobs = SolidQueue::Job.where("created_at > ?", 1.hour.ago).count
        return 0.0 if total_jobs.zero?

        failed_jobs = recent_failed_jobs(1.hour)
        ((failed_jobs.to_f / total_jobs) * 100).round(2)
      rescue StandardError
        0.0
      end

      def calculate_overall_health
        warnings = []
        errors = []

        # Check queue depths
        QUEUE_NAMES.each do |queue_name|
          pending = pending_jobs_count(queue_name)
          if pending > 1000
            errors << "Queue #{queue_name} has #{pending} pending jobs (critical)"
          elsif pending > 100
            warnings << "Queue #{queue_name} has #{pending} pending jobs"
          end

          # Check oldest job age
          age = oldest_pending_job_age(queue_name)
          if age > 3600 # 1 hour
            warnings << "Oldest job in #{queue_name} is #{age}s old"
          end
        end

        # Check failure rate
        failure_rate = calculate_failure_rate
        if failure_rate > 10
          errors << "High failure rate: #{failure_rate}%"
        elsif failure_rate > 5
          warnings << "Elevated failure rate: #{failure_rate}%"
        end

        # Check worker availability
        active_workers = active_workers_count
        if active_workers.zero?
          errors << "No active workers detected"
        end

        status = if errors.any?
          "critical"
        elsif warnings.any?
          "warning"
        else
          "healthy"
        end

        {
          status: status,
          warnings: warnings,
          errors: errors
        }
      end
    end
  end
end
