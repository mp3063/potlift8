# frozen_string_literal: true

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
    unless bundle_product&.product_type_bundle?
      return Result.new(success?: false, variants: [], errors: [ "Product must be a bundle type" ])
    end

    validator = BundleValidationService.new(configuration, company: company)
    unless validator.valid?
      return Result.new(success?: false, variants: [], errors: validator.errors)
    end

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

  def build_variant_combinations
    components = configuration["components"]
    return [] if components.blank?

    sellable_components = components.select { |c| c["product_type"] == "sellable" }
    configurable_components = components.select { |c| c["product_type"] == "configurable" }

    configurable_variants = configurable_components.map do |configurable_component|
      product_id = configurable_component["product_id"]
      variants_data = configurable_component["variants"] || []

      included_variants = variants_data.select { |v| v["included"] == true }

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

    if configurable_variants.empty?
      return [ sellable_components ]
    end

    if configurable_variants.size == 1
      variant_combinations = configurable_variants[0].map { |v| [ v ] }
    else
      variant_combinations = configurable_variants[0].product(*configurable_variants[1..])
    end

    variant_combinations.map do |variant_combo|
      variant_array = variant_combo.is_a?(Array) ? variant_combo : [ variant_combo ]

      sellable_components + variant_array
    end
  end

  def create_variant_product(combination)
    variant_codes = combination
                     .select { |c| c["code"].present? }
                     .map { |c| c["code"] }
                     .reverse

    if variant_codes.empty?
      variant_number = @variants.count + 1
      variant_sku = "#{bundle_product.sku}-V#{variant_number}"
    else
      variant_sku = BundleSkuGeneratorService.generate(bundle_product.sku, variant_codes)
    end

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
    component_names = combination.filter_map do |component|
      if component["component_type"] == "configurable_variant"
        variant_product = Product.find_by(id: component["variant_id"])
        extract_variant_descriptor(variant_product) if variant_product
      end
    end

    if component_names.any?
      component_names.join(" + ")
    else
      # Fallback to parent name if no component names
      bundle_product.name
    end
  end

  def extract_variant_descriptor(variant_product)
    name = variant_product.name

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
      subproduct_id = if component["component_type"] == "configurable_variant"
                        component["variant_id"]
      else
                        component["product_id"]
      end

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
