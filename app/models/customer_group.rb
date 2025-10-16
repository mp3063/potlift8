# CustomerGroup Model
#
# Represents customer groups for group-based pricing.
# Each company can define their own customer groups with specific discount percentages.
#
# Examples:
# - Wholesale: 20% discount
# - VIP: 15% discount
# - Retail: 0% discount (regular price)
#
# JSONB Fields:
# - info: Additional metadata (settings, rules, etc.)
#
class CustomerGroup < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :prices, dependent: :destroy
  has_many :products, through: :prices

  # Validations
  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :discount_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  # Scopes
  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :active, -> { where("info->>'active' IS NULL OR info->>'active' = 'true'") }
  scope :by_name, -> { order(:name) }

  # Get discount percentage (returns 0 if not set)
  #
  # @return [Float] Discount percentage (0-100)
  #
  def discount_percentage
    discount_percent || 0
  end

  # Calculate discounted price
  #
  # @param base_price [Numeric] Original price
  # @return [Numeric] Discounted price
  #
  def calculate_discounted_price(base_price)
    return base_price if discount_percentage.zero?

    base_price * (1 - discount_percentage / 100.0)
  end

  # Check if customer group is active
  #
  # @return [Boolean] true if active (default: true)
  #
  def active?
    info.dig('active').nil? || info.dig('active') == true
  end
end
