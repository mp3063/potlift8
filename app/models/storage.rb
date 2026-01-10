# Storage Model
#
# Represents warehouse storage locations in the multi-tenant Potlift8 system.
# Each storage belongs to a company and can hold inventory for multiple products.
#
# Attributes:
# - company_id: Company that owns this storage
# - storage_type: Type of storage (regular, temporary, incoming)
# - code: Unique storage identifier within company
# - name: Human-readable storage name
# - info: JSONB field for additional metadata
# - default: Whether this is the default storage location
# - storage_position: Display order or physical position
# - storage_status: Current status (deleted, active)
#
# Associations:
# - belongs_to :company
# - has_many :inventories
# - has_many :products (through inventories)
#
# Storage Types:
# - regular: Standard warehouse storage
# - temporary: Temporary holding area
# - incoming: Receiving area for incoming shipments
#
# Storage Status:
# - deleted: Soft-deleted, not visible
# - active: Active and available for use
#
class Storage < ApplicationRecord
  belongs_to :company
  has_many :inventories, dependent: :destroy
  has_many :products, through: :inventories

  # Enums matching pot3 schema
  enum :storage_type, {
    regular: 1,
    temporary: 2,
    incoming: 3
  }

  enum :storage_status, {
    deleted: 0,
    active: 1
  }

  # Validations
  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :storage_type, presence: true
  validates :storage_status, presence: true

  # Scopes
  scope :has_products, -> {
    where("(SELECT count(*) FROM inventories WHERE storage_id = storages.id) > 0")
  }

  scope :order_by_importance, -> {
    order(storage_type: :asc, storage_status: :desc, id: :asc)
  }

  # Use code as URL parameter for friendly URLs
  def to_param
    code
  end

  # Calculate total inventory across all products in this storage
  #
  # @return [Integer] Sum of all inventory values
  #
  # @example
  #   storage.total_inventory # => 1500
  #
  def total_inventory
    inventories.sum(:value)
  end

  # Count distinct products with inventory in this storage
  #
  # @return [Integer] Number of products with value > 0
  #
  # @example
  #   storage.product_count # => 42
  #
  def product_count
    inventories.where("value > 0").count
  end

  # Check if storage has any inventory
  #
  # @return [Boolean] true if storage has any inventory with value > 0
  #
  # @example
  #   storage.has_inventory? # => true
  #
  def has_inventory?
    inventories.where("value > 0").exists?
  end
end
