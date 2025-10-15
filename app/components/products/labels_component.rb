# frozen_string_literal: true

module Products
  # Product labels component with tag-style UI
  #
  # Displays labels as removable tags with blue color scheme.
  # Includes add/remove functionality with select dropdown.
  # Integrates with product_labels_controller.js for label management.
  #
  # @example Render labels component
  #   <%= render Products::LabelsComponent.new(product: @product) %>
  #
  class LabelsComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new labels component
    #
    # @param product [Product] Product instance with labels
    # @return [LabelsComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns available labels (not already assigned)
    #
    # @return [ActiveRecord::Relation] Collection of available labels
    def available_labels
      Label.where.not(id: product.label_ids).order(:name)
    end

    # Checks if product has any labels
    #
    # @return [Boolean] True if labels present
    def has_labels?
      product.labels.any?
    end
  end
end
