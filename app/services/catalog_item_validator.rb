# CatalogItemValidator Service
#
# Comprehensive validation for catalog items, ensuring they are ready for sale.
# Validates product structure, mandatory attributes, and pricing rules.
#
# Validation Checks:
# 1. Product Structure: Validates using ProductValidator
# 2. Mandatory Attributes: Ensures all catalog-scoped mandatory attributes have values
# 3. Pricing: Validates currency ratios using CatalogPriceValidator
#
# Usage:
#   validator = CatalogItemValidator.new(catalog_item)
#   if validator.valid?
#     # Catalog item is ready for sale
#   else
#     # Check validator.errors for specific issues
#   end
#
class CatalogItemValidator
  attr_reader :errors

  def initialize(catalog_item)
    @catalog_item = catalog_item
    @catalog = catalog_item.catalog
    @product = catalog_item.product
    @errors = []
  end

  # Validate catalog item
  #
  # @return [Boolean] true if all validations pass, false otherwise
  #
  def valid?
    validate_product_structure
    validate_mandatory_attributes
    validate_pricing

    @errors.empty?
  end

  private

  # Validate product structure using ProductValidator
  #
  def validate_product_structure
    validator = ProductValidator.new(@product)
    structure_errors = validator.validate_structure

    @errors.concat(structure_errors) if structure_errors.any?
  end

  # Validate mandatory catalog-level attributes
  #
  # Checks that all mandatory attributes with catalog or product_and_catalog scope
  # have values (either at product or catalog level).
  #
  def validate_mandatory_attributes
    # Get mandatory attributes that apply to catalogs
    mandatory_attrs = @catalog.company.product_attributes
                              .where(mandatory: true)
                              .where(product_attribute_scope: [ :catalog_scope, :product_and_catalog_scope ])

    mandatory_attrs.each do |attr|
      value = @catalog_item.effective_attribute_value(attr.code)

      if value.blank?
        @errors << "Mandatory catalog attribute '#{attr.name}' is missing"
      end
    end
  end

  # Validate pricing using CatalogPriceValidator
  #
  def validate_pricing
    price_validator = CatalogPriceValidator.new(@catalog_item)

    unless price_validator.validate
      @errors.concat(price_validator.errors)
    end
  end
end
