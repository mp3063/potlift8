# Price Model
#
# Represents pricing for products with support for base prices, special pricing,
# and customer group pricing.
#
# Price Types:
# - base: Regular product price (one per product, no customer group)
# - special: Time-limited promotional price (date range required)
# - group: Customer group-specific pricing (requires customer_group)
#
# Currencies:
# - EUR, USD, GBP, SEK, NOK, DKK, etc.
#
# Special Pricing:
# - valid_from/valid_to define the active date range
# - Use active? method to check if special price is currently valid
#
# Customer Group Pricing:
# - Associates price with a customer_group
# - One price per product per customer group
#
class Price < ApplicationRecord
  # Associations
  belongs_to :product
  belongs_to :customer_group, optional: true

  # Price Types
  PRICE_TYPES = %w[base special group].freeze

  # Validations
  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :price_type, presence: true, inclusion: { in: PRICE_TYPES }

  # Ensure only one price per product per customer group
  validates :customer_group_id,
            uniqueness: { scope: [ :product_id, :price_type ], allow_nil: true },
            if: :customer_group_id?

  # Validate customer group belongs to same company as product
  validate :customer_group_belongs_to_same_company, if: :customer_group_id?

  # Validate date range for special prices
  validate :valid_date_range, if: -> { price_type == "special" }

  # Scopes
  scope :base_prices, -> { where(price_type: "base", customer_group_id: nil) }
  scope :special_prices, -> { where(price_type: "special") }
  scope :group_prices, -> { where(price_type: "group") }
  scope :active_special_prices, -> {
    where(price_type: "special")
      .where("valid_from IS NULL OR valid_from <= ?", Time.current)
      .where("valid_to IS NULL OR valid_to >= ?", Time.current)
  }

  # Check if special price is currently active
  #
  # @return [Boolean] true if price is active based on date range
  #
  def active?
    return true unless price_type == "special"

    now = Time.current
    (valid_from.nil? || valid_from <= now) && (valid_to.nil? || valid_to >= now)
  end

  # Format price with currency symbol
  #
  # @return [String] Formatted price string
  #
  def formatted_value
    "#{currency} #{value}"
  end

  private

  def customer_group_belongs_to_same_company
    return unless customer_group && product

    unless customer_group.company_id == product.company_id
      errors.add(:customer_group_id, "must belong to the same company")
    end
  end

  # Validate that valid_from is before valid_to for special prices
  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    if valid_from > valid_to
      errors.add(:valid_from, "must be before valid_to")
    end
  end
end
