# frozen_string_literal: true

# Service to calculate available bundle inventory based on component availability
#
# Usage:
#   calculator = BundleInventoryCalculator.new(bundle_product)
#   available = calculator.calculate
#   # => 5 (maximum bundles that can be assembled)
#
#   breakdown = calculator.detailed_breakdown
#   # => { bundle_limit: 5, components: [...] }
#
# Example:
#   Bundle: "Welcome Kit"
#     - 1x T-Shirt (available: 100)
#     - 2x Stickers (available: 10)  <- Bottleneck!
#     - 1x Bag (available: 50)
#
#   calculate => 5 (limited by stickers: 10 / 2 = 5)
#
# Features:
#   - Calculates minimum across all component limits
#   - Respects component quantities (e.g., 2x stickers per bundle)
#   - Identifies bottleneck components
#   - Uses max_sellable_saldo from component inventories
#   - Handles missing/zero inventory gracefully
#
# Integration:
#   - Complements InventoryCalculator concern
#   - Can be used for real-time availability checks
#   - Useful for bundle activation validation
#
class BundleInventoryCalculator
  attr_reader :bundle

  def initialize(bundle)
    @bundle = bundle
  end

  # Calculate maximum bundles that can be assembled
  # Returns: Integer (0 if bundle cannot be assembled)
  def calculate
    return 0 unless bundle.product_type_bundle?

    components = load_components
    return 0 if components.empty?

    calculate_bundle_limit(components)
  end

  # Detailed breakdown showing limiting component
  # Returns: Hash with bundle_limit and component details
  def detailed_breakdown
    return empty_breakdown unless bundle.product_type_bundle?

    components = load_components
    return empty_breakdown if components.empty?

    bundle_limit = calculate_bundle_limit(components)

    {
      bundle_sku: bundle.sku,
      bundle_name: bundle.name,
      bundle_limit: bundle_limit,
      can_assemble: bundle_limit > 0,
      components: component_details(components, bundle_limit),
      bottleneck_components: bottleneck_components(components, bundle_limit)
    }
  end

  # Check if bundle can be assembled (at least 1 available)
  # Returns: Boolean
  def can_assemble?
    calculate > 0
  end

  # Calculate inventory value (limit * component value)
  # Useful for inventory reporting
  # Returns: Hash with total_value and component breakdown
  def inventory_value
    return { total_value: 0, components: [] } unless bundle.product_type_bundle?

    components = load_components
    return { total_value: 0, components: [] } if components.empty?

    bundle_limit = calculate_bundle_limit(components)
    total_value = 0

    component_values = components.map do |config|
      subproduct = config.subproduct
      required = config.quantity
      available = subproduct.total_max_sellable_saldo

      # Calculate value used in bundles
      units_in_bundles = bundle_limit * required
      value_per_unit = fetch_component_value(subproduct)
      component_value = units_in_bundles * value_per_unit

      total_value += component_value

      {
        sku: subproduct.sku,
        name: subproduct.name,
        required_quantity: required,
        available_inventory: available,
        units_in_bundles: units_in_bundles,
        value_per_unit: value_per_unit,
        total_value: component_value
      }
    end

    {
      bundle_limit: bundle_limit,
      total_value: total_value,
      components: component_values
    }
  end

  # Find which component is the bottleneck
  # Returns: Hash with component details or nil if no bottleneck
  def bottleneck_component
    components = load_components
    return nil if components.empty?

    bundle_limit = calculate_bundle_limit(components)
    return nil if bundle_limit.zero?

    bottlenecks = components.select do |config|
      subproduct = config.subproduct
      required = config.quantity
      available = subproduct.total_max_sellable_saldo
      limit = (available.to_f / required).floor

      limit == bundle_limit
    end

    # Return first bottleneck (there may be multiple with same limit)
    return nil if bottlenecks.empty?

    config = bottlenecks.first
    {
      sku: config.subproduct.sku,
      name: config.subproduct.name,
      required_quantity: config.quantity,
      available_inventory: config.subproduct.total_max_sellable_saldo,
      bundle_limit: bundle_limit
    }
  end

  private

  def load_components
    bundle.product_configurations_as_super
          .includes(subproduct: :inventories)
          .order(:position)
  end

  def calculate_bundle_limit(components)
    component_limits = components.map do |config|
      subproduct = config.subproduct
      required_quantity = config.quantity

      # Validate required quantity
      if required_quantity.nil? || required_quantity <= 0
        Rails.logger.warn("Invalid quantity for component #{subproduct.sku}: #{required_quantity}")
        return 0
      end

      available = subproduct.total_max_sellable_saldo

      # Calculate how many bundles can be made with this component
      (available.to_f / required_quantity).floor
    end

    # Bundle limit is minimum across all components
    component_limits.min || 0
  end

  def component_details(components, bundle_limit)
    components.map do |config|
      subproduct = config.subproduct
      required = config.quantity
      available = subproduct.total_max_sellable_saldo
      limit = available > 0 ? (available.to_f / required).floor : 0

      {
        product_configuration_id: config.id,
        sku: subproduct.sku,
        name: subproduct.name,
        product_type: subproduct.product_type,
        required_quantity: required,
        available_inventory: available,
        bundle_limit: limit,
        is_bottleneck: (limit == bundle_limit),
        units_needed_for_bundles: bundle_limit * required,
        units_remaining: available - (bundle_limit * required),
        position: config.position
      }
    end
  end

  def bottleneck_components(components, bundle_limit)
    component_details(components, bundle_limit).select do |detail|
      detail[:is_bottleneck]
    end
  end

  def empty_breakdown
    {
      bundle_sku: bundle&.sku,
      bundle_name: bundle&.name,
      bundle_limit: 0,
      can_assemble: false,
      components: [],
      bottleneck_components: []
    }
  end

  def fetch_component_value(product)
    # Try to get price from product attributes
    # This assumes you have a 'price' attribute in EAV system
    price_value = product.read_attribute_value("price")
    return 0 if price_value.blank?

    # Handle different price formats (string, float, etc.)
    case price_value
    when Numeric
      price_value
    when String
      price_value.gsub(/[^\d.]/, "").to_f
    else
      0
    end
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch price for #{product.sku}: #{e.message}")
    0
  end
end
