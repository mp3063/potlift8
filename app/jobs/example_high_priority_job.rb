# frozen_string_literal: true

# Example job demonstrating high-priority queue usage
# Use this pattern for time-sensitive operations like:
# - Real-time inventory synchronization
# - Critical catalog updates
# - Urgent notifications
class ExampleHighPriorityJob < ApplicationJob
  # Set queue to high priority
  queue_as :high_priority

  # Optional: Include monitoring concern for enhanced metrics
  # include JobMonitoring

  # Define job logic
  def perform(*args)
    # Example: Process urgent inventory update
    Rails.logger.info("Processing high-priority job with args: #{args.inspect}")

    # Simulate work
    sleep 1

    # Log completion
    Rails.logger.info("High-priority job completed successfully")
  end
end
