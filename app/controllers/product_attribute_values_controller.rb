class ProductAttributeValuesController < ApplicationController
  before_action :set_product
  before_action :set_attribute

  def update
    authorize :product_attribute_value, :update?
    value = params[:value]

    begin
      processed_value = process_attribute_value(value)
    rescue Cents::InvalidAmount => e
      return respond_with_failure(e.message)
    end

    @product_attribute_value = @product.product_attribute_values
                                       .find_or_initialize_by(product_attribute: @attribute)

    @product_attribute_value.value = processed_value
    sync_special_price_amount(processed_value) if @attribute.view_format_special_price?

    if params[:unit].present?
      @product_attribute_value.info ||= {}
      @product_attribute_value.info["unit"] = params[:unit]
    end

    if @product_attribute_value.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "#{@attribute.name} updated successfully." }
        format.turbo_stream do
          flash.now[:notice] = "#{@attribute.name} updated successfully."
          @value = @product.product_attribute_values.find_by(product_attribute: @attribute)
          render turbo_stream: [
            turbo_stream.replace(
              "#{helpers.dom_id(@attribute, :value)}",
              partial: "products/attribute_value",
              locals: { attribute: @attribute, value: @value, product: @product }
            ),
            turbo_stream.update("flash", partial: "shared/flash", locals: { flash: flash })
          ]
        end
      end
    else
      respond_with_failure(@product_attribute_value.errors.full_messages.join(", "))
    end
  end

  private

  def respond_with_failure(reason)
    message = "Failed to update #{@attribute.name}: #{reason}"
    respond_to do |format|
      format.html { redirect_to @product, alert: message }
      format.turbo_stream do
        flash.now[:alert] = message
        render turbo_stream: turbo_stream.update("flash", partial: "shared/flash", locals: { flash: flash }),
               status: :unprocessable_entity
      end
    end
  end

  # The value getter reads a special price's amount from info when a date range exists,
  # so keep that amount in step with the column (and drop the range when cleared).
  def sync_special_price_amount(cents)
    return unless @product_attribute_value.info.to_h["special_price"].present?

    if cents.nil?
      @product_attribute_value.info.delete("special_price")
    else
      @product_attribute_value.info["special_price"]["amount"] = cents
    end
  end

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  # Set the product attribute from params
  # Ensures attribute belongs to current company
  # Note: ProductAttribute uses 'code' as URL parameter (via to_param)
  def set_attribute
    @attribute = current_potlift_company.product_attributes.find_by!(code: params[:attribute_id])
  end

  def process_attribute_value(value)
    return nil if value.blank?

    if @attribute.pa_type == "patype_boolean"
      return ActiveModel::Type::Boolean.new.cast(value).to_s
    end

    case @attribute.view_format.to_sym
    when :view_format_general, :view_format_ean, :view_format_markdown
      value.to_s.strip
    when :view_format_price, :view_format_special_price
      Cents.parse(value).to_s
    when :view_format_weight
      value.to_s.strip
    when :view_format_selectable
      options = @attribute.info&.dig("options") || []
      if options.present? && !options.include?(value)
        return options.first
      end
      value.to_s
    when :view_format_html, :view_format_price_hash, :view_format_external_image_list,
         :view_format_customer_group_price, :view_format_related_products
      value.to_s.strip
    else
      value.to_s.strip
    end
  end
end
