# frozen_string_literal: true

class ProductSyncJob < ApplicationJob
  include SyncErrorSanitizer

  # The sync service returned a failure result instead of raising
  class SyncFailed < StandardError; end

  queue_as :default

  retry_on SyncFailed, wait: :polynomially_longer, attempts: 5
  # Retry after the limiter window (per-catalog overrides are not visible here),
  # with jitter so a rate-limited bulk add does not come back all at once
  retry_on RateLimiter::RateLimitExceededError,
           wait: ->(_executions) { ProductSyncService::DEFAULT_RATE_LIMIT_PERIOD + rand(0..30) },
           attempts: 10 do |job, _error|
    # Retries ran out; without this the item stays queued forever
    job.send(:mark_rate_limit_exhausted)
  end

  def perform(product, catalog, timestamp, manual: false)
    Rails.logger.info(
      "Starting product sync: Product #{product.id} (#{product.sku}) " \
      "to Catalog #{catalog.id} (#{catalog.code}), triggered at #{timestamp}"
    )

    # Skip checks come before the lock: a job that sends nothing must not record a
    # start time, or duplicates queued just before it would count as covered.
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

    unless catalog.shop_connected?
      Rails.logger.info("Catalog #{catalog.code} is not connected to a shop. Skipping sync for product #{product.sku}.")
      return
    end

    # A sync queued before the product left the catalog would recreate it in the shop
    unless CatalogItem.exists?(catalog: catalog, product: product)
      Rails.logger.info("Product #{product.sku} is no longer in catalog #{catalog.code}. Skipping sync.")
      return
    end

    # Trailing dedup: the first job syncs now; a change inside the window
    # schedules one sync for when the window ends instead of being dropped.
    # The lock stores when the leading sync started, so duplicates it already covers are dropped.
    lock = sync_lock(product, catalog)
    started_at = Time.current.to_f.to_s
    # A manual sync sends now but still takes the lock, so edits right after it are held
    if manual
      lock.claim!(value: started_at)
    elsif !lock.unique?(value: started_at)
      schedule_trailing_sync(product, catalog, lock, timestamp)
      return
    end
    trailing_marker(product, catalog).clear!

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
    raise SyncFailed, result.error unless result.success?

    duration = (Time.current - start_time).round(2)

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :syncing, last_sync_error: nil)

    Rails.logger.info(
      "Product sync completed: Product #{product.id} (#{product.sku}) " \
      "to Catalog #{catalog.code} in #{duration}s. " \
      "Result: #{result.inspect}"
    )

    log_sync_metric(product, catalog, duration, success: true)
  rescue RateLimiter::RateLimitExceededError
    # Not a sync failure: keep the item's status and error, release the lock, and let retry_on wait
    sync_lock(product, catalog).clear!
    raise
  rescue StandardError => e
    duration = (Time.current - start_time).round(2)

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(sync_status: :failed, last_sync_error: sanitize_sync_error(e))

    log_sync_metric(product, catalog, duration, success: false, error: e)
    # Release the dedup lock so the retry syncs instead of becoming a trailing sync
    sync_lock(product, catalog).clear!
    raise e
  end

  def mark_rate_limit_exhausted
    product, catalog = arguments
    return unless product && catalog

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    catalog_item&.update!(
      sync_status: :failed,
      last_sync_error: "Rate limit reached: sync gave up after 10 attempts. Use Sync to try again."
    )

    Rails.logger.error(
      "Product sync gave up after #{executions} rate-limited attempts: " \
      "Product #{product.id} (#{product.sku}) to Catalog #{catalog.code}"
    )
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

  def sync_lock(product, catalog)
    JobDeduplicator.new(
      job_name: "ProductSyncJob",
      params: { product_id: product.id, catalog_id: catalog.id },
      window: deduplication_window,
      bucketed: false
    )
  end

  # Set while a trailing sync is queued, so later duplicates are dropped:
  # the trailing job builds its payload when it runs.
  def trailing_marker(product, catalog)
    JobDeduplicator.new(
      job_name: "ProductSyncJob:trailing",
      params: { product_id: product.id, catalog_id: catalog.id },
      window: deduplication_window * 2,
      bucketed: false
    )
  end

  def schedule_trailing_sync(product, catalog, lock, timestamp)
    if covered_by_running_sync?(lock, timestamp)
      Rails.logger.info(
        "Sync for Product #{product.id} (#{product.sku}) to Catalog #{catalog.code} was queued before " \
        "the running sync started. Its change is in that sync; skipping."
      )
      return
    end
    return unless trailing_marker(product, catalog).unique?

    # TTL is whole seconds, so add 1s or the trailing job can start while the lock still holds
    wait = [ lock.time_until_executable, 1 ].max + 1
    self.class.set(wait: wait.seconds).perform_later(product, catalog, Time.current)
    Rails.logger.info(
      "Sync for Product #{product.id} (#{product.sku}) to Catalog #{catalog.code} ran recently. " \
      "Scheduled a trailing sync in #{wait}s."
    )
  end

  # Jobs are queued after commit, and the running sync reads the product after it starts,
  # so a job queued before that start is already in its payload. The 2s margin covers
  # clock skew between hosts. An unreadable start (missing, Redis error, or the legacy
  # "1", which parses as 1.0) never drops the job.
  def covered_by_running_sync?(lock, timestamp)
    return false unless timestamp.is_a?(Time)

    started_at = Float(lock.stored_value, exception: false)
    return false if started_at.nil?

    timestamp.to_f < started_at - 2
  end

  def deduplication_window
    ENV.fetch("JOB_DEDUP_WINDOW", "30").to_i
  end
end
