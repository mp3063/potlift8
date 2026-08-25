# frozen_string_literal: true

module Products
  class FormComponent < ViewComponent::Base
    def initialize(product:, url:, method:)
      @product = product
      @url = url
      @method = method
      @company = product.company
    end

    private

    attr_reader :product, :url, :method, :company

    def product_type_options
      Product.product_types.map { |key, _value| [ key.humanize, key ] }
    end

    def configuration_type_options
      Product.configuration_types.map { |key, _value| [ key.humanize, key ] }
    end

    def available_labels
      return Label.none unless company.present?

      company.labels
             .where.not(id: product.label_ids)
             .order(:label_positions, :name)
    end

    def selected_label_ids
      product.label_ids
    end
  end
end
