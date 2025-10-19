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
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :duplicate, :add_label, :remove_label, :toggle_active, :add_to_catalog, :remove_from_catalog, :attribute_value ]

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
    # Use optimized scope with eager loading to prevent N+1 queries
    # .with_labels_only is faster than .with_search_associations for listing pages
    @products = current_potlift_company.products
                                       .with_labels_only

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
        # Use readonly for better performance on read-only operations
        send_csv_export(@products.readonly_records)
      end
    end
  end

  # GET /products/:id
  #
  # Shows detailed product information with HTTP caching via ETags.
  #
  # HTTP Caching Strategy:
  # - ETag based on product, attributes, labels, and inventories
  # - Returns 304 Not Modified if client ETag matches
  # - Last-Modified header based on most recent update timestamp
  #
  # Performance Impact:
  # - First visit: Full render (~100ms)
  # - Cached visit: 304 response (~5ms, no HTML rendered)
  # - Cache invalidation: Automatic on product/association updates
  #
  def show
    # Reload product with necessary associations to prevent N+1 queries
    # Uses optimized eager loading scope
    @product = current_potlift_company.products
                                      .with_attributes
                                      .with_labels
                                      .includes(catalog_items: [ :catalog, catalog_item_attribute_values: :product_attribute ])
                                      # TODO: Add .with_inventory when inventory is displayed in show view
                                      # TODO: Add .with_subproducts when variants/bundles are displayed in show view
                                      .find(params[:id])

    # Build attribute => value hash for the component
    # No additional queries needed as data is already eager loaded
    @attribute_values = @product.product_attribute_values.each_with_object({}) do |pav, hash|
      hash[pav.product_attribute] = pav
    end

    # Load available catalogs for "Add to Catalog" modal
    # Exclude catalogs the product is already in
    @available_catalogs = current_potlift_company.catalogs
                                                 .where.not(id: @product.catalog_items.map(&:catalog_id))
                                                 .order(:name)

    # HTTP caching with ETag and Last-Modified headers
    # ETag includes all related data that affects the view
    # Returns 304 Not Modified if client has current version
    fresh_when(
      etag: [
        @product,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at)
      ],
      last_modified: [
        @product.updated_at,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at)
        # TODO: Add inventories.maximum(:updated_at) when inventory is displayed
      ].compact.max,
      public: false # Don't cache in public CDNs (multi-tenant data)
    )
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

    # Handle restock_level in info JSONB column
    handle_info_fields(@product)

    if @product.save
      respond_to do |format|
        format.html { redirect_to products_path, notice: "Product created successfully." }
        format.turbo_stream do
          redirect_to products_path, notice: "Product created successfully."
        end
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
    # Handle restock_level in info JSONB column before update
    handle_info_fields(@product)

    if @product.update(product_params)
      respond_to do |format|
        format.html { redirect_to products_path, notice: "Product updated successfully." }
        format.turbo_stream do
          redirect_to products_path, notice: "Product updated successfully."
        end
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
      format.html { redirect_to products_path, notice: "Product deleted successfully." }
      format.turbo_stream do
        redirect_to products_path, notice: "Product deleted successfully."
      end
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
      redirect_to products_path, alert: "No products selected."
      return
    end

    # Eager load associations to prevent N+1 queries during destroy callbacks
    products = current_potlift_company.products.where(id: product_ids).includes(:product_attribute_values, :labels, :inventories, :product_assets, :catalog_items, :product_configurations_as_super, :product_configurations_as_sub, images_attachments: :blob)

    # Track success and failure individually
    successful_count = 0
    failed_products = []

    products.each do |product|
      if product.destroy
        successful_count += 1
      else
        failed_products << "#{product.sku} (#{product.errors.full_messages.join(', ')})"
      end
    end

    # Provide detailed feedback
    if failed_products.any?
      redirect_to products_path,
                  alert: "#{successful_count} #{'product'.pluralize(successful_count)} deleted. Failed to delete: #{failed_products.join('; ')}"
    else
      redirect_to products_path,
                  notice: "#{successful_count} #{'product'.pluralize(successful_count)} deleted successfully."
    end
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
      redirect_to products_path, alert: "No products selected."
      return
    end

    successful_count = 0
    failed_products = []

    # Wrap in transaction to ensure atomicity
    ActiveRecord::Base.transaction do
      current_potlift_company.products.where(id: product_ids).includes(:labels).find_each do |product|
        product.label_ids = label_ids
        if product.save
          successful_count += 1
        else
          failed_products << "#{product.sku} (#{product.errors.full_messages.join(', ')})"
        end
      end

      # Rollback if any failures occurred
      raise ActiveRecord::Rollback if failed_products.any?
    end

    # Provide detailed feedback
    if failed_products.any?
      redirect_to products_path,
                  alert: "Failed to update labels. Errors: #{failed_products.join('; ')}"
    else
      redirect_to products_path,
                  notice: "Labels updated for #{successful_count} #{'product'.pluralize(successful_count)}."
    end
  rescue StandardError => e
    redirect_to products_path, alert: "Failed to update labels: #{e.message}"
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
      render json: { valid: false, message: "SKU cannot be blank" }
      return
    end

    # Normalize SKU (same as Product#normalize_sku)
    normalized_sku = sku.to_s.strip.upcase

    # Check if SKU exists, excluding the current product if editing
    existing = current_potlift_company.products.where(sku: normalized_sku)
    existing = existing.where.not(id: params[:product_id]) if params[:product_id].present?

    if existing.exists?
      render json: { valid: false, message: "SKU already exists" }
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
        format.html { redirect_to @product, alert: "Please select a label." }
        format.turbo_stream { flash.now[:alert] = "Please select a label." }
      end
      return
    end

    # Verify label belongs to current company
    label = current_potlift_company.labels.find_by(id: label_id)

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label not found." }
        format.turbo_stream { flash.now[:alert] = "Label not found." }
      end
      return
    end

    # Add label if not already present
    if @product.labels.include?(label)
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label already assigned to this product." }
        format.turbo_stream { flash.now[:alert] = "Label already assigned to this product." }
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
        format.html { redirect_to @product, alert: "Label ID is required." }
        format.turbo_stream { flash.now[:alert] = "Label ID is required." }
      end
      return
    end

    # Verify label belongs to product
    label = @product.labels.find_by(id: label_id)

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label not found on this product." }
        format.turbo_stream { flash.now[:alert] = "Label not found on this product." }
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
      status_text = "deactivated"
    else
      @product.product_status = :active
      status_text = "activated"
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
  rescue ActiveRecord::RecordInvalid => e
    redirect_to products_path, alert: "Failed to toggle product status: #{e.message}"
  end

  # POST /products/:id/add_to_catalog
  # POST /products/:id/add_to_catalog.turbo_stream
  #
  # Adds the product to a catalog with optional configuration.
  #
  # Parameters:
  # - catalog_id: The ID of the catalog to add the product to
  # - active: Whether the product should be active in the catalog (default: true)
  # - priority: The priority order in the catalog (default: 0)
  #
  def add_to_catalog
    catalog_id = params[:catalog_id]
    active = params[:active] == "1"
    priority = params[:priority].to_i

    if catalog_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: "Please select a catalog." }
        format.turbo_stream { flash.now[:alert] = "Please select a catalog." }
      end
      return
    end

    # Verify catalog belongs to current company
    catalog = current_potlift_company.catalogs.find_by(id: catalog_id)

    unless catalog
      respond_to do |format|
        format.html { redirect_to @product, alert: "Catalog not found." }
        format.turbo_stream { flash.now[:alert] = "Catalog not found." }
      end
      return
    end

    # Check if product is already in catalog
    if @product.catalog_items.exists?(catalog_id: catalog.id)
      respond_to do |format|
        format.html { redirect_to @product, alert: "Product is already in #{catalog.name}." }
        format.turbo_stream { flash.now[:alert] = "Product is already in #{catalog.name}." }
      end
      return
    end

    # Create catalog item
    catalog_item = @product.catalog_items.build(
      catalog: catalog,
      catalog_item_state: active ? :active : :inactive,
      priority: priority
    )

    if catalog_item.save
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product added to #{catalog.name} successfully." }
        format.turbo_stream { flash.now[:notice] = "Product added to #{catalog.name} successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to add product to catalog: #{catalog_item.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to add product to catalog: #{catalog_item.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  # DELETE /products/:id/remove_from_catalog
  # DELETE /products/:id/remove_from_catalog.turbo_stream
  #
  # Removes the product from a catalog.
  #
  # Parameters:
  # - catalog_id: The ID of the catalog to remove the product from
  #
  def remove_from_catalog
    catalog_id = params[:catalog_id]

    if catalog_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: "Catalog ID is required." }
        format.turbo_stream { flash.now[:alert] = "Catalog ID is required." }
      end
      return
    end

    # Find the catalog item
    catalog_item = @product.catalog_items.find_by(catalog_id: catalog_id)

    unless catalog_item
      respond_to do |format|
        format.html { redirect_to @product, alert: "Product is not in this catalog." }
        format.turbo_stream { flash.now[:alert] = "Product is not in this catalog." }
      end
      return
    end

    catalog_name = catalog_item.catalog.name

    if catalog_item.destroy
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product removed from #{catalog_name} successfully." }
        format.turbo_stream { flash.now[:notice] = "Product removed from #{catalog_name} successfully." }
      end
    else
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to remove product from catalog: #{catalog_item.errors.full_messages.join(', ')}" }
        format.turbo_stream do
          flash.now[:alert] = "Failed to remove product from catalog: #{catalog_item.errors.full_messages.join(', ')}"
          render :show, status: :unprocessable_entity
        end
      end
    end
  end

  # GET /products/:id/attribute_value
  # Returns the value of a product attribute by code (for AJAX requests)
  #
  # Query Parameters:
  # - code: Attribute code (required)
  #
  # Response:
  # - JSON: { value: "attribute_value" } or { value: nil }
  #
  def attribute_value
    code = params[:code]

    if code.blank?
      render json: { error: "Attribute code is required" }, status: :bad_request
      return
    end

    value = @product.read_attribute_value(code)

    render json: { value: value }
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

  # Handle JSONB info field updates
  # Stores restock_level in product.info["restock_level"]
  #
  # @param product [Product] The product to update
  def handle_info_fields(product)
    return unless params[:product] && params[:product][:restock_level]

    # Initialize info hash if nil
    product.info ||= {}

    # Store restock_level as integer (or remove if blank)
    if params[:product][:restock_level].present?
      product.info["restock_level"] = params[:product][:restock_level].to_i
    else
      product.info["restock_level"] = 0
    end
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
        label_ids = [ @current_label.id ] + @current_label.descendants.pluck(:id)
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
    allowed_columns.include?(params[:sort]) ? params[:sort] : "created_at"
  end

  # Get sort direction from params
  # Defaults to desc if invalid or not provided
  #
  # @return [String] The sort direction (asc or desc)
  #
  def sort_direction
    allowed_directions = %w[asc desc]
    allowed_directions.include?(params[:direction]) ? params[:direction] : "desc"
  end

  # Send CSV export of products
  #
  # @param products [ActiveRecord::Relation] Products to export
  #
  def send_csv_export(products)
    csv_data = ProductExportService.new(products).to_csv

    send_data csv_data,
              filename: "products_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  # Load labels for filter dropdown with product counts
  # Only loads root labels and their immediate children for performance
  # Eager loads associations to prevent N+1 queries
  #
  def load_filter_labels
    @available_labels = current_potlift_company.labels
                                               .root_labels
                                               .includes(sublabels: { sublabels: :sublabels })
                                               .order(:label_positions, :name)

    # Optimized: Calculate product counts for all labels in a single query
    # This eliminates N+1 queries by using GROUP BY instead of per-label queries
    @label_product_counts = calculate_label_product_counts
  end

  # Calculate product counts for all labels efficiently (single GROUP BY query)
  # Returns a hash of label_id => product_count (including descendant labels)
  def calculate_label_product_counts
    # Early return if no company context
    return {} unless current_potlift_company

    # Step 1: Load all labels and build hierarchical structure
    all_labels = current_potlift_company.labels.to_a
    descendant_map = build_descendant_map(all_labels)

    # Step 2: Build a mapping of product_id => [label_ids] to track all label associations
    # This allows us to efficiently check which products belong to which label hierarchies
    product_label_map = {}
    product_label_pairs = ProductLabel.where(product_id: current_potlift_company.products.select(:id))
                                       .pluck(:product_id, :label_id)

    product_label_pairs.each do |product_id, label_id|
      product_label_map[product_id] ||= []
      product_label_map[product_id] << label_id
    end

    # Step 3: Calculate cumulative counts for each label (including descendants)
    # This is done in memory to avoid N database queries
    label_counts = {}

    all_labels.each do |label|
      # Build set of label IDs to check (this label + all descendants)
      label_ids_to_check = Set.new([ label.id ] + (descendant_map[label.id] || []))

      # Count distinct products that are tagged with this label or any descendant
      count = product_label_map.count do |_product_id, label_ids|
        # Check if product has at least one label in our set
        (label_ids.to_a & label_ids_to_check.to_a).any?
      end

      label_counts[label.id] = count
    end

    label_counts
  end

  # Build a map of label_id => [descendant_label_ids] for all labels
  # This is more efficient than calling label.descendants N times
  # @param labels [Array<Label>] All labels to process
  # @return [Hash<Integer, Array<Integer>>] Map of label_id to descendant IDs
  def build_descendant_map(labels)
    # Create parent_id => children_ids mapping
    children_map = labels.group_by(&:parent_label_id)
                        .transform_values { |children| children.map(&:id) }

    # Recursively collect all descendants for each label
    descendant_map = {}

    labels.each do |label|
      descendant_map[label.id] = collect_descendants(label.id, children_map)
    end

    descendant_map
  end

  # Recursively collect all descendant IDs for a given label
  # @param label_id [Integer] The label ID to find descendants for
  # @param children_map [Hash] Map of parent_id => child_ids
  # @return [Array<Integer>] All descendant label IDs
  def collect_descendants(label_id, children_map)
    children = children_map[label_id] || []
    descendants = children.dup

    children.each do |child_id|
      descendants.concat(collect_descendants(child_id, children_map))
    end

    descendants
  end
end
