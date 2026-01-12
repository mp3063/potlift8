# frozen_string_literal: true

# ProductDuplication
#
# Handles product duplication functionality including:
# - Creating a copy of the product with unique SKU
# - Duplicating attribute values
# - Copying labels
#
module ProductDuplication
  extend ActiveSupport::Concern

  def duplicate!
    new_product = dup
    new_product.sku = generate_unique_copy_sku
    new_product.name = "#{name} (Copy)"

    transaction do
      new_product.save!

      # Duplicate attribute values
      product_attribute_values.each do |pav|
        new_product.product_attribute_values.create!(
          product_attribute: pav.product_attribute,
          value: pav.value,
          info: pav.info
        )
      end

      # Copy labels
      new_product.label_ids = label_ids
    end

    new_product
  end

  private

  def generate_unique_copy_sku
    loop do
      candidate = "#{sku}_COPY_#{SecureRandom.hex(4).upcase}"
      break candidate unless company.products.exists?(sku: candidate)
    end
  end
end
