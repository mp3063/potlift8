# CatalogItemsController
#
# Manages catalog items (product-catalog associations).
# Handles adding and removing products from catalogs.
#
# Features:
# - Add single or multiple products to catalog
# - Remove products from catalog
# - Turbo Stream support for dynamic updates
#
class CatalogItemsController < ApplicationController
  before_action :set_catalog

  # GET /catalogs/:code/products/new
  # GET /catalogs/:code/products/new.turbo_stream
  #
  # Shows modal for adding products to catalog.
  # Lists products not currently in the catalog with search and filters.
  #
  # Query Parameters:
  # - q: Search query (matches product name or SKU)
  # - product_type: Filter by product type (sellable, configurable, bundle)
  # - status: Filter by product status (active, draft, etc.)
  # - page: Page number for pagination
  #
  def new
    # Get products not currently in this catalog
    existing_product_ids = @catalog.catalog_items.pluck(:product_id)
    @products = current_potlift_company.products
                                       .where.not(id: existing_product_ids)
                                       .with_attributes
                                       .with_labels
                                       .order(:sku)

    # Apply filters
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @products = @products.where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
    end

    if params[:product_type].present?
      @products = @products.where(product_type: params[:product_type])
    end

    if params[:status].present?
      @products = @products.where(product_status: params[:status])
    end

    @pagy, @products = pagy(@products, items: 15)

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  # POST /catalogs/:code/products
  # POST /catalogs/:code/products.turbo_stream
  #
  # Adds one or more products to the catalog.
  #
  # Parameters:
  # - product_ids: Array of product IDs to add to catalog
  # - catalog_item_state: Initial state for added items (default: active)
  #
  def create
    product_ids = Array(params[:product_ids])

    if product_ids.blank?
      redirect_to catalog_items_path(@catalog), alert: 'No products selected.'
      return
    end

    added_count = 0
    errors = []

    ActiveRecord::Base.transaction do
      product_ids.each do |product_id|
        product = current_potlift_company.products.find_by(id: product_id)
        next unless product

        # Skip if already in catalog
        next if @catalog.catalog_items.exists?(product_id: product.id)

        catalog_item = @catalog.catalog_items.build(
          product: product,
          catalog_item_state: params[:catalog_item_state] || 'active',
          priority: @catalog.catalog_items.maximum(:priority).to_i + 1
        )

        if catalog_item.save
          added_count += 1
        else
          errors << "#{product.sku}: #{catalog_item.errors.full_messages.join(', ')}"
        end
      end
    end

    message = if added_count > 0
                "Successfully added #{added_count} product#{'s' if added_count != 1} to catalog."
              else
                "No products were added to the catalog."
              end

    message += " Errors: #{errors.join('; ')}" if errors.any?

    # Always redirect with HTML response - Turbo will follow the redirect
    redirect_to catalog_items_path(@catalog), notice: message
  end

  # DELETE /catalogs/:code/items/:id
  # DELETE /catalogs/:code/items/:id.turbo_stream
  #
  # Removes a product from the catalog.
  # Deletes the catalog_item association.
  #
  # Parameters:
  # - id: Product ID (not catalog_item ID)
  #
  def destroy
    product = current_potlift_company.products.find(params[:id])
    catalog_item = @catalog.catalog_items.find_by(product: product)

    if catalog_item.nil?
      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), alert: 'Product not found in catalog.' }
        format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', partial: 'shared/flash', locals: { flash: { alert: 'Product not found in catalog.' } }) }
      end
      return
    end

    catalog_item.destroy

    respond_to do |format|
      format.html do
        redirect_to catalog_items_path(@catalog), notice: 'Product removed from catalog.'
      end

      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("catalog_item_#{catalog_item.id}"),
          turbo_stream.prepend('flash', partial: 'shared/flash', locals: { flash: { notice: 'Product removed from catalog.' } })
        ]
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to catalog_items_path(@catalog), alert: 'Product not found.' }
      format.turbo_stream { render turbo_stream: turbo_stream.replace('flash', partial: 'shared/flash', locals: { flash: { alert: 'Product not found.' } }) }
    end
  end

  private

  # Set the catalog for all actions
  # Uses catalog 'catalog_code' as URL parameter (from nested routes)
  # Ensures catalog belongs to current company
  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:catalog_code])
  end
end
