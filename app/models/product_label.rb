class ProductLabel < ApplicationRecord
  belongs_to :product
  belongs_to :label, counter_cache: :products_count

  validates :product_id, uniqueness: { scope: :label_id }

  after_save :touch_product
  after_destroy :touch_product
  after_touch :touch_product

  private

  def touch_product
    product.touch if product.present?
  end
end
