# ProductAttributeValuesController
#
# Manages inline editing of product attribute values.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Update attribute values via PATCH request
# - Type-aware value handling (text, number, boolean, select, etc.)
# - Turbo Stream support for dynamic UI updates
# - Validation with error feedback
#
# Routes:
# - PATCH /products/:product_id/attribute_values/:attribute_id - Update attribute value
#
class ProductAttributeValuesController < ApplicationController
  before_action :set_product
  before_action :set_attribute

  # PATCH /products/:product_id/attribute_values/:attribute_id
  # PATCH /products/:product_id/attribute_values/:attribute_id.turbo_stream
  #
  # Updates a product attribute value with inline editing.
  #
  # Parameters:
  # - value: The new value for the attribute
  # - unit: Optional unit for weight/dimension attributes
  #
  def update
    value = params[:value]

    # Handle different attribute types
    processed_value = process_attribute_value(value)

    # Find or create the product attribute value
    @product_attribute_value = @product.product_attribute_values
                                       .find_or_initialize_by(product_attribute: @attribute)

    # Update the value
    @product_attribute_value.value = processed_value

    # Handle additional fields (e.g., unit for weight attributes)
    if params[:unit].present?
      @product_attribute_value.info ||= {}
      @product_attribute_value.info['unit'] = params[:unit]
    end

    if @product_attribute_value.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "#{@attribute.name} updated successfully." }
        format.turbo_stream do
          flash.now[:notice] = "#{@attribute.name} updated successfully."
          # Re-fetch the value to ensure we have the latest data
          @value = @product.product_attribute_values.find_by(product_attribute: @attribute)
          render turbo_stream: [
            turbo_stream.replace(
              "#{helpers.dom_id(@attribute, :value)}",
              partial: 'products/attribute_value',
              locals: { attribute: @attribute, value: @value, product: @product }
            ),
            turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
          ]
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to @product, alert: "Failed to update #{@attribute.name}: #{@product_attribute_value.errors.full_messages.join(', ')}"
        end
        format.turbo_stream do
          flash.now[:alert] = "Failed to update #{@attribute.name}: #{@product_attribute_value.errors.full_messages.join(', ')}"
          render turbo_stream: turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash }),
                 status: :unprocessable_entity
        end
      end
    end
  end

  private

  # Set the product from params
  # Ensures product belongs to current company
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  # Set the product attribute from params
  # Ensures attribute belongs to current company
  # Note: ProductAttribute uses 'code' as URL parameter (via to_param)
  def set_attribute
    @attribute = current_potlift_company.product_attributes.find_by!(code: params[:attribute_id])
  end

  # Process attribute value based on attribute type
  #
  # @param value [String] The raw value from the form
  # @return [String] The processed value
  #
  def process_attribute_value(value)
    return nil if value.blank?

    # Handle boolean pa_type specially
    if @attribute.pa_type == 'patype_boolean'
      # Convert checkbox values to boolean string
      return ActiveModel::Type::Boolean.new.cast(value).to_s
    end

    # Handle different attribute view formats (using enum symbols)
    case @attribute.view_format.to_sym
    when :view_format_general, :view_format_ean, :view_format_markdown
      # General text value
      value.to_s.strip
    when :view_format_price, :view_format_weight
      # Ensure numeric values are properly formatted
      value.to_s.strip
    when :view_format_selectable
      # Validate against allowed options
      options = @attribute.info&.dig('options') || []
      if options.present? && !options.include?(value)
        return options.first
      end
      value.to_s
    when :view_format_html, :view_format_price_hash, :view_format_external_image_list,
         :view_format_special_price, :view_format_customer_group_price, :view_format_related_products
      # Complex types - store as-is (may need JSON handling in future)
      value.to_s.strip
    else
      # Default: text value
      value.to_s.strip
    end
  end
end
