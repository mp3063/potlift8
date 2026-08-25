class Company < ApplicationRecord
  before_create :generate_api_token
  after_create :provision_system_attributes

  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :authlift_id, uniqueness: true, allow_nil: true

  has_many :products, dependent: :destroy
  has_many :catalogs, dependent: :destroy
  has_many :storages, dependent: :destroy
  has_many :labels, dependent: :destroy
  has_many :product_attributes, dependent: :destroy
  has_many :attribute_groups, dependent: :destroy
  has_many :company_states, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :company_memberships, dependent: :destroy
  has_many :members, through: :company_memberships, source: :user
  has_many :customer_groups, dependent: :destroy
  has_many :imports, dependent: :destroy

  scope :active, -> { where(active: true) }

  def self.from_authlift8(company_data)
    return nil if company_data.blank?

    authlift_id = company_data["id"] || company_data[:id]
    code = company_data["code"] || company_data[:code]
    name = company_data["name"] || company_data[:name]

    return nil if code.blank? || name.blank?

    code = code.to_s.strip.upcase
    company = where("UPPER(code) = ?", code).first_or_initialize(code: code)

    company.authlift_id = authlift_id if authlift_id.present?
    company.name = name
    company.info = company_data.except("id", "code", "name", :id, :code, :name)
    company.active = true

    company.save!
    company
  end

  def self.authenticate_by_api_token(raw_token)
    return nil if raw_token.blank?
    digest = ::OpenSSL::Digest::SHA256.hexdigest(raw_token)
    find_by(api_token_digest: digest)
  end

  def regenerate_api_token!
    raw_token = SecureRandom.hex(32)
    update!(
      api_token: raw_token,
      api_token_digest: ::OpenSSL::Digest::SHA256.hexdigest(raw_token)
    )
    api_token
  end

  private

  def provision_system_attributes
    ProductAttribute.ensure_system_attributes!(self)
  end

  def generate_api_token
    raw_token = loop do
      token = SecureRandom.hex(32)
      break token unless Company.exists?(api_token: token)
    end
    self.api_token = raw_token
    self.api_token_digest = ::OpenSSL::Digest::SHA256.hexdigest(raw_token)
  end
end
