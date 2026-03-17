# frozen_string_literal: true

module Products
  # Renders the inventory grid form for batch editing.
  #
  # Supports three layouts based on product type:
  # - Sellable: storages as rows with value + ETA columns
  # - Configurable: variant subproducts as rows × storages as columns
  # - Bundle: read-only calculated inventory breakdown
  #
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

    # Get inventory for a specific cell in the configurable grid
    def cell_inventory(subproduct_id, storage_id)
      inventory_matrix[[subproduct_id, storage_id]]
    end

    # Get the cell value for a specific cell
    def cell_value(subproduct_id, storage_id)
      cell_inventory(subproduct_id, storage_id)&.value || 0
    end

    # Build the cell key used for form params and Stimulus data attributes
    def cell_key(product_id, storage_id)
      "#{product_id}_#{storage_id}"
    end

    # Check if a cell had a save error
    def cell_failed?(product_id, storage_id)
      failed_cells.include?(cell_key(product_id, storage_id))
    end

    # CSS classes for an input cell
    def cell_classes(product_id, storage_id)
      base = "w-20 text-center py-1.5 px-2 text-sm border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
      if cell_failed?(product_id, storage_id)
        "#{base} border-red-500 ring-2 ring-red-500 bg-red-50"
      else
        "#{base} border-gray-300"
      end
    end

    # Get variant config label for a subproduct
    def variant_label(subproduct)
      config = subproduct.product_configurations_as_sub.first
      return subproduct.name unless config

      variant_config = config.info&.dig("variant_config")
      return subproduct.name unless variant_config.is_a?(Hash) && variant_config.any?

      variant_config.values.join(" / ")
    end

    # Calculate row total for a subproduct across all storages
    def row_total(subproduct_id)
      storages.sum { |s| cell_value(subproduct_id, s.id) }
    end

    # Calculate column total for a storage across all subproducts
    def column_total(storage_id)
      return 0 unless subproducts

      subproducts.sum { |sp| cell_value(sp.id, storage_id) }
    end

    # Return inventories for the sellable grid (existing records only)
    def inventories_or_empty
      inventories || []
    end
  end
end
