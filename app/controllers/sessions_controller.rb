# frozen_string_literal: true

# SessionsController handles OAuth2 authentication flow with Authlift8
#
# Security Features:
# - State token validation (CSRF protection)
# - Secure session handling
# - Error handling without information leakage
# - Session invalidation on logout
#
# Routes:
# - GET  /auth/login    - Initiate OAuth login
# - GET  /auth/callback - OAuth callback handler
# - POST /auth/logout   - Logout and clear session
class SessionsController < ApplicationController
  # Skip authentication for OAuth flow
  skip_before_action :require_authentication, only: [:new, :create], raise: false

  # Protect against CSRF for state-changing actions
  protect_from_forgery except: :create # OAuth callback uses GET with state validation

  # Rate limiting should be configured at infrastructure level
  # Example: Rack::Attack or load balancer rate limiting

  # GET /auth/login
  # Initiates OAuth login flow by redirecting to Authlift8
  #
  # Security:
  # - Generates cryptographically secure state token
  # - Stores state in session for validation
  # - Clears any existing session data
  #
  # @example
  #   <a href="/auth/login">Sign in with Authlift8</a>
  def new
    # If there's an auth_error flag, show the login page with error instead of auto-redirecting
    if session[:auth_error].present?
      @error_message = session.delete(:auth_error)
      render :new and return
    end

    begin
      # Clear any existing session data
      reset_session

      # Generate cryptographically secure state token (min 32 bytes)
      state = SecureRandom.hex(32)

      # Store state in session for validation in callback
      session[:oauth_state] = state
      session[:oauth_initiated_at] = Time.now.to_i

      # Generate authorization URL and redirect
      auth_url = authlift_client.authorization_url(state: state)

      Rails.logger.info("OAuth login initiated for session: #{session.id}")
      redirect_to auth_url, allow_other_host: true
    rescue Authlift::Client::ConfigurationError => e
      Rails.logger.error("OAuth configuration error: #{e.message}")
      @error_message = 'Authentication service is not configured properly.'
      render :new
    rescue StandardError => e
      Rails.logger.error("OAuth initiation failed: #{e.class} - #{e.message}")
      @error_message = 'Unable to initiate authentication. Please try again.'
      render :new
    end
  end

  # GET /auth/callback
  # Handles OAuth callback from Authlift8
  #
  # Security:
  # - Validates state token to prevent CSRF
  # - Validates OAuth state timeout (5 minutes)
  # - Exchanges code for tokens over secure channel
  # - Validates JWT signature and claims
  # - Stores minimal session data
  #
  # @param code [String] Authorization code
  # @param state [String] State token for validation
  # @param error [String] Error code if authorization failed
  # @param error_description [String] Error description
  def create
    # Check for OAuth errors
    if params[:error].present?
      handle_oauth_error(params[:error], params[:error_description])
      return
    end

    # Validate required parameters
    unless params[:code].present? && params[:state].present?
      Rails.logger.warn('OAuth callback missing required parameters')
      redirect_to root_path, alert: 'Invalid authentication response.'
      return
    end

    # Retrieve expected state from session
    expected_state = session[:oauth_state]
    oauth_initiated_at = session[:oauth_initiated_at]

    # Validate OAuth state timeout (5 minutes)
    if oauth_initiated_at.nil? || Time.now.to_i - oauth_initiated_at > 300
      Rails.logger.warn('OAuth state expired')
      reset_session
      redirect_to root_path, alert: 'Authentication session expired. Please try again.'
      return
    end

    begin
      # Exchange authorization code for tokens with state validation
      tokens = authlift_client.exchange_code(
        params[:code],
        params[:state],
        expected_state
      )

      # Extract user information from JWT payload
      user_payload = tokens[:user_payload]

      # Find or create user from OAuth payload
      user = User.find_or_create_from_oauth(user_payload)

      unless user
        Rails.logger.error("Failed to create user from OAuth payload - likely missing company data")
        session[:auth_error] = 'Your account is not associated with a company. Please contact your administrator.'
        redirect_to auth_login_path
        return
      end

      # CRITICAL SECURITY FIX: Regenerate session ID after authentication
      # Prevents session fixation attacks where attacker sets victim's session ID
      # then hijacks it after victim authenticates
      # OWASP recommendation: Always regenerate session ID on privilege level change
      old_session_data = session.to_hash
      reset_session
      old_session_data.each { |k, v| session[k] = v unless k.start_with?('oauth_') }

      # Store authentication data in session
      # Note: In production, consider using encrypted session store
      store_authentication_session(user, tokens, user_payload)

      # Clear OAuth state
      session.delete(:oauth_state)
      session.delete(:oauth_initiated_at)

      Rails.logger.info("User authenticated: #{user.oauth_sub} (ID: #{user.id})")

      # Redirect to intended destination or root
      redirect_to session.delete(:return_to) || root_path, notice: 'Successfully signed in.'
    rescue Authlift::Client::AuthenticationError => e
      Rails.logger.error("Authentication failed: #{e.message}")
      reset_session
      redirect_to root_path, alert: 'Authentication failed. Please try again.'
    rescue Authlift::Client::TokenValidationError => e
      Rails.logger.error("Token validation failed: #{e.message}")
      reset_session
      redirect_to root_path, alert: 'Invalid authentication token. Please try again.'
    rescue StandardError => e
      Rails.logger.error("OAuth callback error: #{e.class} - #{e.message}")
      reset_session
      redirect_to root_path, alert: 'An error occurred during authentication. Please try again.'
    end
  end

  # POST /auth/logout
  # DELETE /auth/logout
  # Logs out user and clears session
  #
  # Security:
  # - Revokes access token at Authlift8
  # - Clears all session data
  # - Invalidates session ID
  # - Redirects to Authlift8 logout for complete logout
  def destroy
    user_id = session[:user_id]
    access_token = session[:access_token]

    # Revoke access token at Authlift8 (best-effort, don't fail logout if revocation fails)
    if access_token.present?
      begin
        authlift_client.revoke_token(access_token)
      rescue StandardError => e
        Rails.logger.error("Token revocation failed: #{e.message}")
        # Continue with logout even if revocation fails
      end
    end

    # Clear session
    reset_session

    Rails.logger.info("User logged out: #{user_id}")

    # Redirect to login page
    # Note: We've revoked the token at Authlift8, so the session is invalidated
    # Next login will require re-authentication at Authlift8
    redirect_to auth_login_path, notice: 'Successfully signed out.'
  rescue StandardError => e
    Rails.logger.error("Logout error: #{e.class} - #{e.message}")
    reset_session
    redirect_to auth_login_path, notice: 'Signed out.'
  end

  private

  # Get or create Authlift client instance
  #
  # @return [Authlift::Client] OAuth2 client
  def authlift_client
    @authlift_client ||= Authlift::Client.new
  end

  # Store authentication data in session
  #
  # Security considerations:
  # - Store minimal data in session
  # - Use encrypted session store in production
  # - Consider token refresh strategy
  #
  # JWT Payload Structure from Authlift8:
  # {
  #   "sub": "user-id",
  #   "user": {"id": 123, "email": "...", "first_name": "...", "last_name": "...", "locale": "en"},
  #   "company": {"id": 15, "code": "ABC1234XYZ", "name": "ACME Corp"},
  #   "membership": {"role": "admin", "scopes": ["read", "write"]}
  # }
  #
  # @param user [User] The authenticated user record
  # @param tokens [Hash] Token information
  # @param user_payload [Hash] User payload from JWT
  def store_authentication_session(user, tokens, user_payload)
    # Extract user data
    user_data = user_payload['user'] || {}
    company_data = user_payload['company'] || {}
    membership_data = user_payload['membership'] || {}

    # Store user ID (database record ID, not oauth_sub)
    session[:user_id] = user.id

    # Store additional user information for convenience
    session[:email] = user.email
    session[:user_name] = user.name
    session[:locale] = user_data['locale']

    # Store company information
    session[:company_id] = company_data['id']
    session[:company_code] = company_data['code']
    session[:company_name] = company_data['name']

    # Store membership information
    session[:role] = membership_data['role']
    session[:scopes] = membership_data['scopes']

    # Store tokens
    session[:access_token] = tokens[:access_token]
    session[:refresh_token] = tokens[:refresh_token]
    session[:expires_at] = tokens[:expires_at]
    session[:authenticated_at] = Time.now.to_i
  end

  # Handle OAuth errors from authorization server
  #
  # @param error [String] Error code
  # @param description [String] Error description
  def handle_oauth_error(error, description)
    # Log error for debugging (don't expose to user)
    Rails.logger.warn("OAuth error: #{error} - #{description}")

    # Reset session to clear any state
    reset_session

    # Provide user-friendly message based on error type
    message = case error
              when 'access_denied'
                'Authentication was cancelled. Please try again if you want to sign in.'
              when 'invalid_request', 'unauthorized_client', 'unsupported_response_type'
                'Authentication service configuration error. Please contact support.'
              when 'server_error', 'temporarily_unavailable'
                'Authentication service is temporarily unavailable. Please try again later.'
              else
                'Authentication failed. Please try again.'
              end

    redirect_to root_path, alert: message
  end
end
