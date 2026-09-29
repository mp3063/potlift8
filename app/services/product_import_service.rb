class ProductImportService
  BATCH_SIZE = 100
  MONEY_COLUMN_SUFFIX = "_eur" # product-level money is in the base currency

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
    headers, rows = parse_csv

    if (legacy_error = legacy_money_column_error(headers))
      @errors << { row: 0, error: legacy_error }
      return { imported_count: 0, updated_count: 0, errors: @errors }
    end

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
    CsvWithLines.parse(@file_content, header_converters: :symbol)
  end

  def money_codes
    @money_codes ||= @company.product_attributes.select(&:money?).map(&:code)
  end

  # Old files held cents in attr_<code>; importing them as euros would be 100x off.
  def legacy_money_column_error(headers)
    code = money_codes.find { |c| headers.include?(:"attr_#{c}") }
    return unless code

    "Column attr_#{code} is no longer supported: prices are now in euros, " \
      "use attr_#{code}#{MONEY_COLUMN_SUFFIX} (e.g. 19.99)"
  end

  # Raises Cents::InvalidAmount, which becomes a row error.
  def parse_money_columns(row)
    money_codes.each_with_object({}) do |code, values|
      cents = Cents.parse(row[:"attr_#{code}#{MONEY_COLUMN_SUFFIX}"])
      values[code] = cents.to_s if cents
    end
  end

  # Each entry is [row, physical file line the row starts on]
  def process_batch(batch)
    batch.each do |row, line|
      process_row(row, line)
    rescue StandardError => e
      @errors << { row: line, error: e.message }
    end
  end

  def process_row(row, line)
    unless row[:sku].present?
      @errors << { row: line, error: "SKU is required" }
      return
    end

    unless row[:name].present?
      @errors << { row: line, error: "Name is required" }
      return
    end

    money_values = parse_money_columns(row)

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
        @errors << { row: line, error: "Unrecognized active value: '#{row[:active]}'. Use true/false/yes/no/1/0" }
      else
        product.active = parsed
      end
    end

    if product.save
      import_labels(product, row) if row[:labels].present?

      import_attributes(product, row, money_values)

      if is_new
        @imported_count += 1
      else
        @updated_count += 1
      end
    else
      @errors << { row: line, error: product.errors.full_messages.join(", ") }
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

  def import_attributes(product, row, money_values)
    money_values.each { |code, cents| product.write_attribute_value(code, cents) }
    money_columns = money_codes.map { |code| :"attr_#{code}#{MONEY_COLUMN_SUFFIX}" }

    row.to_h.each do |key, value|
      next unless key.to_s.start_with?("attr_")
      next if value.blank? || money_columns.include?(key)

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
