class ProductImportService
  BATCH_SIZE = 100

  attr_reader :company, :file_content, :user, :errors, :imported_count, :updated_count

  def initialize(company, file_content, user, on_progress: nil)
    @company = company
    @file_content = file_content
    @user = user
    @on_progress = on_progress
    @errors = []
    @imported_count = 0
    @updated_count = 0
  end

  def import!
    rows = parse_csv
    total = rows.size
    processed = 0

    rows.each_slice(BATCH_SIZE) do |batch|
      process_batch(batch)
      processed += batch.size
      @on_progress&.call(processed, total)
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

  def parse_csv
    CSV.parse(@file_content, headers: true, header_converters: :symbol)
  end

  def process_batch(batch)
    batch.each_with_index do |row, index|
      process_row(row, index)
    rescue StandardError => e
      @errors << { row: index + 2, error: e.message }
    end
  end

  def process_row(row, index)
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

    if row[:active].present?
      parsed = parse_boolean(row[:active])
      if parsed.nil?
        @errors << { row: index + 2, error: "Unrecognized active value: '#{row[:active]}'. Use true/false/yes/no/1/0" }
      else
        product.active = parsed
      end
    end

    if product.save
      import_labels(product, row) if row[:labels].present?

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

  def find_or_initialize_product(sku)
    if sku.present?
      @company.products.find_or_initialize_by(sku: sku.to_s.strip.upcase)
    else
      @company.products.build
    end
  end

  def parse_boolean(value)
    return true if value.to_s.match?(/^(true|yes|1)$/i)
    return false if value.to_s.match?(/^(false|no|0)$/i)
    nil
  end

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
