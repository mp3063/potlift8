# frozen_string_literal: true

module Products
  # Product inventory summary component for sidebar
  #
  # Displays total inventory count with large display and storage location
  # breakdown. Includes link to inventory details page.
  #
  # @example Render inventory summary
  #   <%= render Products::InventorySummaryComponent.new(product: @product) %>
  #
  class InventorySummaryComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new inventory summary component
    #
    # @param product [Product] Product instance with inventory
    # @return [InventorySummaryComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns storage locations with inventory for this product
    #
    # @return [ActiveRecord::Relation] Collection of inventories with storage
    def storage_locations
      product.inventories.includes(:storage).order('storages.name')
    end

    # Returns total inventory count
    #
    # @return [Integer] Total inventory units
    def total_inventory
      product.total_inventory || 0
    end

    # Checks if product has any storage locations
    #
    # @return [Boolean] True if storage locations exist
    def has_storage_locations?
      storage_locations.any?
    end
  end
end
