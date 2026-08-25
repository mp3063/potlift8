# frozen_string_literal: true

module Products
  class InventoryGridToolbarComponent < ViewComponent::Base
    attr_reader :product, :storages

    def initialize(product:, storages:)
      @product = product
      @storages = storages
    end
  end
end
