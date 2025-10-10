# frozen_string_literal: true

# BatchProductSyncJob
#
# Background job for synchronizing multiple products to external systems efficiently.
# Uses batching and eager loading to minimize database queries and memory usage.
#
# Queue: :low_priority (batch operations should not block high-priority individual syncs)
#
# Features:
# - Efficient batch processing with find_each
# - Eager loading of associations to prevent N+1 queries
# - Individual error handling (one failure doesn't stop the batch)
# - Progress tracking and timing metrics
# - Memory-efficient processing (processes in chunks)
#
# Usage:
#   # Sync specific products
#   BatchProductSyncJob.perform_later([product1.id, product2.id, ...], catalog.id)
#
#   # Sync all products in a catalog
#   product_ids = catalog.products.pluck(:id)
#   BatchProductSyncJob.perform_later(product_ids, catalog.id)
#
# Performance Characteristics:
# - Batch size: 100 products per iteration (configurable)
# - Memory usage: Low (streaming queries)
# - Database queries: Minimized with eager loading
# - Failure handling: Graceful (logs but continues)
#
class BatchProductSyncJob < ApplicationJob
  queue_as :low_priority

  # Batch size for find_each iteration
  BATCH_SIZE = 100

  # Perform batch product synchronization
  #
  # @param product_ids [Array<Integer>] Array of product IDs to sync
  # @param catalog_id [Integer] Catalog ID to sync to
  #
  def perform(product_ids, catalog_id)
    start_time = Time.current

    Rails.logger.info(
      "[BatchProductSyncJob] Starting batch sync: #{product_ids.size} products " \
      "to catalog #{catalog_id}"
    )

    catalog = Catalog.find(catalog_id)

    # Validate catalog is not paused
    if catalog.info&.dig('sync_paused')
      Rails.logger.info(
        "[BatchProductSyncJob] Catalog #{catalog.code} has sync paused. Skipping batch sync."
      )
      return
    end

    # Initialize tracking variables
    success_count = 0
    failure_count = 0
    skipped_count = 0
    errors = []

    # Process products in batches using find_each for memory efficiency
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

      # Log progress every 50 products
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

  # Sync a single product within the batch
  #
  # @param product [Product] Product to sync
  # @param catalog [Catalog] Catalog to sync to
  # @return [Hash] Result with status and optional error
  #
  def sync_single_product(product, catalog)
    # Check if product is sync locked
    if product.sync_locked?
      Rails.logger.debug(
        "[BatchProductSyncJob] Product #{product.id} (#{product.sku}) is sync locked. Skipping."
      )
      return { status: :skipped, reason: 'sync_locked' }
    end

    # Perform the sync
    service = ProductSyncService.new(product, catalog)
    result = service.sync_to_external_system

    if result.success?
      { status: :success }
    else
      {
        status: :failure,
        error: "Product #{product.id} (#{product.sku}): #{result.error}"
      }
    end
  rescue StandardError => e
    {
      status: :failure,
      error: "Product #{product.id} (#{product.sku}): #{e.message}"
    }
  end

  # Log batch progress
  #
  def log_progress(processed, total, success, failure, skipped)
    percentage = ((processed.to_f / total) * 100).round(1)

    Rails.logger.info(
      "[BatchProductSyncJob] Progress: #{processed}/#{total} (#{percentage}%) | " \
      "Success: #{success}, Failed: #{failure}, Skipped: #{skipped}"
    )
  end

  # Log batch completion with summary
  #
  def log_batch_completion(total, success, failure, skipped, duration, catalog, errors)
    summary = {
      event: 'batch_sync_completed',
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

    # Structured log for monitoring
    Rails.logger.info(summary.to_json)
  end
end
