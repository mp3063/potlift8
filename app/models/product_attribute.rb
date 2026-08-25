# Validation Rules:
# Rules are stored in the jsonb 'rules' column as an array of rule names.
# Available rules (from RulesService):
# - 'positive': Value must be a positive integer
# - 'not_null': Value must not be blank
class ProductAttribute < ApplicationRecord
  include RulesService
  include SystemAttributes

  SHOPIFY_METAFIELD_TYPE_MAP = {
    "patype_text" => "single_line_text_field",
    "patype_number" => "number_decimal",
    "patype_boolean" => "boolean",
    "patype_select" => "single_line_text_field",
    "patype_multiselect" => "list.single_line_text_field",
    "patype_date" => "date",
    "patype_rich_text" => "multi_line_text_field",
    "patype_custom" => "json"
  }.freeze

  belongs_to :company
  belongs_to :attribute_group, class_name: "AttributeGroup", optional: true
  has_many :product_attribute_values, dependent: :destroy
  has_many :products, through: :product_attribute_values
  has_many :catalog_item_attribute_values, dependent: :destroy

  acts_as_list scope: [ :company_id, :attribute_group_id ], column: :attribute_position

  default_scope { order("attribute_position asc nulls last") }
  scope :all_mandatory, -> { where(mandatory: true) }
  scope :all_with_rules, -> { where(has_rules: true) }
  scope :all_mandatory_or_with_rules, -> { where(mandatory: true).or(where(has_rules: true)) }

  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true
  validates :pa_type, presence: true
  validates :company, presence: true
  validate :immutable_system_fields, if: :system?

  before_destroy :prevent_system_destroy

  before_save :check_for_rules
  after_save :propagate_change
  after_destroy :propagate_change
  after_touch :propagate_change

  enum :pa_type, {
    patype_text: 1,
    patype_number: 2,
    patype_boolean: 3,
    patype_select: 4,
    patype_multiselect: 5,
    patype_date: 6,
    patype_rich_text: 7,
    patype_custom: 99      # Custom types (from pot3 compatibility)
  }

  enum :view_format, {
    view_format_general: 0,
    view_format_price: 1,
    view_format_weight: 2,
    view_format_html: 3,
    view_format_ean: 4,
    view_format_markdown: 5,
    view_format_price_hash: 6,
    view_format_external_image_list: 7,
    view_format_special_price: 8,
    view_format_customer_group_price: 9,
    view_format_selectable: 10,
    view_format_related_products: 11
  }

  enum :product_attribute_scope, {
    product_scope: 0,
    catalog_scope: 1,
    product_and_catalog_scope: 3
  }

  # Use code as URL parameter instead of ID
  def to_param
    code
  end

  def options
    info&.dig("options") || []
  end

  def avjson(av)
    case view_format.to_sym
    when :view_format_general
      {
        value: av.value,
        display: av.value,
        localized_value: av.info.to_h["localized_value"],
        localized_display: av.info.to_h["localized_value"]
      }

    when :view_format_ean, :view_format_selectable
      {
        value: av.value,
        display: av.value
      }

    when :view_format_price
      {
        value: av.value,
        display: ActionController::Base.helpers.number_to_currency(
          (av.value.to_i.to_f / 100),
          unit: "€", separator: ",", delimiter: " ", format: "%n %u"
        )
      }

    when :view_format_weight
      {
        value: av.value,
        display: ActionController::Base.helpers.number_to_human(
          av.value.to_i,
          units: :weight,
          separator: ","
        )
      }

    when :view_format_html
      {
        value: av.value,
        display: av.value,
        localized_value: av.info.to_h["localized_value"],
        localized_display: av.info.to_h["localized_value"]
      }

    when :view_format_external_image_list
      raise NotImplementedError, "External image list format not yet implemented"

    when :view_format_customer_group_price
      {
        value: av.info.to_h["customer_group_prices"].to_h,
        display: av.info.to_h["customer_group_prices"].to_h.keys.sum("") do |customer_group_key|
          price = ActionController::Base.helpers.number_to_currency(
            (av.info.to_h["customer_group_prices"].to_h[customer_group_key].to_f / 100),
            unit: "€", separator: ",", delimiter: " ", format: "%n %u"
          )
          "<strong>#{customer_group_key.gsub('customer_group_', '')}: </strong><span>#{price}</span>"
        end
      }

    when :view_format_special_price
      price = ActionController::Base.helpers.number_to_currency(
        (av.info.to_h["special_price"].to_h["amount"].to_f / 100),
        unit: "€", separator: ",", delimiter: " ", format: "%n %u"
      )
      {
        value: av.info.to_h["special_price"].to_h,
        display: "#{price} (#{av.info.to_h['special_price'].to_h['from']} - #{av.info.to_h['special_price'].to_h['until']})"
      }

    when :view_format_related_products
      {
        value: av.info.to_h["related_products"].to_a,
        display: av.info.to_h["related_products"].to_a
      }

    when :view_format_markdown
      {
        value: av.value,
        display: ApplicationController.helpers.markdown_safe(av.value || ""),
        localized_value: av.info.to_h["localized_value"],
        localized_display: av.info.to_h["localized_value"].to_h.transform_values { |v|
          ApplicationController.helpers.markdown_safe(v || "")
        }
      }

    else
      raise ArgumentError, "Unknown view format: #{view_format}"
    end.stringify_keys
  end

  private

  def immutable_system_fields
    if persisted?
      errors.add(:code, "cannot be changed for system attributes") if code_changed?
      errors.add(:pa_type, "cannot be changed for system attributes") if pa_type_changed?
      errors.add(:view_format, "cannot be changed for system attributes") if view_format_changed?
    end
  end

  def prevent_system_destroy
    # Allow destroy to cascade when the parent Company is being destroyed —
    # otherwise `dependent: :destroy` on Company#product_attributes would
    # abort the whole transaction and leak a half-deleted company.
    return if destroyed_by_association

    if system?
      errors.add(:base, "System attributes cannot be deleted")
      throw(:abort)
    end
  end

  def propagate_change
    products.each(&:touch)
  rescue ActiveRecord::RecordNotFound
  end

  def check_for_rules
    self.has_rules = rules.present? && rules.is_a?(Array) && rules.any?
  end
end
