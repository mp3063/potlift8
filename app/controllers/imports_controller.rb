# Uploaded CSVs are stored as ActiveStorage blobs on an Import record, and
# only the import ID is passed to the background job. This keeps the job
# arguments small, prevents the CSV content from leaking into Rails logs,
# and makes progress tracking durable across job restarts (no Redis needed).
class ImportsController < ApplicationController
  MAX_FILE_SIZE = 10.megabytes

  def new
    authorize :import, :new?
    @import_type = params[:type] || "products"
  end

  def create
    authorize :import, :create?

    unless params[:file].present?
      redirect_to new_import_path, alert: "Please select a file to import."
      return
    end

    unless valid_file?(params[:file])
      redirect_to new_import_path, alert: "Please upload a CSV file."
      return
    end

    if params[:file].size > MAX_FILE_SIZE
      redirect_to new_import_path,
                  alert: "File is too large. Maximum size is #{ActiveSupport::NumberHelper.number_to_human_size(MAX_FILE_SIZE)}."
      return
    end

    import_type = params[:import_type] || "products"

    unless %w[products catalog_items].include?(import_type)
      redirect_to new_import_path, alert: "Unknown import type: #{import_type}"
      return
    end

    import = current_potlift_company.imports.create!(
      user: current_user,
      import_type: import_type,
      status: "pending"
    )
    import.file.attach(params[:file])

    case import_type
    when "products"
      ProductImportJob.perform_later(import.id)
    end

    redirect_to progress_import_path(import.id),
                notice: "Import started. This may take a few minutes."
  end

  def index
    authorize :import, :index?

    @imports = current_potlift_company.imports.recent.limit(50)
  end

  def download_template
    authorize :import, :download_template?

    type = params[:type] || "products"

    csv_data = case type
    when "products"
                 generate_product_template
    when "catalog_items"
                 generate_catalog_items_template
    else
                 redirect_to new_import_path, alert: "Unknown import type: #{type}"
                 return
    end

    send_data csv_data,
              filename: "#{type}_import_template_#{Date.today}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def progress
    authorize :import, :progress?

    @import = current_potlift_company.imports.find(params[:id])

    @status = @import.status
    @percentage = @import.progress
    @imported = @import.imported_count
    @updated = @import.updated_count
    @errors = @import.failed_count
    @error_message = @import.error_message

    respond_to do |format|
      format.html
      format.json do
        render json: {
          status: @status,
          progress: @percentage,
          imported: @imported,
          updated: @updated,
          errors: @errors,
          error: @error_message
        }
      end
    end
  end

  def download_errors
    authorize :import, :download_errors?

    @import = current_potlift_company.imports.find(params[:id])
    errors = @import.row_errors

    if errors.empty?
      redirect_to imports_path, alert: "No errors found for this import."
      return
    end

    csv_data = CSV.generate do |csv|
      csv << [ "Row Number", "Error Message", "Timestamp" ]

      errors.each do |error|
        csv << [
          error["row"] || "N/A",
          error["error"] || error["message"] || "Unknown error",
          error["timestamp"] || @import.created_at&.iso8601
        ]
      end
    end

    send_data csv_data,
              filename: "import_#{@import.id}_errors_#{Date.today}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  private

  def valid_file?(file)
    return false unless file.respond_to?(:content_type)

    file.content_type.in?([ "text/csv", "text/plain", "application/csv" ]) ||
      file.original_filename.end_with?(".csv")
  end

  def generate_product_template
    CSV.generate do |csv|
      csv << [
        "sku",
        "name",
        "description",
        "ean",
        "product_type",
        "product_status",
        "restock_level",
        "attr_price",
        "attr_weight",
        "attr_color"
      ]

      csv << [
        "EXAMPLE-001",
        "Example Product",
        "This is an example product for import",
        "1234567890123",
        "sellable",
        "active",
        "10",
        "19.99",
        "500",
        "Blue"
      ]

      csv << [
        "# SKU is required and must be unique",
        "# Name is required",
        "# Description is optional",
        "# EAN is optional (barcode)",
        "# product_type: sellable, configurable, or bundle",
        "# product_status: draft, active, discontinued",
        "# restock_level: minimum inventory level",
        "# attr_* columns are product attributes",
        "",
        ""
      ]
    end
  end

  def generate_catalog_items_template
    CSV.generate do |csv|
      csv << [
        "product_sku",
        "catalog_code",
        "status",
        "attr_price",
        "attr_special_price"
      ]

      csv << [
        "EXAMPLE-001",
        "WEB-EUR",
        "active",
        "24.99",
        "19.99"
      ]

      csv << [
        "# product_sku: SKU of existing product (required)",
        "# catalog_code: Code of existing catalog (required)",
        "# status: active or inactive",
        "# attr_* columns are catalog-specific attribute overrides",
        ""
      ]
    end
  end
end
