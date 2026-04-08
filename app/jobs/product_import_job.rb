# ProductImportJob
#
# Background job for importing products from a CSV file stored as an
# ActiveStorage blob on an Import record.
#
# The job receives only the Import id as its argument — the CSV content is
# streamed from storage inside the job. Progress and results are persisted
# on the Import row (no Redis).
#
# Usage:
#   import = company.imports.create!(user: user, import_type: "products")
#   import.file.attach(uploaded_file)
#   ProductImportJob.perform_later(import.id)
#   # Check progress at: GET /imports/#{import.id}/progress
#
class ProductImportJob < ApplicationJob
  queue_as :default

  # Perform the import
  #
  # @param import_id [Integer] Import record ID
  #
  def perform(import_id)
    import = Import.find(import_id)
    company = import.company
    user = import.user

    import.update!(status: "processing", progress: 0, started_at: Time.current)

    file_content = import.file.download

    service = ProductImportService.new(
      company, file_content, user,
      on_progress: ->(processed, total) {
        pct = total > 0 ? ((processed.to_f / total) * 100).round : 0
        import.update_columns(
          progress: pct,
          total_rows: total,
          updated_at: Time.current
        )
      }
    )
    result = service.import!

    import.update!(
      status: "completed",
      progress: 100,
      imported_count: result[:imported_count],
      updated_count: result[:updated_count],
      errors_data: result[:errors].map { |e| e.is_a?(Hash) ? e.stringify_keys : e },
      total_rows: result[:imported_count] + result[:updated_count] + result[:errors].size,
      completed_at: Time.current
    )

    Rails.logger.info(
      "Product import completed: import_id=#{import.id} " \
      "imported=#{result[:imported_count]} updated=#{result[:updated_count]} " \
      "errors=#{result[:errors].size}"
    )
  rescue StandardError => e
    Rails.logger.error("Product import failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n")) if e.backtrace

    if defined?(import) && import
      import.update!(
        status: "failed",
        error_message: e.message,
        completed_at: Time.current
      )
    end

    raise # Re-raise to mark job as failed
  end
end
