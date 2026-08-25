class AttributeGroup < ApplicationRecord
  belongs_to :company
  has_many :product_attributes, dependent: :nullify

  acts_as_list scope: :company_id

  validates :name, presence: true
  validates :code, presence: true,
                   uniqueness: { scope: :company_id, case_sensitive: false },
                   format: {
                     with: /\A[a-z0-9_]+\z/,
                     message: "only allows lowercase letters, numbers, and underscores"
                   }
  validates :company, presence: true

  # Use code as URL parameter instead of ID
  def to_param
    code
  end
end
