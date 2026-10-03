# URL Parameter:
# - Uses catalog 'code' instead of 'id' for cleaner URLs
class CatalogsController < ApplicationController
  before_action :set_catalog, only: [ :show, :edit, :update, :destroy, :items, :reorder_items, :export, :shopify_connection, :connect_shopify, :disconnect_shopify, :sync_all, :dismiss_sync_run, :sync_product, :toggle_sync_pause, :sync_preview, :sync_status, :sync_alerts ]

  def index
    authorize Catalog
    @catalogs = current_potlift_company.catalogs
                                       .includes(:catalog_items, :products)
                                       .order(created_at: :desc)
  end

  def show
    authorize @catalog
    redirect_to catalog_items_path(@catalog)
  end

  def items
    authorize @catalog
    @catalog_items = @catalog.catalog_items
                             .includes(:catalog_item_attribute_values, product: [ :labels, :inventories, :product_attribute_values ])
                             .by_priority

    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @catalog_items = @catalog_items.joins(:product)
                                     .where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
    end

    case params[:sync_status]
    when "synced"
      @sync_status_filter = "synced"
      @catalog_items = @catalog_items.up_to_date
    when "out_of_date"
      @sync_status_filter = "out_of_date"
      @catalog_items = @catalog_items.out_of_date
    when *CatalogItem.sync_statuses.keys
      @sync_status_filter = params[:sync_status]
      @catalog_items = @catalog_items.where(sync_status: @sync_status_filter)
    end

    if @catalog.shopify_connected?
      @sync_counts = @catalog.sync_counts
    end

    respond_to do |format|
      format.html do
        @pagy, @catalog_items = pagy(@catalog_items, items: params[:per_page] || 25)
      end

      format.turbo_stream do
        @pagy, @catalog_items = pagy(@catalog_items, items: params[:per_page] || 25)
      end
    end
  end

  def new
    authorize Catalog
    @catalog = current_potlift_company.catalogs.build
  end

  def edit
    authorize @catalog
  end

  def create
    authorize Catalog
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

  def update
    authorize @catalog
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

  def destroy
    authorize @catalog
    @catalog.destroy

    respond_to do |format|
      format.html { redirect_to catalogs_path, notice: "Catalog deleted successfully." }
      format.turbo_stream do
        redirect_to catalogs_path, notice: "Catalog deleted successfully."
      end
    end
  end

  def reorder_items
    authorize @catalog
    order = params[:order]

    if order.blank? || !order.is_a?(Array)
      head :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      order.each_with_index do |catalog_item_id, index|
        catalog_item = @catalog.catalog_items.find_by(id: catalog_item_id)
        next unless catalog_item

        catalog_item.update!(priority: order.length - index)
      end
    end

    head :ok
  rescue ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  def shopify_connection
    authorize @catalog
    @shopify_service = ShopifyConnectionService.new(@catalog)
    @connected = @shopify_service.connected?

    if @connected
      result = @shopify_service.shop_details
      @shop_details = result.success? ? result.data : nil
    end

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def connect_shopify
    authorize @catalog
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

  def disconnect_shopify
    authorize @catalog
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

  def sync_all
    authorize @catalog
    product_count = @catalog.catalog_items.count
    # Mark pending before queueing, so the job can't answer an item first
    # (and clear old errors, so the job's no-op write can't erase a new one)
    @catalog.catalog_items.update_all(sync_status: CatalogItem.sync_statuses[:pending], last_sync_error: nil)
    # A run that could never finish isn't worth tracking
    if product_count.positive? && !@catalog.info&.dig("sync_paused")
      @catalog.info ||= {}
      @catalog.info["sync_run"] = { "started_at" => Time.current.iso8601(6), "total" => product_count, "handed_off_at" => nil }
      @catalog.save!
    end
    @catalog.batch_sync_all_products

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Sync started for all #{product_count} products."
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: flash }),
          sync_summary_card_stream
        ]
      end
      format.html { redirect_to catalog_items_path(@catalog), notice: "Sync started for all #{product_count} products." }
    end
  end

  def dismiss_sync_run
    authorize @catalog
    @catalog.info&.delete("sync_run")
    @catalog.save!

    respond_to do |format|
      format.turbo_stream { render turbo_stream: sync_summary_card_stream }
      format.html { redirect_to catalog_items_path(@catalog) }
    end
  end

  def toggle_sync_pause
    authorize @catalog
    @catalog.info ||= {}
    @catalog.info["sync_paused"] = !@catalog.info["sync_paused"]
    @catalog.save!

    status = @catalog.info["sync_paused"] ? "paused" : "resumed"

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "Auto-sync #{status} for #{@catalog.name}."
        render turbo_stream: [
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: flash }),
          sync_summary_card_stream
        ]
      end
      format.html { redirect_to catalog_items_path(@catalog), notice: "Auto-sync #{status} for #{@catalog.name}." }
    end
  end

  def sync_product
    authorize @catalog
    product = @catalog.products.find(params[:product_id])
    catalog_item = @catalog.catalog_items.find_by!(product: product)

    catalog_item.update!(sync_status: :pending)
    ProductSyncJob.perform_later(product, @catalog, Time.current, manual: true)

    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to catalog_items_path(@catalog), notice: "Sync started for #{product.name}." }
    end
  end

  def sync_preview
    authorize @catalog

    @product = current_potlift_company.products
                 .includes(:labels, :translations,
                           inventories: :storage,
                           product_attribute_values: :product_attribute,
                           configurations: :configuration_values,
                           product_configurations_as_super: { subproduct: [ :translations, inventories: :storage ] })
                 .find(params[:product_id])

    @catalog_item = @catalog.catalog_items.find_by!(product: @product)

    service = ProductSyncService.new(@product, @catalog)
    @payload = service.build_payload

    @shopify_data = nil
    if @catalog.shopify_connected?
      @shopify_data = fetch_shopify_comparison(@product.sku)
    end
  end

  def sync_status
    authorize @catalog
    @recent_tasks = []
    @failed_count = 0
    @summary = {}

    if @catalog.shopify_connected?
      client = build_shopify8_client
      if client
        tasks_result = client.get_sync_tasks(shop_id: @catalog.shop_id, limit: 5)
        @recent_tasks = tasks_result.success? ? (tasks_result.data[:sync_tasks] || []) : []

        summary_result = client.get_sync_task_summary(shop_id: @catalog.shop_id)
        if summary_result.success?
          @summary = summary_result.data
          @failed_count = @summary[:failed] || 0
        end
      end
    end

    render partial: "catalogs/sync_status", locals: {
      catalog: @catalog,
      recent_tasks: @recent_tasks,
      failed_count: @failed_count,
      summary: @summary
    }
  end

  def sync_alerts
    authorize @catalog
    @failed_count = 0

    if @catalog.shopify_connected?
      client = build_shopify8_client
      if client
        # Failures already fixed by a later successful sync of the same product don't count
        result = client.get_sync_tasks(shop_id: @catalog.shop_id, status: "failed", limit: 1, unresolved: true)
        @failed_count = result.success? ? (result.data[:total] || 0) : 0
      end
    end

    render partial: "catalogs/sync_alerts", locals: {
      catalog: @catalog,
      failed_count: @failed_count
    }
  end

  def export
    authorize @catalog
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

  def sync_summary_card_stream
    turbo_stream.replace("sync_summary_#{@catalog.id}", method: :morph, partial: "catalogs/sync_summary_card",
                         locals: { catalog: @catalog, sync_counts: @catalog.sync_counts })
  end

  def build_shopify8_client
    api_token = @catalog.info&.dig("shopify_api_token") || ENV["SHOPIFY8_API_TOKEN"]
    return nil unless api_token.present?

    Shopify8ApiClient.new(api_token: api_token)
  end

  def fetch_shopify_comparison(sku)
    api_token = @catalog.info&.dig("shopify_api_token") || ENV["SHOPIFY8_API_TOKEN"]
    return nil unless api_token.present?

    client = Shopify8ApiClient.new(api_token: api_token)
    result = client.fetch(
      "/api/v1/sync_tasks?shop_id=#{@catalog.shop_id}&origin_target_id=#{CGI.escape(sku)}" \
      "&status=executed&event_type=product_changed&limit=1"
    )
    return nil unless result.success?

    last_task = result.data.is_a?(Array) ? result.data.first : result.data.dig(:sync_tasks)&.first
    return nil unless last_task

    shopify_product = nil
    if @catalog.shop_id.present?
      product_result = client.fetch(
        "/api/v1/products/#{CGI.escape(sku)}?shop_id=#{@catalog.shop_id}"
      )
      shopify_product = product_result.data if product_result.success?
    end

    {
      last_synced_at: last_task[:updated_at],
      last_payload: last_task.dig(:info, :load),
      sync_task_id: last_task[:id],
      sync_status: last_task[:status],
      shopify_product: shopify_product
    }
  rescue StandardError => e
    Rails.logger.warn("[SyncPreview] Failed to fetch Shopify comparison: #{e.message}")
    nil
  end

  # Set the catalog for show, edit, update, destroy, items, reorder_items, export actions
  # Uses catalog 'code' as URL parameter instead of 'id'
  # Ensures catalog belongs to current company
  # Raises ActiveRecord::RecordNotFound if catalog not found or doesn't belong to company
  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:code])
  end

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

  def shopify_connection_params
    params.permit(
      :shopify_domain,
      :shopify_api_key,
      :shopify_password,
      :location_id
    )
  end

  def send_csv_export(catalog_items)
    require "csv"

    csv_data = CSV.generate(headers: true) do |csv|
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
        "Price Currency",
        "Weight",
        "Stock"
      ]

      catalog_items.each do |item|
        product = item.product
        # Overrides are in the catalog currency; the inherited product price is the EUR base
        override = item.catalog_item_attribute_values.joins(:product_attribute)
                       .find_by(product_attributes: { code: "price" })&.value.presence
        price, currency = override ? [ override, @catalog.currency_code ] : [ product.read_attribute_value("price"), "eur" ]

        csv << [
          item.priority,
          item.catalog_item_state,
          product.sku,
          product.name,
          product.product_type,
          product.product_status,
          product.ean,
          product.labels.map(&:name).join(", "),
          Cents.to_decimal(price),
          (currency.upcase if price.present?),
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
