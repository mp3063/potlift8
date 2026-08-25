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

  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :storage_type, presence: true
  validates :storage_status, presence: true

  scope :has_products, -> {
    where("(SELECT count(*) FROM inventories WHERE storage_id = storages.id) > 0")
  }

  scope :order_by_importance, -> {
    order(storage_type: :asc, storage_status: :desc, id: :asc)
  }

  def to_param
    code
  end

  def total_inventory
    inventories.sum(:value)
  end

  def product_count
    inventories.where("value > 0").count
  end

  def has_inventory?
    inventories.where("value > 0").exists?
  end
end
