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
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :duplicate, :toggle_active, :attribute_value ]

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
    # .with_subproducts is needed for expandable row functionality (configurable products)
    # .includes(:bundle_variants) is needed for bundle products
    # .parent_products_only filters out variant products (displayed as expandable children)
    @products = current_potlift_company.products
                                       .parent_products_only
                                       .with_labels_only
                                       .with_subproducts
                                       .includes(bundle_variants: [ :subproducts, { product_configurations_as_super: :subproduct } ])

    # Use extracted services for filtering
    @filter_service = ProductFilteringService.new(@products, params, current_potlift_company)
    @products = @filter_service.call
    @current_label = @filter_service.current_label

    # Load labels for filter dropdown
    @available_labels = current_potlift_company.labels
                                               .root_labels
                                               .includes(:sublabels)
                                               .order(:label_positions, :name)
    @label_product_counts = LabelProductCountService.new(current_potlift_company).call

    # Apply sorting
    @products = @products.order(@filter_service.sort_column => @filter_service.sort_direction)

    respond_to do |format|
      format.html do
        @pagy, @products = pagy(@products, items: params[:per_page] || 25)
      end

      format.turbo_stream do
        # Turbo may request turbo_stream format after redirects.
        # Force a full page refresh instead of partial update.
        render turbo_stream: turbo_stream.refresh
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
    # Load product with eager loading to prevent N+1 queries
    # Associations loaded based on actual view access patterns:
    #
    # 1. product_attribute_values + product_attributes (via .with_attributes scope)
    #    - Accessed throughout show view for attribute display
    #
    # 2. labels
    #    - Line 75 of labels_component.html.erb: product.labels.each
    #    - Line 40 of labels_component.rb: product.labels.any?
    #    - Line 32 of labels_component.rb: product.label_ids (for exclusion)
    #    - NOTE: Bullet may incorrectly flag this as unused due to ViewComponent rendering
    #
    # 3. catalog_items => [:catalog, :catalog_item_attribute_values]
    #    - Lines 23, 29, etc. of catalog_tabs_component.html.erb: catalog_item.catalog.*
    #    - Line 31: catalog_item.catalog_item_attribute_values_count (uses counter cache)
    #    - Line 36 of _catalog_attributes.html.erb: catalog_item.catalog_item_attribute_values.find
    #    - Line 183 of _catalog_attributes.html.erb: catalog_item.catalog_item_attribute_values.any?
    #    - Counter cache optimizes badge count display, but full collection still needed for overrides
    #
    # 4. configurations => :configuration_values
    #    - configurable_card_component.rb: product.configurations.includes(:configuration_values).order(:position)
    #    - Used to display configuration dimensions and values for configurable products
    #
    # 5. subproducts (via .with_subproducts scope)
    #    - configurable_card_component.rb: product.subproducts.count
    #    - Used to display variant count for configurable products
    #
    @product = current_potlift_company.products
                                      .with_attributes
                                      .includes(:labels)
                                      .includes(catalog_items: [ :catalog, :catalog_item_attribute_values ])
                                      .includes(configurations: :configuration_values)
                                      .with_subproducts
                                      # TODO: Add .with_inventory when inventory is displayed in show view
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
    #
    # IMPORTANT: Include CSRF token in ETag to prevent token mismatch errors
    # When the session changes (e.g., token refresh), cached HTML with old CSRF
    # tokens would cause InvalidAuthenticityToken errors on form submissions
    fresh_when(
      etag: [
        @product,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at),
        @product.configurations.maximum(:updated_at),
        @product.subproducts.maximum(:updated_at),
        form_authenticity_token
      ],
      last_modified: [
        @product.updated_at,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at),
        @product.configurations.maximum(:updated_at),
        @product.subproducts.maximum(:updated_at)
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
  # Bundle Variant Generation:
  # If product is a bundle and bundle_configuration param is present,
  # automatically generates bundle variants using BundleVariantGeneratorService.
  #
  def create
    @product = current_potlift_company.products.build(product_params)

    # Handle restock_level in info JSONB column
    handle_info_fields(@product)

    success = false
    @generated_count = 0

    ActiveRecord::Base.transaction do
      unless @product.save
        raise ActiveRecord::Rollback
      end

      # Generate bundle variants if bundle configuration provided
      if @product.product_type_bundle? && bundle_config_present?
        result = BundleVariantGeneratorService.new(@product, bundle_configuration).call

        unless result.success?
          @product.errors.add(:base, result.errors.join(", "))
          raise ActiveRecord::Rollback
        end

        @generated_count = result.variants.count
      end

      success = true
    end

    if success
      notice_message = if @generated_count > 0
                        "Product created successfully. Generated #{@generated_count} #{'variant'.pluralize(@generated_count)}."
      else
                        "Product created successfully."
      end
      redirect_to products_path, notice: notice_message, status: :see_other
    else
      # Turbo will automatically handle re-rendering the form in place
      # when we respond with status :unprocessable_entity
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /products/:id
  # PUT /products/:id
  # PATCH /products/:id.turbo_stream
  #
  # Updates an existing product.
  #
  # Bundle Variant Regeneration:
  # If product is a bundle and regenerate=true param is present,
  # regenerates all bundle variants using BundleRegeneratorService.
  # Old variants are soft-deleted and new ones are created.
  #
  def update
    # Handle restock_level in info JSONB column before update
    handle_info_fields(@product)

    success = false
    @deleted_count = 0
    @created_count = 0

    ActiveRecord::Base.transaction do
      unless @product.update(product_params)
        raise ActiveRecord::Rollback
      end

      # Regenerate bundle variants if requested
      if @product.product_type_bundle? && should_regenerate?
        result = BundleRegeneratorService.new(@product, bundle_configuration).call

        unless result.success?
          @product.errors.add(:base, result.errors.join(", "))
          raise ActiveRecord::Rollback
        end

        @deleted_count = result.deleted_count
        @created_count = result.created_count
      end

      success = true
    end

    if success
      notice_message = if @created_count > 0
                        "Product updated successfully. Regenerated #{@created_count} #{'variant'.pluralize(@created_count)}."
      else
                        "Product updated successfully."
      end
      redirect_to products_path, notice: notice_message, status: :see_other
    else
      # Turbo will automatically handle re-rendering the form in place
      # when we respond with status :unprocessable_entity
      render :edit, status: :unprocessable_entity
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
      format.html { redirect_to products_path, notice: "Product deleted successfully.", status: :see_other }
      format.turbo_stream { render turbo_stream: turbo_stream.action(:refresh, "") }
    end
  end

  # POST /products/:id/duplicate
  #
  # Duplicates a product with all attribute values and labels.
  # Redirects to edit page for the new product.
  #
  def duplicate
    new_product = @product.duplicate!

    redirect_to edit_product_path(new_product), notice: "Product duplicated as #{new_product.sku}", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to products_path, alert: "Failed to duplicate product: #{e.message}", status: :see_other
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

  # PATCH /products/:id/toggle_active
  # PATCH /products/:id/toggle_active.turbo_stream
  #
  # Toggles the product's active status using state machine transitions.
  # If active, disables the product. If not active, activates the product.
  #
  def toggle_active
    begin
      if @product.active?
        # Deactivate by disabling the product
        @product.disable!
        status_text = "deactivated"
      else
        # Activate the product (may fail if validation guards fail)
        @product.activate!
        status_text = "activated"
      end

      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product #{status_text} successfully.", status: :see_other }
        format.turbo_stream { flash.now[:notice] = "Product #{status_text} successfully." }
      end
    rescue AASM::InvalidTransition => e
      # Handle state machine transition failures (e.g., missing required attributes)
      error_message = if @product.active?
                        "Cannot deactivate product: #{e.message}"
      else
                        "Cannot activate product. Ensure all mandatory attributes are set and product structure is valid."
      end

      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, alert: error_message, status: :see_other }
        format.turbo_stream { flash.now[:alert] = error_message }
      end
    rescue ActiveRecord::RecordInvalid => e
      # Handle validation failures
      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to update product: #{e.message}", status: :see_other }
        format.turbo_stream { flash.now[:alert] = "Failed to update product: #{e.message}" }
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

  # Parse bundle configuration from JSON parameter
  # Returns parsed hash or empty hash if invalid/missing
  #
  # @return [Hash] The bundle configuration hash
  #
  def bundle_configuration
    @bundle_configuration ||= JSON.parse(params[:bundle_configuration] || "{}")
  rescue JSON::ParserError
    {}
  end

  # Check if bundle configuration is present and valid
  # Configuration must have 'components' array to be considered present
  #
  # @return [Boolean] True if configuration is present and has components
  #
  def bundle_config_present?
    params[:bundle_configuration].present? && bundle_configuration["components"].present?
  end

  # Check if bundle variants should be regenerated
  # Requires regenerate=true param and valid bundle configuration
  #
  # @return [Boolean] True if should regenerate variants
  #
  def should_regenerate?
    params[:regenerate] == "true" && bundle_config_present?
  end
end
