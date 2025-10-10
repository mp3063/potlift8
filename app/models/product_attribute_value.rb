# ProductAttributeValue Model
#
# Implements the EAV (Entity-Attribute-Value) pattern value storage.
# Each record represents a single attribute value for a specific product.
#
# The value can be stored in different ways depending on the ProductAttribute's view_format:
# - Simple attributes: Stored directly in the 'value' text column
# - Complex attributes: Stored in the 'info' jsonb column (e.g., customer_group_price, special_price)
#
# Validation:
# Values are validated against the ProductAttribute's rules before being marked as ready.
# The 'ready' flag indicates whether the value passes all validation rules.
#
# Example:
#   # Simple attribute
#   pav = ProductAttributeValue.new(
#     product: product,
#     product_attribute: price_attribute,
#     value: "1999"  # 19.99 euros in cents
#   )
#
#   # Complex attribute (customer group prices)
#   pav = ProductAttributeValue.new(
#     product: product,
#     product_attribute: customer_price_attribute,
#     info: {
#       customer_group_prices: {
#         'retail' => 1999,
#         'wholesale' => 1499
#       }
#     }
#   )
#
class ProductAttributeValue < ApplicationRecord
  include AttributeValues

  # Associations
  belongs_to :product
  belongs_to :product_attribute

  # Validations
  validates :product, presence: true
  validates :product_attribute, presence: true
  validates :product_id, uniqueness: { scope: :product_attribute_id }

  # Callbacks
  before_save :check_readiness
  after_save :propagate_change
  after_destroy :propagate_change
  after_touch :propagate_change
end
