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
  validate :currency_ratio_compliance, if: -> { currency_code != 'eur' }

  # Scopes
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :by_type, ->(type) { where(catalog_type: type) }
  scope :by_currency, ->(currency) { where(currency_code: currency) }

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
