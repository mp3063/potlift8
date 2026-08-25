class User < ApplicationRecord
  belongs_to :company
  has_many :company_memberships, dependent: :destroy
  has_many :accessible_companies, through: :company_memberships, source: :company

  validates :email, presence: true, uniqueness: true
  validates :oauth_sub, presence: true, uniqueness: true
  validates :name, presence: true

  def self.find_or_create_from_oauth(payload)
    oauth_sub = payload["sub"]
    user_data = payload["user"] || {}
    company_data = payload["company"] || {}
    membership_data = payload["membership"] || {}

    full_name = [
      user_data["first_name"],
      user_data["last_name"]
    ].compact.join(" ").presence || user_data["email"]&.split("@")&.first

    company = Company.from_authlift8(company_data)

    return nil if company.nil?

    user = find_by(oauth_sub: oauth_sub)

    if user
      user.update!(
        email: user_data["email"],
        name: full_name,
        last_sign_in_at: Time.current,
        company_id: company.id
      )
    else
      user = create!(
        oauth_sub: oauth_sub,
        email: user_data["email"],
        name: full_name,
        last_sign_in_at: Time.current,
        company_id: company.id
      )
    end

    user.ensure_company_membership(company, membership_data["role"] || "member")

    user
  end

  def ensure_company_membership(company, role = "member")
    normalized_role = role == "owner" ? "admin" : role

    membership = company_memberships.find_or_initialize_by(company: company)
    membership.role = normalized_role
    membership.save!
    membership
  end

  def initials
    name.split.map(&:first).join.upcase.first(2)
  end
end
