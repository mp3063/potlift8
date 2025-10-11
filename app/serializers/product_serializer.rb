# Product Serializer
#
# Basic serializer for product list endpoints.
# Returns essential product information with total inventory.
#
# Usage:
#   ProductSerializer.new(product).as_json
#   ProductSerializer.new(products).as_json # for collection
#
# @example JSON output
#   {
#     "id": 123,
#     "sku": "ABC123",
#     "name": "Product Name",
#     "ean": "1234567890123",
#     "product_type": "sellable",
#     "product_status": "active",
#     "total_saldo": 100,
#     "created_at": "2025-10-11T12:00:00Z",
#     "updated_at": "2025-10-11T12:00:00Z"
#   }
#
class ProductSerializer
  attr_reader :product

  def initialize(product)
    @product = product
  end

  # Serialize product to hash
  #
  # @return [Hash] Product data
  #
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

  # Serialize collection of products
  #
  # @param products [ActiveRecord::Relation, Array] Collection of products
  # @return [Array<Hash>] Array of serialized products
  #
  def self.collection(products)
    products.map { |product| new(product).as_json }
  end
end
