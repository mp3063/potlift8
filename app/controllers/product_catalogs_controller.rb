# ProductCatalogsController
#
# Manages product-catalog associations via nested RESTful routes.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Add products to catalogs (create)
# - Remove products from catalogs (destroy)
# - Turbo Stream support for dynamic updates
# - JSON API support
#
# Routes:
# - POST /products/:product_id/catalogs - Add product to catalog
# - DELETE /products/:product_id/catalogs/:id - Remove product from catalog
#
class ProductCatalogsController < ApplicationController
  before_action :set_product

  # POST /products/:product_id/catalogs
  # POST /products/:product_id/catalogs.turbo_stream
  #
  # Adds a product to a catalog.
  #
  # Parameters:
  # - catalog_id: The ID of the catalog to add the product to
  # - active: Whether the catalog item should be active (optional, defaults to false)
  # - priority: The priority of the catalog item (optional, defaults to 0)
  #
  def create
    authorize :product_catalog, :create?
    catalog_id = params[:catalog_id]
    active = params[:active] == "1"
    priority = params[:priority].to_i

    if catalog_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: "Please select a catalog." }
        format.turbo_stream { flash.now[:alert] = "Please select a catalog." }
        format.json { render json: { error: "Please select a catalog." }, status: :bad_request }
      end
      return
    end

    catalog = current_potlift_company.catalogs.find_by(id: catalog_id)

    unless catalog
      respond_to do |format|
        format.html { redirect_to @product, alert: "Catalog not found." }
        format.turbo_stream { flash.now[:alert] = "Catalog not found." }
        format.json { render json: { error: "Catalog not found." }, status: :not_found }
      end
      return
    end

    if @product.catalog_items.exists?(catalog_id: catalog.id)
      respond_to do |format|
        format.html { redirect_to @product, alert: "Product is already in #{catalog.name}." }
        format.turbo_stream { flash.now[:alert] = "Product is already in #{catalog.name}." }
        format.json { render json: { error: "Product is already in #{catalog.name}." }, status: :unprocessable_entity }
      end
      return
    end

    catalog_item = @product.catalog_items.build(
      catalog: catalog,
      catalog_item_state: active ? :active : :inactive,
      priority: priority
    )

    if catalog_item.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product added to #{catalog.name} successfully." }
        format.turbo_stream do
          flash.now[:notice] = "Product added to #{catalog.name} successfully."
          @catalog_items = @product.catalog_items.includes(:catalog, catalog_item_attribute_values: :product_attribute).reload
          @attribute_values = @product.product_attribute_values.includes(:product_attribute).index_by(&:product_attribute)
          @available_catalogs = current_potlift_company.catalogs.where.not(id: @product.catalog_ids)
        end
        format.json { render json: { success: true, message: "Product added to #{catalog.name} successfully." }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to add product to catalog: #{catalog_item.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to add product to catalog: #{catalog_item.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { success: false, error: catalog_item.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/:product_id/catalogs/:id
  # DELETE /products/:product_id/catalogs/:id.turbo_stream
  #
  # Removes a product from a catalog.
  #
  # Parameters:
  # - id: The ID of the catalog to remove the product from
  #
  def destroy
    authorize :product_catalog, :destroy?
    # Support lookup by both catalog ID and code (since Catalog uses code in to_param)
    catalog = current_potlift_company.catalogs.find_by(id: params[:id]) ||
              current_potlift_company.catalogs.find_by(code: params[:id])
    catalog_item = catalog ? @product.catalog_items.find_by(catalog_id: catalog.id) : nil

    unless catalog_item
      respond_to do |format|
        format.html { redirect_to @product, alert: "Product is not in this catalog." }
        format.turbo_stream { flash.now[:alert] = "Product is not in this catalog." }
        format.json { render json: { error: "Product is not in this catalog." }, status: :not_found }
      end
      return
    end

    catalog_name = catalog_item.catalog.name

    if catalog_item.destroy
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product removed from #{catalog_name} successfully." }
        format.turbo_stream do
          flash.now[:notice] = "Product removed from #{catalog_name} successfully."
          @catalog_items = @product.catalog_items.includes(:catalog, catalog_item_attribute_values: :product_attribute).reload
          @attribute_values = @product.product_attribute_values.includes(:product_attribute).index_by(&:product_attribute)
          @available_catalogs = current_potlift_company.catalogs.where.not(id: @product.catalog_ids)
        end
        format.json { render json: { success: true, message: "Product removed from #{catalog_name} successfully." }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to remove product from catalog: #{catalog_item.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to remove product from catalog: #{catalog_item.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
        format.json { render json: { success: false, error: catalog_item.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    end
  end

  private

  # Set the product from params
  # Ensures product belongs to current company
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end
end
