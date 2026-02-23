# frozen_string_literal: true

# Shopify8ApiClient
#
# HTTP client for communicating with the Shopify8 REST API.
# Handles shop management operations for connecting catalogs to Shopify stores.
#
# Usage:
#   client = Shopify8ApiClient.new(api_token: "company_api_token")
#
#   # Create a new shop
#   result = client.create_shop(
#     shopify_domain: "my-store.myshopify.com",
#     shopify_api_key: "api_key",
#     shopify_password: "api_secret",
#     location_id: "gid://shopify/Location/123"
#   )
#
#   if result.success?
#     shop_id = result.data[:id]
#   else
#     puts result.error
#   end
#
class Shopify8ApiClient
  # HTTP timeout settings
  CONNECT_TIMEOUT = 10 # seconds
  READ_TIMEOUT = 30    # seconds

  # Result struct for API responses
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  attr_reader :api_token, :base_url

  # Initialize the API client
  #
  # @param api_token [String] API token for authentication (Company.api_token from Shopify8)
  # @param base_url [String] Base URL for Shopify8 API (defaults to ENV)
  #
  def initialize(api_token:, base_url: nil)
    @api_token = api_token
    @base_url = base_url || ENV.fetch("SHOPIFY8_URL", "http://localhost:3245")
  end

  # Create a new shop in Shopify8
  #
  # @param params [Hash] Shop parameters
  # @option params [String] :shopify_domain The Shopify store domain
  # @option params [String] :shopify_api_key The Shopify API key
  # @option params [String] :shopify_password The Shopify API secret/password
  # @option params [String] :location_id The Shopify location ID (optional)
  # @return [Result] Result with shop data or error
  #
  def create_shop(params)
    post("/api/v1/shops", shop: params)
  end

  # Update an existing shop in Shopify8
  #
  # @param shop_id [Integer] The shop ID to update
  # @param params [Hash] Shop parameters to update
  # @return [Result] Result with updated shop data or error
  #
  def update_shop(shop_id, params)
    patch("/api/v1/shops/#{shop_id}", shop: params)
  end

  # Get a shop from Shopify8
  #
  # @param shop_id [Integer] The shop ID to retrieve
  # @return [Result] Result with shop data or error
  #
  def get_shop(shop_id)
    get("/api/v1/shops/#{shop_id}")
  end

  # Get masked credentials for a shop
  #
  # Returns credential hints without exposing actual secrets.
  # Useful for displaying connection status.
  #
  # @param shop_id [Integer] The shop ID
  # @return [Result] Result with masked credentials or error
  #
  def get_credentials(shop_id)
    get("/api/v1/shops/#{shop_id}/credentials")
  end

  # List all shops for the authenticated company
  #
  # @return [Result] Result with array of shops or error
  #
  def list_shops
    get("/api/v1/shops")
  end

  # Fetch data from an arbitrary API path
  #
  # @param path [String] API path (e.g., "/api/v1/sync_tasks?limit=1")
  # @return [Result] Result with response data or error
  #
  def fetch(path)
    get(path)
  end

  private

  # Perform a GET request
  #
  # @param path [String] API endpoint path
  # @return [Result] Result with response data or error
  #
  def get(path)
    response = connection.get(path)
    handle_response(response)
  rescue Faraday::TimeoutError => e
    error_result("Request timeout: #{e.message}")
  rescue Faraday::ConnectionFailed => e
    error_result("Connection failed: #{e.message}")
  rescue StandardError => e
    error_result("Unexpected error: #{e.message}")
  end

  # Perform a POST request
  #
  # @param path [String] API endpoint path
  # @param body [Hash] Request body
  # @return [Result] Result with response data or error
  #
  def post(path, body)
    response = connection.post(path) do |req|
      req.body = body
    end
    handle_response(response)
  rescue Faraday::TimeoutError => e
    error_result("Request timeout: #{e.message}")
  rescue Faraday::ConnectionFailed => e
    error_result("Connection failed: #{e.message}")
  rescue StandardError => e
    error_result("Unexpected error: #{e.message}")
  end

  # Perform a PATCH request
  #
  # @param path [String] API endpoint path
  # @param body [Hash] Request body
  # @return [Result] Result with response data or error
  #
  def patch(path, body)
    response = connection.patch(path) do |req|
      req.body = body
    end
    handle_response(response)
  rescue Faraday::TimeoutError => e
    error_result("Request timeout: #{e.message}")
  rescue Faraday::ConnectionFailed => e
    error_result("Connection failed: #{e.message}")
  rescue StandardError => e
    error_result("Unexpected error: #{e.message}")
  end

  # Build Faraday connection
  #
  # @return [Faraday::Connection] Configured HTTP connection
  #
  def connection
    @connection ||= Faraday.new(url: base_url) do |faraday|
      faraday.request :json
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = READ_TIMEOUT
      faraday.options.open_timeout = CONNECT_TIMEOUT
      faraday.headers["Authorization"] = "Bearer #{api_token}"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["Accept"] = "application/json"
    end
  end

  # Handle API response
  #
  # @param response [Faraday::Response] HTTP response
  # @return [Result] Result with data or error
  #
  def handle_response(response)
    body = response.body

    if response.success?
      # Shopify8 API wraps successful responses in { success: true, data: ... }
      data = body.is_a?(Hash) ? (body["data"] || body) : body
      Result.new(success: true, data: symbolize_keys(data))
    else
      error_message = extract_error_message(body, response.status)
      Result.new(success: false, error: error_message)
    end
  end

  # Extract error message from response body
  #
  # @param body [Hash, String] Response body
  # @param status [Integer] HTTP status code
  # @return [String] Error message
  #
  def extract_error_message(body, status)
    if body.is_a?(Hash)
      body["error"] || body["message"] || "API error (#{status})"
    else
      "API error (#{status}): #{body.to_s.truncate(100)}"
    end
  end

  # Create error result
  #
  # @param message [String] Error message
  # @return [Result] Error result
  #
  def error_result(message)
    Rails.logger.error("[Shopify8ApiClient] #{message}")
    Result.new(success: false, error: message)
  end

  # Deep symbolize keys in hash
  #
  # @param hash [Hash, Array, Object] Object to symbolize
  # @return [Hash, Array, Object] Object with symbolized keys
  #
  def symbolize_keys(obj)
    case obj
    when Hash
      obj.transform_keys(&:to_sym).transform_values { |v| symbolize_keys(v) }
    when Array
      obj.map { |item| symbolize_keys(item) }
    else
      obj
    end
  end
end
