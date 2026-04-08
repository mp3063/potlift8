# frozen_string_literal: true

require "faraday/retry"

# ProductSyncService
#
# Handles per-product synchronization to Shopify8. This service builds
# complete product payloads including:
# - Product basic data (SKU, name, status, product type)
# - Attribute data with catalog overrides
# - Inventory data (total saldo, max sellable, by warehouse)
# - Catalog-specific information
#
# Sync Target:
# - Shopify8: POST to ENV['SHOPIFY8_URL']/api/v1/sync_tasks
#
# Bizcart sync is NOT handled here — Bizcart expects a full-catalog JSON
# replacement on every push, not per-product events. See BizcartCatalogPushService
# (planned) for the Bizcart path.
#
# Usage:
#   service = ProductSyncService.new(product, catalog)
#   result = service.sync_to_external_system
#
#   if result.success?
#     puts "Synced successfully: #{result.data}"
#   else
#     puts "Sync failed: #{result.error}"
#   end
#
# Error Handling:
# - Network errors (timeouts, connection refused)
# - API errors (4xx, 5xx responses)
# - Data validation errors
# - All errors are logged and returned in result object
#
class ProductSyncService
  # HTTP timeout settings
  CONNECT_TIMEOUT = 10 # seconds
  READ_TIMEOUT = 30    # seconds
  WRITE_TIMEOUT = 30   # seconds

  attr_reader :product, :catalog, :errors

  # Initialize the sync service
  #
  # @param product [Product] The product to sync
  # @param catalog [Catalog] The catalog context (optional)
  #
  def initialize(product, catalog = nil)
    @product = product
    @catalog = catalog
    @errors = []
  end

  # Main sync method - syncs product to external system
  #
  # @return [SyncLockable::SyncLockResult] Result object with success status
  #
  def sync_to_external_system
    validate_prerequisites
    return failure_result("Validation failed: #{@errors.join(', ')}") if @errors.any?

    # Eager load all associations for efficient payload building
    eager_load_product_associations

    payload = build_payload
    target_url = determine_target_url
    sync_target = @catalog.info&.dig("sync_target") || "shopify8"

    return failure_result("No sync target configured for catalog") if target_url.nil?

    Rails.logger.info("[ProductSyncService] Syncing product #{@product.sku} to #{target_url}")

    # Wrap payload in target-specific format
    wrapped_payload = wrap_payload_for_target(payload, sync_target)
    api_token = get_api_token_for_target(sync_target)

    response = send_to_target(target_url, wrapped_payload, api_token)

    if response.success?
      success_result(response.body)
    else
      failure_result("API error: #{response.status} - #{response.body}")
    end

  rescue Faraday::TimeoutError => e
    failure_result("Request timeout: #{e.message}")
  rescue Faraday::ConnectionFailed => e
    failure_result("Connection failed: #{e.message}")
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  # Build the complete payload for sync
  #
  # @return [Hash] Complete product data payload
  #
  def build_payload
    {
      product: build_product_data,
      attributes: build_attributes_payload,
      labels: build_labels_payload,
      assets: build_assets_payload,
      translations: build_translations_payload,
      configurations: build_configurations_payload,
      subproducts: build_subproducts_payload,
      inventory: build_inventory_payload,
      catalog: build_catalog_data,
      sync_metadata: build_sync_metadata
    }.compact
  end

  private

  # Eager load all product associations for efficient payload building
  #
  # Reloads the product with all necessary associations to prevent N+1 queries.
  #
  def eager_load_product_associations
    @product = Product.includes(
      :labels,
      :translations,
      { inventories: :storage },
      { product_assets: { file_attachment: :blob } },
      { product_attribute_values: :product_attribute },
      { configurations: :configuration_values },
      { product_configurations_as_super: {
        subproduct: [ :translations, { inventories: :storage }, { product_attribute_values: :product_attribute } ]
      } }
    ).find(@product.id)
  end

  # Validate prerequisites before syncing
  #
  def validate_prerequisites
    @errors << "Product is required" if @product.nil?
    @errors << "Product must be persisted" if @product.present? && !@product.persisted?

    if @catalog.present?
      @errors << "Catalog must be persisted" unless @catalog.persisted?
      @errors << "Catalog must belong to same company as product" if @product.company_id != @catalog.company_id
    end
  end

  # Build basic product data
  #
  # @return [Hash] Product basic information
  #
  def build_product_data
    {
      id: @product.id,
      sku: @product.sku,
      ean: @product.ean,
      name: @product.name,
      product_type: @product.product_type,
      product_status: @product.product_status,
      configuration_type: @product.configuration_type,
      total_saldo: @product.total_saldo,
      total_max_sellable_saldo: @product.total_max_sellable_saldo
    }
  end

  # Build attributes payload with catalog overrides and localization
  #
  # If a catalog is present, uses catalog-level attribute overrides.
  # Otherwise, uses product-level attribute values.
  # Also includes localized attribute values when present.
  #
  # @return [Hash] Attribute data with values and localized variants
  #
  def build_attributes_payload
    values = {}
    localized = {}

    # Use catalog overrides when available, fall back to product values
    attribute_values = if @catalog.present?
      catalog_item = @catalog.catalog_items.find_by(product: @product)
      catalog_item&.effective_product_attribute_values || @product.product_attribute_values.includes(:product_attribute)
    else
      @product.product_attribute_values.includes(:product_attribute)
    end

    attribute_values.each do |pav|
      pa = pav.product_attribute
      code = pa.code
      values[code] = build_attribute_entry(pa, pav.value.presence || pav.info.to_h.dig("value"))

      localized_value = pav.info.to_h["localized_value"]
      if localized_value.present?
        localized[code] = {
          value: pav.value,
          localized_value: localized_value
        }
      end
    end

    { values: values, localized: localized }
  end

  def build_attribute_entry(product_attribute, value)
    entry = { value: value }
    code_sym = product_attribute.code.to_sym
    registry = SystemAttributes::SYSTEM_ATTRIBUTES[code_sym]

    # Native Shopify field mapping (from registry constant)
    if registry&.dig(:shopify_field)
      entry[:shopify_field] = registry[:shopify_field].to_s
    end

    # Custom handler mapping (special_price, vat_tag, barcode_fallback)
    if registry&.dig(:custom_handler)
      entry[:custom_handler] = registry[:custom_handler].to_s
    end

    # Metafield mapping (from registry or user-configured columns)
    if product_attribute.shopify_metafield_namespace.present?
      entry[:shopify_metafield] = {
        namespace: product_attribute.shopify_metafield_namespace,
        key: product_attribute.shopify_metafield_key,
        type: product_attribute.shopify_metafield_type
      }
    end

    entry[:system] = true if product_attribute.system?
    entry[:unit] = product_attribute.info["unit"] if product_attribute.info&.key?("unit")
    entry
  end

  # Build labels payload
  #
  # Labels include brand, category, campaign, featured, and template types.
  # Each label includes localized values when available.
  #
  # @return [Array<Hash>] Array of label data
  #
  def build_labels_payload
    @product.labels.includes(:parent_label).map do |label|
      {
        label_type: label.label_type,
        code: label.code,
        full_code: label.full_code,
        name: label.name,
        full_name: label.full_name,
        localized_value: label.info.to_h["localized_value"],
        localized_full_value: label.info.to_h["localized_full_value"]
      }.compact
    end
  end

  # Build assets payload
  #
  # Only includes images with public or catalog-only visibility.
  # Generates signed URLs for Shopify8 to fetch.
  #
  # @return [Array<Hash>] Array of asset data with URLs
  #
  def build_assets_payload
    assets = build_product_assets_payload
    return assets if assets.present?

    # Fall back to Active Storage images directly attached to the product
    build_active_storage_images_payload
  end

  def build_product_assets_payload
    @product.product_assets
            .images
            .visible
            .ordered
            .includes(file_attachment: :blob)
            .map do |asset|
      next unless asset.file.attached?

      {
        id: asset.id,
        name: asset.name,
        description: asset.asset_description,
        priority: asset.asset_priority,
        visibility: asset.asset_visibility,
        url: generate_asset_url(asset),
        content_type: asset.file.content_type
      }
    end.compact
  end

  def build_active_storage_images_payload
    return [] unless @product.images.attached?

    @product.images.each_with_index.map do |image, index|
      {
        name: image.filename.to_s,
        priority: @product.images.count - index,
        url: Rails.application.routes.url_helpers.rails_blob_url(
          image,
          host: ENV.fetch("POTLIFT8_HOST", "http://localhost:3246")
        ),
        content_type: image.content_type
      }
    end
  end

  # Build translations payload
  #
  # Organizes translations by locale, with keys for each translated field.
  #
  # @return [Hash] Locale => { key => value } structure
  #
  def build_translations_payload
    translations_hash = {}

    @product.translations.each do |translation|
      translations_hash[translation.locale] ||= {}
      translations_hash[translation.locale][translation.key] = translation.value
    end

    translations_hash.presence
  end

  # Build configurations payload (for configurable products only)
  #
  # Includes variant dimension definitions (Size, Color, etc.) and their values.
  #
  # @return [Array<Hash>, nil] Configuration dimensions or nil if not configurable
  #
  def build_configurations_payload
    return nil unless @product.product_type_configurable?

    @product.configurations
            .includes(:configuration_values)
            .order(:position)
            .map do |config|
      {
        id: config.id,
        code: config.code,
        name: config.name,
        position: config.position,
        values: config.configuration_values.order(:position).map do |cv|
          { id: cv.id, value: cv.value, position: cv.position }
        end
      }
    end
  end

  # Build subproducts payload (for configurable and bundle products)
  #
  # For configurable products: includes variant data with variant_config
  # For bundles: includes component products with quantities
  #
  # @return [Array<Hash>, nil] Subproduct data or nil if no subproducts
  #
  def build_subproducts_payload
    return nil unless @product.product_type_configurable? || @product.product_type_bundle?

    @product.product_configurations_as_super
            .includes(subproduct: [ :translations, :inventories, { product_attribute_values: :product_attribute } ])
            .map do |config|
      subproduct = config.subproduct

      {
        quantity: config.quantity,
        configuration_position: config.configuration_position,
        variant_config: config.info.to_h["variant_config"],
        configuration_details: config.info.to_h["configuration_details"],
        product: {
          id: subproduct.id,
          sku: subproduct.sku,
          ean: subproduct.ean,
          name: subproduct.name,
          product_type: subproduct.product_type,
          product_status: subproduct.product_status
        },
        attributes: build_subproduct_attributes(subproduct),
        inventory: {
          total_saldo: subproduct.total_saldo,
          total_max_sellable_saldo: subproduct.total_max_sellable_saldo,
          single_inventory_with_eta: subproduct.single_inventory_with_eta
        },
        translations: build_subproduct_translations(subproduct)
      }
    end
  end

  # Build enriched attributes for a subproduct (variant)
  #
  # @param subproduct [Product] The subproduct to get attributes for
  # @return [Hash] Enriched attribute entries with mapping info
  #
  def build_subproduct_attributes(subproduct)
    values = {}
    subproduct.product_attribute_values.includes(:product_attribute).each do |pav|
      pa = pav.product_attribute
      values[pa.code] = build_attribute_entry(pa, pav.value.presence || pav.info.to_h.dig("value"))
    end
    values
  end

  # Build translations for a subproduct
  #
  # @param subproduct [Product] The subproduct to get translations for
  # @return [Hash] Locale => { key => value } structure
  #
  def build_subproduct_translations(subproduct)
    translations_hash = {}
    subproduct.translations.each do |translation|
      translations_hash[translation.locale] ||= {}
      translations_hash[translation.locale][translation.key] = translation.value
    end
    translations_hash
  end

  # Generate a signed URL for an asset file
  #
  # @param asset [ProductAsset] The asset with attached file
  # @return [String, nil] The signed URL or nil
  #
  def generate_asset_url(asset)
    return nil unless asset.file.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      asset.file,
      host: ENV.fetch("POTLIFT8_HOST", "http://localhost:3246")
    )
  end

  # Build inventory payload
  #
  # Includes:
  # - Total saldo across all warehouses
  # - Max sellable (respects product type: sellable/configurable/bundle)
  # - Inventory by warehouse (with storage codes and ETAs)
  # - Single inventory with ETA for incoming stock
  #
  # @return [Hash] Inventory data structure
  #
  def build_inventory_payload
    {
      total_saldo: @product.total_saldo,
      total_max_sellable_saldo: @product.total_max_sellable_saldo,
      single_inventory_with_eta: @product.single_inventory_with_eta,
      by_warehouse: build_warehouse_inventory
    }
  end

  # Build warehouse-specific inventory data
  #
  # @return [Array<Hash>] Array of warehouse inventory records
  #
  def build_warehouse_inventory
    @product.inventories.includes(:storage).map do |inventory|
      {
        storage_code: inventory.storage.code,
        storage_name: inventory.storage.name,
        storage_type: inventory.storage.storage_type,
        value: inventory.value,
        eta: inventory.eta,
        default: inventory.storage.default
      }
    end
  end

  # Build catalog data
  #
  # @return [Hash, nil] Catalog information or nil if no catalog
  #
  def build_catalog_data
    return nil unless @catalog.present?

    catalog_item = @catalog.catalog_items.find_by(product: @product)

    {
      id: @catalog.id,
      code: @catalog.code,
      name: @catalog.name,
      catalog_type: @catalog.catalog_type,
      currency_code: @catalog.currency_code,
      catalog_item: catalog_item.present? ? build_catalog_item_data(catalog_item) : nil
    }
  end

  # Build catalog item data
  #
  # @param catalog_item [CatalogItem] The catalog item
  # @return [Hash] Catalog item information
  #
  def build_catalog_item_data(catalog_item)
    {
      id: catalog_item.id,
      catalog_item_state: catalog_item.catalog_item_state,
      priority: catalog_item.priority,
      sales_ready: catalog_item.sales_ready?,
      has_attribute_overrides: catalog_item.has_attribute_overrides?
    }
  end

  # Build sync metadata
  #
  # @return [Hash] Sync timing and version information
  #
  def build_sync_metadata
    {
      synced_at: Time.current.iso8601,
      source_system: "potlift8",
      api_version: "v1"
    }
  end

  # Determine target URL based on catalog's sync_target
  #
  # Shopify8 is the only per-product sync target. Bizcart catalogs are handled
  # via a separate full-catalog push path, not this service.
  #
  # @return [String, nil] Target URL or nil if not configured
  #
  def determine_target_url
    return nil unless @catalog.present?

    shopify8_url
  end

  # Get Shopify8 sync URL
  #
  # @return [String, nil] Shopify8 URL or nil if not configured
  #
  def shopify8_url
    base_url = ENV["SHOPIFY8_URL"]
    return nil if base_url.blank?

    "#{base_url}/api/v1/sync_tasks"
  end

  # Wrap payload in Shopify8 sync_task format
  #
  # @param payload [Hash] Raw product payload
  # @param sync_target [String] Target system (shopify8 only)
  # @return [Hash] Wrapped payload for Shopify8
  #
  def wrap_payload_for_target(payload, sync_target)
    # Shopify8 expects sync_task format with data in info.load.
    # The executor expects a flat structure with sku at the top level.
    load_data = build_shopify_load_data(payload)

    {
      sync_task: {
        shop_id: @catalog.info&.dig("shop_id"),
        event_type: "product_changed",
        origin_event_id: "potlift8_#{@product.id}_#{Time.current.to_i}",
        origin_target_id: @product.sku,
        direction: "inbound",
        info: { load: load_data }
      }
    }
  end

  # Build Shopify-compatible load data structure
  #
  # Shopify8's ProductChangedExecutor expects sku at top level
  #
  # @param payload [Hash] Raw payload from build_payload
  # @return [Hash] Flattened structure for Shopify8
  #
  def build_shopify_load_data(payload)
    product_data = payload[:product] || {}

    {
      # Core product fields at top level
      "sku" => product_data[:sku],
      "ean" => product_data[:ean],
      "name" => product_data[:name],
      "product_type" => product_data[:product_type],
      "product_status" => product_data[:product_status],
      "configuration_type" => product_data[:configuration_type],
      "total_saldo" => product_data[:total_saldo],
      "total_max_sellable_saldo" => product_data[:total_max_sellable_saldo],
      # Nested data preserved
      "attributes" => payload[:attributes],
      "labels" => payload[:labels],
      "assets" => payload[:assets],
      "translations" => payload[:translations],
      "configurations" => payload[:configurations],
      "subproducts" => build_shopify_subproducts(payload[:subproducts]),
      "inventory" => payload[:inventory],
      "catalog" => payload[:catalog],
      "sync_metadata" => payload[:sync_metadata]
    }.compact
  end

  # Build subproducts array with sku at top level for each
  #
  # @param subproducts [Array, nil] Raw subproducts array
  # @return [Array, nil] Transformed subproducts
  #
  def build_shopify_subproducts(subproducts)
    return nil if subproducts.blank?

    subproducts.map do |sub|
      product_info = sub[:product] || {}
      {
        "sku" => product_info[:sku],
        "ean" => product_info[:ean],
        "name" => product_info[:name],
        "product_type" => product_info[:product_type],
        "product_status" => product_info[:product_status],
        "quantity" => sub[:quantity],
        "configuration_position" => sub[:configuration_position],
        "variant_config" => sub[:variant_config],
        "configuration_details" => sub[:configuration_details],
        "attributes" => sub[:attributes],
        "inventory" => sub[:inventory],
        "translations" => sub[:translations]
      }.compact
    end
  end

  # Get API token for target system
  #
  # @param sync_target [String] Target system (shopify8 only)
  # @return [String, nil] API token for authentication
  #
  def get_api_token_for_target(sync_target)
    @catalog.info&.dig("shopify_api_token") || ENV["SHOPIFY8_API_TOKEN"]
  end

  # Send payload to target URL using Faraday with rate limiting
  #
  # @param url [String] Target URL
  # @param payload [Hash] Data to send
  # @param api_token [String, nil] API token for authentication
  # @return [Faraday::Response] HTTP response
  #
  def send_to_target(url, payload, api_token = nil)
    # Apply rate limiting for this catalog
    rate_limiter = build_rate_limiter

    rate_limiter.throttle do
      start_time = Time.current

      connection = Faraday.new(url: url) do |faraday|
        faraday.request :json
        faraday.request :retry, max: 3, interval: 0.5, backoff_factor: 2,
          exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError],
          retry_statuses: [502, 503, 504]
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = READ_TIMEOUT
        faraday.options.open_timeout = CONNECT_TIMEOUT
      end

      Rails.logger.info("[ProductSyncService] Sending payload: #{payload.to_json}")

      response = connection.post do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Accept"] = "application/json"
        req.headers["Authorization"] = "Bearer #{api_token}" if api_token.present?
        req.headers["X-Request-Id"] = Current.request_id || SecureRandom.uuid
        req.body = payload
      end

      api_duration = (Time.current - start_time).round(3)

      Rails.logger.info(
        "[ProductSyncService] Response: #{response.status} - #{response.body.to_s.truncate(200)} " \
        "(API call: #{api_duration}s)"
      )

      # Log slow API calls
      if api_duration > 5.0
        Rails.logger.warn(
          "[ProductSyncService] SLOW API call detected: #{api_duration}s for #{url}"
        )
      end

      response
    end
  rescue RateLimiter::RateLimitExceededError => e
    # Convert rate limit error to retriable error
    Rails.logger.warn("[ProductSyncService] #{e.message}")
    raise e
  end

  # Build rate limiter for catalog
  #
  # @return [RateLimiter] Configured rate limiter
  #
  def build_rate_limiter
    # Get rate limit configuration from catalog or use defaults
    limit = rate_limit_value
    period = rate_limit_period

    rate_key = "sync:#{@catalog.code}"

    RateLimiter.new(rate_key, limit: limit, period: period)
  end

  # Get rate limit value from catalog config or ENV
  #
  # @return [Integer] Maximum requests per period
  #
  def rate_limit_value
    # Check catalog info first
    catalog_limit = @catalog.info&.dig("rate_limit", "limit")
    return catalog_limit.to_i if catalog_limit.present? && catalog_limit.to_i > 0

    # Check ENV for catalog-specific limit
    env_key = "RATE_LIMIT_#{@catalog.code.upcase}"
    env_limit = ENV[env_key]
    return env_limit.to_i if env_limit.present? && env_limit.to_i > 0

    # Default limit
    100
  end

  # Get rate limit period from catalog config or ENV
  #
  # @return [Integer] Time window in seconds
  #
  def rate_limit_period
    # Check catalog info first
    catalog_period = @catalog.info&.dig("rate_limit", "period")
    return catalog_period.to_i if catalog_period.present? && catalog_period.to_i > 0

    # Check ENV for catalog-specific period
    env_key = "RATE_LIMIT_PERIOD_#{@catalog.code.upcase}"
    env_period = ENV[env_key]
    return env_period.to_i if env_period.present? && env_period.to_i > 0

    # Default period (60 seconds)
    60
  end

  # Create success result
  #
  # @param data [Object] Response data
  # @return [SyncLockable::SyncLockResult] Success result
  #
  def success_result(data)
    SyncLockable::SyncLockResult.new(success: true, data: data)
  end

  # Create failure result
  #
  # @param error [String] Error message
  # @return [SyncLockable::SyncLockResult] Failure result
  #
  def failure_result(error)
    Rails.logger.error("[ProductSyncService] #{error}")
    SyncLockable::SyncLockResult.new(success: false, error: error)
  end
end
