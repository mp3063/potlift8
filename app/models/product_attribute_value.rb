class ProductAttributeValue < ApplicationRecord
  include AttributeValues

  belongs_to :product
  belongs_to :product_attribute

  validates :product, presence: true
  validates :product_attribute, presence: true
  validates :product_id, uniqueness: { scope: :product_attribute_id }

  before_save :check_readiness
  after_commit :propagate_change, on: [ :create, :update, :destroy ]
end
