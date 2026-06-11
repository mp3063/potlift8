# Inventory Reduce Service
#
# Handles relative inventory decrements for products (e.g. when an order is
# placed in an external system like Shopify). Unlike InventoryUpdateService,
# which sets absolute values, this service subtracts a quantity from the
# current inventory value.
#
# Features:
# - Atomic decrement using row-level locking
# - Optional explicit storage targeting via storage_code
# - Fallback chain: product default inventory -> company default storage ->
#   most important active regular storage
# - Negative values are allowed by design (makes overselling visible)
# - Returns updated inventory with ETA information
#
# Usage:
#   service = InventoryReduceService.new(company, product)
#   result = service.reduce(quantity: 3)
#   result = service.reduce(quantity: 2, storage_code: 'MAIN')
#
# @example Success response
#   {
#     success: true,
#     inventory: {
#       available: 97,
#       incoming: 0,
#       eta: nil
#     },
#     reduced: { storage_code: 'MAIN', quantity: 3, new_value: 97 }
#   }
#
# @example Error response
#   {
#     success: false,
#     error: 'Storage not found: INVALID',
#     details: { storage_code: 'INVALID' }
#   }
#
class InventoryReduceService
  attr_reader :company, :product, :errors

  def initialize(company, product)
    @company = company
    @product = product
    @errors = []
  end

  # Reduce inventory for product by a relative quantity
  #
  # @param quantity [Integer, String] Quantity to subtract (must be positive)
  # @param storage_code [String, nil] Storage code to target (optional)
  #
  # @return [Hash] Result with success status and inventory data
  #
  def reduce(quantity:, storage_code: nil)
    # Convert quantity to integer
    begin
      quantity = Integer(quantity)
    rescue ArgumentError, TypeError
      return error_response("Invalid quantity: #{quantity}", details: { quantity: quantity })
    end

    # Reject zero or negative quantities
    if quantity <= 0
      return error_response("Quantity must be positive", details: { quantity: quantity })
    end

    # Find target inventory (explicit storage or fallback chain)
    inventory = find_target_inventory(storage_code)

    # Lookup failures return an error response hash
    return inventory if inventory.is_a?(Hash)

    # Persist new records before locking (with_lock requires a persisted row)
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

  # Find the inventory record to decrement
  #
  # Fallback chain:
  # 1. Explicit storage_code (error if storage not found)
  # 2. Product's default-flagged inventory
  # 3. Company's default storage
  # 4. Most important active regular storage
  #
  # @param storage_code [String, nil] Storage code (optional)
  # @return [Inventory, Hash] Inventory record or error response hash
  #
  def find_target_inventory(storage_code)
    # Explicit storage targeting
    if storage_code.present?
      storage = company.storages.find_by(code: storage_code)

      unless storage
        return error_response("Storage not found: #{storage_code}", details: { storage_code: storage_code })
      end

      return product.inventories.find_or_initialize_by(storage: storage)
    end

    # Product's default-flagged inventory
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

  # Build success response
  #
  # @param inventory [Inventory] Decremented inventory record
  # @param quantity [Integer] Quantity that was subtracted
  # @return [Hash] Success response
  #
  def success_response(inventory, quantity)
    # Reload product to get fresh inventory data
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

  # Build error response
  #
  # @param message [String] Error message
  # @param details [Hash] Additional error details
  # @return [Hash] Error response
  #
  def error_response(message, details: {})
    {
      success: false,
      error: message,
      details: details
    }
  end
end
