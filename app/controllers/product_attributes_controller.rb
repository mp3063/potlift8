# frozen_string_literal: true

class ProductAttributesController < ApplicationController
  before_action :set_product_attribute, only: [ :show, :edit, :update, :destroy ]
  before_action :set_attribute_groups, only: [ :new, :edit, :create, :update ]

  def index
    authorize ProductAttribute

    @attribute_groups = current_potlift_company.attribute_groups
      .includes(:product_attributes)
      .order(:position)

    @ungrouped_attributes = current_potlift_company.product_attributes
      .where(attribute_group_id: nil)
      .order(:attribute_position)
  end

  def show
    authorize @product_attribute

    @attribute_values = @product_attribute.product_attribute_values
      .includes(:product)
      .order("products.name")
      .limit(50)
  end

  def new
    authorize ProductAttribute

    @product_attribute = current_potlift_company.product_attributes.build
  end

  def edit
    authorize @product_attribute
  end

  def create
    authorize ProductAttribute

    @product_attribute = current_potlift_company.product_attributes.build(product_attribute_params)

    if @product_attribute.save
      redirect_to product_attributes_path, notice: "Attribute created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @product_attribute

    if @product_attribute.update(product_attribute_params)
      redirect_to product_attributes_path, notice: "Attribute updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product_attribute

    if @product_attribute.system?
      redirect_to product_attributes_path, alert: "System attributes cannot be deleted."
      return
    end

    if @product_attribute.product_attribute_values.any?
      redirect_to product_attributes_path, alert: "Cannot delete attribute with existing values."
    else
      @product_attribute.destroy
      redirect_to product_attributes_path, notice: "Attribute deleted successfully."
    end
  end

  def reorder
    authorize ProductAttribute

    params[:order].each_with_index do |id, index|
      attribute = current_potlift_company.product_attributes.find(id)
      attribute.update_column(:attribute_position, index + 1)
    end

    head :ok
  end

  def validate_code
    authorize ProductAttribute

    code = params[:code].to_s.strip
    attribute_id = params[:id]

    # Validate format (must be lowercase, no conversion)
    unless code.match?(/\A[a-z0-9_]+\z/)
      render json: { valid: false, message: "Code must contain only lowercase letters, numbers, and underscores" }
      return
    end

    exists = current_potlift_company.product_attributes
      .where("LOWER(code) = ?", code.downcase)
      .where.not(id: attribute_id)
      .exists?

    if exists
      render json: { valid: false, message: "Code already exists" }
    else
      render json: { valid: true }
    end
  end

  private

  def set_product_attribute
    @product_attribute = current_potlift_company.product_attributes.find_by!(code: params[:id])
  end

  def set_attribute_groups
    @attribute_groups = current_potlift_company.attribute_groups.order(:position)
  end

  def product_attribute_params
    permitted = params.require(:product_attribute).permit(
      :name,
      :code,
      :view_format,
      :attribute_group_id,
      :mandatory,
      :help_text,
      :default_value,
      :pa_type,
      :description,
      :product_attribute_scope,
      :options,
      :shopify_metafield_namespace,
      :shopify_metafield_key,
      :shopify_metafield_type,
      options: []
    )

    if @product_attribute&.system?
      permitted.delete(:code)
      permitted.delete(:pa_type)
      permitted.delete(:view_format)
      permitted.delete(:shopify_metafield_namespace)
      permitted.delete(:shopify_metafield_key)
      permitted.delete(:shopify_metafield_type)
    end

    if permitted[:options].present?
      # Options come as a JSON string from the hidden field, or as an array in tests
      options_array = if permitted[:options].is_a?(Array)
        permitted[:options]
      else
        begin
          JSON.parse(permitted[:options])
        rescue JSON::ParserError, TypeError
          []
        end
      end

      result = permitted.to_h
      result.delete("options")
      result["info"] = { "options" => options_array.compact_blank }
      result
    else
      permitted
    end
  end
end
