class ProductSerializer
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
      product_status: product.product_status,
      total_saldo: product.total_saldo,
      created_at: product.created_at,
      updated_at: product.updated_at
    }
  end

  def self.collection(products)
    products.map { |product| new(product).as_json }
  end
end
