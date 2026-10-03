# JSONB Fields (pot3 conventions):
# - info: Additional catalog metadata and settings
# - cache: Cached calculated values (product counts, totals, etc.)
# Multi-tenancy:
# - Catalogs belong to a company
# - Code must be unique within company scope
class Catalog < ApplicationRecord
  belongs_to :company
  belongs_to :sync_lock, optional: true  # pot3 has this foreign key

  has_many :catalog_items, dependent: :destroy
  has_many :products, through: :catalog_items

  enum :catalog_type, {
    webshop: 1,
    supply: 2
  }

  MINIMUM_CURRENCY_RATIO = {
    sek: 1.5,
    nok: 1.5
  }.freeze

  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true
  validates :catalog_type, presence: true
  validates :currency_code, inclusion: { in: %w[eur sek nok] }
  validate :currency_ratio_compliance, if: -> { currency_code != "eur" }

  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :by_type, ->(type) { where(catalog_type: type) }
  scope :by_currency, ->(currency) { where(currency_code: currency) }

  # Override to_param to use code instead of id in URLs
  # This allows routes like /catalogs/WEB-EUR instead of /catalogs/1
  def to_param
    code
  end

  def requires_minimum_ratio?
    MINIMUM_CURRENCY_RATIO.key?(currency_code.to_sym)
  end

  def minimum_ratio
    MINIMUM_CURRENCY_RATIO[currency_code.to_sym] || 1.0
  end

  def active_products
    products.joins(:catalog_items)
            .where(catalog_items: { catalog_item_state: :active })
  end

  def products_count
    catalog_items.count
  end

  def batch_sync_all_products(queue: :low_priority, batch_size: nil)
    product_ids = products.pluck(:id)

    if product_ids.empty?
      Rails.logger.info("No products to sync in catalog #{code}")
      return []
    end

    if batch_size
      batches = product_ids.each_slice(batch_size).to_a
      Rails.logger.info(
        "Syncing #{product_ids.size} products in #{batches.size} batches " \
        "of #{batch_size} to catalog #{code}"
      )

      jobs = batches.map do |batch_ids|
        BatchProductSyncJob.set(queue: queue).perform_later(batch_ids, id)
      end
    else
      Rails.logger.info(
        "Syncing all #{product_ids.size} products to catalog #{code} in single batch"
      )

      jobs = [ BatchProductSyncJob.set(queue: queue).perform_later(product_ids, id) ]
    end

    jobs
  end

  def batch_sync_active_products(queue: :low_priority)
    product_ids = active_products.pluck(:id)

    if product_ids.empty?
      Rails.logger.info("No active products to sync in catalog #{code}")
      return nil
    end

    Rails.logger.info(
      "Syncing #{product_ids.size} active products to catalog #{code}"
    )

    BatchProductSyncJob.set(queue: queue).perform_later(product_ids, id)
  end

  def schedule_full_sync(off_peak_hour: 2, batch_size: 500)
    product_ids = products.pluck(:id)

    if product_ids.empty?
      Rails.logger.info("No products to sync in catalog #{code}")
      return []
    end

    now = Time.current
    target_time = now.change(hour: off_peak_hour, min: 0, sec: 0)
    target_time += 1.day if target_time <= now

    wait_seconds = (target_time - now).to_i

    batches = product_ids.each_slice(batch_size).to_a

    Rails.logger.info(
      "Scheduling sync of #{product_ids.size} products in #{batches.size} batches " \
      "to catalog #{code} at #{target_time} (in #{(wait_seconds / 3600.0).round(1)} hours)"
    )

    jobs = batches.map.with_index do |batch_ids, index|
      # Stagger batches by 5 minutes each to avoid overwhelming the system
      wait_time = wait_seconds + (index * 5.minutes)

      BatchProductSyncJob.set(wait: wait_time, queue: :low_priority)
                         .perform_later(batch_ids, id)
    end

    jobs
  end

  def description
    info&.dig("description")
  end

  def description=(value)
    self.info ||= {}
    self.info["description"] = value
  end

  def active?
    info&.dig("active") != false
  end

  def active
    active?
  end

  def active=(value)
    self.info ||= {}
    self.info["active"] = ActiveModel::Type::Boolean.new.cast(value)
  end

  def rate_limit_config
    {
      limit: info&.dig("rate_limit", "limit")&.to_i || 100,
      period: info&.dig("rate_limit", "period")&.to_i || 60
    }
  end

  def update_rate_limit(limit:, period:)
    self.info ||= {}
    self.info["rate_limit"] = {
      "limit" => limit,
      "period" => period,
      "updated_at" => Time.current.iso8601
    }
    save!

    Rails.logger.info(
      "Updated rate limit for catalog #{code}: #{limit} requests per #{period}s"
    )
  end

  def shop_id
    info&.dig("shop_id")
  end

  def shop_id=(value)
    self.info ||= {}
    if value.present?
      self.info["shop_id"] = value.to_i
    else
      self.info.delete("shop_id")
    end
  end

  # The external system this catalog syncs to (same default as ProductSyncService)
  def sync_target
    info&.dig("sync_target").presence || "shopify8"
  end

  # Whether this catalog feeds a shop at all, on any target. Gates every
  # sync, removal and propagation. Without a shop_id, Shopify8 falls back to
  # the company's first shop (the wrong one).
  def shop_connected?
    shop_id.present?
  end

  # Whether the shop this catalog feeds is a Shopify store (via Shopify8)
  def shopify_connected?
    shop_connected? && sync_target == "shopify8"
  end

  # Two catalogs feed the same shop iff their shop_keys are equal and non-nil.
  # shop_id may be stored as integer or string, so compare it as a string.
  def shop_key
    "#{sync_target}:#{shop_id}" if shop_connected?
  end

  # This is cached locally to avoid API calls just for display.
  # Updated when connection is established or modified.
  def shopify_domain
    info&.dig("shopify_domain_cache")
  end

  # Stamps even when paused or unconnected, so the item still shows as changed since sync
  def queue_product_sync(product, timestamp = Time.current, wait: nil)
    catalog_items.where(product: product).update_all(content_changed_at: timestamp)
    return if info&.dig("sync_paused") || !shop_connected?

    (wait ? ProductSyncJob.set(wait: wait) : ProductSyncJob).perform_later(product, self, timestamp)
  end

  def sync_counts
    items = catalog_items
    outdated = items.out_of_date.count
    {
      synced: items.sync_synced.count - outdated,
      outdated: outdated,
      pending: items.sync_pending.count,
      failed: items.sync_failed.count,
      never: items.sync_never_synced.count
    }
  end

  # Progress of the latest Sync All run (info["sync_run"]), or nil without one.
  # The first time it is seen finished, the run is frozen (see #freeze_sync_run).
  def sync_run_progress
    run = info&.dig("sync_run")
    return nil if run.blank? || run["started_at"].blank?

    started_at = Time.zone.parse(run["started_at"])
    handed_off_at = run["handed_off_at"].presence && Time.zone.parse(run["handed_off_at"])

    if run["finished_at"].present?
      finished_at = Time.zone.parse(run["finished_at"])
      return Catalog::SyncRunProgress.new(
        total: run["total"].to_i, confirmed: run["confirmed"].to_i, failed: run["failed"].to_i,
        started_at: started_at, handed_off_at: handed_off_at,
        last_activity_at: finished_at, finished_at: finished_at
      )
    end

    items = catalog_items.reorder(nil)

    answers = items.where(
      "(sync_status = :synced AND last_synced_at >= :since) OR (sync_status = :failed AND updated_at >= :since)",
      synced: CatalogItem.sync_statuses[:synced], failed: CatalogItem.sync_statuses[:failed], since: started_at
    ).group(:sync_status).count

    latest_item_activity = items.where("updated_at >= :since OR last_synced_at >= :since", since: started_at)
                                .maximum(Arel.sql("GREATEST(updated_at, last_synced_at)"))

    progress = Catalog::SyncRunProgress.new(
      total: run["total"].to_i,
      confirmed: answers["synced"].to_i,
      failed: answers["failed"].to_i,
      started_at: started_at,
      handed_off_at: handed_off_at,
      last_activity_at: [ started_at, handed_off_at, latest_item_activity ].compact.max
    )
    freeze_sync_run(progress) if progress.finished?
    progress
  end

  # Refreshes the Shopify sync summary card for everyone on the items page.
  # Morphs so the progress bar widths animate instead of jumping.
  def broadcast_sync_summary
    broadcast_replace_to(
      self, "sync_status",
      target: "sync_summary_#{id}",
      partial: "catalogs/sync_summary_card",
      locals: { catalog: self, sync_counts: sync_counts },
      attributes: { method: :morph }
    )
  end

  private

  # Stores the finish time and final counts, once, so later pending writes or
  # item removals can't reopen a finished run. Guarded SQL, like the hand-off.
  def freeze_sync_run(progress)
    frozen = {
      "finished_at" => progress.finish_time.iso8601(6),
      "confirmed" => progress.confirmed,
      "failed" => progress.failed
    }
    # Matching started_at keeps a stale instance from freezing a newer run
    Catalog.where(id: id)
           .where("info->'sync_run'->>'started_at' = ? AND info->'sync_run'->>'finished_at' IS NULL", info["sync_run"]["started_at"])
           .update_all([ "info = jsonb_set(info, '{sync_run}', (info->'sync_run') || ?::jsonb)", frozen.to_json ])

    # Mirror it in memory, unless info carries unsaved edits of its own
    return if info_changed?

    self.info = info.merge("sync_run" => info["sync_run"].merge(frozen))
    clear_attribute_changes([ :info ])
  end

  def currency_ratio_compliance
  end
end
