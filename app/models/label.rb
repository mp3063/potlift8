class Label < ApplicationRecord
  belongs_to :company
  belongs_to :parent_label, class_name: "Label", optional: true
  has_many :sublabels, class_name: "Label", foreign_key: "parent_label_id", dependent: :destroy
  has_many :product_labels, dependent: :destroy
  has_many :products, through: :product_labels

  validates :code, presence: true
  validates :name, presence: true
  validates :label_type, presence: true
  validates :full_code, uniqueness: { scope: :company_id }
  validate :validate_color_format

  before_validation :inherit_company_from_parent, on: :create
  before_validation :generate_code_from_name, if: -> { code.blank? && name.present? }
  before_save :generate_full_code_and_name

  default_scope { order("label_positions asc nulls last, labels.id asc") }
  scope :root_labels, -> { where(parent_label_id: nil) }
  scope :without_parents, -> { where(parent_label_id: nil) }

  # Eager load sublabels recursively up to 3 levels deep to prevent N+1 queries
  # This is used in the index view where we render a tree with product counts
  scope :with_sublabels_tree, -> {
    includes(
      :products,
      sublabels: [
        :products,
        sublabels: [
          :products,
          :sublabels
        ]
      ]
    )
  }

  enum :product_default_restriction, {
    allow: 1,
    deny: 2
  }, prefix: true

  def root_label?
    parent_label_id.nil?
  end

  alias_method :is_root_label?, :root_label?

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

  def descendants
    sublabels.flat_map { |sublabel| [ sublabel ] + sublabel.descendants }
  end

  def all_products_including_sublabels
    (sublabels.flat_map(&:all_products_including_sublabels) + products.to_a).flatten.uniq
  end

  def update_label_and_children
    save!
    sublabels.each(&:update_label_and_children)
  end

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

  def self.label_types(company)
    company.labels.pluck(:label_type).uniq
  end

  def to_param
    full_code
  end

  def as_json(options = {})
    result = super(options)

    if options[:include_related_objects_for_catalog].present?
      result.delete("parent_label_id")
      result["localized_value"] = info.to_h["localized_value"]
      result["localized_full_value"] = info.to_h["localized_full_value"]
      result["parent_label"] = parent_label&.as_json(options)
    end

    result
  end

  private

  # Validate color format to prevent CSS injection
  # Only allows valid hex colors (#RGB or #RRGGBB)
  def validate_color_format
    return if info.blank? || info["color"].blank?

    color = info["color"].to_s.strip
    unless color.match?(/\A#(?:[0-9a-fA-F]{3}){1,2}\z/)
      errors.add(:base, "Color must be a valid hex color (e.g., #fff or #ffffff)")
    end
  end

  def inherit_company_from_parent
    self.company = parent_label.company if parent_label_id.present? && parent_label.present?
  end

  def generate_full_code_and_name
    self.info ||= {}

    if parent_label_id.present? && parent_label.present?
      self.full_code = "#{parent_label.full_code}-#{code}"
      self.full_name = "#{parent_label.full_name} > #{name}"

      localized_values = info.to_h["localized_value"].to_a
      parent_localized = parent_label.info.to_h["localized_value"].to_a

      (localized_values + parent_localized).uniq.each do |key, _value|
        self.info["localized_full_value"] ||= {}
        parent_full_value = parent_label.info.to_h["localized_full_value"].to_h[key].presence || parent_label.full_name
        child_value = info.to_h["localized_value"].to_h[key].presence || name
        self.info["localized_full_value"][key] = "#{parent_full_value} > #{child_value}"
      end
    else
      self.full_code = code
      self.full_name = name

      if info.to_h["localized_value"].present?
        self.info["localized_full_value"] = info["localized_value"].dup
      end
    end
  end

  def generate_code_from_name
    return if name.blank?

    self.code = name.parameterize
  end
end
