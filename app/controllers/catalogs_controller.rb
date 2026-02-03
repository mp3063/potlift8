# Catalogs Controller
#
# Manages CRUD operations for catalogs in the Potlift8 inventory system.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Full CRUD operations (index, show, new, create, edit, update, destroy)
# - Catalog items management with product associations
# - Priority-based reordering of catalog items
# - JSON/CSV export functionality
# - Multi-currency catalog support (EUR, SEK, NOK)
# - Turbo Stream support for dynamic updates
#
# URL Parameter:
# - Uses catalog 'code' instead of 'id' for cleaner URLs
#
class CatalogsController < ApplicationController
  before_action :set_catalog, only: [ :show, :edit, :update, :destroy, :items, :reorder_items, :export, :shopify_connection, :connect_shopify, :disconnect_shopify ]

  # GET /catalogs
  # GET /catalogs.turbo_stream
  #
  # Lists all catalogs for the current company.
  #
  def index
    @catalogs = current_potlift_company.catalogs
                                       .includes(:catalog_items, :products)
                                       .order(created_at: :desc)
  end

  # GET /catalogs/:code
  #
  # Shows catalog details (redirects to items action).
  #
  def show
    redirect_to catalog_items_path(@catalog)
  end

  # GET /catalogs/:code/items
  # GET /catalogs/:code/items.turbo_stream
  #
  # Lists catalog items (products in this catalog) with pagination and filtering.
  # Includes HTTP caching via ETags for improved performance.
  #
  # Query Parameters:
  # - page: Page number (default: 1)
  # - per_page: Items per page (default: 25)
  # - q: Search query (matches product name or SKU)
  #
  # HTTP Caching Strategy:
  # - ETag based on catalog and maximum updated_at of catalog_items
  # - Returns 304 Not Modified if content hasn't changed
  # - Cache per page and search query
  #
  def items
    @catalog_items = @catalog.catalog_items
                             .includes(:catalog_item_attribute_values, product: [ :labels, :inventories, :product_attribute_values ])
                             .by_priority

    # Apply search filter
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @catalog_items = @catalog_items.joins(:product)
                                     .where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
    end

    respond_to do |format|
      format.html do
        @pagy, @catalog_items = pagy(@catalog_items, items: params[:per_page] || 25)

        # HTTP caching with ETag (per page and search query)
        fresh_when(
          etag: [ @catalog, @catalog_items.maximum(:updated_at), params[:page], params[:q] ],
          last_modified: [ @catalog.updated_at, @catalog_items.maximum(:updated_at) ].compact.max,
          public: false
        )
      end

      format.turbo_stream do
        @pagy, @catalog_items = pagy(@catalog_items, items: params[:per_page] || 25)
      end
    end
  end

  # GET /catalogs/new
  #
  # Renders form for creating a new catalog.
  #
  def new
    @catalog = current_potlift_company.catalogs.build
  end

  # GET /catalogs/:code/edit
  #
  # Renders form for editing an existing catalog.
  #
  def edit
  end

  # POST /catalogs
  # POST /catalogs.turbo_stream
  #
  # Creates a new catalog.
  #
  def create
    @catalog = current_potlift_company.catalogs.build(catalog_params)

    if @catalog.save
      respond_to do |format|
        format.html { redirect_to catalogs_path, notice: "Catalog created successfully." }
        format.turbo_stream do
          redirect_to catalogs_path, notice: "Catalog created successfully."
        end
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /catalogs/:code
  # PUT /catalogs/:code
  # PATCH /catalogs/:code.turbo_stream
  #
  # Updates an existing catalog.
  #
  def update
    if @catalog.update(catalog_params)
      respond_to do |format|
        format.html { redirect_to catalogs_path, notice: "Catalog updated successfully." }
        format.turbo_stream do
          redirect_to catalogs_path, notice: "Catalog updated successfully."
        end
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /catalogs/:code
  # DELETE /catalogs/:code.turbo_stream
  #
  # Destroys a catalog and all associated catalog items.
  #
  def destroy
    @catalog.destroy

    respond_to do |format|
      format.html { redirect_to catalogs_path, notice: "Catalog deleted successfully." }
      format.turbo_stream do
        redirect_to catalogs_path, notice: "Catalog deleted successfully."
      end
    end
  end

  # PATCH /catalogs/:code/reorder_items
  #
  # Reorders catalog items by updating their priority values.
  # Used by drag-and-drop interfaces via AJAX.
  #
  # Parameters:
  # - order: Array of catalog_item IDs in desired order (highest priority first)
  #
  # Response:
  # - 200 OK with no body on success
  # - 422 Unprocessable Entity if order parameter is missing or invalid
  #
  def reorder_items
    order = params[:order]

    if order.blank? || !order.is_a?(Array)
      head :unprocessable_entity
      return
    end

    # Update priority for each catalog item
    # Priority is 1-based, with higher numbers appearing first (default scope: DESC)
    ActiveRecord::Base.transaction do
      order.each_with_index do |catalog_item_id, index|
        catalog_item = @catalog.catalog_items.find_by(id: catalog_item_id)
        next unless catalog_item

        # Priority is reverse of index (first item gets highest priority)
        catalog_item.update!(priority: order.length - index)
      end
    end

    head :ok
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  # GET /catalogs/:code/shopify_connection
  # GET /catalogs/:code/shopify_connection.turbo_stream
  #
  # Shows Shopify connection form/status in a turbo frame.
  # If connected, displays connection details; if not, shows connection form.
  #
  def shopify_connection
    @shopify_service = ShopifyConnectionService.new(@catalog)
    @connected = @shopify_service.connected?

    if @connected
      result = @shopify_service.shop_details
      @shop_details = result.success? ? result.data : nil
    end

    respond_to do |format|
      format.html # Uses default layout
      format.turbo_stream
    end
  end

  # POST /catalogs/:code/connect_shopify
  # POST /catalogs/:code/connect_shopify.turbo_stream
  #
  # Creates or updates the Shopify connection for this catalog.
  # Uses ShopifyConnectionService to manage the connection.
  #
  def connect_shopify
    @shopify_service = ShopifyConnectionService.new(@catalog)
    result = @shopify_service.connect(shopify_connection_params)

    respond_to do |format|
      if result.success?
        format.html { redirect_to edit_catalog_path(@catalog), notice: "Successfully connected to Shopify store." }
        format.turbo_stream do
          flash.now[:notice] = "Successfully connected to Shopify store."
          redirect_to edit_catalog_path(@catalog), notice: "Successfully connected to Shopify store."
        end
      else
        format.html { redirect_to edit_catalog_path(@catalog), alert: result.error }
        format.turbo_stream do
          flash.now[:alert] = result.error
          redirect_to edit_catalog_path(@catalog), alert: result.error
        end
      end
    end
  end

  # DELETE /catalogs/:code/disconnect_shopify
  # DELETE /catalogs/:code/disconnect_shopify.turbo_stream
  #
  # Removes the Shopify connection from this catalog.
  # Uses ShopifyConnectionService to manage the disconnection.
  #
  def disconnect_shopify
    @shopify_service = ShopifyConnectionService.new(@catalog)
    result = @shopify_service.disconnect

    respond_to do |format|
      if result.success?
        format.html { redirect_to edit_catalog_path(@catalog), notice: "Successfully disconnected from Shopify store." }
        format.turbo_stream do
          flash.now[:notice] = "Successfully disconnected from Shopify store."
          redirect_to edit_catalog_path(@catalog), notice: "Successfully disconnected from Shopify store."
        end
      else
        format.html { redirect_to edit_catalog_path(@catalog), alert: result.error }
        format.turbo_stream do
          flash.now[:alert] = result.error
          redirect_to edit_catalog_path(@catalog), alert: result.error
        end
      end
    end
  end

  # GET /catalogs/:code/export
  # GET /catalogs/:code/export.json
  # GET /catalogs/:code/export.csv
  #
  # Exports catalog data in JSON or CSV format.
  #
  def export
    @catalog_items = @catalog.catalog_items
                             .includes(product: [ :labels, :product_attribute_values ])
                             .by_priority

    respond_to do |format|
      format.json do
        render json: {
          catalog: {
            code: @catalog.code,
            name: @catalog.name,
            catalog_type: @catalog.catalog_type,
            currency_code: @catalog.currency_code,
            products_count: @catalog_items.count
          },
          items: @catalog_items.map do |item|
            {
              id: item.id,
              priority: item.priority,
              catalog_item_state: item.catalog_item_state,
              product: {
                id: item.product.id,
                sku: item.product.sku,
                name: item.product.name,
                product_type: item.product.product_type,
                product_status: item.product.product_status,
                ean: item.product.ean,
                labels: item.product.labels.map { |label| { id: label.id, name: label.name } },
                attributes: item.effective_attribute_values_hash
              }
            }
          end
        }
      end

      format.csv do
        send_csv_export(@catalog_items)
      end
    end
  end

  private

  # Set the catalog for show, edit, update, destroy, items, reorder_items, export actions
  # Uses catalog 'code' as URL parameter instead of 'id'
  # Ensures catalog belongs to current company
  # Raises ActiveRecord::RecordNotFound if catalog not found or doesn't belong to company
  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:code])
  end

  # Strong parameters for catalog creation/update
  #
  # Permitted parameters:
  # - name: Catalog display name
  # - code: Unique catalog identifier (URL-safe)
  # - catalog_type: Type of catalog (webshop, supply)
  # - currency_code: ISO currency code (eur, sek, nok)
  # - description: Optional catalog description (stored in info JSONB)
  # - active: Boolean flag for catalog status (stored in info JSONB)
  #
  def catalog_params
    params.require(:catalog).permit(
      :name,
      :code,
      :catalog_type,
      :currency_code,
      :description,
      :active
    )
  end

  # Strong parameters for Shopify connection
  #
  # Permitted parameters:
  # - shopify_domain: The Shopify store domain (e.g., my-store.myshopify.com)
  # - shopify_api_key: The Shopify API key
  # - shopify_password: The Shopify API secret/password
  # - location_id: The Shopify location ID (optional)
  #
  def shopify_connection_params
    params.permit(
      :shopify_domain,
      :shopify_api_key,
      :shopify_password,
      :location_id
    )
  end

  # Send CSV export of catalog items
  #
  # @param catalog_items [ActiveRecord::Relation] Catalog items to export
  #
  def send_csv_export(catalog_items)
    require "csv"

    csv_data = CSV.generate(headers: true) do |csv|
      # CSV headers
      csv << [
        "Priority",
        "State",
        "Product SKU",
        "Product Name",
        "Product Type",
        "Product Status",
        "EAN",
        "Labels",
        "Price",
        "Weight",
        "Stock"
      ]

      # CSV rows
      catalog_items.each do |item|
        product = item.product

        csv << [
          item.priority,
          item.catalog_item_state,
          product.sku,
          product.name,
          product.product_type,
          product.product_status,
          product.ean,
          product.labels.map(&:name).join(", "),
          item.effective_attribute_value("price"),
          item.effective_attribute_value("weight"),
          product.inventories.sum(:value)
        ]
      end
    end

    send_data csv_data,
              filename: "catalog_#{@catalog.code}_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
              type: "text/csv",
              disposition: "attachment"
  end
end
