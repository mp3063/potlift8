class RelatedProduct < ApplicationRecord
  belongs_to :product
  belongs_to :related_to, class_name: "Product"

  enum :relation_type, {
    cross_sell: 0,
    upsell: 1,
    alternative: 2,
    accessory: 3,
    similar: 4
  }

  validates :relation_type, presence: true
  validates :related_to_id, uniqueness: { scope: [ :product_id, :relation_type ] }
  validate :prevent_self_reference
  validate :same_company

  # Position-based ordering within product + relation_type
  # Allows manual ordering of related products (e.g., show most important accessories first)
  acts_as_list scope: [ :product_id, :relation_type ]

  scope :for_relation_type, ->(type) { where(relation_type: type).order(:position) }

  private

  # Prevent a product from being related to itself
  def prevent_self_reference
    return unless product_id.present? && related_to_id.present?

    if product_id == related_to_id
      errors.add(:base, "A product cannot be related to itself")
    end
  end

  def same_company
    if product && related_to && product.company_id != related_to.company_id
      errors.add(:base, "Related products must belong to the same company")
    end
  end
end
