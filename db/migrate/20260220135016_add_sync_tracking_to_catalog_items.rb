class AddSyncTrackingToCatalogItems < ActiveRecord::Migration[8.0]
  def change
    add_column :catalog_items, :sync_status, :integer, default: 0, null: false
    add_column :catalog_items, :last_synced_at, :datetime
    add_column :catalog_items, :last_sync_error, :string

    add_index :catalog_items, :sync_status
    add_index :catalog_items, :last_synced_at
  end
end
