# frozen_string_literal: true

# SyncBroadcastable
#
# Broadcasts Turbo Stream updates when a CatalogItem's sync_status changes.
# Delivers real-time updates to the catalog items page via ActionCable.
#
# Broadcasts two targets:
# 1. Individual sync cell — updates the badge/timestamp for a single row
# 2. Summary card — updates the aggregate sync counts in the header
#
# Uses broadcast_replace_to (synchronous) because the callback fires from
# background jobs (not web requests), so blocking is acceptable. The sync
# variant avoids an extra Solid Queue hop that fails with the async
# ActionCable adapter in development (process-bound in-memory subscriptions).
#
module SyncBroadcastable
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_sync_status, if: :saved_change_to_sync_status?
  end

  private

  def broadcast_sync_status
    broadcast_replace_to(
      catalog, "sync_status",
      target: "catalog_item_#{id}_sync",
      partial: "catalogs/catalog_item_sync_cell",
      locals: { catalog_item: self }
    )

    broadcast_replace_to(
      catalog, "sync_status",
      target: "sync_summary_#{catalog_id}",
      partial: "catalogs/sync_summary_card",
      locals: { catalog: catalog, sync_counts: compute_sync_counts }
    )
  end

  def compute_sync_counts
    items = catalog.catalog_items
    {
      synced: items.sync_synced.where("last_synced_at > ?", 1.hour.ago).count,
      outdated: items.sync_synced.where("last_synced_at <= ?", 1.hour.ago).count,
      failed: items.sync_failed.count,
      never: items.sync_never_synced.count
    }
  end
end
