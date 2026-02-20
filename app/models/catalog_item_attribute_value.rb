# CatalogItemAttributeValue Model
#
# Stores catalog-specific attribute overrides for products in a catalog.
# Part of the EAV (Entity-Attribute-Value) pattern for flexible product attributes.
#
# Attribute Scope Validation:
# - Only attributes with catalog_scope or product_and_catalog_scope can be stored
# - product_scope attributes cannot have catalog-level overrides
#
# Ready Flag:
# - Indicates if the attribute value is ready for display/use
# - Can be used to mark incomplete or pending attribute values
#
# JSONB Fields (pot3 conventions):
# - info: Additional metadata about the attribute value
#
# Hierarchy:
# - CatalogItemAttributeValue overrides ProductAttributeValue
# - Falls back to product value if catalog value is missing
#
class CatalogItemAttributeValue < ApplicationRecord
  # Associations
  belongs_to :catalog_item, counter_cache: true
  belongs_to :product_attribute

  # Callbacks
  after_commit :enqueue_sync_job, on: [ :create, :update, :destroy ]

  # Validations
  validates :catalog_item_id, uniqueness: { scope: :product_attribute_id }
  validates :value, presence: true
  validate :attribute_allows_catalog_scope

  # Scopes
  scope :ready_values, -> { where(ready: true) }
  scope :pending_values, -> { where(ready: false) }
  scope :for_attribute, ->(attribute_code) {
    joins(:product_attribute).where(product_attributes: { code: attribute_code })
  }

  # Get the company through associations
  #
  # @return [Company] The owning company
  #
  def company
    catalog_item.catalog.company
  end

  # Get the product through catalog_item
  #
  # @return [Product] The associated product
  #
  def product
    catalog_item.product
  end

  # Get the catalog through catalog_item
  #
  # @return [Catalog] The associated catalog
  #
  def catalog
    catalog_item.catalog
  end

  # Check if value is complete and ready
  #
  # @return [Boolean] true if ready flag is set and value exists
  #
  def complete?
    ready? && value.present?
  end

  # Get formatted value based on product attribute view format
  #
  # @return [Hash] Formatted value and display representation
  #
  def formatted_value
    product_attribute.avjson(self)
  rescue StandardError => e
    { value: value, display: value, error: e.message }
  end

  private

  # Validates that the product attribute allows catalog-level values
  # Only catalog_scope and product_and_catalog_scope attributes are allowed
  #
  def attribute_allows_catalog_scope
    return if product_attribute.nil?

    unless product_attribute.catalog_scope? || product_attribute.product_and_catalog_scope?
      errors.add(:base, "Attribute '#{product_attribute.name}' doesn't allow catalog-level values")
    end
  end

  # Enqueue sync job when catalog-level attribute values change
  # This ensures catalog-specific overrides (like price) are synced to external systems
  #
  def enqueue_sync_job
    catalog_item = self.catalog_item
    return unless catalog_item

    catalog = catalog_item.catalog
    return unless catalog&.info&.dig("sync_target").present?
    return if catalog.info&.dig("sync_paused")

    ProductSyncJob.perform_later(catalog_item.product, catalog, Time.current)
  rescue StandardError => e
    Rails.logger.error("[CatalogItemAttributeValue] Failed to enqueue sync: #{e.message}")
  end
end
