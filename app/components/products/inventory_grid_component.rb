# frozen_string_literal: true

module Products
  class InventoryGridComponent < ViewComponent::Base
    attr_reader :product, :inventories, :storages, :subproducts, :inventory_matrix,
                :failed_cells, :bundle_breakdown

    def initialize(product:, storages:, inventories: nil, subproducts: nil,
                   inventory_matrix: nil, bundle_breakdown: nil, failed_cells: nil)
      @product = product
      @storages = storages
      @inventories = inventories
      @subproducts = subproducts
      @inventory_matrix = inventory_matrix || {}
      @bundle_breakdown = bundle_breakdown
      @failed_cells = Array(failed_cells)
    end

    def sellable?
      product.product_type_sellable?
    end

    def configurable?
      product.product_type_configurable?
    end

    def bundle?
      product.product_type_bundle?
    end

    def cell_inventory(subproduct_id, storage_id)
      inventory_matrix[[subproduct_id, storage_id]]
    end

    def cell_value(subproduct_id, storage_id)
      cell_inventory(subproduct_id, storage_id)&.value || 0
    end

    def cell_key(product_id, storage_id)
      "#{product_id}_#{storage_id}"
    end

    def cell_failed?(product_id, storage_id)
      failed_cells.include?(cell_key(product_id, storage_id))
    end

    def cell_classes(product_id, storage_id)
      base = "w-20 text-center py-1.5 px-2 text-sm border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
      if cell_failed?(product_id, storage_id)
        "#{base} border-red-500 ring-2 ring-red-500 bg-red-50"
      else
        "#{base} border-gray-300"
      end
    end

    def variant_label(subproduct)
      config = subproduct.product_configurations_as_sub.first
      return subproduct.name unless config

      variant_config = config.info&.dig("variant_config")
      return subproduct.name unless variant_config.is_a?(Hash) && variant_config.any?

      variant_config.values.join(" / ")
    end

    def row_total(subproduct_id)
      storages.sum { |s| cell_value(subproduct_id, s.id) }
    end

    def column_total(storage_id)
      return 0 unless subproducts

      subproducts.sum { |sp| cell_value(sp.id, storage_id) }
    end

    def inventories_or_empty
      inventories || []
    end
  end
end
