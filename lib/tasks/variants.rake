# frozen_string_literal: true

namespace :variants do
  desc "Copy the parent's subproduct_mandatory attribute values into existing variants that lack them"
  task inherit_attributes: :environment do
    copied = 0
    variants = 0

    ProductConfiguration.unscoped
      .joins(:superproduct)
      .where(products: { product_type: Product.product_types[:configurable] })
      .includes(:superproduct, :subproduct)
      .find_each do |configuration|
        count = VariantAttributeInheritance.new(superproduct: configuration.superproduct, subproduct: configuration.subproduct).call
        next if count.zero?

        copied += count
        variants += 1
      end

    puts "#{copied} values copied into #{variants} variants"
  end
end
