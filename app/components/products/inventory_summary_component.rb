# frozen_string_literal: true

module Products
  class InventorySummaryComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def storage_locations
      @storage_locations ||= if product.product_type_configurable?
        configurable_storage_totals
      else
        product.inventories.includes(:storage).order("storages.name")
      end
    end

    def total_inventory
      if product.product_type_configurable?
        Inventory.where(product_id: subproduct_ids).sum(:value)
      else
        product.total_inventory || 0
      end
    end

    def has_storage_locations?
      if product.product_type_configurable?
        Inventory.where(product_id: subproduct_ids).exists?
      else
        product.inventories.any?
      end
    end

    def configurable?
      product.product_type_configurable?
    end

    def subproduct_ids
      @subproduct_ids ||= product.subproducts.pluck(:id)
    end

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
