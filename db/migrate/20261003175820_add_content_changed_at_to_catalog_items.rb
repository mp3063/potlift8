class AddContentChangedAtToCatalogItems < ActiveRecord::Migration[8.0]
  def change
    add_column :catalog_items, :content_changed_at, :datetime
  end
end
