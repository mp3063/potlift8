# frozen_string_literal: true

# Features:
# - Efficient batch processing with find_each
# - Eager loading of associations to prevent N+1 queries
# - Individual error handling (one failure doesn't stop the batch)
# - Progress tracking and timing metrics
# - Memory-efficient processing (processes in chunks)
class BatchProductSyncJob < ApplicationJob
  include SyncErrorSanitizer

  queue_as :low_priority

  BATCH_SIZE = 100

  def perform(product_ids, catalog_id)
    start_time = Time.current

    Rails.logger.info(
      "[BatchProductSyncJob] Starting batch sync: #{product_ids.size} products " \
      "to catalog #{catalog_id}"
    )

    catalog = Catalog.find(catalog_id)

    if catalog.info&.dig("sync_paused")
      Rails.logger.info(
        "[BatchProductSyncJob] Catalog #{catalog.code} has sync paused. Skipping batch sync."
      )
      return
    end

    unless catalog.shop_connected?
      Rails.logger.info("[BatchProductSyncJob] Catalog #{catalog.code} is not connected to a shop. Skipping batch sync.")
      return
    end

    success_count = 0
    failure_count = 0
    skipped_count = 0
    errors = []

    Product.where(id: product_ids)
           .with_inventory
           .with_attributes
           .find_each(batch_size: BATCH_SIZE) do |product|
      begin
        result = sync_single_product(product, catalog)

        case result[:status]
        when :success
          success_count += 1
        when :skipped
          skipped_count += 1
        when :failure
          failure_count += 1
          errors << result[:error]
        end
      rescue StandardError => e
        failure_count += 1
        error_msg = "Product #{product.id} (#{product.sku}): #{e.message}"
        errors << error_msg

        Rails.logger.error(
          "[BatchProductSyncJob] Error syncing product #{product.id}: #{e.class} - #{e.message}\n" \
          "Backtrace:\n#{e.backtrace.first(5).join("\n")}"
        )
      end

      total_processed = success_count + failure_count + skipped_count
      if (total_processed % 50).zero?
        log_progress(total_processed, product_ids.size, success_count, failure_count, skipped_count)
      end
    end

    duration = (Time.current - start_time).round(2)

    log_batch_completion(
      product_ids.size,
      success_count,
      failure_count,
      skipped_count,
      duration,
      catalog,
      errors
    )

    mark_sync_run_handed_off(catalog)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[BatchProductSyncJob] Catalog #{catalog_id} not found: #{e.message}")
    raise e
  rescue StandardError => e
    Rails.logger.error(
      "[BatchProductSyncJob] Unexpected error in batch sync: #{e.class} - #{e.message}\n" \
      "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
    )
    raise e
  end

  private

  # Completes the "Sending to Shopify8" step of a Sync All run, once. Written
  # in SQL so it can't clobber other info keys changed while the batch ran.
  def mark_sync_run_handed_off(catalog)
    marked = Catalog.where(id: catalog.id)
                    .where("info->'sync_run' IS NOT NULL AND info->'sync_run'->>'handed_off_at' IS NULL")
                    .update_all([ "info = jsonb_set(info, '{sync_run,handed_off_at}', to_jsonb(?::text))", Time.current.iso8601(6) ])
    return unless marked.positive?

    begin
      catalog.reload.broadcast_sync_summary
    rescue StandardError => e
      # The hand-off is recorded; a failed render must not retry the whole batch
      Rails.logger.error("[BatchProductSyncJob] Sync All summary broadcast failed for catalog #{catalog.id}: #{e.class} - #{e.message}")
    end
  end

  def sync_single_product(product, catalog)
    catalog_item = catalog.catalog_items.find_by(product: product)

    if product.sync_locked?
      Rails.logger.debug(
        "[BatchProductSyncJob] Product #{product.id} (#{product.sku}) is sync locked. Skipping."
      )
      # An answer, so a Sync All run can finish instead of waiting forever
      catalog_item&.update!(sync_status: :failed, last_sync_error: "Skipped: product is sync-locked")
      return { status: :skipped, reason: "sync_locked" }
    end

    service = ProductSyncService.new(product, catalog)
    result = service.sync_to_external_system

    if result.success?
      catalog_item&.update!(sync_status: :pending, last_sync_error: nil)
      { status: :success }
    else
      catalog_item&.update!(sync_status: :failed, last_sync_error: sanitize_sync_error(result.error))
      {
        status: :failure,
        error: "Product #{product.id} (#{product.sku}): #{result.error}"
      }
    end
  rescue StandardError => e
    catalog_item&.update!(sync_status: :failed, last_sync_error: sanitize_sync_error(e))
    {
      status: :failure,
      error: "Product #{product.id} (#{product.sku}): #{e.message}"
    }
  end

  def log_progress(processed, total, success, failure, skipped)
    percentage = ((processed.to_f / total) * 100).round(1)

    Rails.logger.info(
      "[BatchProductSyncJob] Progress: #{processed}/#{total} (#{percentage}%) | " \
      "Success: #{success}, Failed: #{failure}, Skipped: #{skipped}"
    )
  end

  def log_batch_completion(total, success, failure, skipped, duration, catalog, errors)
    summary = {
      event: "batch_sync_completed",
      catalog_id: catalog.id,
      catalog_code: catalog.code,
      total_products: total,
      success_count: success,
      failure_count: failure,
      skipped_count: skipped,
      duration_seconds: duration,
      products_per_second: total > 0 ? (total.to_f / duration).round(2) : 0,
      success_rate: total > 0 ? ((success.to_f / total) * 100).round(1) : 0,
      timestamp: Time.current.iso8601
    }

    Rails.logger.info(
      "[BatchProductSyncJob] Batch sync completed: " \
      "#{success}/#{total} successful (#{summary[:success_rate]}%) " \
      "in #{duration}s (#{summary[:products_per_second]} products/s)"
    )

    if failure > 0
      Rails.logger.warn(
        "[BatchProductSyncJob] #{failure} products failed to sync. " \
        "First 5 errors: #{errors.first(5).join('; ')}"
      )
      summary[:sample_errors] = errors.first(5)
    end

    Rails.logger.info(summary.to_json)
  end
end
