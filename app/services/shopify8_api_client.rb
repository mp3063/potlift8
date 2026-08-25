# frozen_string_literal: true

class Shopify8ApiClient
  CONNECT_TIMEOUT = 5
  READ_TIMEOUT = 30

  RETRY_OPTIONS = {
    max: 3,
    interval: 0.5,
    backoff_factor: 2,
    exceptions: [Faraday::ConnectionFailed, Faraday::TimeoutError],
    retry_statuses: [502, 503, 504]
  }.freeze

  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  attr_reader :api_token, :base_url

  def initialize(api_token:, base_url: nil)
    @api_token = api_token
    @base_url = base_url || ENV.fetch("SHOPIFY8_URL", "http://localhost:3245")
  end

  def create_shop(params)
    post("/api/v1/shops", shop: params)
  end

  def update_shop(shop_id, params)
    patch("/api/v1/shops/#{shop_id}", shop: params)
  end

  def get_shop(shop_id)
    get("/api/v1/shops/#{shop_id}")
  end

  def get_credentials(shop_id)
    get("/api/v1/shops/#{shop_id}/credentials")
  end

  def list_shops
    get("/api/v1/shops")
  end

  def fetch(path)
    get(path)
  end

  def get_sync_tasks(shop_id:, limit: 5, status: nil)
    params = "shop_id=#{shop_id}&limit=#{limit}"
    params += "&status=#{status}" if status.present?
    get("/api/v1/sync_tasks?#{params}")
  end

  # Fetches recent tasks and aggregates counts client-side
  # to avoid multiple HTTP requests.
  def get_sync_task_summary(shop_id:)
    result = get("/api/v1/sync_tasks?shop_id=#{shop_id}&limit=100")
    return result unless result.success?

    tasks = result.data[:sync_tasks] || []
    counts = { submitted: 0, processing: 0, executed: 0, failed: 0 }
    tasks.each { |t| counts[t[:status]&.to_sym] = (counts[t[:status]&.to_sym] || 0) + 1 }

    Result.new(success: true, data: counts.merge(total: result.data[:total] || tasks.size))
  end

  private

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

  def connection
    @connection ||= Faraday.new(url: base_url) do |faraday|
      faraday.request :json
      faraday.request :retry, RETRY_OPTIONS
      faraday.response :json, content_type: /\bjson$/
      faraday.adapter Faraday.default_adapter
      faraday.options.timeout = READ_TIMEOUT
      faraday.options.open_timeout = CONNECT_TIMEOUT
      faraday.headers["Authorization"] = "Bearer #{api_token}"
      faraday.headers["Content-Type"] = "application/json"
      faraday.headers["Accept"] = "application/json"
      faraday.headers["X-Request-Id"] = Current.request_id || SecureRandom.uuid
    end
  end

  def handle_response(response)
    body = response.body

    if response.success?
      data = body.is_a?(Hash) ? (body["data"] || body) : body
      Result.new(success: true, data: symbolize_keys(data))
    else
      error_message = extract_error_message(body, response.status)
      Result.new(success: false, error: error_message)
    end
  end

  def extract_error_message(body, status)
    if body.is_a?(Hash)
      body["error"] || body["message"] || "API error (#{status})"
    else
      "API error (#{status}): #{body.to_s.truncate(100)}"
    end
  end

  def error_result(message)
    Rails.logger.error("[Shopify8ApiClient] #{message}")
    Result.new(success: false, error: message)
  end

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
