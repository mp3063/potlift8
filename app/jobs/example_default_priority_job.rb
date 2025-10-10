# frozen_string_literal: true

# Example job demonstrating default priority queue usage
# Use this pattern for standard operations like:
# - Product updates
# - Email notifications
# - Routine data synchronization
class ExampleDefaultPriorityJob < ApplicationJob
  # Queue defaults to :default, but explicitly setting it for clarity
  queue_as :default

  # Define job logic
  def perform(*args)
    Rails.logger.info("Processing default-priority job with args: #{args.inspect}")

    # Example: Process product update
    # product = args.first
    # product.sync_with_external_system

    sleep 2

    Rails.logger.info("Default-priority job completed successfully")
  end
end
