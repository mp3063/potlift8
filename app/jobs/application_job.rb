# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # Deadlocks are transient and usually resolve on retry
  retry_on ActiveRecord::Deadlocked,
           wait: :exponentially_longer,
           attempts: 5

  retry_on ActiveRecord::ConnectionNotEstablished,
           wait: :exponentially_longer,
           attempts: 5

  retry_on ActiveRecord::LockWaitTimeout,
           wait: :exponentially_longer,
           attempts: 5

  retry_on Faraday::ConnectionFailed,
           wait: :exponentially_longer,
           attempts: 5

  retry_on Faraday::TimeoutError,
           wait: :exponentially_longer,
           attempts: 3

  # Most jobs are safe to ignore if the underlying records are no longer available
  # This prevents jobs from failing when records are deleted before processing
  discard_on ActiveJob::DeserializationError do |job, error|
    Rails.logger.warn(
      "Job discarded due to deserialization error: #{job.class.name} " \
      "(Job ID: #{job.job_id}). Error: #{error.message}"
    )
  end

  discard_on ActiveRecord::RecordNotFound do |job, error|
    Rails.logger.warn(
      "Job discarded - record not found: #{job.class.name} " \
      "(Job ID: #{job.job_id}). Error: #{error.message}"
    )
  end

  rescue_from StandardError do |exception|
    Rails.logger.error(
      "Job error in #{self.class.name} (Job ID: #{job_id}): " \
      "#{exception.class} - #{exception.message}\n" \
      "Backtrace:\n#{exception.backtrace.join("\n")}"
    )
    raise exception
  end

  around_perform do |job, block|
    start_time = Time.current
    job_name = job.class.name
    job_id = job.job_id
    queue_name = job.queue_name
    arguments = job.arguments.map { |arg| format_argument_for_log(arg) }.join(", ")

    Rails.logger.info(
      "Job started: #{job_name} (ID: #{job_id}, Queue: #{queue_name}) " \
      "with arguments: [#{arguments}]"
    )

    begin
      block.call
      duration = (Time.current - start_time).round(2)

      Rails.logger.info(
        "Job completed: #{job_name} (ID: #{job_id}) " \
        "Duration: #{duration}s"
      )
    rescue StandardError => e
      duration = (Time.current - start_time).round(2)

      Rails.logger.error(
        "Job failed: #{job_name} (ID: #{job_id}) " \
        "Duration: #{duration}s, Error: #{e.class} - #{e.message}"
      )
      raise e
    end
  end

  after_enqueue do |job|
    Rails.logger.info(
      "Job enqueued: #{job.class.name} (ID: #{job.job_id}, " \
      "Queue: #{job.queue_name}, Scheduled at: #{job.scheduled_at || 'immediately'})"
    )
  end

  class << self
    def high_priority
      queue_as :high_priority
    end

    def default_priority
      queue_as :default
    end

    def low_priority
      queue_as :low_priority
    end
  end

  private

  # Format a single job argument for logging.
  # - ActiveRecord objects → their id (no full attribute dump)
  # - Strings longer than 100 chars → truncated with byte size (prevents logging
  #   full file contents or other large payloads)
  # - Everything else → to_s
  def format_argument_for_log(arg)
    if arg.respond_to?(:id) && arg.class.respond_to?(:primary_key)
      arg.id.to_s
    elsif arg.is_a?(String) && arg.length > 100
      "#{arg[0, 100]}... (#{arg.bytesize} bytes)"
    else
      arg.to_s
    end
  end

  def retryable_error?(error)
    return true if error.is_a?(ActiveRecord::Deadlocked)
    return true if error.is_a?(ActiveRecord::ConnectionNotEstablished)
    return true if error.is_a?(ActiveRecord::LockWaitTimeout)
    return true if error.is_a?(Faraday::ConnectionFailed)
    return true if error.is_a?(Faraday::TimeoutError)

    false
  end

  def log_job_metric(metric_name, value, tags = {})
    Rails.logger.info(
      "Job metric: #{metric_name}=#{value} " \
      "job=#{self.class.name} job_id=#{job_id} #{tags.map { |k, v| "#{k}=#{v}" }.join(' ')}"
    )
  end
end
