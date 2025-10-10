# frozen_string_literal: true

# Example job demonstrating low-priority queue usage
# Use this pattern for background maintenance tasks like:
# - Data cleanup
# - Report generation
# - Analytics processing
# - Bulk operations
class ExampleLowPriorityJob < ApplicationJob
  # Set queue to low priority
  queue_as :low_priority

  # Define job logic
  def perform(*args)
    Rails.logger.info("Processing low-priority job with args: #{args.inspect}")

    # Example: Generate daily report
    # Reports::DailyReportGenerator.new.generate

    sleep 5

    Rails.logger.info("Low-priority job completed successfully")
  end
end
