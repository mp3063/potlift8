# frozen_string_literal: true

# ProductRelationships
#
# Handles product relationship helper methods including:
# - Variant detection (has_variants?, is_variant?)
# - Related product accessors (cross_sell, upsell, alternative, accessory, similar)
#
# @example Check if product has variants
#   configurable_product.has_variants? # => true
#   sellable_product.has_variants?     # => false
#
# @example Get related products
#   product.cross_sell_products # => [related_product_1, related_product_2]
#   product.upsell_products     # => [premium_product]
#
module ProductRelationships
  extend ActiveSupport::Concern

  # Check if this product has variants (is a configurable product with subproducts)
  #
  # @return [Boolean] true if product is configurable and has subproducts
  #
  # @example
  #   t_shirt.has_variants? # => true (configurable with size/color variants)
  #   bundle.has_variants? # => false (bundle, not configurable)
  #   simple_product.has_variants? # => false (sellable, not configurable)
  #
  def has_variants?
    product_type_configurable? && subproducts.any?
  end

  # Check if this product is a variant (is a subproduct of a configurable product)
  #
  # @return [Boolean] true if product is a subproduct of any superproduct
  #
  # @example
  #   size_small.is_variant? # => true (subproduct of t-shirt)
  #   t_shirt.is_variant? # => false (is the superproduct)
  #
  def is_variant?
    superproducts.any?
  end

  # Alias for subproducts to maintain compatibility with pot3
  #
  # @return [ActiveRecord::Associations::CollectionProxy] Collection of variant products
  #
  def variants
    subproducts
  end

  # Related Product Helper Methods (Phase 14-16)
  #
  # Get cross-sell products (commonly bought together)
  #
  # @return [Array<Product>] Array of cross-sell products
  #
  # @example
  #   phone.cross_sell_products # => [phone_case, screen_protector]
  #
  def cross_sell_products
    related_products.cross_sell.includes(:related_to).map(&:related_to)
  end

  # Get upsell products (higher-end alternatives)
  #
  # @return [Array<Product>] Array of upsell products
  #
  # @example
  #   phone.upsell_products # => [premium_phone, flagship_phone]
  #
  def upsell_products
    related_products.upsell.includes(:related_to).map(&:related_to)
  end

  # Get alternative products (substitutes)
  #
  # @return [Array<Product>] Array of alternative products
  #
  # @example
  #   product.alternative_products # => [similar_product_a, similar_product_b]
  #
  def alternative_products
    related_products.alternative.includes(:related_to).map(&:related_to)
  end

  # Get accessory products (complementary items)
  #
  # @return [Array<Product>] Array of accessory products
  #
  # @example
  #   phone.accessory_products # => [phone_case, charger, earphones]
  #
  def accessory_products
    related_products.accessory.includes(:related_to).map(&:related_to)
  end

  # Get similar products (same category/attributes)
  #
  # @return [Array<Product>] Array of similar products
  #
  # @example
  #   product.similar_products # => [product_x, product_y]
  #
  def similar_products
    related_products.similar.includes(:related_to).map(&:related_to)
  end
end
