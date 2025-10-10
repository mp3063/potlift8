# SyncLock Model
#
# This model tracks synchronization operations to external systems.
# Each sync_lock record represents a unique sync operation identified by a timestamp string.
#
# The timestamp field serves dual purposes:
# 1. Historical sync tracking: Stores a string identifier for completed sync operations (e.g., "2025-10-10-1500")
# 2. Distributed locking: Stores resource identifiers for active locks (e.g., "product:123", "catalog:456")
#
# Lock Lifecycle:
# - Active locks: timestamp contains resource identifier, updated_at is recent
# - Expired locks: updated_at is older than lock timeout (5 minutes)
# - Historical records: timestamp contains date-based sync identifier
#
# Usage:
# - Products and Catalogs reference this via sync_lock_id for historical tracking
# - SyncLockable concern uses timestamp field for distributed locking
# - Locks automatically expire after 5 minutes of inactivity
#
# Example Historical Sync:
#   sync_lock = SyncLock.create!(timestamp: "2025-10-10-1500")
#   product.update!(sync_lock_id: sync_lock.id)
#
# Example Distributed Lock:
#   lock = SyncLock.find_or_create_by!(timestamp: "product:123")
#   # Lock is active if updated_at is within last 5 minutes
#
class SyncLock < ApplicationRecord
  # Associations
  has_many :products, dependent: :nullify
  has_many :catalogs, dependent: :nullify

  # Validations
  validates :timestamp, presence: true, uniqueness: true

  # Lock timeout in seconds (5 minutes)
  LOCK_TIMEOUT = 5.minutes

  # Check if this lock is currently active (not expired)
  #
  # A lock is considered active if it was updated within the LOCK_TIMEOUT period.
  # Expired locks can be safely acquired by other processes.
  #
  # @return [Boolean] true if lock is active, false if expired
  #
  # @example
  #   lock = SyncLock.find_by(timestamp: "product:123")
  #   lock.active? # => true if updated within last 5 minutes
  #
  def active?
    updated_at >= LOCK_TIMEOUT.ago
  end

  # Check if this lock has expired
  #
  # @return [Boolean] true if lock has expired
  #
  def expired?
    !active?
  end

  # Refresh the lock by updating the timestamp
  # Extends the lock for another LOCK_TIMEOUT period
  #
  # @return [Boolean] true if successful
  #
  def refresh!
    touch
  end

  # Release the lock by deleting the record
  # Should be called when the locked operation completes
  #
  # @return [Boolean] true if successful
  #
  def release!
    destroy
  end

  # Find or create a lock for a specific resource
  #
  # @param resource_key [String] The resource identifier (e.g., "product:123")
  # @return [SyncLock, nil] The lock if available, nil if locked by another process
  #
  def self.acquire(resource_key)
    # Try to find existing lock
    lock = find_by(timestamp: resource_key)

    if lock.nil?
      # No lock exists, create new one
      create!(timestamp: resource_key)
    elsif lock.expired?
      # Lock exists but expired, refresh it
      lock.refresh!
      lock
    else
      # Lock is active, cannot acquire
      nil
    end
  rescue ActiveRecord::RecordNotUnique
    # Race condition: another process created the lock
    nil
  end

  # Clean up expired locks
  # Should be called periodically to prevent stale lock accumulation
  #
  # @return [Integer] Number of expired locks deleted
  #
  def self.cleanup_expired
    where("updated_at < ?", LOCK_TIMEOUT.ago).delete_all
  end
end
