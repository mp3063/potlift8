# Label Model
#
# Represents a hierarchical categorization system for products.
# Labels can have parent-child relationships forming a tree structure.
#
# Attributes:
# - company_id: References the owning company (multi-tenancy)
# - label_type: Category type (e.g., 'category', 'tag', 'brand')
# - code: Short identifier within parent context
# - full_code: Complete hierarchical path (e.g., "electronics-phones-iphone")
# - name: Display name
# - full_name: Complete hierarchical name (e.g., "Electronics > Phones > iPhone")
# - description: Optional description
# - info: JSONB field for additional metadata and localized values
# - parent_label_id: Reference to parent label (self-referential)
# - label_positions: Integer for ordering labels within the same parent
# - product_default_restriction: Enum for product association rules
#
# Tree Structure:
# - Root labels have parent_label_id = nil
# - Child labels reference their parent via parent_label_id
# - full_code and full_name are auto-generated on save
# - full_code uses "-" separator: parent-child
# - full_name uses " > " separator: Parent > Child
#
# Example:
#   root = Label.create(company: company, code: 'electronics', name: 'Electronics', label_type: 'category')
#   child = Label.create(company: company, code: 'phones', name: 'Phones', label_type: 'category', parent_label: root)
#   # child.full_code => "electronics-phones"
#   # child.full_name => "Electronics > Phones"
#
class Label < ApplicationRecord
  # Associations
  belongs_to :company
  belongs_to :parent_label, class_name: 'Label', optional: true
  has_many :sublabels, class_name: 'Label', foreign_key: 'parent_label_id', dependent: :destroy
  has_many :product_labels, dependent: :destroy
  has_many :products, through: :product_labels

  # Validations
  validates :code, presence: true
  validates :name, presence: true
  validates :label_type, presence: true
  validates :full_code, uniqueness: { scope: :company_id }

  # Callbacks
  before_validation :inherit_company_from_parent, on: :create
  before_save :generate_full_code_and_name

  # Scopes
  default_scope { order("label_positions asc nulls last, id asc") }
  scope :root_labels, -> { where(parent_label_id: nil) }
  scope :without_parents, -> { where(parent_label_id: nil) }

  # Enum for product association restrictions
  enum :product_default_restriction, {
    allow: 1,
    deny: 2
  }, prefix: true

  # Returns true if this is a root label (no parent)
  def root_label?
    parent_label_id.nil?
  end

  alias_method :is_root_label?, :root_label?

  # Returns all ancestor labels from root to immediate parent
  # @return [Array<Label>] Array of ancestor labels
  def ancestors
    return [] if root_label?

    ancestors = []
    current = parent_label
    while current
      ancestors.unshift(current)
      current = current.parent_label
    end
    ancestors
  end

  # Returns all descendant labels (children, grandchildren, etc.)
  # @return [Array<Label>] Array of all descendant labels
  def descendants
    sublabels.flat_map { |sublabel| [sublabel] + sublabel.descendants }
  end

  # Returns all products including those from sublabels
  # @return [Array<Product>] Array of unique products
  def all_products_including_sublabels
    (sublabels.flat_map(&:all_products_including_sublabels) + products.to_a).flatten.uniq
  end

  # Updates label and recursively updates all children
  # This ensures full_code and full_name cascade down the tree
  def update_label_and_children
    save!
    sublabels.each(&:update_label_and_children)
  end

  # Reorders sublabels based on provided position hash
  # @param new_order [Hash] Hash mapping full_code to new position
  # @return [Boolean] true if successful, false otherwise
  def reorder_positions(new_order)
    Label.transaction do
      sublabels.each do |sublabel|
        if new_order[sublabel.full_code].present?
          sublabel.label_positions = new_order[sublabel.full_code]
          raise ActiveRecord::Rollback unless sublabel.save
        end
      end
      reload if persisted?
      return true
    end
    reload if persisted?
    false
  end

  # Returns unique label types for a company
  # @param company [Company] The company to query
  # @return [Array<String>] Array of unique label types
  def self.label_types(company)
    company.labels.pluck(:label_type).uniq
  end

  # Use full_code as URL parameter
  def to_param
    full_code
  end

  # Custom as_json for API serialization
  def as_json(options = {})
    result = super(options)

    if options[:include_related_objects_for_catalog].present?
      result.delete('parent_label_id')
      result['localized_value'] = info.to_h['localized_value']
      result['localized_full_value'] = info.to_h['localized_full_value']
      result['parent_label'] = parent_label&.as_json(options)
    end

    result
  end

  private

  # Inherit company from parent label if parent is present
  def inherit_company_from_parent
    self.company = parent_label.company if parent_label_id.present? && parent_label.present?
  end

  # Generate full_code and full_name based on hierarchy
  # full_code: Uses "-" as separator (e.g., "parent-child")
  # full_name: Uses " > " as separator (e.g., "Parent > Child")
  # Also handles localized values in info JSONB field
  def generate_full_code_and_name
    self.info ||= {}

    if parent_label_id.present? && parent_label.present?
      # Child label: prepend parent's full values
      self.full_code = "#{parent_label.full_code}-#{code}"
      self.full_name = "#{parent_label.full_name} > #{name}"

      # Handle localized values
      localized_values = info.to_h['localized_value'].to_a
      parent_localized = parent_label.info.to_h['localized_value'].to_a

      (localized_values + parent_localized).uniq.each do |key, _value|
        self.info['localized_full_value'] ||= {}
        parent_full_value = parent_label.info.to_h['localized_full_value'].to_h[key].presence || parent_label.full_name
        child_value = info.to_h['localized_value'].to_h[key].presence || name
        self.info['localized_full_value'][key] = "#{parent_full_value} > #{child_value}"
      end
    else
      # Root label: use code and name as-is
      self.full_code = code
      self.full_name = name

      # Copy localized_value to localized_full_value for root labels
      if info.to_h['localized_value'].present?
        self.info['localized_full_value'] = info['localized_value'].dup
      end
    end
  end
end
