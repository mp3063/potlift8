class ProductDetailSerializer
  attr_reader :product

  def initialize(product)
    @product = product
  end

  def as_json(_options = {})
    {
      id: product.id,
      sku: product.sku,
      name: product.name,
      ean: product.ean,
      product_type: product.product_type,
      configuration_type: product.configuration_type,
      product_status: product.product_status,
      total_saldo: product.total_saldo,
      structure: product.structure || {},
      info: product.info || {},
      cache: product.cache || {},
      inventory: serialize_inventory,
      attributes: serialize_attributes,
      labels: serialize_labels,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end

  private

  def serialize_inventory
    product.single_inventory_with_eta
  end

  def serialize_attributes
    product.attribute_values_hash
  end

  def serialize_labels
    product.labels.map do |label|
      {
        code: label.code,
        name: label.name
      }
    end
  end
end
