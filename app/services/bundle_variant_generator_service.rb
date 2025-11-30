# frozen_string_literal: true

# Service to generate bundle variant products from a bundle configuration
#
# Usage:
#   configuration = {
#     'components' => [
#       { 'product_id' => 123, 'product_type' => 'sellable', 'quantity' => 2 },
#       {
#         'product_id' => 456,
#         'product_type' => 'configurable',
#         'variants' => [
#           { 'variant_id' => 789, 'included' => true, 'quantity' => 1, 'code' => 'S' },
#           { 'variant_id' => 790, 'included' => true, 'quantity' => 1, 'code' => 'M' }
#         ]
#       }
#     ]
#   }
#
#   service = BundleVariantGeneratorService.new(bundle_product, configuration)
#   result = service.call
#
#   if result.success?
#     puts "Generated #{result.variants.count} bundle variants"
#     result.variants.each { |v| puts v.sku }
#   else
#     puts "Errors: #{result.errors.join(', ')}"
#   end
#
# How it works:
#   1. Validates product is bundle type
#   2. Validates configuration using BundleValidationService
#   3. Generates all variant combinations from configurables (cartesian product)
#   4. For each combination:
#      - Creates a new Product (sellable type, bundle_variant: true)
#      - Generates SKU using BundleSkuGeneratorService
#      - Creates ProductConfiguration records linking variant to components
#   5. Creates/updates BundleTemplate
#   6. Returns Result with variants array
#
class BundleVariantGeneratorService
  Result = Struct.new(:success?, :variants, :errors, keyword_init: true)

  attr_reader :bundle_product, :configuration, :company

  def initialize(bundle_product, configuration)
    @bundle_product = bundle_product
    @configuration = configuration
    @company = bundle_product&.company
    @errors = []
    @variants = []
  end

  def call
    # Validate product type
    unless bundle_product&.product_type_bundle?
      return Result.new(success?: false, variants: [], errors: [ "Product must be a bundle type" ])
    end

    # Validate configuration
    validator = BundleValidationService.new(configuration, company: company)
    unless validator.valid?
      return Result.new(success?: false, variants: [], errors: validator.errors)
    end

    # Generate variants
    begin
      ActiveRecord::Base.transaction do
        generate_variants
        update_bundle_template
      end

      Result.new(success?: true, variants: @variants, errors: [])
    rescue StandardError => e
      Result.new(success?: false, variants: [], errors: [ "Failed to generate variants: #{e.message}" ])
    end
  end

  private

  def generate_variants
    combinations = build_variant_combinations

    combinations.each do |combination|
      variant = create_variant_product(combination)
      link_components_to_variant(variant, combination)
      @variants << variant
    end
  end

  # Build all combinations of variants from configurables
  # Returns array of hashes with component details
  def build_variant_combinations
    components = configuration["components"]
    return [] if components.blank?

    # Separate sellables from configurables
    sellable_components = components.select { |c| c["product_type"] == "sellable" }
    configurable_components = components.select { |c| c["product_type"] == "configurable" }

    # Get included variants for each configurable
    configurable_variants = configurable_components.map do |configurable_component|
      product_id = configurable_component["product_id"]
      variants_data = configurable_component["variants"] || []

      # Filter to only included variants
      included_variants = variants_data.select { |v| v["included"] == true }

      # Map to full component data
      included_variants.map do |variant_data|
        {
          "component_type" => "configurable_variant",
          "product_id" => product_id,
          "variant_id" => variant_data["variant_id"],
          "quantity" => variant_data["quantity"],
          "code" => variant_data["code"]
        }
      end
    end

    # If no configurables, create one combination with just sellables
    if configurable_variants.empty?
      return [ sellable_components ]
    end

    # Generate cartesian product of all configurable variants
    # If only one configurable, wrap each variant in an array
    if configurable_variants.size == 1
      variant_combinations = configurable_variants[0].map { |v| [ v ] }
    else
      # For multiple configurables, use Array#product
      variant_combinations = configurable_variants[0].product(*configurable_variants[1..])
    end

    # For each combination, add the sellables
    variant_combinations.map do |variant_combo|
      # Ensure variant_combo is an array
      variant_array = variant_combo.is_a?(Array) ? variant_combo : [ variant_combo ]

      # Combine sellables with this variant combination
      sellable_components + variant_array
    end
  end

  def create_variant_product(combination)
    # Extract variant codes for SKU generation
    # Reverse order so last configurable appears first in SKU
    variant_codes = combination
                     .select { |c| c["code"].present? }
                     .map { |c| c["code"] }
                     .reverse

    # Generate SKU
    # If no variant codes (sellables only), append a sequential number
    if variant_codes.empty?
      # Use the variant count + 1 for sequential numbering
      variant_number = @variants.count + 1
      variant_sku = "#{bundle_product.sku}-V#{variant_number}"
    else
      variant_sku = BundleSkuGeneratorService.generate(bundle_product.sku, variant_codes)
    end

    # Create the variant product
    # Bundle variants are product_type: bundle (not sellable)
    # They represent specific variant combinations of the template bundle
    variant = company.products.create!(
      sku: variant_sku,
      name: generate_variant_name(combination),
      product_type: :bundle,
      bundle_variant: true,
      parent_bundle: bundle_product,
      product_status: bundle_product.product_status
    )

    variant
  end

  def generate_variant_name(combination)
    # Build name parts from actual component product names
    component_names = combination.filter_map do |component|
      if component["component_type"] == "configurable_variant"
        # For configurable variants, get the variant product name
        variant_product = Product.find_by(id: component["variant_id"])
        extract_variant_descriptor(variant_product) if variant_product
      end
    end

    if component_names.any?
      # Just use component descriptors, no parent name prefix
      component_names.join(" + ")
    else
      # Fallback to parent name if no component names
      bundle_product.name
    end
  end

  # Extract a short descriptor from variant product name
  # e.g., "Cannabis T-Shirt Large/Black" -> "T-Shirt L/Black"
  #       "Cannabis Hoodie Medium" -> "Hoodie M"
  def extract_variant_descriptor(variant_product)
    name = variant_product.name

    # Try to extract variant info from product configuration
    config = variant_product.product_configurations_as_sub.first
    if config&.info&.dig("variant_config").present?
      variant_values = config.info["variant_config"].values
      product_type = extract_product_type(name)
      if product_type && variant_values.any?
        return "#{product_type} #{variant_values.join('/')}"
      elsif variant_values.any?
        return variant_values.join("/")
      end
    end

    # Fallback: use the product name, removing common prefixes
    name.sub(/^Cannabis\s+/i, "")
  end

  # Extract product type from name (e.g., "T-Shirt", "Hoodie")
  def extract_product_type(name)
    case name
    when /T-Shirt/i then "T-Shirt"
    when /Hoodie/i then "Hoodie"
    when /Shirt/i then "Shirt"
    when /Pants/i then "Pants"
    when /Hat/i then "Hat"
    when /Cap/i then "Cap"
    else nil
    end
  end

  def link_components_to_variant(variant, combination)
    combination.each do |component|
      # Determine which product to link
      subproduct_id = if component["component_type"] == "configurable_variant"
                        component["variant_id"]
      else
                        component["product_id"]
      end

      # Create ProductConfiguration linking variant (super) to component (sub)
      variant.product_configurations_as_super.create!(
        subproduct_id: subproduct_id,
        info: { "quantity" => component["quantity"] }
      )
    end
  end

  def update_bundle_template
    template = bundle_product.bundle_template || bundle_product.build_bundle_template(company: company)

    template.update!(
      configuration: configuration,
      generated_variants_count: @variants.count,
      last_generated_at: Time.current
    )
  end
end
