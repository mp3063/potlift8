# frozen_string_literal: true

# Service to generate all possible variant combinations from configurations
#
# Usage:
#   service = VariantGeneratorService.new(configurable_product)
#   count = service.generate!
#   # => Creates all variant combinations and returns count
#
# Example:
#   T-Shirt (configurable)
#     - Size: Small, Medium, Large
#     - Color: Red, Blue
#
#   Generates 6 variants:
#     - T-Shirt Small Red
#     - T-Shirt Small Blue
#     - T-Shirt Medium Red
#     - T-Shirt Medium Blue
#     - T-Shirt Large Red
#     - T-Shirt Large Blue
#
# Features:
#   - Generates Cartesian product of all configuration values
#   - Creates variant products as sellable type
#   - Links variants to configurable via ProductConfiguration
#   - Stores variant_config in ProductConfiguration.info
#   - Prevents duplicate variants
#   - Inherits parent product status
#   - Generates unique SKUs with collision handling
#
# Error Handling:
#   - Validates product type and configuration
#   - Collects all errors during batch generation
#   - Skips existing variants gracefully
#   - Returns count of successfully created variants
#
class VariantGeneratorService
  attr_reader :product, :company, :errors

  def initialize(product)
    @product = product
    @company = product.company
    @errors = []
  end

  # Generate all variant combinations
  # Returns: Integer (number of variants created)
  def generate!
    validate_product!
    return 0 if errors.any?

    configurations = load_configurations
    if configurations.empty?
      @errors << "No configurations found for product"
      return 0
    end

    combinations = generate_combinations(configurations)
    if combinations.empty?
      @errors << "No valid combinations could be generated"
      return 0
    end

    create_variants(combinations)
  end

  # Generate variants without saving (preview mode)
  # Returns: Array of hashes with variant details
  def preview
    validate_product!
    return [] if errors.any?

    configurations = load_configurations
    return [] if configurations.empty?

    combinations = generate_combinations(configurations)
    return [] if combinations.empty?

    preview_variants(combinations)
  end

  # Check if all required configurations have values
  def valid_for_generation?
    validate_product!
    return false if errors.any?

    configurations = load_configurations
    return false if configurations.empty?

    configurations.all? { |config| config.configuration_values.any? }
  end

  # Count how many variants would be generated
  def variant_count
    return 0 unless valid_for_generation?

    configurations = load_configurations
    combinations = generate_combinations(configurations)
    combinations.size
  end

  private

  def validate_product!
    unless product.product_type_configurable?
      @errors << "Product must be configurable type"
      return false
    end

    unless product.configuration_type_variant?
      @errors << "Product must have variant configuration type"
      return false
    end

    if product.new_record?
      @errors << "Product must be persisted before generating variants"
      return false
    end

    true
  end

  def load_configurations
    product.configurations
           .includes(:configuration_values)
           .order(:position)
  end

  def generate_combinations(configurations)
    # Get all values for each configuration
    value_sets = configurations.map do |config|
      values = config.configuration_values.order(:position)

      if values.empty?
        @errors << "Configuration '#{config.name}' has no values"
        return []
      end

      values.map do |value|
        {
          configuration_id: config.id,
          configuration_code: config.code,
          configuration_name: config.name,
          value_id: value.id,
          value: value.value
        }
      end
    end

    return [] if value_sets.any?(&:empty?)

    # Generate Cartesian product
    # For single configuration, wrap in array
    if value_sets.size == 1
      value_sets.first.map { |v| [v] }
    else
      value_sets.first.product(*value_sets[1..])
    end
  end

  def create_variants(combinations)
    count = 0
    skipped = 0

    ActiveRecord::Base.transaction do
      combinations.each do |combination|
        # Build variant config hash
        variant_config = build_variant_config(combination)

        # Check if variant already exists
        if variant_exists?(variant_config)
          skipped += 1
          next
        end

        # Create variant
        variant = create_variant_product(combination, variant_config)
        if variant&.persisted?
          link_variant(variant, combination, variant_config)
          count += 1
        end
      end
    end

    Rails.logger.info("VariantGenerator: Created #{count} variants, skipped #{skipped} existing")
    count
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Transaction failed: #{e.message}"
    0
  end

  def preview_variants(combinations)
    combinations.map do |combination|
      variant_config = build_variant_config(combination)
      exists = variant_exists?(variant_config)

      {
        sku: generate_preview_sku(combination),
        name: generate_variant_name(combination),
        variant_config: variant_config,
        exists: exists,
        status: exists ? 'existing' : 'new'
      }
    end
  end

  def build_variant_config(combination)
    combination.each_with_object({}) do |item, hash|
      hash[item[:configuration_code]] = item[:value]
    end
  end

  def variant_exists?(variant_config)
    product.product_configurations_as_super.any? do |pc|
      pc.info.present? && pc.info['variant_config'] == variant_config
    end
  end

  def create_variant_product(combination, variant_config)
    # Generate unique SKU
    base_suffix = combination.map { |c| sanitize_sku_part(c[:value]) }.join('-')
    sku = generate_unique_sku("#{product.sku}-#{base_suffix}")

    # Generate descriptive name
    name = generate_variant_name(combination)

    # Create variant product
    variant = company.products.create!(
      product_type: :sellable,
      product_status: product.product_status,  # Inherit parent status
      sku: sku,
      name: name
    )

    Rails.logger.debug("Created variant: #{sku} (#{name})")
    variant
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to create variant #{sku}: #{e.message}"
    Rails.logger.error("Variant creation failed: #{e.message}")
    nil
  end

  def link_variant(variant, combination, variant_config)
    # Build detailed metadata for the variant
    configuration_details = combination.map do |item|
      {
        configuration_id: item[:configuration_id],
        configuration_code: item[:configuration_code],
        configuration_name: item[:configuration_name],
        value_id: item[:value_id],
        value: item[:value]
      }
    end

    product.product_configurations_as_super.create!(
      subproduct: variant,
      quantity: 1,  # Variants are 1:1 relationship
      info: {
        variant_config: variant_config,
        configuration_details: configuration_details,
        generated_at: Time.current.iso8601,
        generated_by: 'VariantGeneratorService'
      }
    )
  rescue ActiveRecord::RecordInvalid => e
    @errors << "Failed to link variant #{variant.sku}: #{e.message}"
    Rails.logger.error("Variant linking failed: #{e.message}")
    # Rollback will handle cleanup
    raise
  end

  def generate_variant_name(combination)
    # Format: "Parent Name - Value1 / Value2 / Value3"
    value_parts = combination.map { |c| c[:value] }
    "#{product.name} - #{value_parts.join(' / ')}"
  end

  def generate_preview_sku(combination)
    base_suffix = combination.map { |c| sanitize_sku_part(c[:value]) }.join('-')
    sanitize_sku("#{product.sku}-#{base_suffix}")
  end

  def generate_unique_sku(base_sku)
    # Sanitize SKU (uppercase, alphanumeric + hyphen only)
    sku = sanitize_sku(base_sku)

    # Check if SKU is available
    return sku unless company.products.exists?(sku: sku)

    # Append incrementing number if collision detected
    counter = 1
    loop do
      candidate = "#{sku}-#{counter}"
      break candidate unless company.products.exists?(sku: candidate)

      counter += 1

      # Safety check to prevent infinite loop
      if counter > 1000
        raise "Unable to generate unique SKU after 1000 attempts for base: #{base_sku}"
      end
    end
  end

  def sanitize_sku(sku)
    # Convert to uppercase, remove non-alphanumeric except hyphen
    # Replace spaces with hyphens, collapse multiple hyphens
    sku.to_s
       .upcase
       .gsub(/\s+/, '-')
       .gsub(/[^A-Z0-9-]/, '')
       .gsub(/-+/, '-')
       .gsub(/^-|-$/, '')  # Remove leading/trailing hyphens
  end

  def sanitize_sku_part(part)
    # Sanitize individual part (configuration value)
    part.to_s
        .strip
        .upcase
        .gsub(/\s+/, '-')
        .gsub(/[^A-Z0-9-]/, '')
        .gsub(/-+/, '-')
        .gsub(/^-|-$/, '')
  end
end
