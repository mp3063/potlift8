# frozen_string_literal: true

# ProductAttributesController
#
# Manages CRUD operations for ProductAttributes with support for drag-and-drop
# reordering and inline validation.
#
# Key Features:
# - Attribute grouping with drag-and-drop ordering
# - Inline code validation via JSON endpoint
# - Options management for select/multiselect types
# - Scoped to current_potlift_company
#
class ProductAttributesController < ApplicationController
  before_action :set_product_attribute, only: [ :show, :edit, :update, :destroy ]
  before_action :set_attribute_groups, only: [ :new, :edit, :create, :update ]

  # GET /product_attributes
  # Lists all attributes grouped by AttributeGroup
  def index
    authorize ProductAttribute

    @attribute_groups = current_potlift_company.attribute_groups
      .includes(:product_attributes)
      .order(:position)

    @ungrouped_attributes = current_potlift_company.product_attributes
      .where(attribute_group_id: nil)
      .order(:attribute_position)
  end

  # GET /product_attributes/:code
  def show
    authorize @product_attribute

    @attribute_values = @product_attribute.product_attribute_values
      .includes(:product)
      .order("products.name")
      .limit(50)
  end

  # GET /product_attributes/new
  def new
    authorize ProductAttribute

    @product_attribute = current_potlift_company.product_attributes.build
  end

  # GET /product_attributes/:code/edit
  def edit
    authorize @product_attribute
  end

  # POST /product_attributes
  def create
    authorize ProductAttribute

    @product_attribute = current_potlift_company.product_attributes.build(product_attribute_params)

    if @product_attribute.save
      redirect_to product_attributes_path, notice: "Attribute created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /product_attributes/:code
  def update
    authorize @product_attribute

    if @product_attribute.update(product_attribute_params)
      redirect_to product_attributes_path, notice: "Attribute updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /product_attributes/:code
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

  # PATCH /product_attributes/reorder
  # Updates attribute positions within groups
  def reorder
    authorize ProductAttribute

    params[:order].each_with_index do |id, index|
      attribute = current_potlift_company.product_attributes.find(id)
      attribute.update_column(:attribute_position, index + 1)
    end

    head :ok
  end

  # GET /product_attributes/validate_code
  # JSON endpoint for inline code validation
  def validate_code
    authorize ProductAttribute

    code = params[:code].to_s.strip
    attribute_id = params[:id]

    # Validate format (must be lowercase, no conversion)
    unless code.match?(/\A[a-z0-9_]+\z/)
      render json: { valid: false, message: "Code must contain only lowercase letters, numbers, and underscores" }
      return
    end

    # Check uniqueness within company (case-insensitive)
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
      :options,    # For JSON string from form
      :shopify_metafield_namespace,
      :shopify_metafield_key,
      :shopify_metafield_type,
      options: []  # For array from tests
    )

    # Strip immutable fields for system attributes
    if @product_attribute&.system?
      permitted.delete(:code)
      permitted.delete(:pa_type)
      permitted.delete(:view_format)
      permitted.delete(:shopify_metafield_namespace)
      permitted.delete(:shopify_metafield_key)
      permitted.delete(:shopify_metafield_type)
    end

    # Handle options - parse JSON string and store in info jsonb field
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

      # Convert to hash and add info field with options
      result = permitted.to_h
      result.delete("options")
      result["info"] = { "options" => options_array.compact_blank }
      result
    else
      permitted
    end
  end
end
