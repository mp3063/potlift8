# frozen_string_literal: true

namespace :solid_queue do
  desc "Display Solid Queue health status"
  task health: :environment do
    report = JobMonitoring::QueueHealthService.health_report

    puts "\n" + "=" * 80
    puts "SOLID QUEUE HEALTH REPORT"
    puts "=" * 80
    puts "Timestamp: #{report[:timestamp]}"
    puts "\nOVERALL STATUS: #{report[:overall_health][:status].upcase}"

    if report[:overall_health][:errors].any?
      puts "\nERRORS:"
      report[:overall_health][:errors].each { |error| puts "  - #{error}" }
    end

    if report[:overall_health][:warnings].any?
      puts "\nWARNINGS:"
      report[:overall_health][:warnings].each { |warning| puts "  - #{warning}" }
    end

    puts "\nQUEUE STATISTICS:"
    puts "-" * 80
    report[:queues].each do |queue|
      puts "Queue: #{queue[:name]}"
      puts "  Pending: #{queue[:pending_jobs]}"
      puts "  Processing: #{queue[:processing_jobs]}"
      puts "  Scheduled: #{queue[:scheduled_jobs]}"
      puts "  Oldest pending job age: #{queue[:oldest_pending_job_age]}s"
      puts ""
    end

    puts "WORKER STATISTICS:"
    puts "-" * 80
    puts "Total workers: #{report[:workers][:total_workers]}"
    puts "Active workers: #{report[:workers][:active_workers]}"
    puts "Idle workers: #{report[:workers][:idle_workers]}"

    puts "\nFAILED JOB STATISTICS:"
    puts "-" * 80
    puts "Total failed: #{report[:failed_jobs][:total_failed]}"
    puts "Recent failures (1h): #{report[:failed_jobs][:recent_failures]}"
    puts "Failure rate: #{report[:failed_jobs][:failure_rate]}%"
    puts "=" * 80 + "\n"
  end

  desc "Display queue statistics for a specific queue (e.g., rake solid_queue:queue_stats[high_priority])"
  task :queue_stats, [:queue_name] => :environment do |_t, args|
    queue_name = args[:queue_name] || "default"

    puts "\n" + "=" * 80
    puts "QUEUE STATISTICS: #{queue_name}"
    puts "=" * 80

    pending = SolidQueue::Job.where(queue_name: queue_name)
                              .where(finished_at: nil)
                              .count

    processing = SolidQueue::ClaimedExecution.joins(:job)
                                              .where(solid_queue_jobs: { queue_name: queue_name })
                                              .count

    scheduled = SolidQueue::ScheduledExecution.joins(:job)
                                               .where(solid_queue_jobs: { queue_name: queue_name })
                                               .count

    puts "Pending jobs: #{pending}"
    puts "Processing jobs: #{processing}"
    puts "Scheduled jobs: #{scheduled}"
    puts "Total: #{pending + processing + scheduled}"
    puts "=" * 80 + "\n"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "List failed jobs with details"
  task failed_jobs: :environment do
    failed_jobs = SolidQueue::FailedExecution.order(created_at: :desc).limit(10)

    puts "\n" + "=" * 80
    puts "RECENT FAILED JOBS (Last 10)"
    puts "=" * 80

    if failed_jobs.empty?
      puts "No failed jobs found!"
    else
      failed_jobs.each_with_index do |job, index|
        puts "\n#{index + 1}. Job: #{job.job_class}"
        puts "   ID: #{job.job_id}"
        puts "   Error: #{job.error_class}"
        puts "   Message: #{job.error_message}"
        puts "   Failed at: #{job.created_at}"
        puts "   Attempts: #{job.executions_count}"
      end
    end

    puts "\n" + "=" * 80 + "\n"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "Retry all failed jobs"
  task retry_failed: :environment do
    failed_count = SolidQueue::FailedExecution.count

    if failed_count.zero?
      puts "No failed jobs to retry."
      exit
    end

    print "Found #{failed_count} failed jobs. Retry all? (y/n): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "y"
      retried = 0
      SolidQueue::FailedExecution.find_each do |failed_execution|
        failed_execution.retry
        retried += 1
      end
      puts "Successfully queued #{retried} jobs for retry."
    else
      puts "Retry cancelled."
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "Discard all failed jobs older than specified days (default: 30)"
  task :discard_old_failed, [:days] => :environment do |_t, args|
    days = (args[:days] || 30).to_i
    cutoff_date = days.days.ago

    old_failed = SolidQueue::FailedExecution.where("created_at < ?", cutoff_date)
    count = old_failed.count

    if count.zero?
      puts "No failed jobs older than #{days} days found."
      exit
    end

    print "Found #{count} failed jobs older than #{days} days. Discard them? (y/n): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "y"
      old_failed.destroy_all
      puts "Successfully discarded #{count} old failed jobs."
    else
      puts "Discard cancelled."
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "Monitor queue depth and alert if thresholds are exceeded"
  task monitor: :environment do
    puts "\n" + "=" * 80
    puts "QUEUE DEPTH MONITORING"
    puts "=" * 80

    %w[high_priority default low_priority].each do |queue_name|
      pending = SolidQueue::Job.where(queue_name: queue_name)
                                .where(finished_at: nil)
                                .count

      status = if pending > 1000
        "CRITICAL"
      elsif pending > 100
        "WARNING"
      else
        "OK"
      end

      puts "#{queue_name.ljust(20)} - #{pending.to_s.rjust(5)} jobs [#{status}]"
    end

    puts "=" * 80 + "\n"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "Display job performance statistics"
  task performance: :environment do
    puts "\n" + "=" * 80
    puts "JOB PERFORMANCE STATISTICS (Last 24 hours)"
    puts "=" * 80

    # Get all job classes that have been executed
    job_classes = SolidQueue::Job.where("created_at > ?", 24.hours.ago)
                                  .distinct
                                  .pluck(:class_name)

    job_classes.each do |job_class|
      jobs = SolidQueue::Job.where(class_name: job_class)
                             .where("created_at > ?", 24.hours.ago)
                             .where.not(finished_at: nil)

      next if jobs.empty?

      total_jobs = jobs.count
      durations = jobs.map { |job| (job.finished_at - job.created_at).to_f }
      avg_duration = (durations.sum / total_jobs).round(2)
      max_duration = durations.max.round(2)
      min_duration = durations.min.round(2)

      puts "\nJob: #{job_class}"
      puts "  Total executions: #{total_jobs}"
      puts "  Average duration: #{avg_duration}s"
      puts "  Min duration: #{min_duration}s"
      puts "  Max duration: #{max_duration}s"
    end

    puts "\n" + "=" * 80 + "\n"
  rescue StandardError => e
    puts "Error: #{e.message}"
  end

  desc "Clear completed jobs older than specified days (default: 7)"
  task :clear_completed, [:days] => :environment do |_t, args|
    days = (args[:days] || 7).to_i
    cutoff_date = days.days.ago

    old_jobs = SolidQueue::Job.where("finished_at < ?", cutoff_date)
    count = old_jobs.count

    if count.zero?
      puts "No completed jobs older than #{days} days found."
      exit
    end

    print "Found #{count} completed jobs older than #{days} days. Delete them? (y/n): "
    confirmation = STDIN.gets.chomp

    if confirmation.downcase == "y"
      old_jobs.delete_all
      puts "Successfully deleted #{count} old completed jobs."
    else
      puts "Delete cancelled."
    end
  rescue StandardError => e
    puts "Error: #{e.message}"
  end
end
