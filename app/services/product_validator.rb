# ProductValidator Service
#
# Validates product structure and catalog-specific requirements.
# Used for product activation, catalog synchronization, and ensuring data integrity.
#
# Usage:
#   validator = ProductValidator.new(product)
#   if validator.valid?
#     # Product structure is valid
#   else
#     validator.validate_structure # => array of error messages
#   end
#
#   # Validate for specific catalog
#   errors = validator.validate_for_catalog(catalog)
#
class ProductValidator
  attr_reader :product, :errors

  # Initialize the validator with a product
  #
  # @param product [Product] The product to validate
  #
  def initialize(product)
    @product = product
    @errors = []
  end

  # Validates product structure
  # Checks product type requirements, mandatory attributes, and attribute rules
  #
  # @return [Array<String>] Array of error messages (empty if valid)
  #
  def validate_structure
    @errors = []

    validate_product_type_structure
    validate_mandatory_attributes
    validate_attribute_rules

    @errors
  end

  # Validates product for a specific catalog
  # Checks catalog-specific attributes and pricing requirements
  #
  # @param catalog [Catalog] The catalog to validate against
  # @return [Array<String>] Array of error messages (empty if valid)
  #
  def validate_for_catalog(catalog)
    @errors = []

    # First validate basic structure
    validate_structure

    # Then add catalog-specific validations
    validate_catalog_specific_attributes(catalog)
    validate_pricing_for_currency(catalog)

    @errors
  end

  # Checks if product structure is valid
  #
  # @return [Boolean] true if no validation errors
  #
  def valid?
    validate_structure.empty?
  end

  private

  # Validates product type specific requirements
  #
  def validate_product_type_structure
    case product.product_type.to_sym
    when :configurable
      validate_configurable_structure
    when :bundle
      validate_bundle_structure
    when :sellable
      # No special validation for sellable products
    end
  end

  # Validates configurable product structure
  # Ensures product has variants and they are in valid states
  #
  def validate_configurable_structure
    if product.subproducts.empty?
      @errors << "Configurable product must have at least one variant"
      return
    end

    # Check that all subproducts are in valid states (not draft or deleted)
    invalid_subproducts = product.subproducts.select do |subproduct|
      subproduct.product_status_draft? || subproduct.product_status_deleted?
    end

    if invalid_subproducts.any?
      @errors << "All variants must be active or incoming"
    end
  end

  # Validates bundle product structure
  # Ensures bundle has subproducts with valid quantities
  #
  def validate_bundle_structure
    if product.product_configurations_as_super.empty?
      @errors << "Bundle product must have at least one subproduct"
      return
    end

    # Check that all configurations have valid quantities
    # We check the raw value from info, not the quantity method which has a default
    product.product_configurations_as_super.each do |config|
      raw_quantity = config.info["quantity"]

      # Quantity must be explicitly set and positive for bundles
      if raw_quantity.nil? || raw_quantity.to_i <= 0
        @errors << "Invalid quantity for subproduct #{config.subproduct.sku}"
      end
    end
  end

  # Validates mandatory product attributes
  # Checks that all mandatory attributes have values
  #
  def validate_mandatory_attributes
    # Get mandatory attributes with product scope
    mandatory_attributes = product.company.product_attributes
                                  .all_mandatory
                                  .where(product_attribute_scope: [
                                    :product_scope,
                                    :product_and_catalog_scope
                                  ])

    mandatory_attributes.each do |attr|
      # Check if product has this attribute value
      pav = product.product_attribute_values.find do |value|
        value.product_attribute_id == attr.id
      end

      # Error if attribute is missing or has no value
      if pav.nil? || pav.value.blank?
        @errors << "Mandatory attribute '#{attr.name}' is missing"
      end
    end
  end

  # Validates attribute values against their rules
  # Applies ProductAttribute rules to each product_attribute_value
  #
  def validate_attribute_rules
    # Get attributes with rules
    product.product_attribute_values.includes(:product_attribute).each do |pav|
      attr = pav.product_attribute

      # Skip if no rules defined
      next unless attr.has_rules

      # Validate each rule
      attr.rules.each do |rule|
        next if attr.send(rule, pav.value)

        # Rule failed - add error
        case rule
        when "positive"
          @errors << "Attribute '#{attr.name}' value must be positive"
        when "not_null"
          @errors << "Attribute '#{attr.name}' value cannot be blank"
        else
          @errors << "Attribute '#{attr.name}' value doesn't match validation rules"
        end
      end
    end
  end

  # Validates catalog-specific mandatory attributes
  # Checks attributes required for a specific catalog
  #
  # @param catalog [Catalog] The catalog to validate against
  #
  def validate_catalog_specific_attributes(catalog)
    return unless defined?(Catalog) && catalog.is_a?(Catalog)

    # Get catalog mandatory attributes
    mandatory_catalog_attributes = catalog.company.product_attributes
                                          .all_mandatory
                                          .where(product_attribute_scope: [
                                            :catalog_scope,
                                            :product_and_catalog_scope
                                          ])

    mandatory_catalog_attributes.each do |attr|
      # Check both catalog_item_attribute_values and product_attribute_values
      has_catalog_value = catalog.respond_to?(:catalog_item_attribute_values) &&
                          catalog.catalog_item_attribute_values.exists?(
                            product_id: product.id,
                            product_attribute_id: attr.id
                          )

      has_product_value = product.product_attribute_values.exists?(
        product_attribute_id: attr.id
      )

      unless has_catalog_value || has_product_value
        @errors << "Catalog attribute '#{attr.name}' is missing"
      end
    end
  end

  # Validates pricing for different currencies
  # Ensures catalog prices meet minimum ratio requirements
  #
  # @param catalog [Catalog] The catalog to validate against
  #
  def validate_pricing_for_currency(catalog)
    return unless defined?(Catalog) && catalog.is_a?(Catalog)
    return if catalog.currency_code.blank?
    return if catalog.currency_code.downcase == "eur"

    # Get minimum ratio for currency
    minimum_ratio = Catalog::MINIMUM_CURRENCY_RATIO[catalog.currency_code]
    return if minimum_ratio.nil?

    # Get product price (from product_attribute_values with code 'price')
    product_price_attr = product.product_attribute_values.joins(:product_attribute)
                                .find_by(product_attributes: { code: "price" })
    return if product_price_attr.nil?

    product_price = product_price_attr.value.to_f

    # Get catalog price for this product
    catalog_price = if catalog.respond_to?(:get_product_price)
                      catalog.get_product_price(product)
    elsif catalog.respond_to?(:catalog_items)
                      catalog_item = catalog.catalog_items.find_by(product_id: product.id)
                      catalog_item&.price
    end

    return if catalog_price.nil?

    # Validate minimum ratio
    minimum_price = product_price * minimum_ratio

    if catalog_price < minimum_price
      @errors << "Price for #{catalog.currency_code} is below minimum ratio"
    end
  end
end
