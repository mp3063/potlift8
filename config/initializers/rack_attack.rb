# Rack::Attack configuration for request throttling and IP blocking
#
# Protects against brute-force attacks, API abuse, and DoS.
# Uses Redis as the cache store for distributed rate limiting.

Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(
  url: ENV.fetch("REDIS_URL", "redis://localhost:6379/1")
)

# --- Safelists ---

# Allow unrestricted access from known internal services (Authlift8, Shopify8, monitoring)
Rack::Attack.safelist("internal") do |req|
  internal_ips = ENV.fetch("INTERNAL_IPS", "127.0.0.1").split(",").map(&:strip)
  internal_ips.include?(req.ip)
end

# --- Throttles ---

# General request throttle: 300 requests per 5 minutes per IP
Rack::Attack.throttle("req/ip", limit: 300, period: 5.minutes) do |req|
  req.ip unless req.path.start_with?("/up")
end

# API endpoint throttle: 60 requests per minute per IP
# Higher than login throttle since inter-service sync (Shopify8) sends bursts
Rack::Attack.throttle("api/ip", limit: 60, period: 1.minute) do |req|
  req.ip if req.path.start_with?("/api/")
end

# Login throttle: 5 attempts per 20 seconds per IP
Rack::Attack.throttle("login/ip", limit: 5, period: 20.seconds) do |req|
  req.ip if req.path == "/auth/login" || req.path == "/auth/callback"
end

# Per-token API throttle: 100 requests per minute per bearer token
# Uses SHA-256 digest so the raw token is never stored in Redis or logged
Rack::Attack.throttle("api/token", limit: 100, period: 1.minute) do |req|
  if req.path.start_with?("/api/") && req.env["HTTP_AUTHORIZATION"].present?
    Digest::SHA256.hexdigest(req.env["HTTP_AUTHORIZATION"])
  end
end

# --- Throttled Response ---

Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"]
  now = match_data[:epoch_time]
  retry_after = match_data[:period] - (now % match_data[:period])

  [
    429,
    { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
    [ { error: "rate_limited", retry_after: retry_after }.to_json ]
  ]
end

# --- Monitoring ---

ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _id, payload|
  req = payload[:request]
  Rails.logger.warn(
    "[Rack::Attack] Throttled #{req.env['rack.attack.match_discriminator']} " \
    "#{req.request_method} #{req.path} from #{req.ip}"
  )
end
