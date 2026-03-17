# frozen_string_literal: true

module Products
  # Product inventory summary component for sidebar
  #
  # Displays total inventory count with large display and storage location
  # breakdown. Includes link to inventory details page.
  # Handles configurable products by aggregating subproduct inventories.
  #
  class InventorySummaryComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    # For configurable products, returns per-storage totals as [{storage:, total:}]
    # For other products, returns inventories with storage
    def storage_locations
      @storage_locations ||= if product.product_type_configurable?
        configurable_storage_totals
      else
        product.inventories.includes(:storage).order("storages.name")
      end
    end

    # Returns total inventory count
    def total_inventory
      if product.product_type_configurable?
        Inventory.where(product_id: subproduct_ids).sum(:value)
      else
        product.total_inventory || 0
      end
    end

    # Checks if product has any storage locations
    def has_storage_locations?
      if product.product_type_configurable?
        Inventory.where(product_id: subproduct_ids).exists?
      else
        product.inventories.any?
      end
    end

    # Is this a configurable product?
    def configurable?
      product.product_type_configurable?
    end

    def subproduct_ids
      @subproduct_ids ||= product.subproducts.pluck(:id)
    end

    # Aggregate inventory by storage for configurable products
    def configurable_storage_totals
      Storage.where(id: Inventory.where(product_id: subproduct_ids).select(:storage_id))
             .order(:name)
             .map do |storage|
        total = Inventory.where(product_id: subproduct_ids, storage_id: storage.id).sum(:value)
        OpenStruct.new(storage: storage, value: total)
      end
    end
  end
end
