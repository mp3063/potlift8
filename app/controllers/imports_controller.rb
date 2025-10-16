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
    @import_type = params[:type] || 'products'
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
      redirect_to new_import_path, alert: 'Please select a file to import.'
      return
    end

    # Validate file type
    unless valid_file?(params[:file])
      redirect_to new_import_path, alert: 'Please upload a CSV file.'
      return
    end

    file_content = params[:file].read
    import_type = params[:import_type] || 'products'

    # Enqueue appropriate import job
    job = case import_type
          when 'products'
            ProductImportJob.perform_later(
              current_potlift_company.id,
              file_content,
              current_user.id
            )
          else
            redirect_to new_import_path, alert: "Unknown import type: #{import_type}"
            return
          end

    redirect_to import_progress_path(job.job_id),
                notice: 'Import started. This may take a few minutes.'
  end

  # Show import progress
  #
  # GET /imports/:id/progress
  # GET /imports/:id/progress.json
  #
  def progress
    @job_id = params[:id]
    progress_key = "import_progress:#{@job_id}"

    redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
    progress_data = redis.get(progress_key)

    @progress = if progress_data.present?
                  JSON.parse(progress_data)
                else
                  { 'status' => 'pending' }
                end

    respond_to do |format|
      format.html # renders progress.html.erb
      format.json { render json: @progress }
    end
  rescue Redis::BaseError => e
    Rails.logger.error("Redis error in progress check: #{e.message}")
    @progress = { 'status' => 'error', 'error' => 'Could not retrieve progress' }

    respond_to do |format|
      format.html
      format.json { render json: @progress, status: :service_unavailable }
    end
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
    file.content_type.in?(['text/csv', 'text/plain', 'application/csv']) ||
      file.original_filename.end_with?('.csv')
  end
end
