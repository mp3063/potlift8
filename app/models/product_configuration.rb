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
  validate :prevent_circular_bundle_dependency, if: -> { superproduct&.product_type_bundle? && subproduct&.product_type_bundle? }
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

  # Prevent circular bundle dependencies (Bundle A contains Bundle B contains Bundle A)
  # Only applies when both superproduct and subproduct are bundles
  def prevent_circular_bundle_dependency
    if circular_bundle_exists?(subproduct, superproduct)
      errors.add(:base, "Circular bundle dependency detected")
    end
  end

  # Recursively check if a bundle contains the target bundle
  # Uses depth-first search with visited tracking to prevent infinite loops
  #
  # @param bundle [Product] The bundle to search from
  # @param target [Product] The target bundle to find
  # @param visited [Set] Set of visited bundle IDs to prevent infinite loops
  # @return [Boolean] true if circular dependency exists
  def circular_bundle_exists?(bundle, target, visited = Set.new)
    # If we found the target, circular dependency exists
    return true if bundle.id == target.id

    # If we've already visited this bundle, no need to check again
    return false if visited.include?(bundle.id)

    # Mark this bundle as visited
    visited.add(bundle.id)

    # Check all subproducts of this bundle
    bundle.subproducts.any? do |sub|
      # Only check bundle subproducts
      next unless sub.product_type_bundle?
      circular_bundle_exists?(sub, target, visited)
    end
  end

  # Validate that the superproduct is configurable, bundle, or bundle_variant
  def validate_superproduct_type
    return unless superproduct

    valid_type = superproduct.product_type_configurable? ||
                 superproduct.product_type_bundle? ||
                 superproduct.bundle_variant?

    unless valid_type
      errors.add(:superproduct, "must be a configurable, bundle, or bundle variant product")
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

    # For bundle variants, subproducts must be sellable or configurable
    if superproduct.bundle_variant? && subproduct.product_type_bundle?
      errors.add(:subproduct, "cannot be a bundle when superproduct is a bundle variant")
    end
  end
end
