require "csv"

class ProductExportService
  BATCH_SIZE = 100

  def initialize(products)
    @products = products
  end

  # Uses find_each for memory-efficient batch processing.
  # Automatically eager loads associations to prevent N+1 queries.
  # Includes product attributes as "attr_[code]" columns.
  def to_csv
    products_with_data = @products.includes(
      :labels,
      :inventories,
      product_attribute_values: :product_attribute
    ).order(:id)

    attribute_codes = collect_attribute_codes(products_with_data)

    CSV.generate(headers: true) do |csv|
      csv << headers(attribute_codes)

      products_with_data.find_each(batch_size: BATCH_SIZE) do |product|
        csv << row_for_product(product, attribute_codes)
      end
    end
  end

  def to_json
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

  def collect_attribute_codes(products_relation)
    codes = Set.new

    products_relation.each do |product|
      product.product_attribute_values.each do |pav|
        codes << pav.product_attribute.code
      end
    end

    codes.to_a.sort
  end

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

    attribute_headers = attribute_codes.map { |code| "attr_#{code}" }

    base_headers + attribute_headers
  end

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

    attribute_values = attribute_codes.map do |code|
      product.read_attribute_value(code) || ""
    end

    base_row + attribute_values
  end

  def product_type_label(product)
    product.product_type.to_s.titleize
  end

  def active_label(product)
    product.active? ? "Yes" : "No"
  end

  def labels_list(product)
    product.labels.pluck(:name).join(", ")
  end

  def format_timestamp(timestamp)
    return "" if timestamp.nil?

    timestamp.iso8601
  end
end
