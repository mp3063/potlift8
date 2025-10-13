# CompanyMembership Model
#
# Represents the many-to-many relationship between Users and Companies.
# Allows users to have access to multiple companies with different roles.
#
# Attributes:
# - user_id: Reference to User
# - company_id: Reference to Company
# - role: User's role in the company (e.g., 'admin', 'member', 'viewer')
#
# Validations:
# - Unique constraint on [user_id, company_id] ensures one membership per user per company
# - Role is required
#
# Usage:
# User can switch between accessible companies via the company switcher
# in the UI. Current company context is stored in session.
#
class CompanyMembership < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :company

  # Validations
  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :company_id, message: 'already has membership for this company' }

  # Role validation (can be extended to enum in the future)
  validates :role, inclusion: {
    in: %w[admin member viewer],
    message: '%{value} is not a valid role'
  }

  # Scopes
  scope :admins, -> { where(role: 'admin') }
  scope :members, -> { where(role: 'member') }
  scope :viewers, -> { where(role: 'viewer') }

  # Check if membership has admin role
  #
  # @return [Boolean]
  #
  def admin?
    role == 'admin'
  end

  # Check if membership has member role
  #
  # @return [Boolean]
  #
  def member?
    role == 'member'
  end

  # Check if membership has viewer role
  #
  # @return [Boolean]
  #
  def viewer?
    role == 'viewer'
  end
end
