# frozen_string_literal: true

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

  def can_assemble?
    calculate > 0
  end

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

      if required_quantity.nil? || required_quantity <= 0
        Rails.logger.warn("Invalid quantity for component #{subproduct.sku}: #{required_quantity}")
        return 0
      end

      available = subproduct.total_max_sellable_saldo

      (available.to_f / required_quantity).floor
    end

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
    price_value = product.read_attribute_value("price")
    return 0 if price_value.blank?

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
