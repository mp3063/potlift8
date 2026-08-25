class CompanyMembership < ApplicationRecord
  belongs_to :user
  belongs_to :company

  validates :role, presence: true
  validates :user_id, uniqueness: { scope: :company_id, message: "already has membership for this company" }

  validates :role, inclusion: {
    in: %w[admin member viewer],
    message: "%{value} is not a valid role"
  }

  scope :admins, -> { where(role: "admin") }
  scope :members, -> { where(role: "member") }
  scope :viewers, -> { where(role: "viewer") }

  def admin?
    role == "admin"
  end

  def member?
    role == "member"
  end

  def viewer?
    role == "viewer"
  end
end
