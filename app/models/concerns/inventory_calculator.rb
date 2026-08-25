# Note: pot3 uses 'value' field in inventories, not 'quantity'
require "active_support/concern"

module InventoryCalculator
  extend ActiveSupport::Concern

  def total_saldo
    inventories
      .joins(:storage)
      .where.not(storages: { storage_status: :deleted })
      .sum(:value)
  end

  def total_max_sellable_saldo
    case product_type
    when "sellable"
      total_saldo
    when "configurable"
      return 0 if subproducts.empty?
      subproducts.map(&:total_saldo).max || 0
    when "bundle"
      calculate_bundle_max_sellable
    else
      0
    end
  end

  def single_inventory_with_eta
    total_on_hand = inventories
                      .joins(:storage)
                      .where(storages: { storage_status: :active })
                      .sum(:value)

    incoming_inv = inventories
                     .joins(:storage)
                     .where(storages: { storage_type: :incoming, storage_status: :active })
                     .order(:eta)
                     .first

    eta_quantity = incoming_inv&.info&.dig("eta_quantity").to_i
    eta_date = incoming_inv&.eta || incoming_inv&.info&.dig("eta_date")

    {
      available: total_on_hand,
      incoming: eta_quantity,
      eta: eta_quantity > 0 ? eta_date : nil
    }
  end

  def inventory_by_storage(storage)
    inventory = inventories.find_by(storage: storage)
    inventory&.value || 0
  end

  private

  # For each subproduct in the bundle:
  # 1. Get child_available = subproduct.total_max_sellable_saldo
  # 2. Get required_quantity = configuration.quantity (from info JSONB)
  # 3. Calculate: child_available / required_quantity
  # 4. Return minimum across all subproducts
  def calculate_bundle_max_sellable
    return 0 if product_configurations_as_super.empty?

    ratios = product_configurations_as_super.map do |config|
      child_available = config.subproduct.total_max_sellable_saldo
      required_quantity = config.quantity

      # Avoid division by zero
      next 0 if required_quantity <= 0

      child_available / required_quantity
    end

    ratios.min || 0
  end
end
