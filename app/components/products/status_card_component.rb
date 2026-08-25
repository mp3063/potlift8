# frozen_string_literal: true

module Products
  class StatusCardComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def status_icon
      product.active? ? "check-circle" : "x-circle"
    end

    def status_color
      product.active? ? "text-green-500" : "text-gray-400"
    end

    def status_text
      product.active? ? "Active" : product.product_status.humanize
    end

    def status_text_color
      product.active? ? "text-green-700" : "text-gray-700"
    end

    def toggle_button_text
      product.active? ? "Deactivate" : "Activate"
    end

    def toggle_button_classes
      if product.active?
        "w-full rounded-md bg-gray-600 hover:bg-gray-500 focus:ring-gray-500 px-3 py-2 text-sm font-semibold text-white shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"
      else
        "w-full rounded-md bg-green-600 hover:bg-green-500 focus:ring-green-500 px-3 py-2 text-sm font-semibold text-white shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"
      end
    end

    def product_type_label
      product.product_type.humanize
    end

    def configurable_or_bundle?
      product.product_type_configurable? || product.product_type_bundle?
    end

    def has_inactive_variants?
      return false unless configurable_or_bundle?

      product.subproducts.where.not(product_status: :active).exists?
    end

    def inactive_variant_count
      product.subproducts.where.not(product_status: :active).count
    end

    def total_variant_count
      product.subproducts.count
    end
  end
end
