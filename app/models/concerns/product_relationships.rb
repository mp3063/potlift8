# frozen_string_literal: true

module ProductRelationships
  extend ActiveSupport::Concern

  def has_variants?
    product_type_configurable? && subproducts.any?
  end

  def is_variant?
    superproducts.any?
  end

  # Alias for subproducts to maintain compatibility with pot3
  def variants
    subproducts
  end

  def cross_sell_products
    related_products.cross_sell.includes(:related_to).map(&:related_to)
  end

  def upsell_products
    related_products.upsell.includes(:related_to).map(&:related_to)
  end

  def alternative_products
    related_products.alternative.includes(:related_to).map(&:related_to)
  end

  def accessory_products
    related_products.accessory.includes(:related_to).map(&:related_to)
  end

  def similar_products
    related_products.similar.includes(:related_to).map(&:related_to)
  end
end
