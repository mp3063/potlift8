# ImportsController
#
# Handles product and catalog imports from CSV files.
# Uses background jobs for processing with real-time progress tracking.
#
# Routes:
# - GET  /imports/new        - Show upload form
# - POST /imports            - Upload file and start import
# - GET  /imports/:id/progress - Check import progress (JSON/HTML)
#
# Import Types:
# - products: Import products from CSV
# - catalog_items: Import catalog items from CSV (future)
#
class ImportsController < ApplicationController
  # Show import upload form
  #
  # GET /imports/new?type=products
  #
  def new
    @import_type = params[:type] || "products"
  end

  # Create new import job
  #
  # POST /imports
  # Parameters:
  #   - file: CSV file upload
  #   - import_type: 'products' or 'catalog_items'
  #
  def create
    unless params[:file].present?
      redirect_to new_import_path, alert: "Please select a file to import."
      return
    end

    # Validate file type
    unless valid_file?(params[:file])
      redirect_to new_import_path, alert: "Please upload a CSV file."
      return
    end

    file_content = params[:file].read
    import_type = params[:import_type] || "products"

    # Enqueue appropriate import job
    job = case import_type
    when "products"
            ProductImportJob.perform_later(
              current_potlift_company.id,
              file_content,
              current_user[:id]
            )
    else
            redirect_to new_import_path, alert: "Unknown import type: #{import_type}"
            return
    end

    redirect_to progress_import_path(job.job_id),
                notice: "Import started. This may take a few minutes."
  end

  # List import history
  #
  # GET /imports
  #
  def index
    # For now, we'll use Redis to track recent imports
    # In production, you might want to create an Import model
    @imports = fetch_recent_imports
  end

  # Download CSV template for import type
  #
  # GET /imports/template/:type
  #
  def download_template
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

  # Show import progress
  #
  # GET /imports/:id/progress
  # GET /imports/:id/progress.json
  #
  def progress
    @job_id = params[:id]
    progress_key = "import_progress:#{@job_id}"

    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    progress_data = redis.get(progress_key)

    @progress = if progress_data.present?
                  JSON.parse(progress_data)
    else
                  { "status" => "pending" }
    end

    # Set view variables from progress data
    @status = @progress["status"] || "pending"
    @imported = @progress["imported_count"] || 0
    @updated = @progress["updated_count"] || 0
    @errors = @progress["errors"]&.size || 0
    @error_message = @progress["error"]
    @percentage = @progress["progress"] || 0

    respond_to do |format|
      format.html # renders progress.html.erb
      format.json do
        # Normalize response for JS controller
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
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error in progress check: #{e.message}")
    @progress = { "status" => "error", "error" => "Could not retrieve progress" }
    @status = "error"
    @error_message = "Could not retrieve progress"

    respond_to do |format|
      format.html
      format.json { render json: @progress, status: :service_unavailable }
    end
  end

  # Download import errors as CSV
  #
  # GET /imports/:id/errors
  #
  def download_errors
    @job_id = params[:id]
    progress_key = "import_progress:#{@job_id}"

    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    progress_data = redis.get(progress_key)

    unless progress_data.present?
      redirect_to imports_path, alert: "Import data not found or has expired."
      return
    end

    @progress = JSON.parse(progress_data)
    errors = @progress["errors"] || []

    if errors.empty?
      redirect_to imports_path, alert: "No errors found for this import."
      return
    end

    # Generate CSV with error details
    csv_data = CSV.generate do |csv|
      csv << [ "Row Number", "Error Message", "Timestamp" ]

      errors.each do |error|
        csv << [
          error["row"] || "N/A",
          error["error"] || error["message"] || "Unknown error",
          error["timestamp"] || Time.current.iso8601
        ]
      end
    end

    send_data csv_data,
              filename: "import_#{@job_id}_errors_#{Date.today}.csv",
              type: "text/csv",
              disposition: "attachment"
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error downloading errors: #{e.message}")
    redirect_to imports_path, alert: "Could not retrieve error data. Please try again."
  end

  private

  # Validate uploaded file
  #
  # @param file [ActionDispatch::Http::UploadedFile] Uploaded file
  # @return [Boolean] true if valid
  #
  def valid_file?(file)
    return false unless file.respond_to?(:content_type)

    # Accept CSV files
    file.content_type.in?([ "text/csv", "text/plain", "application/csv" ]) ||
      file.original_filename.end_with?(".csv")
  end

  # Fetch recent imports from Redis
  #
  # @return [Array<Hash>] Array of import data hashes
  #
  def fetch_recent_imports
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))

    # Get all import progress keys (last 50)
    keys = redis.keys("import_progress:*").last(50)

    keys.map do |key|
      data = redis.get(key)
      next unless data

      parsed = JSON.parse(data)
      parsed["id"] = key.sub("import_progress:", "")
      parsed
    end.compact.reverse # Most recent first
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error fetching imports: #{e.message}")
    []
  end

  # Generate product CSV template
  #
  # @return [String] CSV template with headers and example row
  #
  def generate_product_template
    CSV.generate do |csv|
      # Headers
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

      # Example row
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

      # Instructions row
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

  # Generate catalog items CSV template
  #
  # @return [String] CSV template with headers and example row
  #
  def generate_catalog_items_template
    CSV.generate do |csv|
      # Headers
      csv << [
        "product_sku",
        "catalog_code",
        "status",
        "attr_price",
        "attr_special_price"
      ]

      # Example row
      csv << [
        "EXAMPLE-001",
        "WEB-EUR",
        "active",
        "24.99",
        "19.99"
      ]

      # Instructions row
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
