# Features:
# - Atomic decrement using row-level locking
# - Optional explicit storage targeting via storage_code
# - Fallback chain: product default inventory -> company default storage ->
#   most important active regular storage
# - Negative values are allowed by design (makes overselling visible)
# - Returns updated inventory with ETA information
class InventoryReduceService
  attr_reader :company, :product, :errors

  def initialize(company, product)
    @company = company
    @product = product
    @errors = []
  end

  def reduce(quantity:, storage_code: nil)
    begin
      quantity = Integer(quantity)
    rescue ArgumentError, TypeError
      return error_response("Invalid quantity: #{quantity}", details: { quantity: quantity })
    end

    if quantity <= 0
      return error_response("Quantity must be positive", details: { quantity: quantity })
    end

    # Find target inventory (explicit storage or fallback chain)
    inventory = find_target_inventory(storage_code)

    return inventory if inventory.is_a?(Hash)

    if inventory.new_record?
      inventory.value = 0
      inventory.save!
    end

    # Decrement atomically under row lock
    # Negative values are allowed by design (makes overselling visible)
    inventory.with_lock do
      inventory.update!(value: inventory.value - quantity)
    end

    success_response(inventory, quantity)
  end

  private

  # Fallback chain:
  # 1. Explicit storage_code (error if storage not found)
  # 2. Product's default-flagged inventory
  # 3. Company's default storage
  # 4. Most important active regular storage
  def find_target_inventory(storage_code)
    if storage_code.present?
      storage = company.storages.find_by(code: storage_code)

      unless storage
        return error_response("Storage not found: #{storage_code}", details: { storage_code: storage_code })
      end

      return product.inventories.find_or_initialize_by(storage: storage)
    end

    inventory = product.inventories.joins(:storage).find_by(default: true)
    return inventory if inventory

    # Company's default storage, then most important active regular storage
    storage = company.storages.find_by(default: true)
    storage ||= company.storages.active.regular.order_by_importance.first

    unless storage
      return error_response("No storage available for inventory reduction")
    end

    product.inventories.find_or_initialize_by(storage: storage)
  end

  def success_response(inventory, quantity)
    product.reload

    {
      success: true,
      inventory: product.single_inventory_with_eta,
      reduced: {
        storage_code: inventory.storage.code,
        quantity: quantity,
        new_value: inventory.value
      }
    }
  end

  def error_response(message, details: {})
    {
      success: false,
      error: message,
      details: details
    }
  end
end
