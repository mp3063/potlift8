class InventoryUpdateService
  attr_reader :company, :product, :errors

  def initialize(company, product)
    @company = company
    @product = product
    @errors = []
  end

  def update(updates:)
    unless updates.is_a?(Array) && updates.any?
      return error_response("Updates must be a non-empty array")
    end

    results = []
    first_error = nil

    ActiveRecord::Base.transaction do
      updates.each do |update_params|
        result = process_update(update_params)

        if result[:error]
          first_error ||= result[:error]
          raise ActiveRecord::Rollback
        end

        results << result
      end

      return success_response(results)
    end

    error_response(
      first_error || "Failed to update inventory",
      details: { failed_updates: results.select { |r| r[:error] } }
    )
  end

  private

  def process_update(update_params)
    storage_code = update_params[:storage_code]
    value = update_params[:value]
    eta = update_params[:eta]

    if storage_code.blank?
      return { error: "storage_code is required", storage_code: storage_code }
    end

    if value.blank?
      return { error: "value is required", storage_code: storage_code }
    end

    begin
      value = Integer(value)
    rescue ArgumentError, TypeError
      return {
        error: "Invalid value: #{value}",
        storage_code: storage_code
      }
    end

    storage = company.storages.find_by(code: storage_code)

    unless storage
      return {
        error: "Storage not found: #{storage_code}",
        storage_code: storage_code
      }
    end

    inventory = product.inventories.find_or_initialize_by(storage: storage)

    inventory.value = value

    if eta.present?
      inventory.eta = parse_eta(eta)
    end

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

  def parse_eta(eta)
    return nil if eta.blank?
    return eta if eta.is_a?(Date)

    begin
      Date.parse(eta.to_s)
    rescue ArgumentError
      nil
    end
  end

  def success_response(results)
    product.reload

    {
      success: true,
      inventory: product.single_inventory_with_eta,
      updates: results
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
