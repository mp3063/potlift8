# Product Detail Serializer
#
# Detailed serializer for individual product endpoints.
# Returns comprehensive product information including attributes, inventory, and labels.
#
# Usage:
#   ProductDetailSerializer.new(product).as_json
#
# @example JSON output
#   {
#     "id": 123,
#     "sku": "ABC123",
#     "name": "Product Name",
#     "ean": "1234567890123",
#     "product_type": "sellable",
#     "configuration_type": null,
#     "product_status": "active",
#     "structure": {},
#     "info": { "description": "Product description" },
#     "cache": {},
#     "inventory": {
#       "available": 100,
#       "incoming": 50,
#       "eta": "2025-11-15"
#     },
#     "attributes": {
#       "price": "1999",
#       "color": "blue"
#     },
#     "labels": [
#       { "code": "category", "name": "Electronics" }
#     ],
#     "created_at": "2025-10-11T12:00:00Z",
#     "updated_at": "2025-10-11T12:00:00Z"
#   }
#
class ProductDetailSerializer
  attr_reader :product

  def initialize(product)
    @product = product
  end

  # Serialize product to detailed hash
  #
  # @return [Hash] Detailed product data
  #
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

  # Serialize inventory information
  #
  # @return [Hash] Inventory with available, incoming, and ETA
  #
  def serialize_inventory
    product.single_inventory_with_eta
  end

  # Serialize product attributes (EAV)
  #
  # @return [Hash] Hash of attribute codes to values
  #
  def serialize_attributes
    product.attribute_values_hash
  end

  # Serialize product labels
  #
  # @return [Array<Hash>] Array of label objects with code and name
  #
  def serialize_labels
    product.labels.map do |label|
      {
        code: label.code,
        name: label.name
      }
    end
  end
end
