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

  private

  # Normalize SKU by stripping whitespace and converting to uppercase
  def normalize_sku
    self.sku = sku.to_s.strip.upcase if sku.present?
  end
end
