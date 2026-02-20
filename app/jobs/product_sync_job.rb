# frozen_string_literal: true

# ProductSyncJob
#
# Background job for synchronizing products to external systems.
# This job is enqueued automatically when products are updated via the
# ChangePropagator concern, or can be triggered manually.
#
# Queue: :default (normal priority)
#
# Responsibilities:
# - Check if product is locked for sync (skip if locked)
# - Call ProductSyncService to perform the actual synchronization
# - Handle errors gracefully with comprehensive logging
# - Retry on transient failures (inherited from ApplicationJob)
#
# Usage:
#   ProductSyncJob.perform_later(product, catalog, Time.current)
#   ProductSyncJob.set(wait: 5.seconds).perform_later(product, catalog, Time.current)
#
# Parameters:
#   @param product [Product] The product to synchronize
#   @param catalog [Catalog] The catalog to sync to
#   @param timestamp [Time] The timestamp when sync was triggered
#
class ProductSyncJob < ApplicationJob
  queue_as :default

  # Perform product synchronization with deduplication
  #
  # @param product [Product] The product to synchronize
  # @param catalog [Catalog] The catalog to sync to
  # @param timestamp [Time] The timestamp when sync was triggered
  #
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

    # Check if this job was recently executed
    unless deduplicator.unique?
      Rails.logger.info(
        "Skipping duplicate sync for Product #{product.id} (#{product.sku}) " \
        "to Catalog #{catalog.code}. Job executed recently."
      )
      return
    end

    # Check if product is sync locked
    if product.sync_locked?
      Rails.logger.warn(
        "Product #{product.id} (#{product.sku}) is sync locked. Skipping sync to catalog #{catalog.code}."
      )
      return
    end

    # Check if catalog has sync paused
    if catalog.info&.dig("sync_paused")
      Rails.logger.info(
        "Catalog #{catalog.id} (#{catalog.code}) has sync paused. Skipping sync for product #{product.sku}."
      )
      return
    end

    # Perform the synchronization
    begin
      sync_product(product, catalog, timestamp)
    rescue StandardError => e
      Rails.logger.error(
        "Failed to sync product #{product.id} (#{product.sku}) " \
        "to catalog #{catalog.code}: #{e.class} - #{e.message}\n" \
        "Backtrace:\n#{e.backtrace.first(10).join("\n")}"
      )
      raise e # Re-raise to trigger retry logic from ApplicationJob
    end
  end

  private

  # Sync the product to the external system
  #
  # @param product [Product] The product to sync
  # @param catalog [Catalog] The catalog to sync to
  # @param timestamp [Time] The timestamp when sync was triggered
  #
  def sync_product(product, catalog, timestamp)
    start_time = Time.current

    # Call the ProductSyncService (implemented by another agent)
    service = ProductSyncService.new(product, catalog)
    result = service.sync_to_external_system

    duration = (Time.current - start_time).round(2)

    # Record successful sync on catalog_item
    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :synced, last_synced_at: Time.current, last_sync_error: nil)

    Rails.logger.info(
      "Product sync completed: Product #{product.id} (#{product.sku}) " \
      "to Catalog #{catalog.code} in #{duration}s. " \
      "Result: #{result.inspect}"
    )

    # Log sync metrics
    log_sync_metric(product, catalog, duration, success: true)
  rescue StandardError => e
    duration = (Time.current - start_time).round(2)

    # Record failed sync on catalog_item
    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :failed, last_sync_error: e.message.truncate(255))

    log_sync_metric(product, catalog, duration, success: false, error: e)
    raise e
  end

  # Log sync metrics for monitoring
  #
  # @param product [Product] The product that was synced
  # @param catalog [Catalog] The catalog synced to
  # @param duration [Float] Sync duration in seconds
  # @param success [Boolean] Whether sync was successful
  # @param error [Exception] Optional error if sync failed
  #
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

  # Get deduplication window from ENV or use default
  #
  # @return [Integer] Deduplication window in seconds
  #
  def deduplication_window
    ENV.fetch("JOB_DEDUP_WINDOW", "30").to_i
  end
end
