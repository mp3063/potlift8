# SyncLock Model
#
# This model tracks synchronization operations to external systems.
# Each sync_lock record represents a unique sync operation identified by a timestamp string.
#
# Usage:
# - Products and Catalogs reference this via sync_lock_id
# - The timestamp field stores a string identifier for the sync operation (not a datetime)
# - Typically used to group records that were synced together in a single operation
#
# Example:
#   sync_lock = SyncLock.create!(timestamp: "2025-10-10-1500")
#   product.update!(sync_lock_id: sync_lock.id)
#
class SyncLock < ApplicationRecord
  validates :timestamp, presence: true
end
