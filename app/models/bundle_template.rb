class BundleTemplate < ApplicationRecord
  belongs_to :product
  belongs_to :company

  validates :product, presence: true
  validates :company, presence: true
  validates :product_id, uniqueness: true
  validate :product_must_be_bundle

  def components
    configuration["components"] || []
  end

  private

  def product_must_be_bundle
    return if product.blank?

    unless product.product_type_bundle?
      errors.add(:product, "must be a bundle product")
    end
  end
end
