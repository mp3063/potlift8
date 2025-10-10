# ProductLabel Model
#
# Join model connecting products to labels in a many-to-many relationship.
# Allows products to be categorized with multiple labels.
#
# Associations:
# - belongs_to :product
# - belongs_to :label
#
# This is a simple join table with timestamps for tracking when
# product-label associations were created/modified.
#
# Example:
#   product = Product.find(1)
#   label = Label.find_by(full_code: 'electronics-phones')
#   ProductLabel.create(product: product, label: label)
#
class ProductLabel < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :label

  # Validations
  validates :product_id, uniqueness: { scope: :label_id }

  # Callbacks
  # Touch product when product_label is modified to invalidate caches
  after_save :touch_product
  after_destroy :touch_product
  after_touch :touch_product

  private

  # Propagate changes to the product by touching it
  # This ensures product cache is invalidated when labels change
  def touch_product
    product.touch if product.present?
  end
end
