# RelatedProduct Model
#
# Represents relationships between products for merchandising and recommendations.
# Enables cross-selling, upselling, and product alternatives.
#
# Relation Types:
# - cross_sell (0): Products commonly bought together
# - upsell (1): Higher-end alternatives to increase order value
# - alternative (2): Similar products that can substitute
# - accessory (3): Complementary products (e.g., phone case for phone)
# - similar (4): Products in same category or with similar attributes
#
# Example Usage:
# phone = Product.find_by(sku: "PHONE-X")
# phone_case = Product.find_by(sku: "CASE-X")
# premium_phone = Product.find_by(sku: "PHONE-XL")
#
# # Create accessory relationship
# phone.related_products.create!(
#   related_to: phone_case,
#   relation_type: :accessory
# )
#
# # Create upsell relationship
# phone.related_products.create!(
#   related_to: premium_phone,
#   relation_type: :upsell
# )
#
# # Retrieve related products
# phone.cross_sell_products  # => [phone_case, screen_protector]
# phone.upsell_products      # => [premium_phone]
#
# Multi-Tenancy:
# - Validated to ensure both products belong to same company
#
# Ordering:
# - Uses acts_as_list for position-based ordering within relation_type
# - Allows manual ordering of recommendations
#
class RelatedProduct < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :related_to, class_name: 'Product'

  # Relation type enum
  # Creates scopes: .cross_sell, .upsell, .alternative, .accessory, .similar
  # Creates predicates: .cross_sell?, .upsell?, .alternative?, .accessory?, .similar?
  enum :relation_type, {
    cross_sell: 0,
    upsell: 1,
    alternative: 2,
    accessory: 3,
    similar: 4
  }

  # Validations
  validates :relation_type, presence: true
  validates :related_to_id, uniqueness: { scope: [:product_id, :relation_type] }
  validate :prevent_self_reference
  validate :same_company

  # Position-based ordering within product + relation_type
  # Allows manual ordering of related products (e.g., show most important accessories first)
  acts_as_list scope: [:product_id, :relation_type]

  # Scope to retrieve related products by type
  # Usage: product.related_products.for_relation_type(:cross_sell)
  scope :for_relation_type, ->(type) { where(relation_type: type).order(:position) }

  private

  # Prevent a product from being related to itself
  def prevent_self_reference
    return unless product_id.present? && related_to_id.present?

    if product_id == related_to_id
      errors.add(:base, "A product cannot be related to itself")
    end
  end

  # Ensure both products belong to same company (multi-tenancy)
  def same_company
    if product && related_to && product.company_id != related_to.company_id
      errors.add(:base, "Related products must belong to the same company")
    end
  end
end
