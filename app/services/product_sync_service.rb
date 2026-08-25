# frozen_string_literal: true

require "faraday/retry"

# Bizcart sync is NOT handled here — Bizcart expects a full-catalog JSON
# replacement on every push, not per-product events. See BizcartCatalogPushService
# (planned) for the Bizcart path.
class ProductSyncService
  CONNECT_TIMEOUT = 10
  READ_TIMEOUT = 30
  WRITE_TIMEOUT = 30

  attr_reader :product, :catalog, :errors

  def initialize(product, catalog = nil)
    @product = product
    @catalog = catalog
    @errors = []
  end

  def sync_to_external_system
    validate_prerequisites
    return failure_result("Validation failed: #{@errors.join(', ')}") if @errors.any?

    eager_load_product_associations

    payload = build_payload
    target_url = determine_target_url
    sync_target = @catalog.info&.dig("sync_target") || "shopify8"

    return failure_result("No sync target configured for catalog") if target_url.nil?

    Rails.logger.info("[ProductSyncService] Syncing product #{@product.sku} to #{target_url}")

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

  # Reloads the product with all necessary associations to prevent N+1 queries.
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

  def validate_prerequisites
    @errors << "Product is required" if @product.nil?
    @errors << "Product must be persisted" if @product.present? && !@product.persisted?

    if @catalog.present?
      @errors << "Catalog must be persisted" unless @catalog.persisted?
      @errors << "Catalog must belong to same company as product" if @product.company_id != @catalog.company_id
    end
  end

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

  # If a catalog is present, uses catalog-level attribute overrides.
  # Otherwise, uses product-level attribute values.
  # Also includes localized attribute values when present.
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

    if registry&.dig(:shopify_field)
      entry[:shopify_field] = registry[:shopify_field].to_s
    end

    # Custom handler mapping (special_price, vat_tag, barcode_fallback)
    if registry&.dig(:custom_handler)
      entry[:custom_handler] = registry[:custom_handler].to_s
    end

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

  def build_translations_payload
    translations_hash = {}

    @product.translations.each do |translation|
      translations_hash[translation.locale] ||= {}
      translations_hash[translation.locale][translation.key] = translation.value
    end

    translations_hash.presence
  end

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

  def build_subproduct_attributes(subproduct)
    values = {}
    subproduct.product_attribute_values.includes(:product_attribute).each do |pav|
      pa = pav.product_attribute
      values[pa.code] = build_attribute_entry(pa, pav.value.presence || pav.info.to_h.dig("value"))
    end
    values
  end

  def build_subproduct_translations(subproduct)
    translations_hash = {}
    subproduct.translations.each do |translation|
      translations_hash[translation.locale] ||= {}
      translations_hash[translation.locale][translation.key] = translation.value
    end
    translations_hash
  end

  def generate_asset_url(asset)
    return nil unless asset.file.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      asset.file,
      host: ENV.fetch("POTLIFT8_HOST", "http://localhost:3246")
    )
  end

  def build_inventory_payload
    {
      total_saldo: @product.total_saldo,
      total_max_sellable_saldo: @product.total_max_sellable_saldo,
      single_inventory_with_eta: @product.single_inventory_with_eta,
      by_warehouse: build_warehouse_inventory
    }
  end

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

  def build_catalog_item_data(catalog_item)
    {
      id: catalog_item.id,
      catalog_item_state: catalog_item.catalog_item_state,
      priority: catalog_item.priority,
      sales_ready: catalog_item.sales_ready?,
      has_attribute_overrides: catalog_item.has_attribute_overrides?
    }
  end

  def build_sync_metadata
    {
      synced_at: Time.current.iso8601,
      source_system: "potlift8",
      api_version: "v1"
    }
  end

  def determine_target_url
    return nil unless @catalog.present?

    shopify8_url
  end

  def shopify8_url
    base_url = ENV["SHOPIFY8_URL"]
    return nil if base_url.blank?

    "#{base_url}/api/v1/sync_tasks"
  end

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

  # Shopify8's ProductChangedExecutor expects sku at top level
  def build_shopify_load_data(payload)
    product_data = payload[:product] || {}

    {
      "sku" => product_data[:sku],
      "ean" => product_data[:ean],
      "name" => product_data[:name],
      "product_type" => product_data[:product_type],
      "product_status" => product_data[:product_status],
      "configuration_type" => product_data[:configuration_type],
      "total_saldo" => product_data[:total_saldo],
      "total_max_sellable_saldo" => product_data[:total_max_sellable_saldo],
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

  def get_api_token_for_target(sync_target)
    @catalog.info&.dig("shopify_api_token") || ENV["SHOPIFY8_API_TOKEN"]
  end

  def send_to_target(url, payload, api_token = nil)
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

      if api_duration > 5.0
        Rails.logger.warn(
          "[ProductSyncService] SLOW API call detected: #{api_duration}s for #{url}"
        )
      end

      response
    end
  rescue RateLimiter::RateLimitExceededError => e
    Rails.logger.warn("[ProductSyncService] #{e.message}")
    raise e
  end

  def build_rate_limiter
    limit = rate_limit_value
    period = rate_limit_period

    rate_key = "sync:#{@catalog.code}"

    RateLimiter.new(rate_key, limit: limit, period: period)
  end

  def rate_limit_value
    catalog_limit = @catalog.info&.dig("rate_limit", "limit")
    return catalog_limit.to_i if catalog_limit.present? && catalog_limit.to_i > 0

    env_key = "RATE_LIMIT_#{@catalog.code.upcase}"
    env_limit = ENV[env_key]
    return env_limit.to_i if env_limit.present? && env_limit.to_i > 0

    100
  end

  def rate_limit_period
    catalog_period = @catalog.info&.dig("rate_limit", "period")
    return catalog_period.to_i if catalog_period.present? && catalog_period.to_i > 0

    env_key = "RATE_LIMIT_PERIOD_#{@catalog.code.upcase}"
    env_period = ENV[env_key]
    return env_period.to_i if env_period.present? && env_period.to_i > 0

    60
  end

  def success_result(data)
    SyncLockable::SyncLockResult.new(success: true, data: data)
  end

  def failure_result(error)
    Rails.logger.error("[ProductSyncService] #{error}")
    SyncLockable::SyncLockResult.new(success: false, error: error)
  end
end
