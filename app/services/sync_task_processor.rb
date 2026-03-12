# Sync Task Processor Service
#
# Processes sync tasks received from external systems (M23, Shopify3, Bizcart).
# Handles bidirectional synchronization of product data, inventory, and orders.
#
# Features:
# - Process sync tasks based on event type
# - Support for inbound and outbound sync directions
# - Idempotent processing using origin_event_id
# - Automatic error handling and logging
# - Supports multiple event types (product_update, inventory_update, order_sync, etc.)
#
# Usage:
#   service = SyncTaskProcessor.new(company)
#   result = service.process(
#     origin_event_id: 'evt_123',
#     direction: 'inbound',
#     event_type: 'product_update',
#     load: { sku: 'ABC123', name: 'Updated Product' },
#     key: 'ABC123'
#   )
#
# @example Success response
#   {
#     success: true,
#     event_id: 'evt_123',
#     event_type: 'product_update',
#     processed_at: 2025-10-11T12:00:00Z,
#     result: { product_id: 123, updated: true }
#   }
#
# @example Error response
#   {
#     success: false,
#     event_id: 'evt_123',
#     event_type: 'product_update',
#     error: 'Product not found: ABC123'
#   }
#
class SyncTaskProcessor
  attr_reader :company, :errors

  # Supported event types
  EVENT_TYPES = %w[
    product_update
    product_create
    inventory_update
    order_sync
    catalog_sync
    shopify_product_deleted
    shopify_sync_confirmed
    shopify_sync_failed
  ].freeze

  # Sync directions
  DIRECTIONS = %w[inbound outbound].freeze

  def initialize(company)
    @company = company
    @errors = []
  end

  # Process a sync task
  #
  # @param origin_event_id [String] Unique event identifier from source system
  # @param direction [String] Sync direction ('inbound' or 'outbound')
  # @param event_type [String] Type of event (see EVENT_TYPES)
  # @param load [Hash] Payload data for the event
  # @param key [String] Primary key for the entity (e.g., SKU, order ID)
  #
  # @return [Hash] Result with success status and processing details
  #
  def process(origin_event_id:, direction:, event_type:, load:, key: nil)
    # Validate parameters
    validation_error = validate_params(origin_event_id, direction, event_type, load)
    return validation_error if validation_error

    # Check for duplicate event (idempotency)
    if duplicate_event?(origin_event_id)
      return duplicate_response(origin_event_id, event_type)
    end

    # Process event based on type
    result = case event_type
    when "product_update"
               process_product_update(load, key)
    when "product_create"
               process_product_create(load)
    when "inventory_update"
               process_inventory_update(load, key)
    when "order_sync"
               process_order_sync(load, key)
    when "catalog_sync"
               process_catalog_sync(load, key)
    when "shopify_product_deleted"
               process_shopify_product_deleted(load, key)
    when "shopify_sync_confirmed"
               process_shopify_sync_confirmed(load, key)
    when "shopify_sync_failed"
               process_shopify_sync_failed(load, key)
    else
               { error: "Unsupported event type: #{event_type}" }
    end

    # Build response
    if result[:error]
      error_response(origin_event_id, event_type, result[:error])
    else
      # Store event ID for deduplication
      store_processed_event(origin_event_id)

      success_response(origin_event_id, event_type, result)
    end
  rescue StandardError => e
    Rails.logger.error("SyncTaskProcessor error: #{e.message}\n#{e.backtrace.join("\n")}")
    error_response(origin_event_id, event_type, e.message)
  end

  private

  # Validate processing parameters
  #
  # @return [Hash, nil] Error hash if validation fails, nil if valid
  #
  def validate_params(origin_event_id, direction, event_type, load)
    if origin_event_id.blank?
      return { success: false, error: "origin_event_id is required" }
    end

    unless DIRECTIONS.include?(direction)
      return { success: false, error: "Invalid direction: #{direction}. Must be one of: #{DIRECTIONS.join(', ')}" }
    end

    unless EVENT_TYPES.include?(event_type)
      return { success: false, error: "Invalid event_type: #{event_type}. Must be one of: #{EVENT_TYPES.join(', ')}" }
    end

    # Accept both Hash and ActionController::Parameters
    unless load.is_a?(Hash) || load.is_a?(ActionController::Parameters)
      return { success: false, error: "load must be a hash" }
    end

    nil
  end

  # Check if event has already been processed (idempotency)
  #
  # @param origin_event_id [String] Event ID
  # @return [Boolean] true if event was already processed
  #
  def duplicate_event?(origin_event_id)
    # Use Redis to check for duplicate events (24 hour window)
    redis_key = "sync_task:processed:#{company.id}:#{origin_event_id}"

    begin
      result = redis.exists?(redis_key)
      # Redis 4.x+ returns integer (0 or 1), older versions return boolean
      result.is_a?(Integer) ? result > 0 : result
    rescue Redis::BaseError => e
      Rails.logger.warn("Redis check failed, assuming not duplicate: #{e.message}")
      false
    end
  end

  # Store processed event ID for deduplication
  #
  # @param origin_event_id [String] Event ID
  #
  def store_processed_event(origin_event_id)
    redis_key = "sync_task:processed:#{company.id}:#{origin_event_id}"

    begin
      # Store with 24 hour expiration
      redis.setex(redis_key, 86400, Time.current.to_i)
    rescue Redis::BaseError => e
      Rails.logger.warn("Failed to store event ID in Redis: #{e.message}")
    end
  end

  # Get Redis connection
  #
  # @return [Redis] Redis client instance
  #
  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  # Process product update event
  #
  # @param load [Hash] Product data
  # @param key [String] Product SKU
  # @return [Hash] Result
  #
  def process_product_update(load, key)
    # Convert ActionController::Parameters to hash if needed
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load

    sku = key || load_hash[:sku] || load_hash["sku"]

    unless sku.present?
      return { error: "SKU is required for product_update" }
    end

    product = company.products.find_by(sku: sku)

    unless product
      return { error: "Product not found: #{sku}" }
    end

    # Update product with allowed fields
    update_params = load_hash.slice(:name, :ean, :product_status, :info, "name", "ean", "product_status", "info")

    if product.update(update_params)
      { product_id: product.id, sku: product.sku, updated: true }
    else
      { error: "Failed to update product: #{product.errors.full_messages.join(', ')}" }
    end
  end

  # Process product create event
  #
  # @param load [Hash] Product data
  # @return [Hash] Result
  #
  def process_product_create(load)
    # This is a stub - actual implementation would create products
    # For now, return not implemented
    { error: "Product creation via sync is not yet implemented" }
  end

  # Process inventory update event
  #
  # @param load [Hash] Inventory data
  # @param key [String] Product SKU
  # @return [Hash] Result
  #
  def process_inventory_update(load, key)
    # Convert ActionController::Parameters to hash if needed
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load

    sku = key || load_hash[:sku] || load_hash["sku"]
    updates = load_hash[:updates] || load_hash["updates"]

    unless sku.present?
      return { error: "SKU is required for inventory_update" }
    end

    unless updates.present? && updates.is_a?(Array)
      return { error: "updates array is required for inventory_update" }
    end

    product = company.products.find_by(sku: sku)

    unless product
      return { error: "Product not found: #{sku}" }
    end

    # Use InventoryUpdateService
    service = InventoryUpdateService.new(company, product)
    result = service.update(updates: updates)

    if result[:success]
      { product_id: product.id, sku: product.sku, inventory: result[:inventory] }
    else
      { error: result[:error] }
    end
  end

  # Process order sync event
  #
  # @param load [Hash] Order data
  # @param key [String] Order identifier
  # @return [Hash] Result
  #
  def process_order_sync(load, key)
    # This is a stub - actual implementation would sync orders
    # For now, return not implemented
    { error: "Order sync is not yet implemented" }
  end

  # Process catalog sync event
  #
  # @param load [Hash] Catalog data
  # @param key [String] Catalog identifier
  # @return [Hash] Result
  #
  def process_catalog_sync(load, key)
    # This is a stub - actual implementation would sync catalogs
    # For now, return not implemented
    { error: "Catalog sync is not yet implemented" }
  end

  # Process shopify_product_deleted event
  #
  # Resets sync status on all CatalogItems for the deleted product.
  #
  # @param load [Hash] Payload with SKU in data.sku or top-level sku
  # @param key [String] Product SKU
  # @return [Hash] Result
  #
  def process_shopify_product_deleted(load, key)
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load

    sku = key || load_hash.dig("data", "sku") || load_hash["sku"] || load_hash[:sku]

    unless sku.present?
      return { error: "SKU is required for shopify_product_deleted" }
    end

    product = company.products.find_by(sku: sku)

    unless product
      return { error: "Product not found: #{sku}" }
    end

    reset_count = 0
    product.catalog_items.find_each do |catalog_item|
      catalog_item.update!(
        sync_status: :never_synced,
        last_synced_at: nil,
        last_sync_error: "Product deleted from Shopify"
      )
      reset_count += 1
    end

    { product_id: product.id, sku: product.sku, catalog_items_reset: reset_count }
  end

  def process_shopify_sync_confirmed(load, key)
    update_sync_status_from_callback(load, key, :synced)
  end

  def process_shopify_sync_failed(load, key)
    update_sync_status_from_callback(load, key, :failed)
  end

  def update_sync_status_from_callback(load, key, status)
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load
    data = load_hash["data"] || load_hash

    sku = key || data["sku"]
    catalog_code = data["catalog_code"]

    return { error: "SKU is required" } unless sku.present?
    return { error: "catalog_code is required" } unless catalog_code.present?

    product = company.products.find_by(sku: sku)
    return { error: "Product not found: #{sku}" } unless product

    catalog = company.catalogs.find_by(code: catalog_code)
    return { error: "Catalog not found: #{catalog_code}" } unless catalog

    catalog_item = CatalogItem.find_by(catalog: catalog, product: product)
    return { error: "CatalogItem not found for #{sku} in #{catalog_code}" } unless catalog_item

    attrs = { sync_status: status }
    if status == :synced
      attrs[:last_synced_at] = Time.current
      attrs[:last_sync_error] = nil
    else
      attrs[:last_sync_error] = data["error"]&.truncate(255)
    end

    catalog_item.update!(attrs)
    { product_id: product.id, sku: sku, catalog_code: catalog_code, sync_status: status.to_s }
  end

  # Build success response
  #
  # @param event_id [String] Event ID
  # @param event_type [String] Event type
  # @param result [Hash] Processing result
  # @return [Hash] Success response
  #
  def success_response(event_id, event_type, result)
    {
      success: true,
      event_id: event_id,
      event_type: event_type,
      processed_at: Time.current,
      result: result
    }
  end

  # Build error response
  #
  # @param event_id [String] Event ID
  # @param event_type [String] Event type
  # @param error_message [String] Error message
  # @return [Hash] Error response
  #
  def error_response(event_id, event_type, error_message)
    {
      success: false,
      event_id: event_id,
      event_type: event_type,
      error: error_message
    }
  end

  # Build duplicate event response
  #
  # @param event_id [String] Event ID
  # @param event_type [String] Event type
  # @return [Hash] Duplicate response
  #
  def duplicate_response(event_id, event_type)
    {
      success: true,
      event_id: event_id,
      event_type: event_type,
      duplicate: true,
      message: "Event already processed (idempotent)"
    }
  end
end
