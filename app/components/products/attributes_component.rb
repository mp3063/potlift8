# frozen_string_literal: true

module Products
  class AttributesComponent < ViewComponent::Base
    attr_reader :product, :attributes

    def initialize(product:, attributes:)
      @product = product
      @attributes = attributes
    end

    private

    def grouped_attributes
      [ [ nil, attributes ] ]
    end

    def has_attributes?
      attributes.any?
    end
  end
end
