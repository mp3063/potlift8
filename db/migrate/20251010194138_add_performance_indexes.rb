# Performance Indexes Migration
#
# Adds composite indexes to improve query performance for common access patterns.
# These indexes are designed to optimize:
# - Product filtering by company, status, and type
# - Product sorting by updated_at within company scope
# - Inventory lookups and calculations
# - Product attribute value searches
# - Label hierarchy traversal and filtering
#
# Index Design Rationale:
# 1. Composite indexes follow the "equality first, range second" principle
# 2. Index column order matches common WHERE/ORDER BY patterns
# 3. Covering indexes reduce the need for table lookups
#
class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def up
    # Products: Composite index for filtering by company, status, and type
    # Optimizes queries like: Product.for_company(id).active_products.sellable_products
    # This index supports queries with any combination of these three columns
    add_index :products, [:company_id, :product_status, :product_type],
              name: 'index_products_on_company_status_type',
              comment: 'Optimizes product filtering by company, status, and type',
              if_not_exists: true

    # Products: Composite index for sorting by updated_at within company
    # Optimizes queries like: Product.for_company(id).order(updated_at: :desc)
    # Common for "recently updated products" listings
    add_index :products, [:company_id, :updated_at],
              name: 'index_products_on_company_updated_at',
              comment: 'Optimizes product sorting by updated_at within company scope',
              if_not_exists: true

    # Inventories: Composite index for inventory calculations and filtering
    # Optimizes queries like: Inventory.for_product(id).with_stock
    # The value column inclusion enables covering index optimization
    add_index :inventories, [:product_id, :storage_id, :value],
              name: 'index_inventories_on_product_storage_value',
              comment: 'Optimizes inventory lookups and saldo calculations',
              if_not_exists: true

    # Product Attribute Values: Composite index for attribute value lookups
    # Optimizes queries like: ProductAttributeValue.where(product_id: x, product_attribute_id: y)
    # Note: There's already a unique index on [product_id, product_attribute_id] named 'pavs_index'
    # Adding value column for covering index benefits on searches
    add_index :product_attribute_values, [:product_id, :product_attribute_id, :value],
              name: 'index_pav_on_product_attribute_value',
              comment: 'Optimizes product attribute value searches with covering index',
              if_not_exists: true

    # Labels: Composite index for label hierarchy and filtering
    # Optimizes queries like: Label.where(company_id: x, label_type: 'category').root_labels
    # Supports fast traversal of label trees and filtering by type
    add_index :labels, [:company_id, :label_type, :parent_label_id],
              name: 'index_labels_on_company_type_parent',
              comment: 'Optimizes label filtering and hierarchy traversal',
              if_not_exists: true
  end

  def down
    # Remove indexes in reverse order
    remove_index :labels, name: 'index_labels_on_company_type_parent', if_exists: true
    remove_index :product_attribute_values, name: 'index_pav_on_product_attribute_value', if_exists: true
    remove_index :inventories, name: 'index_inventories_on_product_storage_value', if_exists: true
    remove_index :products, name: 'index_products_on_company_updated_at', if_exists: true
    remove_index :products, name: 'index_products_on_company_status_type', if_exists: true
  end
end
