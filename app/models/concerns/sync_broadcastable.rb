# frozen_string_literal: true

# Broadcasts two targets:
# 1. Individual sync cell — updates the badge/timestamp for a single row
# 2. Summary card — updates the aggregate sync counts in the header
# Uses broadcast_replace_to (synchronous) because the callback fires from
# background jobs (not web requests), so blocking is acceptable. The sync
# variant avoids an extra Solid Queue hop that fails with the async
# ActionCable adapter in development (process-bound in-memory subscriptions).
module SyncBroadcastable
  extend ActiveSupport::Concern

  included do
    after_update_commit :broadcast_sync_status, if: :saved_change_to_sync_status?
  end

  private

  def broadcast_sync_status
    [ catalog, product ].each do |streamable|
      broadcast_replace_to(
        streamable, "sync_status",
        target: "catalog_item_#{id}_sync",
        partial: "catalogs/catalog_item_sync_cell",
        locals: { catalog_item: self }
      )
    end

    catalog.broadcast_sync_summary
  end
end
