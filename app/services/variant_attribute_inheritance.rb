# Copies the superproduct's values for attributes flagged subproduct_mandatory into a variant,
# as pot3's add_mandatory_attributes did: parent value if present, else the attribute default.
# Never overwrites a value the variant already has, so it is safe to run repeatedly.
class VariantAttributeInheritance
  def initialize(superproduct:, subproduct:)
    @superproduct = superproduct
    @subproduct = subproduct
  end

  # Returns the number of attribute values created.
  def call
    @superproduct.company.product_attributes.where(subproduct_mandatory: true).count do |attribute|
      next false if @subproduct.product_attribute_values.exists?(product_attribute: attribute)

      parent_value = @superproduct.product_attribute_values.find_by(product_attribute: attribute)
      value = parent_value&.value.presence || attribute.default_value
      next false if value.blank?

      @subproduct.product_attribute_values.create!(
        product_attribute: attribute,
        value: value,
        info: parent_value&.value.present? ? parent_value.info : {}
      )
      true
    end
  end
end
