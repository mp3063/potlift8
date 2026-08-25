class ProductValidator
  attr_reader :product, :errors

  def initialize(product)
    @product = product
    @errors = []
  end

  def validate_structure
    @errors = []

    validate_product_type_structure
    validate_mandatory_attributes
    validate_attribute_rules

    @errors
  end

  def validate_for_catalog(catalog)
    @errors = []

    validate_structure

    validate_catalog_specific_attributes(catalog)
    validate_pricing_for_currency(catalog)

    @errors
  end

  def valid?
    validate_structure.empty?
  end

  private

  def validate_product_type_structure
    case product.product_type.to_sym
    when :configurable
      validate_configurable_structure
    when :bundle
      validate_bundle_structure
    when :sellable
    end
  end

  def validate_configurable_structure
    if product.subproducts.empty?
      @errors << "Configurable product must have at least one variant"
      return
    end

    invalid_subproducts = product.subproducts.select do |subproduct|
      subproduct.product_status_draft? || subproduct.product_status_deleted?
    end

    if invalid_subproducts.any?
      @errors << "All variants must be active or incoming"
    end
  end

  def validate_bundle_structure
    if product.product_configurations_as_super.empty?
      @errors << "Bundle product must have at least one subproduct"
      return
    end

    product.product_configurations_as_super.each do |config|
      raw_quantity = config.info["quantity"]

      # Quantity must be explicitly set and positive for bundles
      if raw_quantity.nil? || raw_quantity.to_i <= 0
        @errors << "Invalid quantity for subproduct #{config.subproduct.sku}"
      end
    end
  end

  def validate_mandatory_attributes
    mandatory_attributes = product.company.product_attributes
                                  .all_mandatory
                                  .where(product_attribute_scope: [
                                    :product_scope,
                                    :product_and_catalog_scope
                                  ])

    mandatory_attributes.each do |attr|
      pav = product.product_attribute_values.find do |value|
        value.product_attribute_id == attr.id
      end

      if pav.nil? || pav.value.blank?
        inherited = product.superproducts.any? { |sp| sp.read_attribute_value(attr.code).present? }
        @errors << "Mandatory attribute '#{attr.name}' is missing" unless inherited
      end
    end
  end

  def validate_attribute_rules
    product.product_attribute_values.includes(:product_attribute).each do |pav|
      attr = pav.product_attribute

      next unless attr.has_rules

      attr.rules.each do |rule|
        next if attr.send(rule, pav.value)

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

  def validate_catalog_specific_attributes(catalog)
    return unless defined?(Catalog) && catalog.is_a?(Catalog)

    mandatory_catalog_attributes = catalog.company.product_attributes
                                          .all_mandatory
                                          .where(product_attribute_scope: [
                                            :catalog_scope,
                                            :product_and_catalog_scope
                                          ])

    mandatory_catalog_attributes.each do |attr|
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

  def validate_pricing_for_currency(catalog)
    return unless defined?(Catalog) && catalog.is_a?(Catalog)
    return if catalog.currency_code.blank?
    return if catalog.currency_code.downcase == "eur"

    minimum_ratio = Catalog::MINIMUM_CURRENCY_RATIO[catalog.currency_code]
    return if minimum_ratio.nil?

    product_price_attr = product.product_attribute_values.joins(:product_attribute)
                                .find_by(product_attributes: { code: "price" })
    return if product_price_attr.nil?

    product_price = product_price_attr.value.to_f

    catalog_price = if catalog.respond_to?(:get_product_price)
                      catalog.get_product_price(product)
    elsif catalog.respond_to?(:catalog_items)
                      catalog_item = catalog.catalog_items.find_by(product_id: product.id)
                      catalog_item&.price
    end

    return if catalog_price.nil?

    minimum_price = product_price * minimum_ratio

    if catalog_price < minimum_price
      @errors << "Price for #{catalog.currency_code} is below minimum ratio"
    end
  end
end
