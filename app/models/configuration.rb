class Configuration < ApplicationRecord
  belongs_to :company

  belongs_to :product

  has_many :configuration_values, dependent: :destroy

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: [ :company_id, :product_id ] }
  validate :product_must_be_configurable
  validate :company_must_match_product

  acts_as_list scope: :product_id

  accepts_nested_attributes_for :configuration_values,
                                allow_destroy: true,
                                reject_if: :all_blank

  private

  def product_must_be_configurable
    unless product&.product_type_configurable?
      errors.add(:product, "must be a configurable product")
    end
  end

  def company_must_match_product
    return unless product.present? && company.present?

    if company_id != product.company_id
      errors.add(:company, "must match the product's company")
    end
  end
end
