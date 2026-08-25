class Price < ApplicationRecord
  belongs_to :product
  belongs_to :customer_group, optional: true

  PRICE_TYPES = %w[base special group].freeze

  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :price_type, presence: true, inclusion: { in: PRICE_TYPES }

  validates :customer_group_id,
            uniqueness: { scope: [ :product_id, :price_type ], allow_nil: true },
            if: :customer_group_id?

  validate :customer_group_belongs_to_same_company, if: :customer_group_id?

  validate :valid_date_range, if: -> { price_type == "special" }

  scope :base_prices, -> { where(price_type: "base", customer_group_id: nil) }
  scope :special_prices, -> { where(price_type: "special") }
  scope :group_prices, -> { where(price_type: "group") }
  scope :active_special_prices, -> {
    where(price_type: "special")
      .where("valid_from IS NULL OR valid_from <= ?", Time.current)
      .where("valid_to IS NULL OR valid_to >= ?", Time.current)
  }

  def active?
    return true unless price_type == "special"

    now = Time.current
    (valid_from.nil? || valid_from <= now) && (valid_to.nil? || valid_to >= now)
  end

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

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    if valid_from > valid_to
      errors.add(:valid_from, "must be before valid_to")
    end
  end
end
