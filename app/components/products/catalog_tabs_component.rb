# frozen_string_literal: true

module Products
  class CatalogTabsComponent < ViewComponent::Base
    attr_reader :product, :catalog_items, :attribute_values, :available_catalogs

    def initialize(product:, catalog_items:, attribute_values:, available_catalogs: [])
      @product = product
      @catalog_items = catalog_items
      @attribute_values = attribute_values
      @available_catalogs = available_catalogs
    end

    private

    def has_catalog_items?
      catalog_items.any?
    end

    def has_available_catalogs?
      available_catalogs.any?
    end

    def has_attributes?
      attribute_values.any?
    end

    def all_attributes
      @all_attributes ||= product.company.product_attributes
    end
  end
end
