# User Model
#
# Represents a user authenticated via Authlift8 OAuth2 provider.
# Users can belong to multiple companies through CompanyMembership.
#
# Attributes:
# - oauth_sub: Unique identifier from Authlift8 (JWT 'sub' claim)
# - email: User email address
# - name: User display name (from first_name + last_name)
# - last_sign_in_at: Timestamp of last successful authentication
# - company_id: Primary company association
#
# Associations:
# - belongs_to :company (primary company)
# - has_many :company_memberships
# - has_many :accessible_companies (companies user can access)
#
# OAuth Flow:
# User.find_or_create_from_oauth(jwt_payload) is called during
# authentication callback to synchronize user data from Authlift8.
#
class User < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :company_memberships, dependent: :destroy
  has_many :accessible_companies, through: :company_memberships, source: :company

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :oauth_sub, presence: true, uniqueness: true
  validates :name, presence: true

  # Find or create user from Authlift8 OAuth payload
  #
  # This method is called during OAuth callback to synchronize user data.
  # It creates a new user if oauth_sub doesn't exist, or updates existing
  # user information if the user already exists.
  #
  # JWT Payload Structure from Authlift8:
  # {
  #   "sub": "user-oauth-id",
  #   "user": {
  #     "id": 123,
  #     "email": "user@example.com",
  #     "first_name": "John",
  #     "last_name": "Doe",
  #     "locale": "en"
  #   },
  #   "company": {
  #     "id": 15,
  #     "code": "ABC1234XYZ",
  #     "name": "ACME Corporation"
  #   },
  #   "membership": {
  #     "role": "admin",
  #     "scopes": ["read", "write"]
  #   }
  # }
  #
  # @param payload [Hash] JWT payload from Authlift8
  # @return [User] The synchronized user record
  #
  # @example
  #   payload = {
  #     'sub' => 'oauth_user_123',
  #     'user' => { 'email' => 'john@example.com', 'first_name' => 'John', 'last_name' => 'Doe' },
  #     'company' => { 'id' => 15, 'code' => 'ABC123', 'name' => 'ACME Corp' },
  #     'membership' => { 'role' => 'admin' }
  #   }
  #   user = User.find_or_create_from_oauth(payload)
  #
  def self.find_or_create_from_oauth(payload)
    # Extract user data from payload
    oauth_sub = payload['sub']
    user_data = payload['user'] || {}
    company_data = payload['company'] || {}
    membership_data = payload['membership'] || {}

    # Build full name from first_name and last_name
    full_name = [
      user_data['first_name'],
      user_data['last_name']
    ].compact.join(' ').presence || user_data['email']&.split('@')&.first

    # Find or create company from payload
    company = Company.from_authlift8(company_data)

    return nil if company.nil?

    # Find existing user by oauth_sub
    user = find_by(oauth_sub: oauth_sub)

    if user
      # Update existing user
      user.update!(
        email: user_data['email'],
        name: full_name,
        last_sign_in_at: Time.current,
        company_id: company.id
      )
    else
      # Create new user
      user = create!(
        oauth_sub: oauth_sub,
        email: user_data['email'],
        name: full_name,
        last_sign_in_at: Time.current,
        company_id: company.id
      )
    end

    # Ensure company membership exists
    user.ensure_company_membership(company, membership_data['role'] || 'member')

    user
  end

  # Ensure user has membership for the given company
  #
  # Creates or updates a CompanyMembership record for the user and company.
  # This is called during authentication to ensure the user's membership
  # is synchronized with Authlift8.
  #
  # Role Mapping:
  # - 'owner' from Authlift8 is mapped to 'admin' (full permissions)
  # - Other roles are used as-is (admin, member, viewer)
  #
  # @param company [Company] The company to create membership for
  # @param role [String] The user's role in the company from Authlift8
  # @return [CompanyMembership] The membership record
  #
  def ensure_company_membership(company, role = 'member')
    # Map Authlift8 'owner' role to 'admin' role
    normalized_role = role == 'owner' ? 'admin' : role

    membership = company_memberships.find_or_initialize_by(company: company)
    membership.role = normalized_role
    membership.save!
    membership
  end

  # Get user initials for avatar display
  #
  # @return [String] User initials (e.g., "JD" for John Doe)
  #
  def initials
    name.split.map(&:first).join.upcase.first(2)
  end
end
