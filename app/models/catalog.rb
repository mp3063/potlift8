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

  def shopify_connected?
    shop_id.present?
  end

  # This is cached locally to avoid API calls just for display.
  # Updated when connection is established or modified.
  def shopify_domain
    info&.dig("shopify_domain_cache")
  end

  private

  def currency_ratio_compliance
  end
end
