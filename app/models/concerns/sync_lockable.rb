# frozen_string_literal: true

# Provides distributed locking functionality for models that need to sync to external systems.
# Prevents concurrent sync operations on the same resource, which could cause race conditions
# or duplicate operations in external systems (Shopify3, Bizcart).
module SyncLockable
  extend ActiveSupport::Concern

  class SyncLockError < StandardError; end

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

  # Acquires a lock before executing the block and automatically releases it
  # when done. If the lock cannot be acquired (resource is already locked),
  # returns a failure result without executing the block.
  def with_sync_lock(&block)
    lock = nil
    resource_key = sync_lock_key

    begin
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

      result_data = yield

      Rails.logger.info("[SyncLockable] Operation completed for #{resource_key}")

      SyncLockResult.new(success: true, data: result_data)

    rescue StandardError => e
      Rails.logger.error(
        "[SyncLockable] Error during locked operation for #{resource_key}: #{e.message}\n" \
        "#{e.backtrace.first(5).join("\n")}"
      )

      SyncLockResult.new(success: false, error: e.message)

    ensure
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

  def sync_locked?
    lock = SyncLock.find_by(timestamp: sync_lock_key)
    lock.present? && lock.active?
  end

  def sync_lock_time_remaining
    lock = SyncLock.find_by(timestamp: sync_lock_key)
    return nil unless lock.present? && lock.active?

    remaining = SyncLock::LOCK_TIMEOUT.to_i - (Time.current - lock.updated_at).to_i
    [ remaining, 0 ].max
  end

  private

  def sync_lock_key
    "#{self.class.name.downcase}:#{id}"
  end
end
