# frozen_string_literal: true

# Bundles user identity with role/scope data for Pundit authorization.
#
# Pundit passes `pundit_user` as the first argument to all policies.
# Since roles and scopes live in the session (from Authlift8 OAuth),
# not on the User model, this class bridges that gap.
#
# @example In a policy
#   def create?
#     user_context.can_write?
#   end
#
# @example In a controller (automatic via pundit_user)
#   authorize @product  # passes UserContext to ProductPolicy
#
class UserContext
  VALID_ROLES = %w[admin member viewer].freeze

  attr_reader :user, :role, :scopes, :company

  # @param user [User] the authenticated User model instance
  # @param role [String] "admin", "member", or "viewer"
  # @param scopes [Array<String>] e.g. ["read", "write"]
  # @param company [Company] the current Potlift company
  def initialize(user, role, scopes, company)
    @user = user
    @role = VALID_ROLES.include?(role) ? role.freeze : "viewer"
    @scopes = (scopes || []).map(&:to_s).freeze
    @company = company
  end

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def viewer?
    role == "viewer"
  end

  def can_write?
    admin? || scopes.include?("write") || scopes.any? { |s| s.end_with?(":write") }
  end

  def can_read?
    admin? || member? || scopes.include?("read") || scopes.any? { |s| s.end_with?(":read") }
  end
end
