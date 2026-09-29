class CatalogImportsController < ApplicationController
  before_action :set_catalog

  def new
    authorize :catalog_import, :new?

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  def create
    authorize :catalog_import, :create?

    unless params[:file].present?
      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), alert: "Please select a file to import." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Please select a file to import." } }) }
      end
      return
    end

    begin
      result = process_csv_import(params[:file])

      message = "Import completed: #{result[:success]} products added"
      message += ", #{result[:updated]} updated" if result[:updated] > 0
      message += ", #{result[:skipped]} skipped" if result[:skipped] > 0
      message += ", #{result[:failed]} failed" if result[:failed] > 0

      if result[:errors].any?
        message += ". Errors: #{result[:errors].join('; ')}"
      end

      flash_type = result[:failed] > 0 ? :alert : :notice

      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), flash_type => message }
        format.turbo_stream do
          redirect_to catalog_items_path(@catalog), flash_type => message
        end
      end
    rescue CSV::MalformedCSVError => e
      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), alert: "Invalid CSV file: #{e.message}" }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Invalid CSV file: #{e.message}" } }) }
      end
    rescue => e
      Rails.logger.error "Catalog import error: #{e.message}\n#{e.backtrace.join("\n")}"
      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), alert: "Import failed: #{e.message}" }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Import failed: #{e.message}" } }) }
      end
    end
  end

  def template
    authorize :catalog_import, :template?

    require "csv"

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "product_sku",
        "catalog_item_state",
        "priority",
        "price_override"
      ]

      csv << [
        "EXAMPLE-SKU",
        "active",
        "100",
        "19.99"
      ]
    end

    send_data csv_data,
              filename: "catalog_#{@catalog.code}_import_template_#{Time.current.strftime('%Y%m%d')}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:catalog_code])
  end

  def process_csv_import(file)
    require "csv"

    result = {
      success: 0,
      updated: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    csv_content = file.read.force_encoding("UTF-8")
    rows = CsvWithLines.parse(csv_content, header_converters: :symbol)

    required_headers = [ :product_sku ]
    missing_headers = required_headers - (rows.first&.first&.headers || [])
    if rows.any? && missing_headers.any? # a header-only file imports nothing, so it needs no check
      raise "Missing required headers: #{missing_headers.join(', ')}"
    end

    ActiveRecord::Base.transaction do
      rows.each do |row, row_number|
        begin
          next if row[:product_sku].blank?

          product = current_potlift_company.products.find_by(sku: row[:product_sku].strip)
          unless product
            result[:failed] += 1
            result[:errors] << "Row #{row_number}: Product not found with SKU '#{row[:product_sku]}'"
            next
          end

          # Amounts are in the catalog currency; invalid ones raise before anything is written
          price_cents = Cents.parse(row[:price_override])

          existing_catalog_item = @catalog.catalog_items.find_by(product: product)

          if existing_catalog_item
            updated = false

            if row[:catalog_item_state].present?
              state = row[:catalog_item_state].strip.downcase
              if %w[active inactive].include?(state)
                existing_catalog_item.catalog_item_state = state
                updated = true
              end
            end

            if row[:priority].present? && row[:priority].strip =~ /^\d+$/
              existing_catalog_item.priority = row[:priority].strip.to_i
              updated = true
            end

            if updated && !existing_catalog_item.save
              result[:failed] += 1
              result[:errors] << "Row #{row_number}: #{existing_catalog_item.errors.full_messages.to_sentence}"
            elsif price_cents && !update_price_override(existing_catalog_item, price_cents)
              result[:failed] += 1
              result[:errors] << "Row #{row_number}: price override could not be saved"
            elsif updated || price_cents
              result[:updated] += 1
            else
              result[:skipped] += 1
            end
          else
            catalog_item_state = row[:catalog_item_state].present? ? row[:catalog_item_state].strip.downcase : "active"
            priority = row[:priority].present? && row[:priority].strip =~ /^\d+$/ ? row[:priority].strip.to_i : nil

            priority ||= (@catalog.catalog_items.maximum(:priority).to_i + 1)

            catalog_item = @catalog.catalog_items.build(
              product: product,
              catalog_item_state: catalog_item_state,
              priority: priority
            )

            if catalog_item.save
              if price_cents && !update_price_override(catalog_item, price_cents)
                result[:failed] += 1
                result[:errors] << "Row #{row_number}: added, but the price override could not be saved"
              else
                result[:success] += 1
              end
            else
              result[:failed] += 1
              result[:errors] << "Row #{row_number}: #{catalog_item.errors.full_messages.join(', ')}"
            end
          end
        rescue => e
          result[:failed] += 1
          result[:errors] << "Row #{row_number}: #{e.message}"
        end
      end
    end

    result
  end

  def update_price_override(catalog_item, price_cents)
    price_attribute = current_potlift_company.product_attributes.find_by(code: "price")
    return false unless price_attribute

    catalog_item.write_catalog_attribute_value("price", price_cents.to_s)
  end
end
