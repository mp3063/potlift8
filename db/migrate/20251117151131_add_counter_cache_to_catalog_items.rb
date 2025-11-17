class AddCounterCacheToCatalogItems < ActiveRecord::Migration[8.0]
  def change
    add_column :catalog_items, :catalog_item_attribute_values_count, :integer, default: 0, null: false

    # Backfill existing counts
    reversible do |dir|
      dir.up do
        # Use raw SQL for better performance on large datasets
        execute <<-SQL.squish
          UPDATE catalog_items
          SET catalog_item_attribute_values_count = (
            SELECT COUNT(*)
            FROM catalog_item_attribute_values
            WHERE catalog_item_attribute_values.catalog_item_id = catalog_items.id
          )
        SQL
      end
    end
  end
end
