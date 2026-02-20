# CatalogItem Model
#
# Join table linking catalogs to products with catalog-specific configuration.
# Supports attribute overrides, priority ordering, and state management.
#
# States (catalog_item_state):
# - inactive (0): Product not visible in catalog
# - active (1): Product visible and available in catalog
#
# Priority Ordering:
# - Higher priority items appear first in catalog listings
# - Default scope orders by priority descending
#
# Catalog-Specific Attributes:
# - Catalog items can override product attribute values
# - Overrides are stored in CatalogItemAttributeValue records
# - Falls back to product values if no catalog override exists
#
# JSONB Fields (pot3 conventions):
# - info: Catalog-specific metadata and settings
#
class CatalogItem < ApplicationRecord
  # Associations
  belongs_to :catalog, counter_cache: :catalog_items_count
  belongs_to :product
  has_many :catalog_item_attribute_values, dependent: :destroy

  # Enums
  # NOTE: pot3 uses 'catalog_item_state', not 'state'
  enum :catalog_item_state, {
    inactive: 0,
    active: 1
  }

  enum :sync_status, {
    never_synced: 0,
    synced: 1,
    pending: 2,
    failed: 3
  }, prefix: :sync

  # Validations
  validates :catalog_id, uniqueness: { scope: :product_id }

  # Scopes
  default_scope { order(Arel.sql("catalog_items.priority DESC NULLS LAST")) }
  scope :active_items, -> { where(catalog_item_state: :active) }
  scope :inactive_items, -> { where(catalog_item_state: :inactive) }
  scope :by_priority, -> { reorder(Arel.sql("catalog_items.priority DESC NULLS LAST")) }

  # Check if product is ready for sale in this catalog
  # Validates product structure, mandatory attributes, and pricing
  #
  # @return [Boolean] true if product passes all validations
  #
  def sales_ready?
    validator = CatalogItemValidator.new(self)
    validator.valid?
  end

  # Get effective attribute value (catalog override or product value)
  # First checks for catalog-specific override, then falls back to product value
  #
  # @param attribute_code [String] The attribute code to retrieve
  # @return [String, nil] The effective attribute value or nil
  #
  # @example
  #   catalog_item.effective_attribute_value('price') # => "1999" (catalog override)
  #   catalog_item.effective_attribute_value('weight') # => "500" (product value)
  #
  def effective_attribute_value(attribute_code)
    attr = catalog.company.product_attributes.find_by(code: attribute_code)
    return nil unless attr

    # Check catalog-level override first
    ciav = catalog_item_attribute_values.find_by(product_attribute: attr)
    return ciav.value if ciav.present? && ciav.value.present?

    # Fall back to product-level value
    product.read_attribute_value(attribute_code)
  end

  # Write catalog-specific attribute override
  # Only works for attributes with catalog scope or product_and_catalog scope
  #
  # @param attribute_code [String] The attribute code to set
  # @param value [String, Object] The value to store
  # @return [Boolean] true if successful, false otherwise
  #
  # @example
  #   catalog_item.write_catalog_attribute_value('price', '1999')
  #   catalog_item.write_catalog_attribute_value('description', 'Special catalog text')
  #
  def write_catalog_attribute_value(attribute_code, value)
    attr = catalog.company.product_attributes.find_by(code: attribute_code)
    return false unless attr
    return false unless attr.catalog_scope? || attr.product_and_catalog_scope?

    ciav = catalog_item_attribute_values.find_or_initialize_by(product_attribute: attr)
    ciav.value = value.to_s
    ciav.save
  end

  # Get all effective attribute values as a hash
  # Merges product attributes with catalog overrides
  #
  # @return [Hash] Hash of attribute codes to effective values
  #
  # @example
  #   catalog_item.effective_attribute_values_hash
  #   # => { 'price' => '1999', 'weight' => '500', 'description' => 'Special text' }
  #
  def effective_attribute_values_hash
    # Start with product attributes
    result = product.attribute_values_hash.dup

    # Override with catalog-specific values
    catalog_item_attribute_values.includes(:product_attribute).each do |ciav|
      code = ciav.product_attribute.code
      result[code] = ciav.value if ciav.value.present?
    end

    result
  end

  # Check if catalog item has any attribute overrides
  #
  # @return [Boolean] true if any catalog-specific attributes exist
  #
  def has_attribute_overrides?
    catalog_item_attribute_values.any?
  end

  # Get validation errors for this catalog item
  #
  # @return [Array<String>] Array of error messages
  #
  def validation_errors
    validator = CatalogItemValidator.new(self)
    validator.valid? # Run validation
    validator.errors
  end
end
