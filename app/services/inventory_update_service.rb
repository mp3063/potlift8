# Inventory Update Service
#
# Handles inventory updates for products from external systems (M23, Shopify3, Bizcart).
# Updates inventory values across multiple storage locations with ETA support.
#
# Features:
# - Multi-storage inventory updates in single transaction
# - ETA (Estimated Time of Arrival) support for incoming inventory
# - Automatic storage creation if not exists
# - Validates storage codes and inventory values
# - Returns updated inventory with ETA information
#
# Usage:
#   service = InventoryUpdateService.new(company, product)
#   result = service.update(updates: [
#     { storage_code: 'MAIN', value: 100 },
#     { storage_code: 'INCOMING', value: 50, eta: '2025-11-15' }
#   ])
#
# @example Success response
#   {
#     success: true,
#     inventory: {
#       available: 100,
#       incoming: 50,
#       eta: #<Date: 2025-11-15>
#     },
#     updates: [
#       { storage_code: 'MAIN', value: 100, updated: true },
#       { storage_code: 'INCOMING', value: 50, eta: '2025-11-15', updated: true }
#     ]
#   }
#
# @example Error response
#   {
#     success: false,
#     error: 'Storage not found: INVALID',
#     details: { storage_code: 'INVALID' }
#   }
#
class InventoryUpdateService
  attr_reader :company, :product, :errors

  def initialize(company, product)
    @company = company
    @product = product
    @errors = []
  end

  # Update inventory for product
  #
  # @param updates [Array<Hash>] Array of inventory updates
  # @option updates [String] :storage_code Storage code (required)
  # @option updates [Integer] :value Inventory quantity (required)
  # @option updates [String, Date] :eta Estimated arrival date (optional, for incoming storage)
  #
  # @return [Hash] Result with success status and inventory data
  #
  def update(updates:)
    # Validate input
    unless updates.is_a?(Array) && updates.any?
      return error_response("Updates must be a non-empty array")
    end

    # Process updates in transaction
    results = []
    first_error = nil

    ActiveRecord::Base.transaction do
      updates.each do |update_params|
        result = process_update(update_params)

        if result[:error]
          # Store first error for reporting
          first_error ||= result[:error]
          # Rollback transaction
          raise ActiveRecord::Rollback
        end

        results << result
      end

      # If we got here, all updates succeeded
      return success_response(results)
    end

    # Transaction was rolled back - return the specific error
    error_response(
      first_error || "Failed to update inventory",
      details: { failed_updates: results.select { |r| r[:error] } }
    )
  end

  private

  # Process a single inventory update
  #
  # @param update_params [Hash] Update parameters
  # @return [Hash] Result with storage_code, value, updated status
  #
  def process_update(update_params)
    storage_code = update_params[:storage_code]
    value = update_params[:value]
    eta = update_params[:eta]

    # Validate required fields
    if storage_code.blank?
      return { error: "storage_code is required", storage_code: storage_code }
    end

    if value.blank?
      return { error: "value is required", storage_code: storage_code }
    end

    # Convert value to integer
    begin
      value = Integer(value)
    rescue ArgumentError, TypeError
      return {
        error: "Invalid value: #{value}",
        storage_code: storage_code
      }
    end

    # Find storage by code
    storage = company.storages.find_by(code: storage_code)

    unless storage
      return {
        error: "Storage not found: #{storage_code}",
        storage_code: storage_code
      }
    end

    # Find or create inventory record
    inventory = product.inventories.find_or_initialize_by(storage: storage)

    # Update inventory value
    inventory.value = value

    # Update ETA if provided (for incoming storage)
    if eta.present?
      inventory.eta = parse_eta(eta)
    end

    # Save inventory
    if inventory.save
      {
        storage_code: storage_code,
        storage_name: storage.name,
        value: value,
        eta: inventory.eta,
        updated: true
      }
    else
      {
        error: "Failed to save inventory: #{inventory.errors.full_messages.join(', ')}",
        storage_code: storage_code
      }
    end
  end

  # Parse ETA date from string or Date object
  #
  # @param eta [String, Date, nil] ETA value
  # @return [Date, nil] Parsed date or nil
  #
  def parse_eta(eta)
    return nil if eta.blank?
    return eta if eta.is_a?(Date)

    begin
      Date.parse(eta.to_s)
    rescue ArgumentError
      nil
    end
  end

  # Build success response
  #
  # @param results [Array<Hash>] Update results
  # @return [Hash] Success response
  #
  def success_response(results)
    # Reload product to get fresh inventory data
    product.reload

    {
      success: true,
      inventory: product.single_inventory_with_eta,
      updates: results
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
