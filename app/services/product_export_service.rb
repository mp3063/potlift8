require 'csv'

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
  #
  # @return [String] CSV data as a string
  #
  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers

      # Eager load associations to prevent N+1 queries
      products_with_associations = @products
                                   .includes(:labels, :inventories)
                                   .order(:id)

      products_with_associations.find_each(batch_size: BATCH_SIZE) do |product|
        csv << row_for_product(product)
      end
    end
  end

  private

  attr_reader :products

  # CSV headers
  #
  # @return [Array<String>] Array of header names
  #
  def headers
    [
      'SKU',
      'Name',
      'Product Type',
      'Description',
      'Active',
      'Labels',
      'Total Inventory',
      'Created At',
      'Updated At'
    ]
  end

  # Generate CSV row for a product
  #
  # @param product [Product] Product to export
  # @return [Array] Array of values for CSV row
  #
  def row_for_product(product)
    [
      product.sku,
      product.name,
      product_type_label(product),
      product.description || '',
      active_label(product),
      labels_list(product),
      product.total_inventory,
      format_timestamp(product.created_at),
      format_timestamp(product.updated_at)
    ]
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
    product.active? ? 'Yes' : 'No'
  end

  # Get comma-separated list of label names
  #
  # @param product [Product] Product instance
  # @return [String] Comma-separated label names, or empty string if no labels
  #
  def labels_list(product)
    product.labels.pluck(:name).join(', ')
  end

  # Format timestamp as ISO 8601
  #
  # @param timestamp [Time, DateTime, nil] Timestamp to format
  # @return [String] ISO 8601 formatted timestamp, or empty string if nil
  #
  def format_timestamp(timestamp)
    return '' if timestamp.nil?

    timestamp.iso8601
  end
end
