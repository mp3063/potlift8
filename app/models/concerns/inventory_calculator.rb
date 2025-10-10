# InventoryCalculator Concern
#
# Provides complex inventory calculation methods for products across different product types
# and warehouses. This concern handles inventory logic for:
# - Sellable products: Simple inventory tracking
# - Configurable products: Show max of any variant
# - Bundle products: Limited by subproduct with lowest availability ratio
#
# Key Methods:
# - total_saldo: Total inventory across all active warehouses
# - total_max_sellable_saldo: Maximum sellable quantity by product type
# - single_inventory_with_eta: Get single inventory with incoming ETA
# - inventory_by_storage: Get inventory for specific storage
#
# Note: pot3 uses 'value' field in inventories, not 'quantity'
#
require 'active_support/concern'

module InventoryCalculator
  extend ActiveSupport::Concern

  # Calculate total inventory across all active warehouses
  #
  # Sums the 'value' field from inventories, excluding deleted storages.
  # Only counts storages with storage_status != :deleted
  #
  # @return [Integer] Total inventory value across all active storages
  #
  # @example
  #   product.total_saldo # => 150
  #
  def total_saldo
    inventories
      .joins(:storage)
      .where.not(storages: { storage_status: :deleted })
      .sum(:value)
  end

  # Calculate maximum sellable quantity based on product type
  #
  # Product Type Logic:
  # - sellable: Returns total_saldo
  # - configurable: Returns max of all subproducts' total_saldo
  # - bundle: Returns calculate_bundle_max_sellable (limiting factor)
  # - other: Returns 0
  #
  # @return [Integer] Maximum quantity that can be sold
  #
  # @example Sellable product
  #   product.total_max_sellable_saldo # => 100
  #
  # @example Configurable product with variants
  #   # Variant A: 50 units, Variant B: 75 units, Variant C: 30 units
  #   product.total_max_sellable_saldo # => 75 (max of variants)
  #
  # @example Bundle product
  #   # Product A needs 2 units (100 available) = 50 bundles
  #   # Product B needs 3 units (90 available) = 30 bundles
  #   product.total_max_sellable_saldo # => 30 (limiting factor)
  #
  def total_max_sellable_saldo
    case product_type
    when 'sellable'
      total_saldo
    when 'configurable'
      return 0 if subproducts.empty?
      subproducts.map(&:total_saldo).max || 0
    when 'bundle'
      calculate_bundle_max_sellable
    else
      0
    end
  end

  # Get single inventory with incoming ETA information
  #
  # Returns a hash with:
  # - available: Sum from regular + active storages
  # - incoming: First incoming storage value, ordered by ETA
  # - eta: Estimated arrival date for incoming inventory
  #
  # @return [Hash] Inventory information with keys :available, :incoming, :eta
  #
  # @example With incoming inventory
  #   product.single_inventory_with_eta
  #   # => { available: 50, incoming: 100, eta: #<Date: 2025-11-15> }
  #
  # @example Without incoming inventory
  #   product.single_inventory_with_eta
  #   # => { available: 50, incoming: 0, eta: nil }
  #
  def single_inventory_with_eta
    # Calculate regular inventory from regular and active storages
    regular_inventory = inventories
                          .joins(:storage)
                          .where(storages: { storage_type: :regular, storage_status: :active })
                          .sum(:value)

    # Find first incoming inventory ordered by ETA
    incoming_inv = inventories
                     .joins(:storage)
                     .where(storages: { storage_type: :incoming, storage_status: :active })
                     .order(:eta)
                     .first

    {
      available: regular_inventory,
      incoming: incoming_inv&.value || 0,
      eta: incoming_inv&.eta
    }
  end

  # Get inventory value for a specific storage
  #
  # @param storage [Storage] The storage to check
  # @return [Integer] Inventory value for that storage, or 0 if none
  #
  # @example
  #   warehouse = Storage.find_by(code: 'MAIN')
  #   product.inventory_by_storage(warehouse) # => 50
  #
  def inventory_by_storage(storage)
    inventory = inventories.find_by(storage: storage)
    inventory&.value || 0
  end

  private

  # Calculate maximum sellable quantity for bundle products
  #
  # For each subproduct in the bundle:
  # 1. Get child_available = subproduct.total_max_sellable_saldo
  # 2. Get required_quantity = configuration.quantity (from info JSONB)
  # 3. Calculate: child_available / required_quantity
  # 4. Return minimum across all subproducts
  #
  # This ensures we can only sell as many bundles as the limiting subproduct allows.
  #
  # @return [Integer] Maximum number of bundles that can be created
  #
  # @example
  #   # Bundle contains:
  #   # - Product A: 2 required, 100 available = 50 bundles possible
  #   # - Product B: 1 required, 40 available = 40 bundles possible
  #   # - Product C: 3 required, 150 available = 50 bundles possible
  #   product.send(:calculate_bundle_max_sellable) # => 40 (limited by Product B)
  #
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
