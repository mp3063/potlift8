class AddIndexForCatalogProductFiltering < ActiveRecord::Migration[8.0]
  def change
    add_index :catalog_items, :product_id,
              name: "index_catalog_items_on_product_id",
              if_not_exists: true,
              comment: "Optimizes product-to-catalog reverse lookups and LEFT JOIN filtering"
  end
end
