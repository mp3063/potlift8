# ProductAttribute Model
#
# Implements the EAV (Entity-Attribute-Value) pattern for flexible product attributes.
# Product attributes define the schema for dynamic product properties that can vary
# by product type and company requirements.
#
# Attribute Types (pa_type):
# - text: String/text values
# - number: Numeric values (integer)
# - boolean: True/false values
# - select: Single selection from predefined options
# - multiselect: Multiple selections from predefined options
# - date: Date values
# - rich_text: HTML/rich text content
#
# View Formats:
# - general: Plain text display
# - price: Formatted as currency (cents to euros)
# - weight: Formatted with weight units
# - html: Raw HTML display
# - ean: EAN/barcode display
# - markdown: Markdown formatted text
# - price_hash: Complex price structure in jsonb
# - external_image_list: List of external image URLs
# - special_price: Price with date range
# - customer_group_price: Different prices per customer group
# - selectable: Selectable option display
# - related_products: References to related products
#
# Scopes:
# - product_scope: Attributes for products only
# - catalog_scope: Attributes for catalog items only
# - product_and_catalog_scope: Attributes for both
#
# Validation Rules:
# Rules are stored in the jsonb 'rules' column as an array of rule names.
# Available rules (from RulesService):
# - 'positive': Value must be a positive integer
# - 'not_null': Value must not be blank
#
# Example:
#   attribute.rules = ['positive', 'not_null']
#   attribute.has_rules # => true (set automatically)
#   attribute.positive(value) # => true/false
#
class ProductAttribute < ApplicationRecord
  include RulesService

  # Associations
  belongs_to :company
  belongs_to :attribute_group, class_name: "AttributeGroup", optional: true
  has_many :product_attribute_values, dependent: :destroy
  has_many :products, through: :product_attribute_values
  has_many :catalog_item_attribute_values, dependent: :destroy

  # List ordering scoped to company and attribute_group
  # This allows independent positioning within each group or ungrouped attributes
  # Using existing attribute_position column
  acts_as_list scope: [ :company_id, :attribute_group_id ], column: :attribute_position

  # Scopes
  default_scope { order("attribute_position asc nulls last") }
  scope :all_mandatory, -> { where(mandatory: true) }
  scope :all_with_rules, -> { where(has_rules: true) }
  scope :all_mandatory_or_with_rules, -> { where(mandatory: true).or(where(has_rules: true)) }

  # Validations
  validates :code, presence: true, uniqueness: { scope: :company_id, case_sensitive: false }
  validates :name, presence: true
  validates :pa_type, presence: true
  validates :company, presence: true

  # Callbacks
  before_save :check_for_rules
  after_save :propagate_change
  after_destroy :propagate_change
  after_touch :propagate_change

  # Enums for pa_type (attribute type)
  # Maps to 7 attribute types as specified in Phase 2.3
  enum :pa_type, {
    patype_text: 1,        # String/text values
    patype_number: 2,      # Numeric values (integer)
    patype_boolean: 3,     # True/false values
    patype_select: 4,      # Single selection
    patype_multiselect: 5, # Multiple selections
    patype_date: 6,        # Date values
    patype_rich_text: 7,   # HTML/rich text content
    patype_custom: 99      # Custom types (from pot3 compatibility)
  }

  # Enums for view_format (display format)
  # Maps to 12 view formats as specified in Phase 2.3
  enum :view_format, {
    view_format_general: 0,                # Plain text display
    view_format_price: 1,                  # Currency format (cents to euros)
    view_format_weight: 2,                 # Weight with units
    view_format_html: 3,                   # Raw HTML
    view_format_ean: 4,                    # EAN/barcode
    view_format_markdown: 5,               # Markdown formatted
    view_format_price_hash: 6,             # Complex price structure
    view_format_external_image_list: 7,    # External image URLs
    view_format_special_price: 8,          # Price with date range
    view_format_customer_group_price: 9,   # Customer group prices
    view_format_selectable: 10,            # Selectable option
    view_format_related_products: 11       # Related product references
  }

  # Enums for product_attribute_scope
  # Maps to 3 scopes as specified in Phase 2.3
  enum :product_attribute_scope, {
    product_scope: 0,               # Product attributes only
    catalog_scope: 1,               # Catalog item attributes only
    product_and_catalog_scope: 3    # Both product and catalog attributes
  }

  # Use code as URL parameter instead of ID
  #
  # @return [String] The attribute code
  #
  def to_param
    code
  end

  # Get options for select/multiselect attributes
  #
  # @return [Array<String>] List of available options
  #
  def options
    info&.dig("options") || []
  end

  # Formats an attribute value for JSON API response
  #
  # Applies view_format-specific formatting to display attribute values
  # correctly in the API and frontend.
  #
  # @param av [ProductAttributeValue] The attribute value to format
  # @return [Hash] Formatted value and display representation
  #
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

  # Propagates attribute changes to associated products
  # Touches all products that use this attribute
  #
  def propagate_change
    products.each(&:touch)
  rescue ActiveRecord::RecordNotFound
    # Ignore if products have been deleted
  end

  # Sets has_rules flag based on rules presence
  # Called before_save to maintain has_rules consistency
  #
  def check_for_rules
    self.has_rules = rules.present? && rules.is_a?(Array) && rules.any?
  end
end
