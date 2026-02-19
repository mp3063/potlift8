# CatalogImportsController
#
# Handles CSV import of products into catalogs.
# Allows bulk adding/updating catalog items via CSV upload.
#
# CSV Format:
# - product_sku: Product SKU (required)
# - catalog_item_state: State (active/inactive) - default: active
# - priority: Priority for ordering (optional)
# - price_override: Catalog-specific price override (optional)
#
# Features:
# - CSV file upload and parsing
# - Validation of product existence
# - Bulk catalog item creation
# - Error reporting for failed rows
#
class CatalogImportsController < ApplicationController
  before_action :set_catalog

  # GET /catalogs/:code/imports/new
  # GET /catalogs/:code/imports/new.turbo_stream
  #
  # Shows import modal with file upload form and template download link.
  #
  def new
    authorize :catalog_import, :new?

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  # POST /catalogs/:code/imports
  # POST /catalogs/:code/imports.turbo_stream
  #
  # Processes CSV file upload and imports products into catalog.
  #
  # Parameters:
  # - file: CSV file to import
  #
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

  # GET /catalogs/:code/imports/template
  #
  # Downloads CSV template for catalog imports.
  #
  def template
    authorize :catalog_import, :template?

    require "csv"

    csv_data = CSV.generate(headers: true) do |csv|
      # CSV headers
      csv << [
        "product_sku",
        "catalog_item_state",
        "priority",
        "price_override"
      ]

      # Example row
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

  # Set the catalog for all actions
  # Uses catalog 'catalog_code' as URL parameter (from nested routes)
  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:catalog_code])
  end

  # Process CSV import file
  #
  # @param file [ActionDispatch::Http::UploadedFile] The uploaded CSV file
  # @return [Hash] Import results with counts and errors
  #
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
    csv = CSV.parse(csv_content, headers: true, header_converters: :symbol)

    # Validate headers
    required_headers = [ :product_sku ]
    missing_headers = required_headers - csv.headers
    if missing_headers.any?
      raise "Missing required headers: #{missing_headers.join(', ')}"
    end

    ActiveRecord::Base.transaction do
      csv.each_with_index do |row, index|
        row_number = index + 2 # +2 because index is 0-based and we skip header row

        begin
          # Skip empty rows
          next if row[:product_sku].blank?

          # Find product by SKU
          product = current_potlift_company.products.find_by(sku: row[:product_sku].strip)
          unless product
            result[:failed] += 1
            result[:errors] << "Row #{row_number}: Product not found with SKU '#{row[:product_sku]}'"
            next
          end

          # Check if already in catalog
          existing_catalog_item = @catalog.catalog_items.find_by(product: product)

          if existing_catalog_item
            # Update existing catalog item
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

            if updated && existing_catalog_item.save
              result[:updated] += 1

              # Handle price override if specified
              if row[:price_override].present?
                update_price_override(existing_catalog_item, row[:price_override].strip)
              end
            else
              result[:skipped] += 1
            end
          else
            # Create new catalog item
            catalog_item_state = row[:catalog_item_state].present? ? row[:catalog_item_state].strip.downcase : "active"
            priority = row[:priority].present? && row[:priority].strip =~ /^\d+$/ ? row[:priority].strip.to_i : nil

            # Default priority to max + 1 if not specified
            priority ||= (@catalog.catalog_items.maximum(:priority).to_i + 1)

            catalog_item = @catalog.catalog_items.build(
              product: product,
              catalog_item_state: catalog_item_state,
              priority: priority
            )

            if catalog_item.save
              result[:success] += 1

              # Handle price override if specified
              if row[:price_override].present?
                update_price_override(catalog_item, row[:price_override].strip)
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

  # Update price override for catalog item
  #
  # @param catalog_item [CatalogItem] The catalog item to update
  # @param price_value [String] The price value to set
  #
  def update_price_override(catalog_item, price_value)
    # Find the price attribute
    price_attribute = current_potlift_company.product_attributes.find_by(code: "price")
    return unless price_attribute

    # Create or update catalog item attribute value for price
    catalog_item.write_catalog_attribute_value("price", price_value)
  end
end
