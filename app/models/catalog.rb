# Catalog Model
#
# Manages product catalogs with multi-currency support.
# Catalogs represent different sales channels (webshop, supply) and support
# multiple currencies with enforced minimum price ratios.
#
# Catalog Types:
# - webshop (1): Public-facing web store catalog
# - supply (2): Internal supply chain catalog
#
# Supported Currencies:
# - eur: Euro (base currency, no minimum ratio)
# - sek: Swedish Krona (minimum ratio: 1.5)
# - nok: Norwegian Krone (minimum ratio: 1.5)
#
# JSONB Fields (pot3 conventions):
# - info: Additional catalog metadata and settings
# - cache: Cached calculated values (product counts, totals, etc.)
#
# Multi-tenancy:
# - Catalogs belong to a company
# - Code must be unique within company scope
#
class Catalog < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :sync_lock, optional: true  # pot3 has this foreign key

  has_many :catalog_items, dependent: :destroy
  has_many :products, through: :catalog_items

  # Enums
  enum :catalog_type, {
    webshop: 1,
    supply: 2
  }

  # Minimum currency ratio for non-EUR catalogs
  # Ensures pricing consistency across different currency catalogs
  MINIMUM_CURRENCY_RATIO = {
    sek: 1.5,
    nok: 1.5
  }.freeze

  # Validations
  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true
  validates :catalog_type, presence: true
  validates :currency_code, inclusion: { in: %w[eur sek nok] }
  validate :currency_ratio_compliance, if: -> { currency_code != "eur" }

  # Scopes
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :by_type, ->(type) { where(catalog_type: type) }
  scope :by_currency, ->(currency) { where(currency_code: currency) }

  # Override to_param to use code instead of id in URLs
  #
  # This allows routes like /catalogs/WEB-EUR instead of /catalogs/1
  #
  # @return [String] The catalog code
  #
  def to_param
    code
  end

  # Check if catalog requires minimum price ratio
  #
  # @return [Boolean] true if catalog has a minimum ratio requirement
  #
  def requires_minimum_ratio?
    MINIMUM_CURRENCY_RATIO.key?(currency_code.to_sym)
  end

  # Get the minimum price ratio for this catalog's currency
  #
  # @return [Float] The minimum ratio (default: 1.0 for EUR)
  #
  def minimum_ratio
    MINIMUM_CURRENCY_RATIO[currency_code.to_sym] || 1.0
  end

  # Get all active products in this catalog
  #
  # @return [ActiveRecord::Relation] Active catalog items
  #
  def active_products
    products.joins(:catalog_items)
            .where(catalog_items: { catalog_item_state: :active })
  end

  # Get catalog items count
  #
  # @return [Integer] Number of products in catalog
  #
  def products_count
    catalog_items.count
  end

  # Batch Sync Helper Methods
  #
  # Sync all products in this catalog using batch job
  #
  # @param queue [Symbol] Queue to use for batch job
  # @param batch_size [Integer] Maximum products per batch (nil = all at once)
  # @return [Array<BatchProductSyncJob>] Array of enqueued jobs
  #
  def batch_sync_all_products(queue: :low_priority, batch_size: nil)
    product_ids = products.pluck(:id)

    if product_ids.empty?
      Rails.logger.info("No products to sync in catalog #{code}")
      return []
    end

    # Split into batches if batch_size specified
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

  # Sync only active products in this catalog
  #
  # @param queue [Symbol] Queue to use for batch job
  # @return [BatchProductSyncJob] Enqueued job
  #
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

  # Schedule full catalog sync during off-peak hours
  #
  # @param off_peak_hour [Integer] Hour to run (0-23, default: 2 AM)
  # @param batch_size [Integer] Products per batch (default: 500)
  # @return [Array<BatchProductSyncJob>] Array of scheduled jobs
  #
  def schedule_full_sync(off_peak_hour: 2, batch_size: 500)
    product_ids = products.pluck(:id)

    if product_ids.empty?
      Rails.logger.info("No products to sync in catalog #{code}")
      return []
    end

    # Calculate time until next off-peak hour
    now = Time.current
    target_time = now.change(hour: off_peak_hour, min: 0, sec: 0)
    target_time += 1.day if target_time <= now

    wait_seconds = (target_time - now).to_i

    # Split into batches
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

  # Get catalog description from info JSONB field
  #
  # @return [String, nil] Description or nil
  #
  def description
    info&.dig("description")
  end

  # Set catalog description in info JSONB field
  #
  # @param value [String] Description text
  #
  def description=(value)
    self.info ||= {}
    self.info["description"] = value
  end

  # Check if catalog is active (from info JSONB field)
  #
  # @return [Boolean] true if active, defaults to true
  #
  def active?
    # Default to true if not explicitly set to false
    info&.dig("active") != false
  end

  # Get catalog active status (alias for forms)
  # Rails form helpers call this method (without ?) for checkbox values
  #
  # @return [Boolean] true if active, defaults to true
  #
  def active
    active?
  end

  # Set catalog active status in info JSONB field
  #
  # @param value [Boolean] Active status
  #
  def active=(value)
    self.info ||= {}
    self.info["active"] = ActiveModel::Type::Boolean.new.cast(value)
  end

  # Get rate limit configuration for this catalog
  #
  # @return [Hash] Rate limit configuration
  #
  def rate_limit_config
    {
      limit: info&.dig("rate_limit", "limit")&.to_i || 100,
      period: info&.dig("rate_limit", "period")&.to_i || 60
    }
  end

  # Update rate limit configuration
  #
  # @param limit [Integer] Maximum requests per period
  # @param period [Integer] Time window in seconds
  #
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

  private

  # Validates currency ratio compliance for non-EUR catalogs
  # This is a placeholder for catalog-level validation
  # Actual price ratio validation happens at the catalog item level
  #
  def currency_ratio_compliance
    # Price validation is enforced at catalog_item level via CatalogPriceValidator
    # This method exists to document the requirement
  end
end
