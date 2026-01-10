# ProductImportService
#
# Service for importing products from CSV files with validation and error handling.
#
# Features:
# - Batch processing (100 products at a time)
# - Create or update products by SKU
# - Import product attributes (columns prefixed with "attr_")
# - Import labels (comma-separated)
# - Detailed error reporting with row numbers
#
# CSV Format:
# - Required columns: sku, name
# - Optional columns: description, active (true/false/yes/no/1/0)
# - Attribute columns: attr_price, attr_color, etc.
# - Labels column: labels (comma-separated, e.g., "clothing,summer,sale")
#
# Usage:
#   service = ProductImportService.new(company, file_content, user)
#   result = service.import!
#   # => { imported_count: 10, updated_count: 5, errors: [...] }
#
class ProductImportService
  BATCH_SIZE = 100

  attr_reader :company, :file_content, :user, :errors, :imported_count, :updated_count

  def initialize(company, file_content, user)
    @company = company
    @file_content = file_content
    @user = user
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  # Import products from CSV
  #
  # @return [Hash] Import result with counts and errors
  #
  def import!
    rows = parse_csv

    rows.each_slice(BATCH_SIZE) do |batch|
      process_batch(batch)
    end

    {
      imported_count: @imported_count,
      updated_count: @updated_count,
      errors: @errors
    }
  rescue CSV::MalformedCSVError => e
    @errors << { row: 0, error: "Invalid CSV format: #{e.message}" }
    {
      imported_count: 0,
      updated_count: 0,
      errors: @errors
    }
  end

  private

  # Parse CSV file content
  #
  # @return [CSV::Table] Parsed CSV rows
  #
  def parse_csv
    CSV.parse(@file_content, headers: true, header_converters: :symbol)
  end

  # Process a batch of CSV rows
  #
  # @param batch [Array<CSV::Row>] Batch of rows to process
  #
  def process_batch(batch)
    batch.each_with_index do |row, index|
      process_row(row, index)
    rescue StandardError => e
      @errors << { row: index + 2, error: e.message }
    end
  end

  # Process a single CSV row
  #
  # @param row [CSV::Row] CSV row to process
  # @param index [Integer] Row index for error reporting
  #
  def process_row(row, index)
    # Validate required fields
    unless row[:sku].present?
      @errors << { row: index + 2, error: "SKU is required" }
      return
    end

    unless row[:name].present?
      @errors << { row: index + 2, error: "Name is required" }
      return
    end

    product = find_or_initialize_product(row[:sku])
    is_new = product.new_record?

    product.assign_attributes(
      name: row[:name],
      description: row[:description],
      product_type: product.product_type || :sellable
    )

    # Handle active status
    if row[:active].present?
      product.active = parse_boolean(row[:active])
    end

    if product.save
      # Handle labels
      import_labels(product, row) if row[:labels].present?

      # Handle attributes (columns prefixed with "attr_")
      import_attributes(product, row)

      if is_new
        @imported_count += 1
      else
        @updated_count += 1
      end
    else
      @errors << { row: index + 2, error: product.errors.full_messages.join(", ") }
    end
  end

  # Find or initialize product by SKU
  #
  # @param sku [String] Product SKU
  # @return [Product] Product instance
  #
  def find_or_initialize_product(sku)
    if sku.present?
      @company.products.find_or_initialize_by(sku: sku.to_s.strip.upcase)
    else
      @company.products.build
    end
  end

  # Parse boolean value from CSV
  #
  # @param value [String] String value to parse
  # @return [Boolean, nil] Boolean value or nil
  #
  def parse_boolean(value)
    return true if value.to_s.match?(/^(true|yes|1)$/i)
    return false if value.to_s.match?(/^(false|no|0)$/i)
    nil
  end

  # Import labels from CSV row
  #
  # @param product [Product] Product instance
  # @param row [CSV::Row] CSV row
  #
  def import_labels(product, row)
    label_names = row[:labels].to_s.split(",").map(&:strip).reject(&:blank?)
    return if label_names.empty?

    labels = label_names.map do |name|
      @company.labels.find_or_create_by!(name: name) do |label|
        label.code = name.parameterize.underscore
        label.label_type = "import"
      end
    end

    product.labels = labels
  rescue StandardError => e
    Rails.logger.error("Failed to import labels for product #{product.sku}: #{e.message}")
  end

  # Import attributes from CSV row
  #
  # Processes columns prefixed with "attr_" and creates/updates
  # product attribute values.
  #
  # @param product [Product] Product instance
  # @param row [CSV::Row] CSV row
  #
  def import_attributes(product, row)
    row.to_h.each do |key, value|
      next unless key.to_s.start_with?("attr_")
      next if value.blank?

      attr_code = key.to_s.sub("attr_", "")
      attribute = @company.product_attributes.find_by(code: attr_code)

      if attribute
        product.write_attribute_value(attr_code, value)
      else
        Rails.logger.warn(
          "Attribute '#{attr_code}' not found for company #{@company.code}, " \
          "skipping for product #{product.sku}"
        )
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to import attributes for product #{product.sku}: #{e.message}")
  end
end
