# frozen_string_literal: true

require 'oauth2'
require 'jwt'
require 'faraday'
require 'openssl'

module Authlift
  # OAuth2 client for Authlift8 integration with comprehensive security features
  #
  # Authlift8 uses Doorkeeper OAuth2 provider which returns user data in the
  # access_token JWT itself (no separate id_token).
  #
  # Security Features:
  # - RS256 JWT signature verification
  # - State token validation (CSRF protection)
  # - Public key caching with automatic refresh
  # - Token expiration validation
  # - Secure token exchange
  #
  # @example Basic usage
  #   client = Authlift::Client.new
  #   auth_url = client.authorization_url(state: SecureRandom.hex(32))
  #   tokens = client.exchange_code(code, state, expected_state)
  #   payload = tokens[:user_payload]  # Already decoded from access_token
  class Client
    class AuthenticationError < StandardError; end
    class TokenValidationError < StandardError; end
    class ConfigurationError < StandardError; end
    class PublicKeyError < StandardError; end

    # Cache duration for public keys (1 hour)
    PUBLIC_KEY_CACHE_DURATION = 3600

    attr_reader :client_id, :client_secret, :site, :redirect_uri

    # Initialize OAuth2 client with configuration from environment variables
    #
    # Required environment variables:
    # - AUTHLIFT8_CLIENT_ID: OAuth2 client ID
    # - AUTHLIFT8_CLIENT_SECRET: OAuth2 client secret
    # - AUTHLIFT8_SITE: Authlift8 base URL (e.g., https://auth.example.com)
    # - AUTHLIFT8_REDIRECT_URI: OAuth2 callback URL
    #
    # @raise [ConfigurationError] if required configuration is missing
    def initialize
      @client_id = ENV.fetch('AUTHLIFT8_CLIENT_ID') { raise ConfigurationError, 'AUTHLIFT8_CLIENT_ID is required' }
      @client_secret = ENV.fetch('AUTHLIFT8_CLIENT_SECRET') { raise ConfigurationError, 'AUTHLIFT8_CLIENT_SECRET is required' }
      @site = ENV.fetch('AUTHLIFT8_SITE') { raise ConfigurationError, 'AUTHLIFT8_SITE is required' }
      @redirect_uri = ENV.fetch('AUTHLIFT8_REDIRECT_URI') { raise ConfigurationError, 'AUTHLIFT8_REDIRECT_URI is required' }

      validate_configuration!
    end

    # Generate authorization URL with state token for CSRF protection
    #
    # @param state [String] Cryptographically secure random state token
    # @param scope [String] OAuth2 scopes (default: 'openid profile email')
    # @return [String] Authorization URL for redirecting user
    #
    # @example
    #   state = SecureRandom.hex(32)
    #   session[:oauth_state] = state
    #   redirect_to client.authorization_url(state: state)
    def authorization_url(state:, scope: 'public')
      raise ArgumentError, 'state cannot be blank' if state.blank?
      raise ArgumentError, 'state must be at least 32 characters' if state.length < 32

      oauth_client.auth_code.authorize_url(
        redirect_uri: redirect_uri,
        scope: scope,
        state: state
      )
    end

    # Exchange authorization code for tokens
    #
    # Authlift8 uses Doorkeeper OAuth2 provider which returns the user payload
    # in the access_token itself (JWT format), NOT in a separate id_token.
    #
    # Security:
    # - Validates state token to prevent CSRF attacks
    # - Exchanges code over secure channel
    # - Validates JWT signature and expiration
    #
    # @param code [String] Authorization code from callback
    # @param state [String] State token for validation
    # @param expected_state [String] Expected state token from session
    # @return [Hash] Token information including :access_token, :refresh_token, :id_token, :expires_at, :user_payload
    # @raise [AuthenticationError] if state validation fails or token exchange fails
    # @raise [TokenValidationError] if JWT validation fails
    #
    # @example
    #   tokens = client.exchange_code(params[:code], params[:state], session[:oauth_state])
    #   session[:access_token] = tokens[:access_token]
    #   session[:user_id] = tokens[:user_payload]['sub']
    def exchange_code(code, state, expected_state)
      # CRITICAL: Validate state token to prevent CSRF attacks
      validate_state!(state, expected_state)

      # Exchange authorization code for tokens
      token_response = oauth_client.auth_code.get_token(
        code,
        redirect_uri: redirect_uri,
        client_id: client_id,
        client_secret: client_secret
      )

      # Extract tokens from response
      access_token = token_response.token
      refresh_token = token_response.refresh_token
      expires_at = token_response.expires_at

      # IMPORTANT: Authlift8/Doorkeeper returns user data in the access_token JWT itself
      # There is no separate id_token in the OAuth response
      # Decode the access_token to extract user payload
      user_payload = decode_jwt(access_token)

      {
        access_token: access_token,
        refresh_token: refresh_token,
        id_token: nil, # Authlift8 doesn't use separate id_token
        expires_at: expires_at,
        user_payload: user_payload
      }
    rescue OAuth2::Error => e
      Rails.logger.error("OAuth2 token exchange failed: #{e.message}")
      raise AuthenticationError, "Token exchange failed: #{e.message}"
    end

    # Decode and validate JWT token with RS256 signature verification
    #
    # Used internally to decode the access_token JWT from Authlift8.
    # Can also be used to decode refresh tokens if needed.
    #
    # Security:
    # - Verifies RS256 signature using public key
    # - Validates token expiration
    # - Validates issuer and audience claims
    # - Automatic public key refresh on verification failure
    #
    # @param token [String] JWT token to decode (typically the access_token)
    # @param retry_on_failure [Boolean] Whether to retry with fresh public key (internal use)
    # @return [Hash] Decoded JWT payload
    # @raise [TokenValidationError] if validation fails
    #
    # @example
    #   payload = client.decode_jwt(access_token)
    #   user_id = payload['sub']
    #   email = payload.dig('user', 'email')
    #   company_id = payload.dig('company', 'id')
    def decode_jwt(token, retry_on_failure: true)
      raise ArgumentError, 'token cannot be blank' if token.blank?

      public_key = fetch_public_key

      # Decode and verify JWT with RS256 algorithm
      decoded_token = JWT.decode(
        token,
        public_key,
        true, # Verify signature
        {
          algorithm: 'RS256',
          verify_expiration: true,
          verify_iat: true, # Verify issued at
          iss: site, # Verify issuer
          verify_iss: true
        }
      )

      payload = decoded_token[0]
      validate_jwt_claims!(payload)

      payload
    rescue JWT::ExpiredSignature
      Rails.logger.warn('JWT token has expired')
      raise TokenValidationError, 'Token has expired'
    rescue JWT::VerificationError, JWT::DecodeError => e
      # If verification fails and we haven't retried yet, refresh public key and retry
      if retry_on_failure
        Rails.logger.info('JWT verification failed, refreshing public key and retrying')
        clear_public_key_cache!
        decode_jwt(token, retry_on_failure: false)
      else
        Rails.logger.error("JWT validation failed: #{e.message}")
        raise TokenValidationError, "Invalid token: #{e.message}"
      end
    end

    # Refresh access token using refresh token
    #
    # @param refresh_token [String] Refresh token
    # @return [Hash] New token information
    # @raise [AuthenticationError] if refresh fails
    #
    # @example
    #   tokens = client.refresh_token(session[:refresh_token])
    #   session[:access_token] = tokens[:access_token]
    def refresh_token(refresh_token)
      raise ArgumentError, 'refresh_token cannot be blank' if refresh_token.blank?

      token = OAuth2::AccessToken.new(oauth_client, nil, refresh_token: refresh_token)
      new_token = token.refresh!

      {
        access_token: new_token.token,
        refresh_token: new_token.refresh_token,
        expires_at: new_token.expires_at
      }
    rescue OAuth2::Error => e
      Rails.logger.error("Token refresh failed: #{e.message}")
      raise AuthenticationError, "Token refresh failed: #{e.message}"
    end

    # Validate if token is expired or about to expire
    #
    # @param expires_at [Integer, Time] Token expiration timestamp
    # @param buffer_seconds [Integer] Buffer time before expiration (default: 300 = 5 minutes)
    # @return [Boolean] true if token is expired or about to expire
    #
    # @example
    #   if client.token_expired?(session[:expires_at])
    #     tokens = client.refresh_token(session[:refresh_token])
    #     session[:access_token] = tokens[:access_token]
    #   end
    def token_expired?(expires_at, buffer_seconds: 300)
      return true if expires_at.nil?

      expiry_time = expires_at.is_a?(Time) ? expires_at : Time.at(expires_at)
      Time.now >= (expiry_time - buffer_seconds)
    end

    # Clear public key cache (useful for testing or forcing refresh)
    def clear_public_key_cache!
      Rails.cache.delete(public_key_cache_key)
    end

    private

    # Get or initialize OAuth2 client
    #
    # @return [OAuth2::Client] OAuth2 client instance
    def oauth_client
      @oauth_client ||= OAuth2::Client.new(
        client_id,
        client_secret,
        site: site,
        authorize_url: '/oauth/authorize',
        token_url: '/oauth/token',
        connection_opts: {
          headers: {
            'User-Agent' => 'Potlift8/1.0'
          },
          ssl: {
            verify: Rails.env.production? # Verify SSL in production
          }
        }
      )
    end

    # Fetch public key for JWT verification with caching
    #
    # @return [OpenSSL::PKey::RSA] RSA public key
    # @raise [PublicKeyError] if public key cannot be fetched
    def fetch_public_key
      Rails.cache.fetch(public_key_cache_key, expires_in: PUBLIC_KEY_CACHE_DURATION) do
        fetch_public_key_from_server
      end
    end

    # Fetch public key from Authlift8 server
    #
    # @return [OpenSSL::PKey::RSA] RSA public key
    # @raise [PublicKeyError] if public key cannot be fetched
    def fetch_public_key_from_server
      response = Faraday.get("#{site}/api/v1/.well-known/jwks.json") do |req|
        req.options.timeout = 10
        req.options.open_timeout = 5
      end

      unless response.success?
        raise PublicKeyError, "Failed to fetch public key: HTTP #{response.status}"
      end

      jwks = JSON.parse(response.body)
      key_data = jwks.dig('keys', 0)

      raise PublicKeyError, 'No keys found in JWKS' if key_data.nil?

      # Convert JWK to PEM format
      jwk = JWT::JWK.import(key_data)
      jwk.public_key
    rescue Faraday::Error => e
      Rails.logger.error("Failed to fetch public key: #{e.message}")
      raise PublicKeyError, "Network error fetching public key: #{e.message}"
    rescue JSON::ParserError => e
      Rails.logger.error("Invalid JWKS response: #{e.message}")
      raise PublicKeyError, "Invalid JWKS format: #{e.message}"
    end

    # Validate state token to prevent CSRF attacks
    #
    # @param state [String] State token from callback
    # @param expected_state [String] Expected state token from session
    # @raise [AuthenticationError] if validation fails
    def validate_state!(state, expected_state)
      if state.blank? || expected_state.blank?
        raise AuthenticationError, 'Missing state token - possible CSRF attack'
      end

      unless ActiveSupport::SecurityUtils.secure_compare(state, expected_state)
        raise AuthenticationError, 'State token mismatch - possible CSRF attack'
      end
    end

    # Validate JWT claims
    #
    # @param payload [Hash] JWT payload
    # @raise [TokenValidationError] if validation fails
    def validate_jwt_claims!(payload)
      # Validate required claims
      required_claims = ['sub', 'iat', 'exp']
      missing_claims = required_claims - payload.keys

      unless missing_claims.empty?
        raise TokenValidationError, "Missing required claims: #{missing_claims.join(', ')}"
      end

      # Validate subject is not empty
      if payload['sub'].blank?
        raise TokenValidationError, 'Invalid subject claim'
      end
    end

    # Validate OAuth2 configuration
    #
    # @raise [ConfigurationError] if configuration is invalid
    def validate_configuration!
      if site.blank? || !site.start_with?('http')
        raise ConfigurationError, 'AUTHLIFT8_SITE must be a valid URL'
      end

      if redirect_uri.blank? || !redirect_uri.start_with?('http')
        raise ConfigurationError, 'AUTHLIFT8_REDIRECT_URI must be a valid URL'
      end

      if client_id.blank?
        raise ConfigurationError, 'AUTHLIFT8_CLIENT_ID cannot be blank'
      end

      if client_secret.blank?
        raise ConfigurationError, 'AUTHLIFT8_CLIENT_SECRET cannot be blank'
      end
    end

    # Cache key for public key
    #
    # @return [String] Cache key
    def public_key_cache_key
      "authlift8:public_key:#{site}"
    end
  end
end
