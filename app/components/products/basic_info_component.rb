# frozen_string_literal: true

module Products
  class BasicInfoComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def status_badge_variant
      case product.product_status
      when "active"
        :success
      when "draft", "incoming"
        :warning
      when "discontinued", "deleted"
        :danger
      else
        :gray
      end
    end

    def type_badge_variant
      :info
    end

    def product_type_label
      product.product_type.humanize
    end

    def product_status_label
      product.product_status.humanize
    end
  end
end
