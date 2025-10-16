# Migration: Add Counter Caches for Performance Optimization
#
# Adds counter cache columns to reduce N+1 queries when displaying counts.
# Counter caches automatically maintain counts of associated records.
#
# Tables affected:
# - labels: Add products_count
# - catalogs: Add catalog_items_count
# - products: Add subproducts_count (for configurable/bundle products)
#
# Performance Impact:
# - Eliminates COUNT(*) queries when displaying product/catalog/label counts
# - Trades write overhead for read optimization (acceptable for read-heavy systems)
# - Reduces database load for list views and summary pages
#
class AddCounterCaches < ActiveRecord::Migration[8.0]
  def up
    # Add counter cache column for labels (products_count)
    add_column :labels, :products_count, :integer, default: 0, null: false
    add_index :labels, :products_count, comment: 'Optimizes label filtering by product count'

    # Add counter cache column for catalogs (catalog_items_count)
    add_column :catalogs, :catalog_items_count, :integer, default: 0, null: false
    add_index :catalogs, :catalog_items_count, comment: 'Optimizes catalog sorting by item count'

    # Add counter cache column for products (subproducts_count for configurable/bundle products)
    add_column :products, :subproducts_count, :integer, default: 0, null: false
    add_index :products, [:company_id, :subproducts_count],
              name: 'index_products_on_company_and_subproducts_count',
              comment: 'Optimizes queries for products with variants/components'

    # Backfill existing counts
    # Use update_all for batch updates to avoid callbacks and improve performance

    say_with_time "Backfilling labels.products_count" do
      Label.find_each do |label|
        # Count products with this label or any sublabel (includes descendants)
        label_ids = [label.id] + label.descendants.pluck(:id)
        count = ProductLabel.where(label_id: label_ids).distinct.count(:product_id)
        label.update_column(:products_count, count)
      end
    end

    say_with_time "Backfilling catalogs.catalog_items_count" do
      Catalog.find_each do |catalog|
        count = catalog.catalog_items.count
        catalog.update_column(:catalog_items_count, count)
      end
    end

    say_with_time "Backfilling products.subproducts_count" do
      Product.where(product_type: [:configurable, :bundle]).find_each do |product|
        count = product.subproducts.count
        product.update_column(:subproducts_count, count)
      end
    end
  end

  def down
    remove_index :labels, :products_count if index_exists?(:labels, :products_count)
    remove_column :labels, :products_count

    remove_index :catalogs, :catalog_items_count if index_exists?(:catalogs, :catalog_items_count)
    remove_column :catalogs, :catalog_items_count

    remove_index :products, name: 'index_products_on_company_and_subproducts_count' if index_exists?(:products, [:company_id, :subproducts_count], name: 'index_products_on_company_and_subproducts_count')
    remove_column :products, :subproducts_count
  end
end
