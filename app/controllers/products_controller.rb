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
  before_action :set_product, only: [:show, :edit, :update, :destroy, :duplicate, :add_label, :remove_label, :toggle_active]

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
  # - label_id: Filter by label ID (includes sublabels)
  # - q: Search query (matches name or SKU)
  #
  def index
    @products = current_potlift_company.products
                                       .includes(:labels, :inventories)

    # Load labels for filter dropdown
    load_filter_labels

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
    # Reload product with associations to ensure they're loaded
    @product = current_potlift_company.products
                                      .includes(product_attribute_values: :product_attribute)
                                      .find(params[:id])

    # Build attribute => value hash for the component
    @attribute_values = @product.product_attribute_values.each_with_object({}) do |pav, hash|
      hash[pav.product_attribute] = pav
    end
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
    products = current_potlift_company.products.where(id: product_ids).includes(:product_attribute_values, :labels, :inventories, :product_assets, :catalog_items, :product_configurations_as_super, :product_configurations_as_sub, images_attachments: :blob)
    count = products.destroy_all.size

    redirect_to products_path, notice: "#{count} #{'product'.pluralize(count)} deleted successfully."
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

    redirect_to products_path, notice: "Labels updated for #{count} #{'product'.pluralize(count)}."
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

  # POST /products/:id/add_label
  # POST /products/:id/add_label.turbo_stream
  #
  # Adds a label to the product.
  #
  # Parameters:
  # - label_id: The ID of the label to add
  #
  def add_label
    label_id = params[:label_id]

    if label_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Please select a label.' }
        format.turbo_stream { flash.now[:alert] = 'Please select a label.' }
      end
      return
    end

    # Verify label belongs to current company
    label = current_potlift_company.labels.find_by(id: label_id)

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Label not found.' }
        format.turbo_stream { flash.now[:alert] = 'Label not found.' }
      end
      return
    end

    # Add label if not already present
    if @product.labels.include?(label)
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Label already assigned to this product.' }
        format.turbo_stream { flash.now[:alert] = 'Label already assigned to this product.' }
      end
      return
    end

    @product.labels << label

    respond_to do |format|
      format.html { redirect_to @product, notice: "Label '#{label.name}' added successfully." }
      format.turbo_stream { flash.now[:notice] = "Label '#{label.name}' added successfully." }
    end
  end

  # DELETE /products/:id/remove_label
  # DELETE /products/:id/remove_label.turbo_stream
  #
  # Removes a label from the product.
  #
  # Parameters:
  # - label_id: The ID of the label to remove
  #
  def remove_label
    label_id = params[:label_id]

    if label_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Label ID is required.' }
        format.turbo_stream { flash.now[:alert] = 'Label ID is required.' }
      end
      return
    end

    # Verify label belongs to product
    label = @product.labels.find_by(id: label_id)

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Label not found on this product.' }
        format.turbo_stream { flash.now[:alert] = 'Label not found on this product.' }
      end
      return
    end

    @product.labels.delete(label)

    respond_to do |format|
      format.html { redirect_to @product, notice: "Label '#{label.name}' removed successfully." }
      format.turbo_stream { flash.now[:notice] = "Label '#{label.name}' removed successfully." }
    end
  end

  # PATCH /products/:id/toggle_active
  # PATCH /products/:id/toggle_active.turbo_stream
  #
  # Toggles the product's active status.
  # If active, sets to draft. If not active, sets to active.
  #
  def toggle_active
    if @product.active?
      @product.product_status = :draft
      status_text = 'deactivated'
    else
      @product.product_status = :active
      status_text = 'activated'
    end

    if @product.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product #{status_text} successfully." }
        format.turbo_stream { flash.now[:notice] = "Product #{status_text} successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to update product: #{@product.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to update product: #{@product.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
      end
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

    # Filter by product status
    if params[:status].present? && Product.product_statuses.key?(params[:status])
      products = products.where(product_status: params[:status])
    end

    # Filter by label (includes sublabels for hierarchical filtering)
    if params[:label_id].present?
      begin
        @current_label = current_potlift_company.labels.find(params[:label_id])
        # Get all label IDs including descendants (sublabels)
        label_ids = [@current_label.id] + @current_label.descendants.pluck(:id)
        products = products.joins(:labels).where(labels: { id: label_ids }).distinct
      rescue ActiveRecord::RecordNotFound
        # Label not found or doesn't belong to company - ignore filter
        @current_label = nil
      end
    end

    # Search by name or SKU
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      # Qualify table name to avoid ambiguity when joining labels
      products = products.where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
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

  # Load labels for filter dropdown with product counts
  # Only loads root labels and their immediate children for performance
  # Eager loads associations to prevent N+1 queries
  #
  def load_filter_labels
    @available_labels = current_potlift_company.labels
                                               .root_labels
                                               .includes(sublabels: :products)
                                               .includes(:products)
                                               .order(:label_positions, :name)

    # Calculate product counts for each label (including sublabels)
    @label_product_counts = {}
    @available_labels.each do |label|
      # Count products with this label or any sublabel
      label_ids = [label.id] + label.descendants.pluck(:id)
      count = current_potlift_company.products
                                     .joins(:labels)
                                     .where(labels: { id: label_ids })
                                     .distinct
                                     .count
      @label_product_counts[label.id] = count

      # Also calculate counts for sublabels
      label.sublabels.each do |sublabel|
        sublabel_ids = [sublabel.id] + sublabel.descendants.pluck(:id)
        sublabel_count = current_potlift_company.products
                                                .joins(:labels)
                                                .where(labels: { id: sublabel_ids })
                                                .distinct
                                                .count
        @label_product_counts[sublabel.id] = sublabel_count
      end
    end
  end
end
