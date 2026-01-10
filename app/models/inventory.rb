# Inventory Model
#
# Represents stock levels for products in storage locations.
# Each inventory record tracks the quantity (value) of a specific product
# in a specific storage location.
#
# Attributes:
# - product_id: Product being tracked
# - storage_id: Storage location
# - value: Stock quantity (note: named 'value' for pot3 compatibility, not 'quantity')
# - info: JSONB field for additional metadata
# - default: Whether this is the default inventory location for the product
# - eta: Estimated time of arrival for incoming inventory
#
# Associations:
# - belongs_to :product
# - belongs_to :storage
#
# Constraints:
# - Each product can only have one inventory record per storage location
# - Value defaults to 0 and cannot be null
#
# Note: This model uses 'value' instead of 'quantity' to maintain
# compatibility with the pot3 (Rails 7) schema.
#
class Inventory < ApplicationRecord
  belongs_to :product
  belongs_to :storage

  # Validations
  validates :value, presence: true, numericality: { only_integer: true }
  validates :product_id, uniqueness: { scope: :storage_id }

  # Scopes
  scope :for_product, ->(product) { where(product: product) }
  scope :except_in, ->(storage) { where.not(storage: storage) }
  scope :with_stock, -> { where("value > 0") }
  scope :incoming, -> { joins(:storage).where(storages: { storage_type: 3 }) }

  # Custom JSON serialization for catalog integration
  # This matches pot3 behavior for catalog item exports
  def as_json(options = {})
    res = super(options)
    if options[:include_related_objects_for_catalog].present?
      res.delete("storage_id")
      res.merge!(storage.as_json(except: [ :id, :company_id, :info, :created_at, :updated_at, :default ]))
      res["default"] ||= storage.default
    end
    res
  end
end
