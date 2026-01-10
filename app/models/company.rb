# Company Model
#
# Represents a company in the multi-tenant Potlift8 system.
# Companies are synchronized from Authlift8 OAuth provider.
#
# Attributes:
# - code: Unique company identifier from Authlift8 (10-char alphanumeric)
# - authlift_id: Authlift8's internal company ID
# - name: Company name
# - info: JSONB field storing additional company data from Authlift8
# - active: Soft delete flag
#
# Associations:
# - has_many :products (future)
# - has_many :catalogs (future)
# - has_many :storages (future)
# - has_many :labels (future)
# - has_many :product_attributes (future)
# - has_many :company_states (future)
#
# Multi-tenancy:
# All domain models should belong_to :company and use ActsAsTenant
# for automatic scoping of queries to current company context.
#
class Company < ApplicationRecord
  # Callbacks
  before_create :generate_api_token

  # Validations
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :authlift_id, uniqueness: true, allow_nil: true

  # Associations - prepared for future implementation
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

  # Scopes
  scope :active, -> { where(active: true) }

  # Find or create company from Authlift8 JWT payload
  #
  # Synchronizes company data from OAuth provider. Creates new company
  # if it doesn't exist, or updates existing company information.
  #
  # @param company_data [Hash] Company data from JWT payload
  # @option company_data [Integer] 'id' Authlift8's internal company ID (required)
  # @option company_data [String] 'code' Unique company identifier (required)
  # @option company_data [String] 'name' Company name (required)
  # @option company_data [Hash] Additional company attributes stored in info field
  #
  # @return [Company] The synchronized company record
  #
  # @example
  #   company_data = {
  #     'id' => 15,
  #     'code' => 'ABC1234XYZ',
  #     'name' => 'ACME Corporation',
  #     'settings' => { 'timezone' => 'UTC' }
  #   }
  #   company = Company.from_authlift8(company_data)
  #
  def self.from_authlift8(company_data)
    return nil if company_data.blank?

    # Extract required fields
    authlift_id = company_data["id"] || company_data[:id]
    code = company_data["code"] || company_data[:code]
    name = company_data["name"] || company_data[:name]

    return nil if code.blank? || name.blank?

    # Find or initialize company by code (primary identifier)
    # Use case-insensitive search to match validation
    code = code.to_s.strip.upcase
    company = where("UPPER(code) = ?", code).first_or_initialize(code: code)

    # Update attributes
    company.authlift_id = authlift_id if authlift_id.present?
    company.name = name
    company.info = company_data.except("id", "code", "name", :id, :code, :name)
    company.active = true # Always activate on sync

    # Save and return
    company.save!
    company
  end

  # Regenerate the API token
  #
  # @return [String] The new API token
  #
  def regenerate_api_token!
    update!(api_token: generate_api_token)
    api_token
  end

  private

  # Generate a secure random API token
  #
  # @return [String] A 32-character hex token
  #
  def generate_api_token
    self.api_token = loop do
      token = SecureRandom.hex(32)
      break token unless Company.exists?(api_token: token)
    end
  end
end
