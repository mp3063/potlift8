# ProductImportJob
#
# Background job for importing products from CSV files.
# Uses Redis to track import progress and store results.
#
# Features:
# - Progress tracking (0-100%)
# - Error reporting with row numbers
# - Import statistics (imported count, updated count)
# - Status tracking (processing, completed, failed)
#
# Redis Progress Key Format:
#   import_progress:#{job_id}
#
# Progress Data Structure:
#   {
#     status: 'processing' | 'completed' | 'failed',
#     progress: 0-100,
#     imported_count: Integer,
#     updated_count: Integer,
#     errors: Array<{ row: Integer, error: String }>
#   }
#
# Usage:
#   job = ProductImportJob.perform_later(company_id, file_content, user_id)
#   # => Check progress at: GET /imports/#{job.job_id}/progress
#
class ProductImportJob < ApplicationJob
  queue_as :default

  # Perform the import
  #
  # @param company_id [Integer] Company ID
  # @param file_content [String] CSV file content
  # @param user_id [Integer] User ID who initiated the import
  #
  def perform(company_id, file_content, user_id)
    company = Company.find(company_id)
    user = User.find(user_id)
    @started_at = Time.current

    # Initialize progress tracking
    progress_key = "import_progress:#{company_id}:#{job_id}"
    update_progress(progress_key, status: "processing", progress: 0)

    # Perform import with progress callback
    service = ProductImportService.new(
      company, file_content, user,
      on_progress: ->(processed, total) {
        pct = total > 0 ? ((processed.to_f / total) * 100).round : 0
        update_progress(progress_key,
          status: "processing",
          progress: pct,
          total_rows: total
        )
      }
    )
    result = service.import!

    # Update progress with final results (all keys the view expects)
    update_progress(
      progress_key,
      status: "completed",
      progress: 100,
      imported_count: result[:imported_count],
      updated_count: result[:updated_count],
      errors: result[:errors],
      total_rows: result[:imported_count] + result[:updated_count] + result[:errors].size,
      success_count: result[:imported_count] + result[:updated_count],
      failed_count: result[:errors].size,
      started_at: @started_at.iso8601,
      import_type: "products"
    )

    Rails.logger.info(
      "Product import completed: #{result[:imported_count]} imported, " \
      "#{result[:updated_count]} updated, #{result[:errors].size} errors"
    )
  rescue StandardError => e
    Rails.logger.error("Product import failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))

    # Update progress with error status
    progress_key = "import_progress:#{company_id}:#{job_id}"
    update_progress(
      progress_key,
      status: "failed",
      error: e.message,
      started_at: @started_at&.iso8601,
      import_type: "products"
    )

    raise # Re-raise to mark job as failed
  end

  private

  # Update progress in Redis
  #
  # @param key [String] Redis key
  # @param data [Hash] Progress data
  #
  def update_progress(key, data)
    redis = Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
    redis.setex(key, 7.days.to_i, data.to_json)
  rescue StandardError => e
    Rails.logger.error("Failed to update import progress: #{e.message}")
  end
end
