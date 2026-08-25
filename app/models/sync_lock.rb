# The timestamp field serves dual purposes:
# 1. Historical sync tracking: Stores a string identifier for completed sync operations (e.g., "2025-10-10-1500")
# 2. Distributed locking: Stores resource identifiers for active locks (e.g., "product:123", "catalog:456")
class SyncLock < ApplicationRecord
  has_many :products, dependent: :nullify
  has_many :catalogs, dependent: :nullify

  validates :timestamp, presence: true, uniqueness: true

  LOCK_TIMEOUT = 5.minutes

  def active?
    updated_at >= LOCK_TIMEOUT.ago
  end

  def expired?
    !active?
  end

  def refresh!
    touch
  end

  def release!
    destroy
  end

  def self.acquire(resource_key)
    lock = find_by(timestamp: resource_key)

    if lock.nil?
      create!(timestamp: resource_key)
    elsif lock.expired?
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
  def self.cleanup_expired
    where("updated_at < ?", LOCK_TIMEOUT.ago).delete_all
  end
end
