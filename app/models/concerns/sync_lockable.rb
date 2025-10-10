# frozen_string_literal: true

# SyncLockable Concern
#
# Provides distributed locking functionality for models that need to sync to external systems.
# Prevents concurrent sync operations on the same resource, which could cause race conditions
# or duplicate operations in external systems (Shopify3, Bizcart).
#
# Lock Mechanism:
# - Uses SyncLock model with timestamp field as resource identifier
# - Lock timeout: 5 minutes (defined in SyncLock::LOCK_TIMEOUT)
# - Automatic lock cleanup on success or failure
# - Expired locks can be safely acquired by new processes
#
# Usage in models:
#   class Product < ApplicationRecord
#     include SyncLockable
#   end
#
#   result = product.with_sync_lock do
#     # Perform sync operation
#     # This code only runs if lock is acquired
#   end
#
# Error Handling:
# - Returns SyncLockResult object with success/failure status
# - Automatically releases lock on completion or error
# - Logs all sync operations and errors
#
module SyncLockable
  extend ActiveSupport::Concern

  # Custom error class for sync lock failures
  class SyncLockError < StandardError; end

  # Result object for sync operations
  class SyncLockResult
    attr_reader :success, :error, :data

    def initialize(success:, error: nil, data: nil)
      @success = success
      @error = error
      @data = data
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end

  # Execute a block with a distributed lock on this resource
  #
  # Acquires a lock before executing the block and automatically releases it
  # when done. If the lock cannot be acquired (resource is already locked),
  # returns a failure result without executing the block.
  #
  # @yield The block to execute while holding the lock
  # @return [SyncLockResult] Result object with success status and optional data/error
  #
  # @example Successful sync
  #   result = product.with_sync_lock do
  #     # Perform sync operation
  #     { synced_at: Time.current }
  #   end
  #   result.success? # => true
  #   result.data # => { synced_at: ... }
  #
  # @example Lock already held
  #   result = product.with_sync_lock do
  #     # This won't execute if another process holds the lock
  #   end
  #   result.success? # => false
  #   result.error # => "Resource is currently locked by another process"
  #
  # @example Error during sync
  #   result = product.with_sync_lock do
  #     raise "API error"
  #   end
  #   result.success? # => false
  #   result.error # => "API error"
  #
  def with_sync_lock(&block)
    lock = nil
    resource_key = sync_lock_key

    begin
      # Try to acquire the lock
      lock = SyncLock.acquire(resource_key)

      if lock.nil?
        Rails.logger.warn(
          "[SyncLockable] Failed to acquire lock for #{resource_key} - already locked"
        )
        return SyncLockResult.new(
          success: false,
          error: "Resource is currently locked by another process"
        )
      end

      Rails.logger.info("[SyncLockable] Lock acquired for #{resource_key}")

      # Execute the block
      result_data = yield

      Rails.logger.info("[SyncLockable] Operation completed for #{resource_key}")

      SyncLockResult.new(success: true, data: result_data)

    rescue StandardError => e
      # Log the error
      Rails.logger.error(
        "[SyncLockable] Error during locked operation for #{resource_key}: #{e.message}\n" \
        "#{e.backtrace.first(5).join("\n")}"
      )

      SyncLockResult.new(success: false, error: e.message)

    ensure
      # Always release the lock, even if an error occurred
      if lock.present?
        begin
          lock.release!
          Rails.logger.info("[SyncLockable] Lock released for #{resource_key}")
        rescue StandardError => release_error
          Rails.logger.error(
            "[SyncLockable] Error releasing lock for #{resource_key}: #{release_error.message}"
          )
        end
      end
    end
  end

  # Check if this resource is currently locked
  #
  # @return [Boolean] true if resource has an active lock
  #
  # @example
  #   product.sync_locked? # => true if currently being synced
  #
  def sync_locked?
    lock = SyncLock.find_by(timestamp: sync_lock_key)
    lock.present? && lock.active?
  end

  # Get the time remaining on the current lock
  #
  # @return [Integer, nil] Seconds remaining, or nil if not locked
  #
  def sync_lock_time_remaining
    lock = SyncLock.find_by(timestamp: sync_lock_key)
    return nil unless lock.present? && lock.active?

    remaining = SyncLock::LOCK_TIMEOUT.to_i - (Time.current - lock.updated_at).to_i
    [remaining, 0].max
  end

  private

  # Generate the lock key for this resource
  # Format: "model_name:id"
  #
  # @return [String] The lock key
  #
  # @example
  #   product.send(:sync_lock_key) # => "product:123"
  #   catalog.send(:sync_lock_key) # => "catalog:456"
  #
  def sync_lock_key
    "#{self.class.name.downcase}:#{id}"
  end
end
