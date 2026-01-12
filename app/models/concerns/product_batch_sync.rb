# frozen_string_literal: true

# ProductBatchSync
#
# Handles batch synchronization methods for products including:
# - Syncing to all catalogs
# - Syncing to specific catalogs with deduplication
# - Scheduling off-peak batch syncs
#
module ProductBatchSync
  extend ActiveSupport::Concern

  def sync_to_all_catalogs_batch(queue: :low_priority)
    catalog_ids = catalogs.pluck(:id)
    return [] if catalog_ids.empty?

    jobs = catalog_ids.map do |catalog_id|
      BatchProductSyncJob.set(queue: queue).perform_later([id], catalog_id)
    end

    Rails.logger.info(
      "Enqueued #{jobs.size} batch sync jobs for product #{id} (#{sku})"
    )

    jobs
  end

  def sync_to_catalog(catalog, force: false)
    unless force
      deduplicator = JobDeduplicator.new(
        job_name: "ProductSyncJob",
        params: { product_id: id, catalog_id: catalog.id },
        window: 30
      )

      unless deduplicator.unique?
        Rails.logger.debug(
          "Skipping duplicate sync for product #{id} (#{sku}) to catalog #{catalog.code}"
        )
        return false
      end
    end

    ProductSyncJob.perform_later(self, catalog, Time.current)
    true
  end

  class_methods do
    def batch_sync_to_catalog(product_ids, catalog_id, queue: :low_priority)
      BatchProductSyncJob.set(queue: queue).perform_later(product_ids, catalog_id)
    end

    def schedule_batch_sync(product_ids, catalog_id, off_peak_hour: 2)
      now = Time.current
      target_time = now.change(hour: off_peak_hour, min: 0, sec: 0)
      target_time += 1.day if target_time <= now

      wait_seconds = (target_time - now).to_i

      Rails.logger.info(
        "Scheduling batch sync of #{product_ids.size} products to catalog #{catalog_id} " \
        "at #{target_time} (in #{wait_seconds / 3600.0} hours)"
      )

      BatchProductSyncJob.set(wait: wait_seconds, queue: :low_priority)
                         .perform_later(product_ids, catalog_id)
    end
  end
end
