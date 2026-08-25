# Validation Rules:
# - EUR catalogs: No ratio validation required (base currency)
# - SEK catalogs: Price must be at least 1.5x EUR price
# - NOK catalogs: Price must be at least 1.5x EUR price
class CatalogPriceValidator
  attr_reader :errors

  def initialize(catalog_item)
    @catalog_item = catalog_item
    @catalog = catalog_item.catalog
    @product = catalog_item.product
    @errors = []
  end

  def validate
    return true if @catalog.currency_code == "eur"

    validate_price_ratio

    @errors.empty?
  end

  def valid?
    validate
  end

  private

  def validate_price_ratio
    base_price = get_base_price
    catalog_price = get_catalog_price

    if base_price.nil? || base_price.zero?
      @errors << "Base price (EUR) is missing"
      return
    end

    if catalog_price.nil? || catalog_price.zero?
      @errors << "Catalog price (#{@catalog.currency_code.upcase}) is missing"
      return
    end

    minimum_ratio = @catalog.minimum_ratio
    actual_ratio = catalog_price / base_price

    if actual_ratio < minimum_ratio
      @errors << "Price ratio #{actual_ratio.round(2)} is below minimum #{minimum_ratio}"
    end
  end

  def get_base_price
    price_value = @product.read_attribute_value("price")
    return nil if price_value.blank?

    price_value.to_f
  end

  # Get the catalog-specific price (catalog override only, not fallback)
  def get_catalog_price
    price_attr = @catalog.company.product_attributes.find_by(code: "price")
    return nil unless price_attr

    # Check for catalog-level override only (don't fall back to product price)
    ciav = @catalog_item.catalog_item_attribute_values.find_by(product_attribute: price_attr)
    return nil if ciav.nil? || ciav.value.blank?

    ciav.value.to_f
  end
end
