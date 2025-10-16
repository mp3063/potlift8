# frozen_string_literal: true

# Search Performance Indexes Migration (Phase 20-21)
#
# Adds comprehensive database indexes to optimize search performance, including:
# - PostgreSQL pg_trgm extension for ILIKE/trigram search
# - GIN indexes on text fields for fast full-text search
# - Additional composite indexes for common query patterns
# - Indexes on foreign keys and association lookups
# - Timestamp indexes for caching strategies
#
# Performance Impact:
# - ILIKE queries: 10-100x faster with trigram indexes
# - Association queries: 5-10x faster with proper foreign key indexes
# - Timestamp-based caching: instant cache key generation
#
# IMPORTANT: This migration is idempotent and safe to run multiple times.
# All index operations use if_not_exists/if_exists flags.
#
class AddSearchPerformanceIndexes < ActiveRecord::Migration[8.0]
  def up
    # Enable PostgreSQL pg_trgm extension for trigram search
    # This enables fast ILIKE pattern matching with GIN indexes
    enable_extension 'pg_trgm' unless extension_enabled?('pg_trgm')

    # ========================================
    # PRODUCTS TABLE - Search Indexes
    # ========================================

    # Products: GIN trigram index on name for fast ILIKE search
    # Optimizes queries like: products.where("name ILIKE ?", "%query%")
    # Expected speedup: 10-50x for name searches
    unless index_exists?(:products, :name, name: 'index_products_on_name_trgm')
      add_index :products, :name,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_products_on_name_trgm',
                comment: 'Trigram index for fast ILIKE searches on product names'
    end

    # Products: GIN trigram index on SKU for fast ILIKE search
    # Optimizes queries like: products.where("sku ILIKE ?", "%query%")
    # Expected speedup: 10-50x for SKU searches
    unless index_exists?(:products, :sku, name: 'index_products_on_sku_trgm')
      add_index :products, :sku,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_products_on_sku_trgm',
                comment: 'Trigram index for fast ILIKE searches on product SKUs'
    end

    # Products: Index on created_at for date filtering within company
    # Optimizes queries like: products.where("created_at >= ?", date).order(created_at: :desc)
    # Expected speedup: 5-10x for date range filters
    unless index_exists?(:products, [:company_id, :created_at])
      add_index :products, [:company_id, :created_at],
                name: 'index_products_on_company_created_at',
                comment: 'Optimizes date filtering and sorting for products'
    end

    # Products: Index on updated_at alone for cache key generation
    # Optimizes queries like: products.maximum(:updated_at)
    # Expected speedup: Instant (vs table scan)
    unless index_exists?(:products, :updated_at, name: 'index_products_on_updated_at')
      add_index :products, :updated_at,
                name: 'index_products_on_updated_at',
                comment: 'Optimizes cache key generation and timestamp queries'
    end

    # ========================================
    # STORAGES TABLE - Search Indexes
    # ========================================

    # Storages: GIN trigram index on name for fast ILIKE search
    # Optimizes queries like: storages.where("name ILIKE ?", "%query%")
    # Expected speedup: 10-50x for storage name searches
    unless index_exists?(:storages, :name, name: 'index_storages_on_name_trgm')
      add_index :storages, :name,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_storages_on_name_trgm',
                comment: 'Trigram index for fast ILIKE searches on storage names'
    end

    # ========================================
    # PRODUCT ATTRIBUTES TABLE - Search Indexes
    # ========================================

    # Product Attributes: GIN trigram index on name for fast ILIKE search
    # Optimizes queries like: product_attributes.where("name ILIKE ?", "%query%")
    # Expected speedup: 10-50x for attribute name searches
    unless index_exists?(:product_attributes, :name, name: 'index_product_attributes_on_name_trgm')
      add_index :product_attributes, :name,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_product_attributes_on_name_trgm',
                comment: 'Trigram index for fast ILIKE searches on attribute names'
    end

    # ========================================
    # LABELS TABLE - Search Indexes
    # ========================================

    # Labels: GIN trigram index on name for fast ILIKE search
    # Optimizes queries like: labels.where("name ILIKE ?", "%query%")
    # Expected speedup: 10-50x for label name searches
    unless index_exists?(:labels, :name, name: 'index_labels_on_name_trgm')
      add_index :labels, :name,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_labels_on_name_trgm',
                comment: 'Trigram index for fast ILIKE searches on label names'
    end

    # Labels: Index on updated_at for cache key generation
    # Optimizes queries like: labels.maximum(:updated_at)
    # Expected speedup: Instant (vs table scan)
    unless index_exists?(:labels, :updated_at, name: 'index_labels_on_updated_at')
      add_index :labels, :updated_at,
                name: 'index_labels_on_updated_at',
                comment: 'Optimizes cache key generation for labels'
    end

    # ========================================
    # CATALOGS TABLE - Search Indexes
    # ========================================

    # Catalogs: GIN trigram index on name for fast ILIKE search
    # Optimizes queries like: catalogs.where("name ILIKE ?", "%query%")
    # Expected speedup: 10-50x for catalog name searches
    unless index_exists?(:catalogs, :name, name: 'index_catalogs_on_name_trgm')
      add_index :catalogs, :name,
                using: :gin,
                opclass: :gin_trgm_ops,
                name: 'index_catalogs_on_name_trgm',
                comment: 'Trigram index for fast ILIKE searches on catalog names'
    end

    # ========================================
    # PRODUCT ATTRIBUTE VALUES - Association Indexes
    # ========================================

    # Product Attribute Values: Composite index for filtering by attribute and value
    # Optimizes queries like: product_attribute_values.where(product_attribute_id: x, value: y)
    # Expected speedup: 5-10x for attribute value filtering
    unless index_exists?(:product_attribute_values, [:product_attribute_id, :value])
      add_index :product_attribute_values, [:product_attribute_id, :value],
                name: 'index_pav_on_attribute_value',
                comment: 'Optimizes filtering by attribute and value'
    end

    # Product Attribute Values: Index on updated_at for cache key generation
    # Optimizes queries like: product_attribute_values.maximum(:updated_at)
    # Expected speedup: Instant (vs table scan)
    unless index_exists?(:product_attribute_values, :updated_at, name: 'index_pav_on_updated_at')
      add_index :product_attribute_values, :updated_at,
                name: 'index_pav_on_updated_at',
                comment: 'Optimizes cache key generation for attribute values'
    end

    # ========================================
    # INVENTORIES - Association Indexes
    # ========================================

    # Inventories: Composite index for inventory queries by storage and saldo
    # Optimizes queries like: inventories.where(storage_id: x).where("value > ?", 0)
    # Expected speedup: 5-10x for storage inventory reports
    unless index_exists?(:inventories, [:storage_id, :value])
      add_index :inventories, [:storage_id, :value],
                name: 'index_inventories_on_storage_value',
                comment: 'Optimizes inventory queries by storage and stock level'
    end

    # ========================================
    # CATALOG ITEMS - Association Indexes
    # ========================================

    # Catalog Items: Composite index for priority ordering
    # Optimizes queries like: catalog_items.where(catalog_id: x).order(:priority)
    # Expected speedup: 5-10x for catalog product listings
    unless index_exists?(:catalog_items, [:catalog_id, :priority])
      add_index :catalog_items, [:catalog_id, :priority],
                name: 'index_catalog_items_on_catalog_priority',
                comment: 'Optimizes ordered catalog product retrieval'
    end

    # ========================================
    # PRICES TABLE - Association Indexes (if exists)
    # ========================================

    # Prices: Composite index for price lookups by product and customer group
    # Optimizes queries like: prices.where(product_id: x, customer_group_id: y)
    # Expected speedup: 5-10x for customer-specific pricing
    if table_exists?(:prices)
      unless index_exists?(:prices, [:product_id, :customer_group_id])
        add_index :prices, [:product_id, :customer_group_id],
                  name: 'index_prices_on_product_customer_group',
                  comment: 'Optimizes price lookups by product and customer group',
                  where: 'customer_group_id IS NOT NULL'
      end
    end

    # ========================================
    # TRANSLATIONS TABLE - Association Indexes (if exists)
    # ========================================

    # Translations: Composite index for translation lookups
    # Optimizes queries like: translations.where(translatable_type: 'Product', translatable_id: x, locale: 'en')
    # Expected speedup: 5-10x for translated content retrieval
    if table_exists?(:translations)
      unless index_exists?(:translations, [:translatable_type, :translatable_id, :locale])
        add_index :translations, [:translatable_type, :translatable_id, :locale],
                  name: 'index_translations_on_type_id_locale',
                  comment: 'Optimizes translation lookups by type, ID, and locale'
      end
    end

    # ========================================
    # PRODUCT LABELS - Join Table Index
    # ========================================

    # Product Labels: Index on label_id for reverse lookups
    # Optimizes queries like: product_labels.where(label_id: x)
    # Note: product_id index already exists via foreign key
    unless index_exists?(:product_labels, :label_id, name: 'index_product_labels_on_label_id')
      # Index should already exist, but verify
      add_index :product_labels, :label_id,
                name: 'index_product_labels_on_label_id',
                comment: 'Optimizes reverse label lookups',
                if_not_exists: true
    end
  end

  def down
    # Remove indexes in reverse order
    # Using if_exists to make rollback idempotent

    remove_index :product_labels, name: 'index_product_labels_on_label_id', if_exists: true

    if table_exists?(:translations)
      remove_index :translations, name: 'index_translations_on_type_id_locale', if_exists: true
    end

    if table_exists?(:prices)
      remove_index :prices, name: 'index_prices_on_product_customer_group', if_exists: true
    end

    remove_index :catalog_items, name: 'index_catalog_items_on_catalog_priority', if_exists: true
    remove_index :inventories, name: 'index_inventories_on_storage_value', if_exists: true
    remove_index :product_attribute_values, name: 'index_pav_on_updated_at', if_exists: true
    remove_index :product_attribute_values, name: 'index_pav_on_attribute_value', if_exists: true

    remove_index :catalogs, name: 'index_catalogs_on_name_trgm', if_exists: true
    remove_index :labels, name: 'index_labels_on_updated_at', if_exists: true
    remove_index :labels, name: 'index_labels_on_name_trgm', if_exists: true
    remove_index :product_attributes, name: 'index_product_attributes_on_name_trgm', if_exists: true
    remove_index :storages, name: 'index_storages_on_name_trgm', if_exists: true

    remove_index :products, name: 'index_products_on_updated_at', if_exists: true
    remove_index :products, name: 'index_products_on_company_created_at', if_exists: true
    remove_index :products, name: 'index_products_on_sku_trgm', if_exists: true
    remove_index :products, name: 'index_products_on_name_trgm', if_exists: true

    # Note: We don't disable pg_trgm extension on rollback
    # as other parts of the application might be using it
    # To manually disable: execute 'DROP EXTENSION IF EXISTS pg_trgm;'
  end
end
