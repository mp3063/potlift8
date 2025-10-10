# ProductConfiguration Model
#
# Represents the relationship between products in a superproduct/subproduct hierarchy.
# This model enables two key product patterns:
#
# 1. Product Variants (Configurable Products):
#    A configurable product (superproduct) has multiple sellable variants (subproducts).
#    Example: A t-shirt (configurable) with different sizes (sellable variants)
#
# 2. Product Bundles:
#    A bundle (superproduct) is composed of multiple products (subproducts).
#    The 'info' JSONB field stores quantities for bundle components.
#    Example: A "Starter Kit" bundle containing 3 products with specific quantities
#
# Terminology Note:
# We use pot3's superproduct/subproduct terminology rather than parent/child:
# - Superproduct: The configurable or bundle product
# - Subproduct: The variant or component product
#
# JSONB Fields:
# - info: Stores additional configuration data
#   - quantity: Number of units in a bundle (default: 1)
#   - configuration: Variant configuration details
#   - variant_name: Display name for the variant
#
class ProductConfiguration < ApplicationRecord
  # Associations
  belongs_to :superproduct, class_name: 'Product', foreign_key: 'superproduct_id'
  belongs_to :subproduct, class_name: 'Product', foreign_key: 'subproduct_id'

  # Validations
  validates :superproduct_id, presence: true
  validates :subproduct_id, presence: true
  validates :superproduct_id, uniqueness: {
    scope: :subproduct_id,
    message: "and subproduct combination already exists"
  }

  validate :prevent_circular_dependency
  validate :validate_superproduct_type
  validate :validate_subproduct_type

  # Default scope for ordering - matches pot3 implementation
  default_scope {
    joins(:subproduct)
      .order('product_configurations.configuration_position ASC NULLS LAST')
      .order('products.sku ASC')
  }

  # Get the quantity for bundle configurations
  #
  # @return [Integer] The quantity stored in info['quantity'] or 1 if not set
  #
  # @example
  #   config.quantity # => 3 (for a bundle with 3 units of this component)
  #   config.quantity # => 1 (default for variants)
  #
  def quantity
    info['quantity'].to_i.positive? ? info['quantity'].to_i : 1
  end

  # Set the quantity for bundle configurations
  #
  # @param value [Integer] The quantity to store
  #
  def quantity=(value)
    self.info ||= {}
    self.info['quantity'] = value.to_i
  end

  private

  # Prevent a product from being its own subproduct (circular dependency)
  def prevent_circular_dependency
    if superproduct_id == subproduct_id
      errors.add(:base, "A product cannot be its own subproduct")
    end
  end

  # Validate that the superproduct is configurable or bundle
  def validate_superproduct_type
    return unless superproduct

    unless superproduct.product_type_configurable? || superproduct.product_type_bundle?
      errors.add(:superproduct, "must be a configurable or bundle product")
    end
  end

  # Validate that the subproduct type is appropriate for the superproduct
  def validate_subproduct_type
    return unless superproduct && subproduct

    # For configurable products, subproducts must be sellable
    if superproduct.product_type_configurable? && !subproduct.product_type_sellable?
      errors.add(:subproduct, "must be sellable for configurable superproducts")
    end

    # For bundles, subproducts cannot be bundles
    if superproduct.product_type_bundle? && subproduct.product_type_bundle?
      errors.add(:subproduct, "cannot be a bundle when superproduct is a bundle")
    end
  end
end
