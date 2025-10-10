# Product Model
#
# Core model representing products in the Potlift8 inventory management system.
# Products are multi-tenant and belong to a company. They support three product types
# and use the EAV pattern for flexible attributes.
#
# Product Types:
# - sellable (1): Regular products that can be sold directly
# - configurable (2): Products with variants or options (e.g., t-shirt with sizes)
# - bundle (3): Products composed of multiple other products
#
# Configuration Types (for configurable products):
# - variant (1): Products with variations (e.g., size, color)
# - option (2): Products with optional add-ons
#
# Product Statuses:
# - draft (0): Product in development, not ready for sale
# - active (1): Product available for sale
# - incoming (2): Product on order, not yet in stock
# - discontinuing (3): Product being phased out
# - disabled (4): Product temporarily unavailable
# - discontinued (6): Product permanently unavailable
# - deleted (999): Soft-deleted product
#
# JSONB Fields:
# - structure: Stores product configuration (variants, bundles, options)
# - info: Metadata and additional product information
# - cache: Cached calculated values (prices, inventory totals, etc.)
#
# EAV Pattern:
# Products use the Entity-Attribute-Value pattern via product_attribute_values
# for flexible, company-specific attributes. Use helper methods:
# - read_attribute_value(code) to retrieve attribute values
# - write_attribute_value(code, value) to set attribute values
#
class Product < ApplicationRecord
  include InventoryCalculator
  include ProductStateMachine
  include SyncLockable
  include ChangePropagator

  # Product Types
  enum :product_type, {
    sellable: 1,
    configurable: 2,
    bundle: 3
  }, prefix: true

  # Configuration Types (for configurable products)
  enum :configuration_type, {
    variant: 1,
    option: 2
  }, prefix: true

  # Product Statuses
  enum :product_status, {
    draft: 0,
    active: 1,
    incoming: 2,
    discontinuing: 3,
    disabled: 4,
    discontinued: 6,
    deleted: 999
  }, prefix: true

  # Associations
  belongs_to :company
  belongs_to :sync_lock, optional: true

  has_many :product_attribute_values, dependent: :destroy
  has_many :product_attributes, through: :product_attribute_values
  has_many :product_labels, dependent: :destroy
  has_many :labels, through: :product_labels
  has_many :inventories, dependent: :destroy
  has_many :storages, through: :inventories
  has_many :product_assets, dependent: :destroy

  # Catalog associations
  has_many :catalog_items, dependent: :destroy
  has_many :catalogs, through: :catalog_items

  # Product Configuration associations (for configurable and bundle products)
  # When this product is the superproduct (parent)
  has_many :product_configurations_as_super,
           class_name: 'ProductConfiguration',
           foreign_key: 'superproduct_id',
           dependent: :destroy
  has_many :subproducts, through: :product_configurations_as_super, source: :subproduct

  # When this product is the subproduct (child)
  has_many :product_configurations_as_sub,
           class_name: 'ProductConfiguration',
           foreign_key: 'subproduct_id',
           dependent: :destroy
  has_many :superproducts, through: :product_configurations_as_sub, source: :superproduct

  # Validations
  validates :company, presence: true
  validates :sku, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true
  validates :product_type, presence: true

  # Validate configuration_type only for configurable products
  validates :configuration_type, presence: true, if: :product_type_configurable?

  # Scopes
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :active_products, -> { where(product_status: :active) }
  scope :sellable_products, -> { where(product_type: :sellable) }
  scope :configurable_products, -> { where(product_type: :configurable) }
  scope :bundle_products, -> { where(product_type: :bundle) }
  scope :by_sku, ->(sku) { where(sku: sku) }
  scope :by_ean, ->(ean) { where(ean: ean) }

  # Performance-Optimized Scopes with Eager Loading
  #
  # These scopes use includes/preload to avoid N+1 queries when accessing associations.
  # Use these when you need to iterate over products and access their related data.
  #
  # Performance Guidelines:
  # - includes: Use when you'll filter or sort by association attributes
  # - preload: Use when you'll only access association data (no filtering/sorting)
  # - eager_load: Use when you need LEFT OUTER JOIN behavior
  #
  # Examples:
  #   Product.with_inventory.each { |p| p.inventories.sum(:value) } # No N+1
  #   Product.with_attributes.each { |p| p.attribute_values_hash } # No N+1
  #   Product.with_labels.each { |p| p.labels.pluck(:name) } # No N+1
  #

  # Eager load inventories with their storage information
  # Use when: Displaying product inventory across multiple storages
  # Prevents: N+1 queries on inventories and storages
  scope :with_inventory, -> {
    includes(inventories: :storage)
  }

  # Eager load product attribute values with product attributes
  # Use when: Displaying or filtering by product attributes
  # Prevents: N+1 queries on product_attribute_values and product_attributes
  scope :with_attributes, -> {
    includes(product_attribute_values: :product_attribute)
  }

  # Eager load product labels with label information
  # Use when: Displaying product categories, tags, or filtering by labels
  # Prevents: N+1 queries on product_labels and labels
  scope :with_labels, -> {
    includes(product_labels: :label)
  }

  # Eager load subproducts (variants/bundle components)
  # Use when: Displaying configurable products or bundles with their variants
  # Prevents: N+1 queries on product_configurations and subproducts
  scope :with_subproducts, -> {
    includes(product_configurations_as_super: :subproduct)
  }

  # Eager load superproducts (parent products)
  # Use when: Displaying variant products with their parent configurable product
  # Prevents: N+1 queries on product_configurations and superproducts
  scope :with_superproducts, -> {
    includes(product_configurations_as_sub: :superproduct)
  }

  # Comprehensive eager loading for product listing pages
  # Use when: Displaying full product details with all relationships
  # Warning: This loads a lot of data, use only when necessary
  scope :with_all_associations, -> {
    includes(
      :company,
      :product_assets,
      inventories: :storage,
      product_attribute_values: :product_attribute,
      product_labels: :label,
      product_configurations_as_super: :subproduct
    )
  }

  # Performance-optimized scope for inventory calculations
  # Preloads only the data needed for inventory sums
  scope :with_inventory_summary, -> {
    preload(:inventories)
  }

  # Scope for recent products sorted by updated_at
  # Uses the composite index (company_id, updated_at) for optimal performance
  scope :recently_updated, ->(limit = 10) {
    order(updated_at: :desc).limit(limit)
  }

  # Scope for products with specific status and type (uses composite index)
  # Optimized to use the index_products_on_company_status_type index
  scope :by_status_and_type, ->(status, type) {
    where(product_status: status, product_type: type)
  }

  # Callbacks
  before_validation :normalize_sku

  # EAV Helper Methods
  #
  # Read an attribute value by its code
  #
  # @param code [String] The attribute code to retrieve
  # @return [String, nil] The attribute value or nil if not found
  #
  # @example
  #   product.read_attribute_value('price') # => "1999"
  #   product.read_attribute_value('color') # => "blue"
  #
  def read_attribute_value(code)
    return nil if code.blank?

    pav = product_attribute_values.joins(:product_attribute)
                                  .find_by(product_attributes: { code: code })

    return nil unless pav

    # Return the value from the appropriate field based on attribute type
    pav.value.presence || pav.info['value']
  end

  # Write an attribute value by its code
  #
  # Creates or updates a product_attribute_value for the given attribute code.
  # The attribute must exist for this product's company.
  #
  # @param code [String] The attribute code to set
  # @param value [String, Object] The value to store
  # @return [Boolean] true if successful, false otherwise
  #
  # @example
  #   product.write_attribute_value('price', '1999')
  #   product.write_attribute_value('color', 'blue')
  #
  def write_attribute_value(code, value)
    return false if code.blank?

    # Find the attribute for this company
    attribute = company.product_attributes.find_by(code: code)
    return false unless attribute

    # Find or initialize the value record
    pav = product_attribute_values.find_or_initialize_by(product_attribute: attribute)

    # Store the value
    pav.value = value.to_s
    pav.save
  end

  # Get all attribute values as a hash
  #
  # @return [Hash] Hash of attribute codes to values
  #
  # @example
  #   product.attribute_values_hash # => { 'price' => '1999', 'color' => 'blue' }
  #
  def attribute_values_hash
    product_attribute_values.includes(:product_attribute).each_with_object({}) do |pav, hash|
      code = pav.product_attribute.code
      hash[code] = pav.value.presence || pav.info['value']
    end
  end

  # Check if product has a specific label
  #
  # @param label_code [String] The label code to check
  # @return [Boolean] true if product has the label
  #
  def has_label?(label_code)
    labels.exists?(code: label_code)
  end

  # Get total inventory across all storages
  #
  # @return [Integer] Total inventory value
  #
  def total_inventory
    inventories.sum(:value)
  end

  # Check if product is in stock
  #
  # @return [Boolean] true if total inventory > 0
  #
  def in_stock?
    total_inventory > 0
  end

  # Get the default storage inventory
  #
  # @return [Inventory, nil] The default inventory record
  #
  def default_inventory
    inventories.joins(:storage).find_by(storages: { default: true })
  end

  # Check if product is active and available
  #
  # @return [Boolean] true if product can be sold
  #
  def available?
    product_status_active? && in_stock?
  end

  # Product Relationship Helper Methods
  #
  # Check if this product has variants (is a configurable product with subproducts)
  #
  # @return [Boolean] true if product is configurable and has subproducts
  #
  # @example
  #   t_shirt.has_variants? # => true (configurable with size variants)
  #   bundle.has_variants? # => false (bundle, not configurable)
  #   simple_product.has_variants? # => false (sellable, not configurable)
  #
  def has_variants?
    product_type_configurable? && subproducts.any?
  end

  # Check if this product is a variant (is a subproduct of a configurable product)
  #
  # @return [Boolean] true if product is a subproduct of any superproduct
  #
  # @example
  #   size_small.is_variant? # => true (subproduct of t-shirt)
  #   t_shirt.is_variant? # => false (is the superproduct)
  #
  def is_variant?
    superproducts.any?
  end

  # Alias for subproducts to maintain compatibility with pot3
  #
  # @return [ActiveRecord::Associations::CollectionProxy] Collection of variant products
  #
  def variants
    subproducts
  end

  # Batch Sync Helper Methods
  #
  # Sync this product to all catalogs in batch
  #
  # @param queue [Symbol] Queue to use for batch job (:low_priority, :default, :high_priority)
  # @return [Array<BatchProductSyncJob>] Array of enqueued jobs
  #
  def sync_to_all_catalogs_batch(queue: :low_priority)
    catalog_ids = catalogs.pluck(:id)
    return [] if catalog_ids.empty?

    jobs = catalog_ids.map do |catalog_id|
      BatchProductSyncJob.set(queue: queue).perform_later([id], catalog_id)
    end

    Rails.logger.info(
      "Enqueued #{jobs.size} batch sync jobs for product #{id} (#{sku})"
    )

    jobs
  end

  # Sync to specific catalog with deduplication
  #
  # @param catalog [Catalog] Catalog to sync to
  # @param force [Boolean] Force sync even if recently synced
  # @return [Boolean] true if sync was enqueued
  #
  def sync_to_catalog(catalog, force: false)
    # Check deduplication unless forced
    unless force
      deduplicator = JobDeduplicator.new(
        job_name: 'ProductSyncJob',
        params: { product_id: id, catalog_id: catalog.id },
        window: 30
      )

      unless deduplicator.unique?
        Rails.logger.debug(
          "Skipping duplicate sync for product #{id} (#{sku}) to catalog #{catalog.code}"
        )
        return false
      end
    end

    ProductSyncJob.perform_later(self, catalog, Time.current)
    true
  end

  # Class method to batch sync multiple products
  #
  # @param product_ids [Array<Integer>] Product IDs to sync
  # @param catalog_id [Integer] Catalog ID to sync to
  # @param queue [Symbol] Queue to use
  # @return [BatchProductSyncJob] Enqueued job
  #
  def self.batch_sync_to_catalog(product_ids, catalog_id, queue: :low_priority)
    BatchProductSyncJob.set(queue: queue).perform_later(product_ids, catalog_id)
  end

  # Class method to schedule batch sync during off-peak hours
  #
  # @param product_ids [Array<Integer>] Product IDs to sync
  # @param catalog_id [Integer] Catalog ID to sync to
  # @param off_peak_hour [Integer] Hour to run (0-23, default: 2 AM)
  # @return [BatchProductSyncJob] Scheduled job
  #
  def self.schedule_batch_sync(product_ids, catalog_id, off_peak_hour: 2)
    # Calculate time until next off-peak hour
    now = Time.current
    target_time = now.change(hour: off_peak_hour, min: 0, sec: 0)
    target_time += 1.day if target_time <= now

    wait_seconds = (target_time - now).to_i

    Rails.logger.info(
      "Scheduling batch sync of #{product_ids.size} products to catalog #{catalog_id} " \
      "at #{target_time} (in #{wait_seconds / 3600.0} hours)"
    )

    BatchProductSyncJob.set(wait: wait_seconds, queue: :low_priority)
                       .perform_later(product_ids, catalog_id)
  end

  private

  # Normalize SKU by stripping whitespace and converting to uppercase
  def normalize_sku
    self.sku = sku.to_s.strip.upcase if sku.present?
  end
end
