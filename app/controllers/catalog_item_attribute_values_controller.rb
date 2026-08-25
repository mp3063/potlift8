# Features:
# - Create catalog attribute overrides
# - Update existing overrides
# - Delete overrides (fall back to product value)
# - Turbo Stream support for dynamic updates
class CatalogItemAttributeValuesController < ApplicationController
  before_action :set_catalog_item, only: [ :create ]
  before_action :set_catalog_item_attribute_value, only: [ :update, :destroy ]

  def create
    authorize :catalog_item_attribute_value, :create?

    @product_attribute = current_potlift_company.product_attributes.find(params[:product_attribute_id])

    unless @product_attribute.catalog_scope? || @product_attribute.product_and_catalog_scope?
      respond_to do |format|
        format.html { redirect_back fallback_location: product_path(@catalog_item.product), alert: "Attribute '#{@product_attribute.name}' doesn't allow catalog-level values." }
        format.turbo_stream do
          flash.now[:alert] = "Attribute '#{@product_attribute.name}' doesn't allow catalog-level values."
          render :error, status: :unprocessable_entity
        end
      end
      return
    end

    @catalog_item_attribute_value = @catalog_item.catalog_item_attribute_values.find_or_initialize_by(
      product_attribute: @product_attribute
    )

    @catalog_item_attribute_value.value = params[:value]
    @catalog_item_attribute_value.ready = true

    if @catalog_item_attribute_value.save
      @catalog_item.reload
      @product = @catalog_item.product

      respond_to do |format|
        format.html { redirect_to product_path(@product), notice: "Attribute override created successfully." }
        format.turbo_stream { flash.now[:notice] = "Attribute override created successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: product_path(@catalog_item.product), alert: "Failed to create override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to create override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}"
          render :error, status: :unprocessable_entity
        end
      end
    end
  end

  def update
    authorize :catalog_item_attribute_value, :update?

    if @catalog_item_attribute_value.update(value: params[:value])
      @catalog_item = @catalog_item_attribute_value.catalog_item
      @catalog_item.reload
      @product = @catalog_item.product

      respond_to do |format|
        format.html { redirect_to product_path(@product), notice: "Attribute override updated successfully." }
        format.turbo_stream { flash.now[:notice] = "Attribute override updated successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: product_path(@catalog_item_attribute_value.product), alert: "Failed to update override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to update override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}"
          render :error, status: :unprocessable_entity
        end
      end
    end
  end

  # Deletes a catalog attribute override.
  # The product will fall back to using the product-level attribute value.
  def destroy
    authorize :catalog_item_attribute_value, :destroy?

    @catalog_item = @catalog_item_attribute_value.catalog_item
    @product = @catalog_item.product
    @product_attribute = @catalog_item_attribute_value.product_attribute

    if @catalog_item_attribute_value.destroy
      @catalog_item.reload

      respond_to do |format|
        format.html { redirect_to product_path(@product), notice: "Attribute override removed. Using product value." }
        format.turbo_stream { flash.now[:notice] = "Attribute override removed. Using product value." }
      end
    else
      respond_to do |format|
        format.html { redirect_back fallback_location: product_path(@product), alert: "Failed to remove override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to remove override: #{@catalog_item_attribute_value.errors.full_messages.join(', ')}"
          render :error, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_catalog_item
    catalog_item_id = params[:catalog_item_id]

    @catalog_item = CatalogItem.joins(:catalog)
                               .where(catalogs: { company_id: current_potlift_company.id })
                               .find(catalog_item_id)
  end

  def set_catalog_item_attribute_value
    @catalog_item_attribute_value = CatalogItemAttributeValue.joins(catalog_item: :catalog)
                                                              .where(catalogs: { company_id: current_potlift_company.id })
                                                              .find(params[:id])
  end
end
