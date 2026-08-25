# frozen_string_literal: true

class ProductSyncJob < ApplicationJob
  include SyncErrorSanitizer

  queue_as :default

  def perform(product, catalog, timestamp)
    Rails.logger.info(
      "Starting product sync: Product #{product.id} (#{product.sku}) " \
      "to Catalog #{catalog.id} (#{catalog.code}), triggered at #{timestamp}"
    )

    # Apply job deduplication to prevent duplicate syncs
    deduplicator = JobDeduplicator.new(
      job_name: "ProductSyncJob",
      params: { product_id: product.id, catalog_id: catalog.id },
      window: deduplication_window
    )

    unless deduplicator.unique?
      Rails.logger.info(
        "Skipping duplicate sync for Product #{product.id} (#{product.sku}) " \
        "to Catalog #{catalog.code}. Job executed recently."
      )
      return
    end

    if product.sync_locked?
      Rails.logger.warn(
        "Product #{product.id} (#{product.sku}) is sync locked. Skipping sync to catalog #{catalog.code}."
      )
      return
    end

    if catalog.info&.dig("sync_paused")
      Rails.logger.info(
        "Catalog #{catalog.id} (#{catalog.code}) has sync paused. Skipping sync for product #{product.sku}."
      )
      return
    end

    begin
      sync_product(product, catalog, timestamp)
    rescue StandardError => e
      Rails.logger.error(
        "Failed to sync product #{product.id} (#{product.sku}) " \
        "to catalog #{catalog.code}: #{e.class} - #{e.message}\n" \
        "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
      )
      raise e
    end
  end

  private

  def sync_product(product, catalog, timestamp)
    start_time = Time.current

    service = ProductSyncService.new(product, catalog)
    result = service.sync_to_external_system

    duration = (Time.current - start_time).round(2)

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :pending, last_sync_error: nil)

    Rails.logger.info(
      "Product sync completed: Product #{product.id} (#{product.sku}) " \
      "to Catalog #{catalog.code} in #{duration}s. " \
      "Result: #{result.inspect}"
    )

    log_sync_metric(product, catalog, duration, success: true)
  rescue StandardError => e
    duration = (Time.current - start_time).round(2)

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :failed, last_sync_error: sanitize_sync_error(e))

    log_sync_metric(product, catalog, duration, success: false, error: e)
    raise e
  end

  def log_sync_metric(product, catalog, duration, success:, error: nil)
    metric_data = {
      event: "product_sync",
      product_id: product.id,
      product_sku: product.sku,
      catalog_id: catalog.id,
      catalog_code: catalog.code,
      duration_seconds: duration,
      success: success,
      timestamp: Time.current
    }

    metric_data[:error_class] = error.class.name if error
    metric_data[:error_message] = error.message if error

    Rails.logger.info(metric_data.to_json)

    # Log warning for slow syncs
    if duration > 5.0
      Rails.logger.warn(
        "SLOW sync detected: Product #{product.id} (#{product.sku}) " \
        "to Catalog #{catalog.code} took #{duration}s"
      )
    end
  end

  def deduplication_window
    ENV.fetch("JOB_DEDUP_WINDOW", "30").to_i
  end
end
