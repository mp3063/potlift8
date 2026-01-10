# Configuration Model
#
# Defines variant dimensions (Size, Color, Material, etc.) for configurable products.
# Each configuration represents one dimension of variation for a configurable product.
#
# Multi-Tenancy:
# - Scoped to company via company_id for data isolation
#
# Example Usage:
# configurable_product = Product.create!(
#   name: "T-Shirt",
#   product_type: :configurable,
#   configuration_type: :variant,
#   company: company
# )
#
# size_config = configurable_product.configurations.create!(
#   company: company,
#   name: "Size",
#   code: "size"
# )
#
# size_config.configuration_values.create!(value: "Small")
# size_config.configuration_values.create!(value: "Medium")
# size_config.configuration_values.create!(value: "Large")
#
# Ordering:
# - Uses acts_as_list for position-based ordering within a product
# - Allows reordering of configuration dimensions (e.g., show Size before Color)
#
class Configuration < ApplicationRecord
  # Multi-tenant association
  belongs_to :company

  # Configuration belongs to a single configurable product
  belongs_to :product

  # A configuration has multiple values (Small, Medium, Large for Size)
  has_many :configuration_values, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: [ :company_id, :product_id ] }
  validate :product_must_be_configurable
  validate :company_must_match_product

  # Position-based ordering within a product
  # Allows drag-and-drop reordering in admin interface
  acts_as_list scope: :product_id

  # Nested attributes for form handling
  # Allows creating/updating configuration values when creating/updating configuration
  accepts_nested_attributes_for :configuration_values,
                                allow_destroy: true,
                                reject_if: :all_blank

  private

  # Validate that the associated product is configurable
  # Configurations only make sense for configurable products
  def product_must_be_configurable
    unless product&.product_type_configurable?
      errors.add(:product, "must be a configurable product")
    end
  end

  # Validate that the configuration's company matches the product's company
  # Ensures multi-tenant data isolation
  def company_must_match_product
    return unless product.present? && company.present?

    if company_id != product.company_id
      errors.add(:company, "must match the product's company")
    end
  end
end
