# Products Controller
#
# Manages CRUD operations for products in the Potlift8 inventory system.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Full CRUD operations (index, show, new, create, edit, update, destroy)
# - Product duplication (create copy with attribute values and labels)
# - Bulk operations (bulk_destroy, bulk_update_labels)
# - Sorting by SKU, name, created_at, updated_at
# - Filtering by product type, labels, and search query
# - Pagination with Pagy (25 items per page by default)
# - CSV export with applied filters
# - AJAX SKU validation
# - Turbo Stream support for dynamic updates
#
class ProductsController < ApplicationController
  before_action :set_product, only: [:show, :edit, :update, :destroy, :duplicate]

  # GET /products
  # GET /products.turbo_stream
  # GET /products.csv
  #
  # Lists products with pagination, sorting, and filtering.
  #
  # Query Parameters:
  # - page: Page number (default: 1)
  # - per_page: Items per page (default: 25)
  # - sort: Sort column (sku, name, created_at, updated_at)
  # - direction: Sort direction (asc, desc)
  # - type: Filter by product_type (sellable, configurable, bundle)
  # - label_id: Filter by label ID
  # - q: Search query (matches name or SKU)
  #
  def index
    @products = current_potlift_company.products
                                       .includes(:labels, :inventories)

    # Apply filtering
    @products = apply_filters(@products)

    # Apply sorting
    @products = @products.order(sort_column => sort_direction)

    respond_to do |format|
      format.html do
        @pagy, @products = pagy(@products, items: params[:per_page] || 25)
      end

      format.turbo_stream do
        @pagy, @products = pagy(@products, items: params[:per_page] || 25)
      end

      format.csv do
        # For CSV export, we don't paginate - export all filtered results
        send_csv_export(@products)
      end
    end
  end

  # GET /products/:id
  #
  # Shows detailed product information.
  #
  def show
    @attribute_values = @product.product_attribute_values
                                .includes(:product_attribute)
                                .order('product_attributes.code')
  end

  # GET /products/new
  #
  # Renders form for creating a new product.
  #
  def new
    @product = current_potlift_company.products.build
  end

  # GET /products/:id/edit
  #
  # Renders form for editing an existing product.
  #
  def edit
  end

  # POST /products
  # POST /products.turbo_stream
  #
  # Creates a new product.
  #
  def create
    @product = current_potlift_company.products.build(product_params)

    if @product.save
      respond_to do |format|
        format.html { redirect_to products_path, notice: 'Product created successfully.' }
        format.turbo_stream { flash.now[:notice] = 'Product created successfully.' }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /products/:id
  # PUT /products/:id
  # PATCH /products/:id.turbo_stream
  #
  # Updates an existing product.
  #
  def update
    if @product.update(product_params)
      respond_to do |format|
        format.html { redirect_to products_path, notice: 'Product updated successfully.' }
        format.turbo_stream { flash.now[:notice] = 'Product updated successfully.' }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/:id
  # DELETE /products/:id.turbo_stream
  #
  # Destroys a product.
  #
  def destroy
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_path, notice: 'Product deleted successfully.' }
      format.turbo_stream { flash.now[:notice] = 'Product deleted successfully.' }
    end
  end

  # POST /products/:id/duplicate
  #
  # Duplicates a product with all attribute values and labels.
  # Redirects to edit page for the new product.
  #
  def duplicate
    new_product = @product.duplicate!

    redirect_to edit_product_path(new_product), notice: "Product duplicated as #{new_product.sku}"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to products_path, alert: "Failed to duplicate product: #{e.message}"
  end

  # POST /products/bulk_destroy
  #
  # Bulk deletes multiple products.
  #
  # Parameters:
  # - product_ids: Array of product IDs to delete
  #
  def bulk_destroy
    product_ids = params[:product_ids] || []

    if product_ids.empty?
      redirect_to products_path, alert: 'No products selected.'
      return
    end

    # Eager load associations to prevent N+1 queries during destroy callbacks
    products = current_potlift_company.products.where(id: product_ids).includes(:product_attribute_values, :labels)
    count = products.destroy_all.size

    redirect_to products_path, notice: "#{count} product(s) deleted successfully."
  end

  # POST /products/bulk_update_labels
  #
  # Bulk updates labels for multiple products.
  #
  # Parameters:
  # - product_ids: Array of product IDs to update
  # - label_ids: Array of label IDs to assign
  #
  def bulk_update_labels
    product_ids = params[:product_ids] || []
    label_ids = params[:label_ids] || []

    if product_ids.empty?
      redirect_to products_path, alert: 'No products selected.'
      return
    end

    count = 0
    current_potlift_company.products.where(id: product_ids).includes(:labels).find_each do |product|
      product.label_ids = label_ids
      count += 1
    end

    redirect_to products_path, notice: "Labels updated for #{count} product(s)."
  end

  # GET /products/validate_sku?sku=ABC123
  #
  # AJAX endpoint for validating SKU uniqueness.
  #
  # Returns JSON:
  # - { valid: true } if SKU is available
  # - { valid: false, message: "..." } if SKU is taken
  #
  def validate_sku
    sku = params[:sku]

    if sku.blank?
      render json: { valid: false, message: 'SKU cannot be blank' }
      return
    end

    # Normalize SKU (same as Product#normalize_sku)
    normalized_sku = sku.to_s.strip.upcase

    # Check if SKU exists, excluding the current product if editing
    existing = current_potlift_company.products.where(sku: normalized_sku)
    existing = existing.where.not(id: params[:product_id]) if params[:product_id].present?

    if existing.exists?
      render json: { valid: false, message: 'SKU already exists' }
    else
      render json: { valid: true }
    end
  end

  private

  # Set the product for show, edit, update, destroy, duplicate actions
  # Ensures product belongs to current company
  # Raises ActiveRecord::RecordNotFound if product not found or doesn't belong to company
  def set_product
    @product = current_potlift_company.products.find(params[:id])
  end

  # Strong parameters for product creation/update
  def product_params
    params.require(:product).permit(
      :sku,
      :name,
      :description,
      :product_type,
      :configuration_type,
      :product_status,
      :ean,
      :active,
      label_ids: []
    )
  end

  # Apply filters to products query
  #
  # @param products [ActiveRecord::Relation] The products relation
  # @return [ActiveRecord::Relation] Filtered products relation
  #
  def apply_filters(products)
    # Filter by product type
    if params[:type].present? && Product.product_types.key?(params[:type])
      products = products.where(product_type: params[:type])
    end

    # Filter by label
    if params[:label_id].present?
      products = products.joins(:labels).where(labels: { id: params[:label_id] })
    end

    # Search by name or SKU
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      products = products.where("name ILIKE ? OR sku ILIKE ?", search_term, search_term)
    end

    products
  end

  # Get sort column from params
  # Defaults to created_at if invalid or not provided
  #
  # @return [String] The column to sort by
  #
  def sort_column
    allowed_columns = %w[sku name created_at updated_at]
    allowed_columns.include?(params[:sort]) ? params[:sort] : 'created_at'
  end

  # Get sort direction from params
  # Defaults to desc if invalid or not provided
  #
  # @return [String] The sort direction (asc or desc)
  #
  def sort_direction
    allowed_directions = %w[asc desc]
    allowed_directions.include?(params[:direction]) ? params[:direction] : 'desc'
  end

  # Send CSV export of products
  #
  # @param products [ActiveRecord::Relation] Products to export
  #
  def send_csv_export(products)
    csv_data = ProductExportService.new(products).to_csv

    send_data csv_data,
              filename: "products_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end
end
