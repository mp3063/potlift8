# frozen_string_literal: true

module Products
  # Toolbar for the inventory grid with Fill All, Save, and Add Storage controls.
  class InventoryGridToolbarComponent < ViewComponent::Base
    attr_reader :product, :storages

    def initialize(product:, storages:)
      @product = product
      @storages = storages
    end
  end
end
