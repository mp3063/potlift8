# frozen_string_literal: true

class UserContext
  VALID_ROLES = %w[admin member viewer].freeze

  attr_reader :user, :role, :scopes, :company

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
