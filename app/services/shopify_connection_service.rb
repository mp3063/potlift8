# frozen_string_literal: true

# ShopifyConnectionService
#
# Orchestrates the connection between a Potlift8 Catalog and a Shopify8 Shop.
# Credentials are stored securely in Shopify8 - Potlift8 only stores the shop_id reference.
#
# Usage:
#   service = ShopifyConnectionService.new(catalog)
#
#   # Connect catalog to Shopify store
#   result = service.connect(
#     shopify_domain: "my-store.myshopify.com",
#     shopify_api_key: "api_key",
#     shopify_password: "api_secret",
#     location_id: "gid://shopify/Location/123"
#   )
#
#   # Check connection status
#   service.connected? # => true
#
#   # Get shop details (with masked credentials)
#   details = service.shop_details
#
#   # Disconnect (removes shop_id from catalog, doesn't delete shop)
#   service.disconnect
#
class ShopifyConnectionService
  # Result struct for service operations
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  attr_reader :catalog, :errors

  # Initialize the service
  #
  # @param catalog [Catalog] The catalog to manage Shopify connection for
  #
  def initialize(catalog)
    @catalog = catalog
    @errors = []
  end

  # Connect catalog to a Shopify store
  #
  # Creates or updates a shop in Shopify8 with the provided credentials,
  # then stores the shop_id reference in the catalog.
  #
  # @param params [Hash] Shopify connection parameters
  # @option params [String] :shopify_domain The Shopify store domain
  # @option params [String] :shopify_api_key The Shopify API key
  # @option params [String] :shopify_password The Shopify API secret/password
  # @option params [String] :location_id The Shopify location ID (optional)
  # @return [Result] Result with shop data or error
  #
  def connect(params)
    validate_params(params)
    return failure_result(@errors.join(", ")) if @errors.any?

    api_result = if connected?
      # Update existing shop
      api_client.update_shop(catalog.shop_id, params)
    else
      # Create new shop
      api_client.create_shop(params)
    end

    if api_result.success?
      shop_data = api_result.data
      update_catalog_shop_reference(shop_data)
      Result.new(success: true, data: shop_data)
    else
      failure_result(api_result.error)
    end
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  # Disconnect catalog from Shopify store
  #
  # Removes the shop_id reference from the catalog.
  # Does NOT delete the shop from Shopify8 (other catalogs may share it).
  #
  # @return [Result] Result indicating success or failure
  #
  def disconnect
    return failure_result("Catalog is not connected to Shopify") unless connected?

    catalog.shop_id = nil
    catalog.info&.delete("shopify_domain_cache")

    if catalog.save
      Result.new(success: true, data: { disconnected: true })
    else
      failure_result(catalog.errors.full_messages.join(", "))
    end
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  # Check if catalog is connected to a Shopify store
  #
  # @return [Boolean] true if connected
  #
  def connected?
    catalog.shopify_connected?
  end

  # Get shop details from Shopify8
  #
  # Returns shop information including masked credential hints
  # for display purposes.
  #
  # @return [Result] Result with shop details or error
  #
  def shop_details
    return failure_result("Catalog is not connected to Shopify") unless connected?

    api_client.get_credentials(catalog.shop_id)
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  # Get the full shop record from Shopify8
  #
  # @return [Result] Result with shop data or error
  #
  def get_shop
    return failure_result("Catalog is not connected to Shopify") unless connected?

    api_client.get_shop(catalog.shop_id)
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  private

  # Validate connection parameters
  #
  # @param params [Hash] Parameters to validate
  #
  def validate_params(params)
    @errors = []
    @errors << "Shopify domain is required" if params[:shopify_domain].blank?
    @errors << "API key is required" if params[:shopify_api_key].blank?
    @errors << "API secret is required" if params[:shopify_password].blank?
  end

  # Update catalog with shop reference
  #
  # @param shop_data [Hash] Shop data from Shopify8 API
  #
  def update_catalog_shop_reference(shop_data)
    catalog.shop_id = shop_data[:id]
    # Cache domain for display without API call
    catalog.info ||= {}
    catalog.info["shopify_domain_cache"] = shop_data[:shopify_domain]
    catalog.save!
  end

  # Build API client for Shopify8
  #
  # Uses the catalog's configured API token or falls back to ENV.
  #
  # @return [Shopify8ApiClient] Configured API client
  #
  def api_client
    @api_client ||= Shopify8ApiClient.new(
      api_token: shopify_api_token
    )
  end

  # Get API token for Shopify8
  #
  # @return [String] API token
  #
  def shopify_api_token
    catalog.info&.dig("shopify_api_token") || ENV.fetch("SHOPIFY8_API_TOKEN", nil)
  end

  # Create failure result
  #
  # @param message [String] Error message
  # @return [Result] Error result
  #
  def failure_result(message)
    Rails.logger.error("[ShopifyConnectionService] #{message}")
    Result.new(success: false, error: message)
  end
end
