# frozen_string_literal: true

# Service to validate bundle configuration before variant generation
#
# Usage:
#   config = {
#     'components' => [
#       { 'product_id' => 123, 'product_type' => 'sellable', 'quantity' => 2 },
#       {
#         'product_id' => 456,
#         'product_type' => 'configurable',
#         'variants' => [
#           { 'variant_id' => 789, 'included' => true, 'quantity' => 1 }
#         ]
#       }
#     ]
#   }
#   service = BundleValidationService.new(config, company: company)
#   if service.valid?
#     # Proceed with bundle creation
#     puts "Will generate #{service.combination_count} bundle variants"
#   else
#     puts "Errors: #{service.errors.join(', ')}"
#   end
#
# Validation Rules:
#   - Min 2 products
#   - Max 3 configurables, max 10 sellables, max 12 total
#   - Max 200 combinations
#   - Quantity 1-99
#   - No duplicate products
#   - Products must exist and not be discontinued
#   - At least one variant must be selected for configurables
#   - Warn (not error) when combinations > 100
#   - Warn for discontinued variants (they'll be skipped)
#
class BundleValidationService
  attr_reader :configuration, :company, :errors, :warnings

  LIMITS = {
    max_configurables: 3,
    max_sellables: 10,
    max_total_products: 12,
    max_combinations: 200,
    max_quantity: 99,
    min_quantity: 1
  }.freeze

  def initialize(configuration, company:)
    @configuration = configuration
    @company = company
    @errors = []
    @warnings = []
    @products_cache = {}
  end

  # Returns true if valid, false otherwise
  def valid?
    @errors = []
    @warnings = []

    validate_structure
    return false if @errors.any?

    validate_components
    return false if @errors.any?

    validate_limits
    return false if @errors.any?

    validate_combinations
    return false if @errors.any?

    true
  end

  # Returns count of variant combinations that would be generated
  def combination_count
    return 0 unless configuration.is_a?(Hash)
    return 0 unless configuration["components"].is_a?(Array)

    components = configuration["components"]
    return 0 if components.empty?

    # Count variants for each configurable
    variant_counts = components.map do |component|
      if component["product_type"] == "configurable"
        count_included_variants(component)
      else
        1  # Sellable products contribute 1 to the product
      end
    end

    # Filter out any zeros
    variant_counts = variant_counts.select { |count| count > 0 }
    return 0 if variant_counts.empty?

    # Calculate cartesian product
    variant_counts.reduce(1, :*)
  end

  private

  def validate_structure
    unless configuration.is_a?(Hash)
      @errors << "Configuration must be a hash"
      return
    end

    unless configuration["components"].is_a?(Array)
      @errors << "Configuration must have components array"
      return
    end

    components = configuration["components"]

    if components.empty?
      @errors << "Bundle must contain at least 2 products"
      return
    end

    if components.size < 2
      @errors << "Bundle must contain at least 2 products"
    end
  end

  def validate_components
    components = configuration["components"]

    # Track product IDs to check for duplicates
    product_ids = []

    components.each do |component|
      product_id = component["product_id"]
      product_type = component["product_type"]

      # Check for duplicates
      if product_ids.include?(product_id)
        @errors << "Duplicate product found in bundle"
        next
      end
      product_ids << product_id

      # Load and validate product
      product = load_product(product_id)
      unless product
        @errors << "Product with ID #{product_id} not found"
        next
      end

      # Check if discontinued
      if product.product_status_discontinued?
        @errors << "Product '#{product.sku}' is discontinued"
        next
      end

      # Validate based on product type
      if product_type == "sellable"
        validate_sellable_component(component, product)
      elsif product_type == "configurable"
        validate_configurable_component(component, product)
      end
    end
  end

  def validate_sellable_component(component, product)
    quantity = component["quantity"].to_i

    if quantity < LIMITS[:min_quantity] || quantity > LIMITS[:max_quantity]
      @errors << "Product '#{product.sku}' quantity must be between #{LIMITS[:min_quantity]} and #{LIMITS[:max_quantity]}"
    end
  end

  def validate_configurable_component(component, product)
    variants = component["variants"]

    unless variants.is_a?(Array)
      @errors << "Configurable product '#{product.sku}' must have variants array"
      return
    end

    # Count included variants
    included_variants = variants.select { |v| v["included"] == true }

    if included_variants.empty?
      @errors << "Configurable product '#{product.sku}' must have at least one variant selected"
      return
    end

    # Validate each variant
    variants.each do |variant_data|
      next unless variant_data["included"]

      variant_id = variant_data["variant_id"]
      quantity = variant_data["quantity"].to_i

      # Load variant product
      variant = load_product(variant_id)
      unless variant
        @errors << "Variant with ID #{variant_id} not found"
        next
      end

      # Warn if variant is discontinued (don't error, it will be skipped)
      if variant.product_status_discontinued?
        @warnings << "Variant '#{variant.sku}' is discontinued and will be skipped"
      end

      # Validate quantity
      if quantity < LIMITS[:min_quantity] || quantity > LIMITS[:max_quantity]
        @errors << "Variant '#{variant.sku}' quantity must be between #{LIMITS[:min_quantity]} and #{LIMITS[:max_quantity]}"
      end
    end
  end

  def validate_limits
    components = configuration["components"]

    # Count by type
    sellable_count = components.count { |c| c["product_type"] == "sellable" }
    configurable_count = components.count { |c| c["product_type"] == "configurable" }
    total_count = components.size

    # Check limits
    if sellable_count > LIMITS[:max_sellables]
      @errors << "Bundle cannot contain more than #{LIMITS[:max_sellables]} sellable products"
    end

    if configurable_count > LIMITS[:max_configurables]
      @errors << "Bundle cannot contain more than #{LIMITS[:max_configurables]} configurable products"
    end

    if total_count > LIMITS[:max_total_products]
      @errors << "Bundle cannot contain more than #{LIMITS[:max_total_products]} total products"
    end
  end

  def validate_combinations
    count = combination_count

    if count > LIMITS[:max_combinations]
      @errors << "Bundle would generate #{count} combinations, maximum is #{LIMITS[:max_combinations]}"
    elsif count > 100
      @warnings << "Bundle will generate #{count} combinations which may take time to process"
    end
  end

  def count_included_variants(component)
    variants = component["variants"]
    return 0 unless variants.is_a?(Array)

    # Count only included variants that are not discontinued
    included_count = 0
    variants.each do |variant_data|
      next unless variant_data["included"] == true

      variant_id = variant_data["variant_id"]
      variant = load_product(variant_id)

      # Count only non-discontinued variants
      if variant && !variant.product_status_discontinued?
        included_count += 1
      end
    end

    included_count
  end

  def load_product(product_id)
    return @products_cache[product_id] if @products_cache.key?(product_id)

    product = company.products.find_by(id: product_id)
    @products_cache[product_id] = product
    product
  end
end
