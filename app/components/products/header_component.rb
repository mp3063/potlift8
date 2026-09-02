# frozen_string_literal: true

module Products
  class HeaderComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def status_badge_variant
      case product.product_status
      when "active" then :success
      when "draft", "incoming" then :warning
      when "discontinued", "deleted" then :danger
      else :gray
      end
    end

    def status_label
      product.product_status.humanize
    end

    def type_label
      label = product.product_type.humanize
      return label unless product.product_type_configurable? && product.configuration_type.present?

      "#{label} · #{product.configuration_type.humanize}"
    end

    def restock_level
      product.info&.dig("restock_level") || 0
    end

    def toggle_button_text
      product.active? ? "Deactivate" : "Activate"
    end

    def toggle_button_classes
      base = "inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-medium text-white shadow-sm " \
             "focus:outline-none focus:ring-2 focus:ring-offset-2"
      if product.active?
        "#{base} bg-gray-600 hover:bg-gray-500 focus:ring-gray-500"
      else
        "#{base} bg-green-600 hover:bg-green-500 focus:ring-green-500"
      end
    end

    def show_inactive_variants_notice?
      return false if product.active?
      return false unless product.product_type_configurable? || product.product_type_bundle?

      inactive_variant_count.positive?
    end

    def inactive_variant_count
      @inactive_variant_count ||= product.subproducts.where.not(product_status: :active).count
    end

    def total_variant_count
      @total_variant_count ||= product.subproducts.count
    end
  end
end
