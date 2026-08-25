class SyncTaskProcessor
  attr_reader :company, :errors

  EVENT_TYPES = %w[
    product_update
    inventory_update
    shopify_product_deleted
    shopify_sync_confirmed
    shopify_sync_failed
    shopify_order_created
    shopify_order_fulfilled
  ].freeze

  DIRECTIONS = %w[inbound outbound].freeze

  def initialize(company)
    @company = company
    @errors = []
  end

  def process(origin_event_id:, direction:, event_type:, load:, key: nil)
    validation_error = validate_params(origin_event_id, direction, event_type, load)
    return validation_error if validation_error

    if duplicate_event?(origin_event_id)
      return duplicate_response(origin_event_id, event_type)
    end

    result = case event_type
    when "product_update"
               process_product_update(load, key)
    when "inventory_update"
               process_inventory_update(load, key)
    when "shopify_product_deleted"
               process_shopify_product_deleted(load, key)
    when "shopify_sync_confirmed"
               process_shopify_sync_confirmed(load, key)
    when "shopify_sync_failed"
               process_shopify_sync_failed(load, key)
    when "shopify_order_created"
               process_shopify_order_created(load, key)
    when "shopify_order_fulfilled"
               process_shopify_order_fulfilled(load, key)
    else
               { error: "Unsupported event type: #{event_type}" }
    end

    if result[:error]
      error_response(origin_event_id, event_type, result[:error])
    else
      store_processed_event(origin_event_id)

      success_response(origin_event_id, event_type, result)
    end
  rescue StandardError => e
    Rails.logger.error("SyncTaskProcessor error: #{e.message}\n#{e.backtrace.join("\n")}")
    error_response(origin_event_id, event_type, e.message)
  end

  private

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

    unless load.is_a?(Hash) || load.is_a?(ActionController::Parameters)
      return { success: false, error: "load must be a hash" }
    end

    nil
  end

  def duplicate_event?(origin_event_id)
    redis_key = "sync_task:processed:#{company.id}:#{origin_event_id}"

    begin
      result = redis.exists?(redis_key)
      result.is_a?(Integer) ? result > 0 : result
    rescue Redis::BaseError => e
      Rails.logger.warn("Redis check failed, assuming not duplicate: #{e.message}")
      false
    end
  end

  def store_processed_event(origin_event_id)
    redis_key = "sync_task:processed:#{company.id}:#{origin_event_id}"

    begin
      redis.setex(redis_key, 86400, Time.current.to_i)
    rescue Redis::BaseError => e
      Rails.logger.warn("Failed to store event ID in Redis: #{e.message}")
    end
  end

  def redis
    @redis ||= Redis.new(url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1"))
  end

  def process_product_update(load, key)
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load

    sku = key || load_hash[:sku] || load_hash["sku"]

    unless sku.present?
      return { error: "SKU is required for product_update" }
    end

    product = company.products.find_by(sku: sku)

    unless product
      return { error: "Product not found: #{sku}" }
    end

    update_params = load_hash.slice(:name, :ean, :product_status, :info, "name", "ean", "product_status", "info")

    if product.update(update_params)
      { product_id: product.id, sku: product.sku, updated: true }
    else
      { error: "Failed to update product: #{product.errors.full_messages.join(', ')}" }
    end
  end

  def process_inventory_update(load, key)
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

    service = InventoryUpdateService.new(company, product)
    result = service.update(updates: updates)

    if result[:success]
      { product_id: product.id, sku: product.sku, inventory: result[:inventory] }
    else
      { error: result[:error] }
    end
  end

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

  def process_shopify_order_created(load, key)
    acknowledge_shopify_order(load, key, "created")
  end

  def process_shopify_order_fulfilled(load, key)
    acknowledge_shopify_order(load, key, "fulfilled")
  end

  # Payload is the raw Shopify order webhook JSON wrapped by Shopify8's
  # NotifyPotliftExecutor as { source:, shop:, timestamp:, data: <order json> },
  # so the order ID lives at load.dig("data", "id") with fallbacks to the
  # top-level id and key.
  def acknowledge_shopify_order(load, key, action)
    load_hash = load.is_a?(ActionController::Parameters) ? load.to_unsafe_h : load

    order_id = load_hash.dig("data", "id") || load_hash["id"] || key
    order_number = load_hash.dig("data", "order_number")

    Rails.logger.info(
      "SyncTaskProcessor: acknowledged shopify order #{action} " \
      "(order_id: #{order_id}, order_number: #{order_number})"
    )

    { acknowledged: true, order_id: order_id, order_number: order_number }
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

  def success_response(event_id, event_type, result)
    {
      success: true,
      event_id: event_id,
      event_type: event_type,
      processed_at: Time.current,
      result: result
    }
  end

  def error_response(event_id, event_type, error_message)
    {
      success: false,
      event_id: event_id,
      event_type: event_type,
      error: error_message
    }
  end

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
