# frozen_string_literal: true

module Products
  # Product attributes component with inline editing
  #
  # Displays product attributes grouped by attribute group in a 2-column grid.
  # Supports inline editing with type-specific editors using Turbo Frames.
  # Integrates with inline_editor_controller.js for edit interactions.
  #
  # @example Render attributes component
  #   <%= render Products::AttributesComponent.new(
  #     product: @product,
  #     attributes: @attribute_values
  #   ) %>
  #
  class AttributesComponent < ViewComponent::Base
    attr_reader :product, :attributes

    # Initialize a new attributes component
    #
    # @param product [Product] Product instance
    # @param attributes [Hash] Hash of attribute => value pairs
    # @return [AttributesComponent]
    def initialize(product:, attributes:)
      @product = product
      @attributes = attributes
    end

    private

    # Groups attributes by attribute group and sorts by position
    #
    # @return [Array<Array>] Array of [group, attributes] pairs sorted by position
    def grouped_attributes
      # For now, group all attributes under a single "General" group
      # ProductAttribute doesn't have attribute_group association yet
      [ [ nil, attributes ] ]
    end

    # Checks if any attributes exist
    #
    # @return [Boolean] True if attributes present
    def has_attributes?
      attributes.any?
    end
  end
end
