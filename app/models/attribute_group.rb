# AttributeGroup Model
#
# Organizes ProductAttributes into logical groups for better organization and UI presentation.
# Used in the EAV (Entity-Attribute-Value) pattern to categorize product attributes.
#
# Example groups:
# - "basic_info" - Basic product information (name, description, etc.)
# - "pricing" - Price-related attributes
# - "dimensions" - Size, weight, and measurement attributes
# - "technical" - Technical specifications
#
# Attributes:
# - company_id: The company this group belongs to
# - name: Human-readable group name (e.g., "Basic Information")
# - code: Unique identifier within company (e.g., "basic_info")
# - description: Optional description of the group's purpose
# - position: Display order (managed by acts_as_list)
# - info: JSONB field for additional metadata
#
# Associations:
# - belongs_to :company
# - has_many :product_attributes
#
# Usage:
#   group = AttributeGroup.create(
#     company: company,
#     code: 'pricing',
#     name: 'Pricing Information',
#     description: 'All price-related attributes'
#   )
#
#   # Attributes are automatically ordered by position
#   group.product_attributes # => [price, special_price, customer_group_price]
#
#   # Reordering groups
#   group.move_to_top
#   group.move_lower
#
class AttributeGroup < ApplicationRecord
  # Associations
  belongs_to :company
  has_many :product_attributes, dependent: :nullify

  # List ordering scoped to company
  acts_as_list scope: :company_id

  # Validations
  validates :name, presence: true
  validates :code, presence: true,
                   uniqueness: { scope: :company_id, case_sensitive: false },
                   format: {
                     with: /\A[a-z0-9_]+\z/,
                     message: "only allows lowercase letters, numbers, and underscores"
                   }
  validates :company, presence: true

  # Use code as URL parameter instead of ID
  #
  # @return [String] The group code
  #
  def to_param
    code
  end
end
