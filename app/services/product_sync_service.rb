# frozen_string_literal: true

# ProductSyncService
#
# Handles synchronization of products to external systems (Shopify3, Bizcart).
# This service builds complete product payloads including:
# - Product basic data (SKU, name, status, product type)
# - Attribute data with catalog overrides
# - Inventory data (total saldo, max sellable, by warehouse)
# - Catalog-specific information
#
# Sync Targets:
# - Shopify3: POST to ENV['SHOPIFY3_URL']/sync_tasks
# - Bizcart: POST to ENV['BIZCART_URL']/api/api/update_catalog
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

    payload = build_payload
    target_url = determine_target_url

    return failure_result("No sync target configured for catalog") if target_url.nil?

    Rails.logger.info("[ProductSyncService] Syncing product #{@product.sku} to #{target_url}")

    response = send_to_target(target_url, payload)

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
      inventory: build_inventory_payload,
      catalog: build_catalog_data,
      sync_metadata: build_sync_metadata
    }
  end

  private

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

  # Build attributes payload with catalog overrides
  #
  # If a catalog is present, uses catalog-level attribute overrides.
  # Otherwise, uses product-level attribute values.
  #
  # @return [Hash] Attribute code => value mapping
  #
  def build_attributes_payload
    return @product.attribute_values_hash unless @catalog.present?

    catalog_item = @catalog.catalog_items.find_by(product: @product)
    return @product.attribute_values_hash unless catalog_item.present?

    # Get effective values (catalog overrides take precedence)
    catalog_item.effective_attribute_values_hash
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
      source_system: 'potlift8',
      api_version: 'v1'
    }
  end

  # Determine target URL based on catalog's sync_target
  #
  # @return [String, nil] Target URL or nil if not configured
  #
  def determine_target_url
    return nil unless @catalog.present?

    case @catalog.info&.dig('sync_target')
    when 'shopify3'
      shopify3_url
    when 'bizcart'
      bizcart_url
    else
      # Default to shopify3 if not specified
      shopify3_url
    end
  end

  # Get Shopify3 sync URL
  #
  # @return [String, nil] Shopify3 URL or nil if not configured
  #
  def shopify3_url
    base_url = ENV['SHOPIFY3_URL']
    return nil if base_url.blank?

    "#{base_url}/sync_tasks"
  end

  # Get Bizcart sync URL
  #
  # @return [String, nil] Bizcart URL or nil if not configured
  #
  def bizcart_url
    base_url = ENV['BIZCART_URL']
    return nil if base_url.blank?

    "#{base_url}/api/api/update_catalog"
  end

  # Send payload to target URL using Faraday with rate limiting
  #
  # @param url [String] Target URL
  # @param payload [Hash] Data to send
  # @return [Faraday::Response] HTTP response
  #
  def send_to_target(url, payload)
    # Apply rate limiting for this catalog
    rate_limiter = build_rate_limiter

    rate_limiter.throttle do
      start_time = Time.current

      connection = Faraday.new(url: url) do |faraday|
        faraday.request :json
        faraday.response :json
        faraday.adapter Faraday.default_adapter
        faraday.options.timeout = READ_TIMEOUT
        faraday.options.open_timeout = CONNECT_TIMEOUT
      end

      Rails.logger.info("[ProductSyncService] Sending payload: #{payload.to_json}")

      response = connection.post do |req|
        req.headers['Content-Type'] = 'application/json'
        req.headers['Accept'] = 'application/json'
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
    catalog_limit = @catalog.info&.dig('rate_limit', 'limit')
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
    catalog_period = @catalog.info&.dig('rate_limit', 'period')
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
