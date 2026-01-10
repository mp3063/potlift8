require "csv"

# Product Export Service
#
# Generates CSV exports of products with their key attributes and relationships.
# Uses batch processing (find_each) for memory-efficient handling of large datasets.
#
# CSV Format:
# - Headers: SKU, Name, Product Type, Description, Active, Labels, Total Inventory, Created At, Updated At
# - Date format: ISO 8601 (YYYY-MM-DDTHH:MM:SSZ)
# - Boolean format: "Yes" / "No"
# - Labels: Comma-separated list of label names
#
# @example Basic usage
#   products = company.products.active_products
#   csv_data = ProductExportService.new(products).to_csv
#
# @example With filters applied
#   products = company.products.where(product_type: :sellable)
#   service = ProductExportService.new(products)
#   File.write('products.csv', service.to_csv)
#
class ProductExportService
  # Batch size for find_each processing
  BATCH_SIZE = 100

  # Initialize the service with a products collection
  #
  # @param products [ActiveRecord::Relation] Products to export
  #
  def initialize(products)
    @products = products
  end

  # Generate CSV export
  #
  # Uses find_each for memory-efficient batch processing.
  # Automatically eager loads associations to prevent N+1 queries.
  # Includes product attributes as "attr_[code]" columns.
  #
  # @return [String] CSV data as a string
  #
  def to_csv
    # Eager load all data including attributes
    products_with_data = @products.includes(
      :labels,
      :inventories,
      product_attribute_values: :product_attribute
    ).order(:id)

    # Collect all unique attribute codes
    attribute_codes = collect_attribute_codes(products_with_data)

    CSV.generate(headers: true) do |csv|
      csv << headers(attribute_codes)

      products_with_data.find_each(batch_size: BATCH_SIZE) do |product|
        csv << row_for_product(product, attribute_codes)
      end
    end
  end

  # Generate JSON export
  #
  # Exports products with full details including attributes, labels, and inventory.
  # Returns a pretty-printed JSON string.
  #
  # @return [String] JSON data as a string
  #
  def to_json
    # Eager load all associations
    products_with_data = @products.includes(
      :labels,
      :inventories,
      product_attribute_values: :product_attribute
    )

    products_data = products_with_data.map do |product|
      {
        sku: product.sku,
        name: product.name,
        description: product.description,
        ean: product.ean,
        product_type: product.product_type,
        product_status: product.product_status,
        active: product.active?,
        labels: product.labels.pluck(:name),
        attributes: product.attribute_values_hash,
        total_inventory: product.total_inventory,
        created_at: product.created_at.iso8601,
        updated_at: product.updated_at.iso8601
      }
    end

    JSON.pretty_generate({
      exported_at: Time.current.iso8601,
      count: products_data.size,
      products: products_data
    })
  end

  private

  attr_reader :products

  # Collect all unique attribute codes from products
  #
  # @param products_relation [ActiveRecord::Relation] Products with eager loaded attributes
  # @return [Array<String>] Sorted array of attribute codes
  #
  def collect_attribute_codes(products_relation)
    codes = Set.new

    products_relation.each do |product|
      product.product_attribute_values.each do |pav|
        codes << pav.product_attribute.code
      end
    end

    codes.to_a.sort
  end

  # CSV headers including attribute columns
  #
  # @param attribute_codes [Array<String>] Attribute codes to include
  # @return [Array<String>] Array of header names
  #
  def headers(attribute_codes = [])
    base_headers = [
      "SKU",
      "Name",
      "Product Type",
      "Description",
      "Active",
      "Labels",
      "Total Inventory",
      "Created At",
      "Updated At"
    ]

    # Add attribute headers
    attribute_headers = attribute_codes.map { |code| "attr_#{code}" }

    base_headers + attribute_headers
  end

  # Generate CSV row for a product including attributes
  #
  # @param product [Product] Product to export
  # @param attribute_codes [Array<String>] Attribute codes to include
  # @return [Array] Array of values for CSV row
  #
  def row_for_product(product, attribute_codes = [])
    base_row = [
      product.sku,
      product.name,
      product_type_label(product),
      product.description || "",
      active_label(product),
      labels_list(product),
      product.total_inventory,
      format_timestamp(product.created_at),
      format_timestamp(product.updated_at)
    ]

    # Add attribute values
    attribute_values = attribute_codes.map do |code|
      product.read_attribute_value(code) || ""
    end

    base_row + attribute_values
  end

  # Get human-readable product type label
  #
  # @param product [Product] Product instance
  # @return [String] Product type label (Sellable, Configurable, Bundle)
  #
  def product_type_label(product)
    product.product_type.to_s.titleize
  end

  # Format product status as Yes/No
  #
  # @param product [Product] Product instance
  # @return [String] "Yes" if active, "No" otherwise
  #
  def active_label(product)
    product.active? ? "Yes" : "No"
  end

  # Get comma-separated list of label names
  #
  # @param product [Product] Product instance
  # @return [String] Comma-separated label names, or empty string if no labels
  #
  def labels_list(product)
    product.labels.pluck(:name).join(", ")
  end

  # Format timestamp as ISO 8601
  #
  # @param timestamp [Time, DateTime, nil] Timestamp to format
  # @return [String] ISO 8601 formatted timestamp, or empty string if nil
  #
  def format_timestamp(timestamp)
    return "" if timestamp.nil?

    timestamp.iso8601
  end
end
