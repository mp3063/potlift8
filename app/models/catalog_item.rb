# Catalog-Specific Attributes:
# - Catalog items can override product attribute values
# - Overrides are stored in CatalogItemAttributeValue records
# - Falls back to product values if no catalog override exists
# JSONB Fields (pot3 conventions):
# - info: Catalog-specific metadata and settings
class CatalogItem < ApplicationRecord
  include SyncBroadcastable

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

  validates :catalog_id, uniqueness: { scope: :product_id }

  default_scope { order(Arel.sql("catalog_items.priority DESC NULLS LAST, catalog_items.id ASC")) }
  scope :active_items, -> { where(catalog_item_state: :active) }
  scope :inactive_items, -> { where(catalog_item_state: :inactive) }
  scope :by_priority, -> { reorder(Arel.sql("catalog_items.priority DESC NULLS LAST, catalog_items.id ASC")) }

  def sales_ready?
    validator = CatalogItemValidator.new(self)
    validator.valid?
  end

  # Get effective attribute value (catalog override or product value)
  # First checks for catalog-specific override, then falls back to product value
  def effective_attribute_value(attribute_code)
    attr = catalog.company.product_attributes.find_by(code: attribute_code)
    return nil unless attr

    ciav = catalog_item_attribute_values.find_by(product_attribute: attr)
    return ciav.value if ciav.present? && ciav.value.present?

    # Fall back to product-level value
    product.read_attribute_value(attribute_code)
  end

  def write_catalog_attribute_value(attribute_code, value)
    attr = catalog.company.product_attributes.find_by(code: attribute_code)
    return false unless attr
    return false unless attr.catalog_scope? || attr.product_and_catalog_scope?

    ciav = catalog_item_attribute_values.find_or_initialize_by(product_attribute: attr)
    ciav.value = value.to_s
    ciav.save
  end

  def effective_product_attribute_values
    product_values = product.product_attribute_values.includes(:product_attribute).index_by(&:product_attribute_id)
    catalog_overrides = catalog_item_attribute_values.includes(:product_attribute).index_by(&:product_attribute_id)

    merged = product_values.merge(catalog_overrides)
    merged.values
  end

  def effective_attribute_values_hash
    result = product.attribute_values_hash.dup

    catalog_item_attribute_values.includes(:product_attribute).each do |ciav|
      code = ciav.product_attribute.code
      result[code] = ciav.value if ciav.value.present?
    end

    result
  end

  def has_attribute_overrides?
    catalog_item_attribute_values.any?
  end

  def validation_errors
    validator = CatalogItemValidator.new(self)
    validator.valid?
    validator.errors
  end
end
