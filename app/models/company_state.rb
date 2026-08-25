# Constraints:
# - Company + code combination must be unique
# - Code is required
# - Company association is required
class CompanyState < ApplicationRecord
  belongs_to :company

  validates :code, presence: true
  validates :code, uniqueness: { scope: :company_id }
  validates :company_id, presence: true
end
