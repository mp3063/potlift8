# frozen_string_literal: true

require "faraday"
require "json"

module PotliftApiClient
  # Main client class for interacting with the Potlift8 API
  #
  # @example Initialize client
  #   client = PotliftApiClient::Client.new(
  #     api_token: 'your_api_token',
  #     base_url: 'http://localhost:3246'
  #   )
  #
  # @example List products
  #   products = client.products.list
  #   products.each { |p| puts "#{p['sku']}: #{p['name']}" }
  #
  # @example Get product details
  #   product = client.products.get('PROD001')
  #   puts "Total inventory: #{product['total_saldo']}"
  #
  # @example Update product
  #   client.products.update('PROD001', name: 'New Name', product_status: 'active')
  #
  # @example Update inventory
  #   client.inventories.update('PROD001', [
  #     { storage_code: 'MAIN', value: 150 },
  #     { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
  #   ])
  #
  # @example Create sync task
  #   client.sync_tasks.create(
  #     origin_event_id: 'evt_123',
  #     direction: 'inbound',
  #     event_type: 'product.updated',
  #     key: 'PROD001',
  #     load: { sku: 'PROD001', name: 'Updated Name' }
  #   )
  #
  class Client
    # Base URL for API endpoints
    attr_reader :base_url

    # API token for authentication
    attr_reader :api_token

    # Faraday connection instance
    attr_reader :connection

    # Initialize a new API client
    #
    # @param api_token [String] Your company's API token (required)
    # @param base_url [String] Base URL for the API (default: http://localhost:3246)
    # @param timeout [Integer] Request timeout in seconds (default: 30)
    # @param open_timeout [Integer] Connection timeout in seconds (default: 10)
    #
    # @raise [ArgumentError] if api_token is not provided
    #
    def initialize(api_token:, base_url: "http://localhost:3246", timeout: 30, open_timeout: 10)
      raise ArgumentError, "api_token is required" if api_token.nil? || api_token.empty?

      @api_token = api_token
      @base_url = base_url.chomp("/")
      @connection = build_connection(timeout, open_timeout)
    end

    # Access products API endpoints
    #
    # @return [ProductsResource] Products resource instance
    #
    def products
      @products ||= ProductsResource.new(self)
    end

    # Access inventories API endpoints
    #
    # @return [InventoriesResource] Inventories resource instance
    #
    def inventories
      @inventories ||= InventoriesResource.new(self)
    end

    # Access sync tasks API endpoints
    #
    # @return [SyncTasksResource] Sync tasks resource instance
    #
    def sync_tasks
      @sync_tasks ||= SyncTasksResource.new(self)
    end

    # Make a GET request
    #
    # @param path [String] API endpoint path
    # @param params [Hash] Query parameters
    # @return [Hash, Array] Parsed JSON response
    #
    # @raise [ApiError] on HTTP error
    #
    def get(path, params = {})
      handle_response do
        connection.get(path, params)
      end
    end

    # Make a POST request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash, Array] Parsed JSON response
    #
    # @raise [ApiError] on HTTP error
    #
    def post(path, body = {})
      handle_response do
        connection.post(path, body.to_json)
      end
    end

    # Make a PATCH request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash, Array] Parsed JSON response
    #
    # @raise [ApiError] on HTTP error
    #
    def patch(path, body = {})
      handle_response do
        connection.patch(path, body.to_json)
      end
    end

    # Make a PUT request
    #
    # @param path [String] API endpoint path
    # @param body [Hash] Request body
    # @return [Hash, Array] Parsed JSON response
    #
    # @raise [ApiError] on HTTP error
    #
    def put(path, body = {})
      handle_response do
        connection.put(path, body.to_json)
      end
    end

    # Make a DELETE request
    #
    # @param path [String] API endpoint path
    # @return [Hash, Array] Parsed JSON response
    #
    # @raise [ApiError] on HTTP error
    #
    def delete(path)
      handle_response do
        connection.delete(path)
      end
    end

    private

    # Build Faraday connection with authentication and error handling
    #
    # @param timeout [Integer] Request timeout
    # @param open_timeout [Integer] Connection timeout
    # @return [Faraday::Connection] Configured connection
    #
    def build_connection(timeout, open_timeout)
      Faraday.new(url: "#{base_url}/api/v1") do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.options.timeout = timeout
        f.options.open_timeout = open_timeout
        f.headers["Authorization"] = "Bearer #{api_token}"
        f.headers["Content-Type"] = "application/json"
        f.headers["Accept"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    # Handle API response and raise errors
    #
    # @yield Block that makes the HTTP request
    # @return [Hash, Array] Parsed response body
    #
    # @raise [AuthenticationError] on 401 Unauthorized
    # @raise [NotFoundError] on 404 Not Found
    # @raise [ValidationError] on 422 Unprocessable Entity
    # @raise [ApiError] on other HTTP errors
    #
    def handle_response
      response = yield
      body = response.body

      case response.status
      when 200..299
        body
      when 401
        raise AuthenticationError.new(body["error"] || "Unauthorized", response)
      when 404
        raise NotFoundError.new(body["error"] || "Not found", response)
      when 422
        raise ValidationError.new(body["error"] || "Validation failed", response, body["details"])
      else
        raise ApiError.new(body["error"] || "HTTP #{response.status}", response)
      end
    rescue Faraday::TimeoutError => e
      raise TimeoutError.new("Request timeout: #{e.message}")
    rescue Faraday::ConnectionFailed => e
      raise ConnectionError.new("Connection failed: #{e.message}")
    rescue Faraday::Error => e
      raise ApiError.new("Request failed: #{e.message}")
    end
  end

  # Base resource class
  class Resource
    attr_reader :client

    def initialize(client)
      @client = client
    end
  end

  # Products API resource
  class ProductsResource < Resource
    # List all products
    #
    # @param page [Integer] Page number (default: 1)
    # @param per_page [Integer] Items per page (default: 100, max: 500)
    # @return [Array<Hash>] Array of product hashes
    #
    # @example
    #   products = client.products.list(page: 1, per_page: 50)
    #   products.each { |p| puts p['sku'] }
    #
    def list(page: 1, per_page: 100)
      client.get("/products", { page: page, per_page: per_page })
    end

    # Get product by SKU
    #
    # @param sku [String] Product SKU (case-insensitive)
    # @return [Hash] Product details
    #
    # @raise [NotFoundError] if product not found
    #
    # @example
    #   product = client.products.get('PROD001')
    #   puts "Name: #{product['name']}"
    #   puts "Inventory: #{product['total_saldo']}"
    #
    def get(sku)
      client.get("/products/#{sku}")
    end

    # Update product
    #
    # @param sku [String] Product SKU
    # @param attributes [Hash] Product attributes to update
    # @option attributes [String] :name Product name
    # @option attributes [String] :product_status Product status
    # @option attributes [String] :ean EAN code
    # @option attributes [Hash] :info Metadata
    # @return [Hash] Updated product
    #
    # @raise [NotFoundError] if product not found
    # @raise [ValidationError] if validation fails
    #
    # @example Update name and status
    #   product = client.products.update('PROD001', {
    #     name: 'New Product Name',
    #     product_status: 'active'
    #   })
    #
    # @example Update metadata
    #   product = client.products.update('PROD001', {
    #     info: { thc_content: '23%', cbd_content: '1.2%' }
    #   })
    #
    def update(sku, attributes)
      client.patch("/products/#{sku}", { product: attributes })
    end
  end

  # Inventories API resource
  class InventoriesResource < Resource
    # Update product inventory
    #
    # @param sku [String] Product SKU
    # @param updates [Array<Hash>] Array of inventory updates
    # @option updates [String] :storage_code Storage location code (required)
    # @option updates [Integer] :value Stock quantity (required)
    # @option updates [String] :eta Estimated arrival date (optional, for incoming)
    # @return [Hash] Update response with inventory details
    #
    # @raise [NotFoundError] if product or storage not found
    # @raise [ValidationError] if validation fails
    #
    # @example Update single storage
    #   result = client.inventories.update('PROD001', [
    #     { storage_code: 'MAIN', value: 150 }
    #   ])
    #
    # @example Update multiple storages
    #   result = client.inventories.update('PROD001', [
    #     { storage_code: 'MAIN', value: 120 },
    #     { storage_code: 'INCOMING', value: 50, eta: '2025-10-15' }
    #   ])
    #
    def update(sku, updates)
      client.post("/inventories/update", {
        sku: sku,
        inventory: { updates: updates }
      })
    end
  end

  # Sync Tasks API resource
  class SyncTasksResource < Resource
    # Create sync task
    #
    # @param origin_event_id [String] Unique identifier from originating system
    # @param direction [String] Data flow direction ('inbound' or 'outbound')
    # @param event_type [String] Event type (e.g., 'product.updated')
    # @param key [String] Entity identifier (e.g., SKU)
    # @param load [Hash] Event payload with actual data
    # @return [Hash] Sync task response
    #
    # @raise [ValidationError] if validation fails
    #
    # @example Product update event
    #   result = client.sync_tasks.create(
    #     origin_event_id: 'shopify3_evt_12345',
    #     direction: 'inbound',
    #     event_type: 'product.updated',
    #     key: 'PROD001',
    #     load: { sku: 'PROD001', name: 'Updated Name', price: 3299 }
    #   )
    #
    # @example Inventory sync event
    #   result = client.sync_tasks.create(
    #     origin_event_id: 'm23_inv_67890',
    #     direction: 'inbound',
    #     event_type: 'inventory.updated',
    #     key: 'PROD002',
    #     load: { sku: 'PROD002', storage_code: 'MAIN', value: 250 }
    #   )
    #
    def create(origin_event_id:, direction:, event_type:, key:, load:)
      client.post("/sync_tasks", {
        origin_event_id: origin_event_id,
        direction: direction,
        event_type: event_type,
        key: key,
        load: load
      })
    end
  end

  # Base error class
  class Error < StandardError; end

  # API error with response details
  class ApiError < Error
    attr_reader :response

    def initialize(message, response = nil)
      super(message)
      @response = response
    end

    def status_code
      response&.status
    end
  end

  # Authentication error (401)
  class AuthenticationError < ApiError; end

  # Not found error (404)
  class NotFoundError < ApiError; end

  # Validation error (422) with field details
  class ValidationError < ApiError
    attr_reader :details

    def initialize(message, response = nil, details = nil)
      super(message, response)
      @details = details || {}
    end

    def field_errors
      details
    end
  end

  # Connection error
  class ConnectionError < Error; end

  # Timeout error
  class TimeoutError < Error; end
end
