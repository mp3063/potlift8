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
  include ProductBatchSync
  include ProductRelationships
  include ProductTranslations
  include ProductDuplication
  include SyncLockable
  include ChangePropagator

  # Version tracking with PaperTrail
  has_paper_trail on: [ :update, :destroy ],
                  ignore: [ :updated_at ],
                  meta: {
                    company_id: :company_id
                  }

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

  # ActiveStorage associations
  # Multiple images can be attached to a product for product detail pages
  # Images are ordered by attachment ID (creation order) via config/initializers/active_storage_ordering.rb
  has_many_attached :images

  # Catalog associations
  has_many :catalog_items, dependent: :destroy
  has_many :catalogs, through: :catalog_items

  # Product Configuration associations (for configurable and bundle products)
  # When this product is the superproduct (parent)
  has_many :product_configurations_as_super,
           class_name: "ProductConfiguration",
           foreign_key: "superproduct_id",
           dependent: :destroy
  has_many :subproducts, through: :product_configurations_as_super, source: :subproduct

  # When this product is the subproduct (child)
  has_many :product_configurations_as_sub,
           class_name: "ProductConfiguration",
           foreign_key: "subproduct_id",
           dependent: :destroy,
           counter_cache: :subproducts_count
  has_many :superproducts, through: :product_configurations_as_sub, source: :superproduct

  # Configuration associations (Phase 14-16)
  has_many :configurations, dependent: :destroy

  # Related product associations (Phase 14-16)
  has_many :related_products, dependent: :destroy
  has_many :related_to_products, class_name: "RelatedProduct", foreign_key: "related_to_id", dependent: :destroy

  # Translation associations (Phase 17-19)
  has_many :translations, as: :translatable, dependent: :destroy

  # Pricing associations (Phase 17-19)
  has_many :prices, dependent: :destroy

  # Bundle template relationship
  has_one :bundle_template, dependent: :destroy

  # Generated variants relationship (this bundle is the parent)
  has_many :bundle_variants,
           class_name: "Product",
           foreign_key: "parent_bundle_id",
           dependent: :destroy

  # Parent bundle relationship (this product is a generated variant)
  belongs_to :parent_bundle,
             class_name: "Product",
             optional: true

  # Validations
  validates :company, presence: true
  validates :sku, presence: true, uniqueness: { scope: :company_id, case_sensitive: false, conditions: -> { where.not(product_status: :deleted) } }
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
  scope :bundle_variants, -> { where(bundle_variant: true) }
  scope :not_bundle_variants, -> { where(bundle_variant: false) }

  # Parent products only - excludes:
  # 1. Products that are subproducts of configurable/bundle products (via ProductConfiguration)
  # 2. Bundle variants (products generated from bundle templates with parent_bundle_id set)
  # Use when: Displaying product listing with hierarchical view (parent products with expandable children)
  # This filters out variant products that are managed as children of configurable/bundle products
  scope :parent_products_only, -> {
    where.not(id: ProductConfiguration.select(:subproduct_id))
         .where(bundle_variant: false)
  }

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
  # Note: Includes both the through association (:subproducts) and the intermediate
  # association (product_configurations_as_super: :subproduct) for Bullet compatibility
  scope :with_subproducts, -> {
    includes(:subproducts, product_configurations_as_super: :subproduct)
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

  # Performance-Optimized Search Scopes (Phase 20-21)
  #
  # These scopes leverage PostgreSQL trigram indexes for fast ILIKE searches.
  # Expected performance: 10-50x faster than non-indexed ILIKE queries.
  #

  # Search-optimized scope for full product data with all associations
  # Use when: Displaying search results with complete product information
  # Prevents: All N+1 queries on product associations
  # Warning: Heavy query, use with pagination
  scope :with_search_associations, -> {
    includes(
      :labels,
      :inventories,
      product_attribute_values: :product_attribute
    )
  }

  # Minimal eager loading for product listing pages
  # Use when: Displaying product tables with basic info
  # Prevents: N+1 queries on labels only
  scope :with_labels_only, -> {
    includes(:labels)
  }

  # Comprehensive eager loading for catalog item pages
  # Use when: Displaying products in catalog context
  # Prevents: N+1 queries on catalog associations
  scope :with_catalog_associations, -> {
    includes(
      :labels,
      :catalog_items,
      catalog_items: :catalog
    )
  }

  # Eager loading for price calculations
  # Use when: Displaying products with pricing information
  # Prevents: N+1 queries on prices and customer groups
  scope :with_pricing, -> {
    includes(prices: :customer_group)
  }

  # Eager loading for translations
  # Use when: Displaying products with multi-language support
  # Prevents: N+1 queries on translations
  scope :with_translations, -> {
    includes(:translations)
  }

  # Readonly scope for reporting and analytics
  # Use when: Generating reports where updates aren't needed
  # Performance: Skips dirty tracking, ~10% faster
  scope :readonly_records, -> {
    readonly
  }

  # Callbacks
  before_validation :generate_sku_if_missing
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
    pav.value.presence || pav.info["value"]
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
  # Note: For optimal performance, use Product.with_attributes scope when
  # calling this method on multiple products to avoid N+1 queries.
  #
  def attribute_values_hash
    # Use the already-loaded association if available, otherwise load with includes
    pavs = if product_attribute_values.loaded?
             product_attribute_values
    else
             product_attribute_values.includes(:product_attribute)
    end

    pavs.each_with_object({}) do |pav, hash|
      code = pav.product_attribute.code
      hash[code] = pav.value.presence || pav.info["value"]
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

  # Check if product is active (alias for product_status_active?)
  #
  # @return [Boolean] true if product status is active
  #
  def active?
    product_status_active?
  end

  # Virtual attribute for form checkbox
  # Maps to product_status enum (active = true, anything else = false)
  #
  # @return [Boolean] true if status is active
  #
  def active
    product_status_active?
  end

  # Virtual attribute setter for form checkbox
  # Sets product_status to active if truthy, draft if falsy
  #
  # @param value [Boolean, String] Checkbox value
  #
  def active=(value)
    self.product_status = ActiveModel::Type::Boolean.new.cast(value) ? :active : :draft
  end

  # Get product description from info JSONB field
  #
  # @return [String, nil] Description or nil
  #
  def description
    info&.dig("description")
  end

  # Set product description in info JSONB field
  #
  # @param value [String] Description text
  #
  def description=(value)
    self.info ||= {}
    self.info["description"] = value
  end

  private

  # Generate SKU if not provided
  # Uses format: PRD_XXXXXXXX (8 random hex characters)
  def generate_sku_if_missing
    return if sku.present?
    return unless company.present? # Need company for uniqueness check

    self.sku = generate_unique_sku("PRD")
  end

  # Normalize SKU by stripping whitespace and converting to uppercase
  def normalize_sku
    self.sku = sku.to_s.strip.upcase if sku.present?
  end

  # Generate a unique SKU with the given prefix
  #
  # Appends a random hexadecimal suffix to ensure uniqueness within the company.
  # Loops until a unique SKU is found.
  #
  # @param prefix [String] The SKU prefix (e.g., "PRD", "ORIG_COPY")
  # @return [String] A unique SKU for this company
  #
  # @example
  #   generate_unique_sku("PRD") # => "PRD_A1B2C3D4"
  #   generate_unique_sku("ORIG_COPY") # => "ORIG_COPY_E5F6G7H8"
  #
  def generate_unique_sku(prefix)
    loop do
      candidate = "#{prefix}_#{SecureRandom.hex(4).upcase}"
      break candidate unless company.products.exists?(sku: candidate)
    end
  end
end
