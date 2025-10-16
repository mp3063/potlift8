# frozen_string_literal: true

module Products
  # Product catalog tabs component with attribute overrides
  #
  # Displays a tabbed interface showing product attributes and catalog-specific
  # attribute overrides. Features:
  # - Product tab (base attributes)
  # - Catalog tabs (one per catalog the product is in)
  # - Add to catalog button (opens modal)
  # - Attribute override highlighting
  # - URL hash and localStorage persistence
  #
  # @example Render catalog tabs component
  #   <%= render Products::CatalogTabsComponent.new(
  #     product: @product,
  #     catalog_items: @product.catalog_items,
  #     attribute_values: @attribute_values,
  #     available_catalogs: @available_catalogs
  #   ) %>
  #
  class CatalogTabsComponent < ViewComponent::Base
    attr_reader :product, :catalog_items, :attribute_values, :available_catalogs

    # Initialize a new catalog tabs component
    #
    # @param product [Product] Product instance
    # @param catalog_items [Array<CatalogItem>] Catalog items for this product
    # @param attribute_values [Hash] Hash of ProductAttribute => ProductAttributeValue
    # @param available_catalogs [Array<Catalog>] Catalogs not yet associated with product
    # @return [CatalogTabsComponent]
    def initialize(product:, catalog_items:, attribute_values:, available_catalogs: [])
      @product = product
      @catalog_items = catalog_items
      @attribute_values = attribute_values
      @available_catalogs = available_catalogs
    end

    private

    # Checks if there are any catalog items
    #
    # @return [Boolean] True if product is in any catalogs
    def has_catalog_items?
      catalog_items.any?
    end

    # Checks if there are any available catalogs to add product to
    #
    # @return [Boolean] True if available catalogs exist
    def has_available_catalogs?
      available_catalogs.any?
    end

    # Checks if any attributes exist
    #
    # @return [Boolean] True if attributes present
    def has_attributes?
      attribute_values.any?
    end

    # Get all product attributes for the company
    # Sorted by attribute_position (uses default scope)
    #
    # @return [Array<ProductAttribute>] All company product attributes
    def all_attributes
      @all_attributes ||= product.company.product_attributes
    end
  end
end
