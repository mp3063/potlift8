class CustomerGroup < ApplicationRecord
  belongs_to :company
  has_many :prices, dependent: :destroy
  has_many :products, through: :prices

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :code, presence: true, uniqueness: { scope: :company_id }
  validates :discount_percent,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 },
            allow_nil: true

  scope :for_company, ->(company_id) { where(company_id: company_id) }
  scope :active, -> { where("info->>'active' IS NULL OR info->>'active' = 'true'") }
  scope :by_name, -> { order(:name) }

  def discount_percentage
    discount_percent || 0
  end

  def calculate_discounted_price(base_price)
    return base_price if discount_percentage.zero?

    base_price * (1 - discount_percentage / 100.0)
  end

  def active?
    info.dig("active").nil? || info.dig("active") == true
  end
end
