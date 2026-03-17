# frozen_string_literal: true

module Storages
  # Click-to-edit cell for inventory values in the storage inventory table.
  # Wraps in a turbo_frame for seamless inline updates via PATCH.
  class InlineInventoryCellComponent < ViewComponent::Base
    include Turbo::FramesHelper

    attr_reader :inventory, :storage, :error

    def initialize(inventory:, storage:, error: false)
      @inventory = inventory
      @storage = storage
      @error = error
    end

    def frame_id
      helpers.dom_id(inventory, :value)
    end

    def value
      inventory.value || 0
    end

    def update_url
      helpers.storage_inventory_path(storage, inventory)
    end

    def input_classes
      base = "w-20 text-center py-1 px-2 text-sm border rounded-md focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
      error ? "#{base} border-red-500" : "#{base} border-gray-300"
    end
  end
end
