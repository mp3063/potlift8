# frozen_string_literal: true

# Solid Queue Configuration and Initialization
# This initializer sets up Solid Queue for background job processing
# and configures monitoring, logging, and error handling

Rails.application.configure do
  # Solid Queue configuration is loaded from config/queue.yml
  # and config/database.yml for the queue database connection

  # Configure Solid Queue logging
  if defined?(SolidQueue)
    # Set log level for Solid Queue
    SolidQueue.logger = Rails.logger

    # Configure error handling for Solid Queue
    SolidQueue.on_thread_error = ->(error) do
      Rails.logger.error(
        "Solid Queue thread error: #{error.class} - #{error.message}\n" \
        "Backtrace:\n#{error.backtrace.join("\n")}"
      )

      # In production, you might want to send this to an error tracking service
      # Example: Sentry.capture_exception(error) if defined?(Sentry)
    end

    # Configure Solid Queue supervision
    # This controls how Solid Queue monitors and restarts workers
    SolidQueue.supervisor_pidfile = Rails.root.join("tmp/pids/solid_queue_supervisor.pid")

    # Log Solid Queue startup
    Rails.logger.info("Solid Queue initialized with configuration from config/queue.yml")
  end
end

# Set default queue for Active Job
ActiveJob::Base.queue_adapter = :solid_queue unless Rails.env.test?

# Configure queue name prefixes for different environments
# This helps separate jobs in shared queue infrastructure
ActiveJob::Base.queue_name_prefix = Rails.env.production? ? nil : "#{Rails.env}_"

# Log Active Job configuration
Rails.application.config.after_initialize do
  Rails.logger.info(
    "Active Job configured with adapter: #{ActiveJob::Base.queue_adapter.class.name}"
  )
  Rails.logger.info(
    "Queue name prefix: #{ActiveJob::Base.queue_name_prefix || 'none'}"
  )
end

# Health check endpoint data collector
# This can be used by monitoring systems to check queue health
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Schedule periodic health checks (every 5 minutes)
    # Note: This is a simple implementation; consider using a dedicated monitoring solution
    Thread.new do
      loop do
        begin
          sleep 300 # 5 minutes

          health_report = JobMonitoring::QueueHealthService.health_report
          if health_report[:overall_health][:status] == "critical"
            Rails.logger.error(
              "[Queue Health Check] CRITICAL: #{health_report[:overall_health][:errors].join(', ')}"
            )
          elsif health_report[:overall_health][:status] == "warning"
            Rails.logger.warn(
              "[Queue Health Check] WARNING: #{health_report[:overall_health][:warnings].join(', ')}"
            )
          else
            Rails.logger.info("[Queue Health Check] Status: healthy")
          end
        rescue StandardError => e
          Rails.logger.error(
            "Error in queue health check: #{e.class} - #{e.message}"
          )
        end
      end
    end
  end
end

# Configure job instrumentation for performance tracking
ActiveSupport::Notifications.subscribe("enqueue.active_job") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000 # Convert to milliseconds
  Rails.logger.debug(
    "[Job Enqueue] #{payload[:job].class.name} (Queue: #{payload[:job].queue_name}) " \
    "enqueued in #{duration.round(2)}ms"
  )
end

ActiveSupport::Notifications.subscribe("perform_start.active_job") do |name, start, finish, id, payload|
  Rails.logger.debug(
    "[Job Start] #{payload[:job].class.name} (ID: #{payload[:job].job_id}) started"
  )
end

ActiveSupport::Notifications.subscribe("perform.active_job") do |name, start, finish, id, payload|
  duration = (finish - start) * 1000 # Convert to milliseconds
  Rails.logger.debug(
    "[Job Complete] #{payload[:job].class.name} (ID: #{payload[:job].job_id}) " \
    "completed in #{duration.round(2)}ms"
  )
end
