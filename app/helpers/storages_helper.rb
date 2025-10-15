# frozen_string_literal: true

module StoragesHelper
  # Renders a badge for storage type with appropriate variant
  # @param storage [Storage] The storage instance
  # @return [String] HTML badge component
  def storage_type_badge(storage)
    variant = case storage.storage_type
              when "regular" then :info
              when "temporary" then :warning
              when "incoming" then :gray
              else :gray
              end

    render Ui::BadgeComponent.new(variant: variant, size: :sm) do
      storage.storage_type.titleize
    end
  end

  # Renders a badge for storage status with appropriate variant
  # @param storage [Storage] The storage instance
  # @return [String] HTML badge component
  def storage_status_badge(storage)
    return nil if storage.storage_status == "active"

    render Ui::BadgeComponent.new(variant: :danger, size: :sm) do
      "Inactive"
    end
  end

  # Renders a default badge if storage is marked as default
  # @param storage [Storage] The storage instance
  # @return [String, nil] HTML badge component or nil
  def storage_default_badge(storage)
    return nil unless storage.default

    render Ui::BadgeComponent.new(variant: :primary, size: :sm) do
      "Default"
    end
  end

  # Formats inventory value with red text if below restock level
  # @param inventory [Inventory] The inventory instance
  # @param product [Product] The product instance
  # @return [Hash] Hash with text and classes
  def inventory_value_display(inventory, product)
    restock_level = product.info&.dig('restock_level') || 0
    is_low = inventory.value < restock_level

    {
      value: inventory.value,
      classes: is_low ? 'text-red-600 font-medium' : 'text-gray-900 font-medium'
    }
  end
end
