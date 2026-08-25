# frozen_string_literal: true

# Security Features:
# - State token validation (CSRF protection)
# - Secure session handling
# - Error handling without information leakage
# - Session invalidation on logout
class SessionsController < ApplicationController
  skip_before_action :require_authentication, only: [ :new, :create ], raise: false
  skip_before_action :check_session_version, only: [ :new, :create ], raise: false
  skip_after_action :verify_authorized

  protect_from_forgery except: :create

  # Security:
  # - Generates cryptographically secure state token
  # - Stores state in session for validation
  # - Clears any existing session data
  def new
    # If there's an auth_error flag, show the login page with error instead of auto-redirecting
    if session[:auth_error].present?
      @error_message = session.delete(:auth_error)
      render :new and return
    end

    begin
      preserved_return_to = session[:return_to]

      reset_session

      session[:return_to] = preserved_return_to if preserved_return_to.present?

      state = SecureRandom.hex(32)

      session[:oauth_state] = state
      session[:oauth_initiated_at] = Time.now.to_i

      auth_url = authlift_client.authorization_url(state: state)

      Rails.logger.info("OAuth login initiated for session: #{session.id}")
      redirect_to auth_url, allow_other_host: true
    rescue Authlift::Client::ConfigurationError => e
      Rails.logger.error("OAuth configuration error: #{e.message}")
      @error_message = "Authentication service is not configured properly."
      render :new
    rescue StandardError => e
      Rails.logger.error("OAuth initiation failed: #{e.class} - #{e.message}")
      @error_message = "Unable to initiate authentication. Please try again."
      render :new
    end
  end

  # Security:
  # - Validates state token to prevent CSRF
  # - Validates OAuth state timeout (5 minutes)
  # - Exchanges code for tokens over secure channel
  # - Validates JWT signature and claims
  # - Stores minimal session data
  def create
    if params[:error].present?
      handle_oauth_error(params[:error], params[:error_description])
      return
    end

    unless params[:code].present? && params[:state].present?
      Rails.logger.warn("OAuth callback missing required parameters")
      redirect_to root_path, alert: "Invalid authentication response."
      return
    end

    expected_state = session[:oauth_state]
    oauth_initiated_at = session[:oauth_initiated_at]

    if oauth_initiated_at.nil? || Time.now.to_i - oauth_initiated_at > 300
      Rails.logger.warn("OAuth state expired")
      reset_session
      redirect_to root_path, alert: "Authentication session expired. Please try again."
      return
    end

    begin
      tokens = authlift_client.exchange_code(
        params[:code],
        params[:state],
        expected_state
      )

      user_payload = tokens[:user_payload]

      user = User.find_or_create_from_oauth(user_payload)

      unless user
        Rails.logger.error("Failed to create user from OAuth payload - likely missing company data")
        session[:auth_error] = "Your account is not associated with a company. Please contact your administrator."
        redirect_to auth_login_path
        return
      end

      # CRITICAL SECURITY FIX: Regenerate session ID after authentication
      # Prevents session fixation attacks where attacker sets victim's session ID
      # then hijacks it after victim authenticates
      # OWASP recommendation: Always regenerate session ID on privilege level change
      old_session_data = session.to_hash
      reset_session
      old_session_data.each { |k, v| session[k] = v unless k.start_with?("oauth_") }

      # Store authentication data in session
      # Note: In production, consider using encrypted session store
      store_authentication_session(user, tokens, user_payload)

      session.delete(:oauth_state)
      session.delete(:oauth_initiated_at)

      Rails.logger.info("User authenticated: #{user.oauth_sub} (ID: #{user.id})")

      redirect_to session.delete(:return_to) || root_path, notice: "Successfully signed in."
    rescue Authlift::Client::AuthenticationError => e
      Rails.logger.error("Authentication failed: #{e.message}")
      reset_session
      redirect_to root_path, alert: "Authentication failed. Please try again."
    rescue Authlift::Client::TokenValidationError => e
      Rails.logger.error("Token validation failed: #{e.message}")
      reset_session
      redirect_to root_path, alert: "Invalid authentication token. Please try again."
    rescue StandardError => e
      Rails.logger.error("OAuth callback error: #{e.class} - #{e.message}")
      reset_session
      redirect_to root_path, alert: "An error occurred during authentication. Please try again."
    end
  end

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
      end
    end

    reset_session

    Rails.logger.info("User logged out: #{user_id}")

    # Redirect to login page
    # Note: We've revoked the token at Authlift8, so the session is invalidated
    # Next login will require re-authentication at Authlift8
    redirect_to auth_login_path, notice: "Successfully signed out."
  rescue StandardError => e
    Rails.logger.error("Logout error: #{e.class} - #{e.message}")
    reset_session
    redirect_to auth_login_path, notice: "Signed out."
  end

  private

  def authlift_client
    @authlift_client ||= Authlift::Client.new
  end

  # Security considerations:
  # - Store minimal data in session
  # - Use encrypted session store in production
  # - Consider token refresh strategy
  def store_authentication_session(user, tokens, user_payload)
    user_data = user_payload["user"] || {}
    company_data = user_payload["company"] || {}
    membership_data = user_payload["membership"] || {}

    session[:user_id] = user.id

    session[:email] = user.email
    session[:user_name] = user.name
    session[:locale] = user_data["locale"]

    session[:company_id] = company_data["id"]
    session[:company_code] = company_data["code"]
    session[:company_name] = company_data["name"]

    session[:role] = membership_data["role"]
    session[:scopes] = membership_data["scopes"]

    session[:access_token] = tokens[:access_token]
    session[:refresh_token] = tokens[:refresh_token]
    session[:expires_at] = tokens[:expires_at]
    session[:authenticated_at] = Time.now.to_i

    session[:customer_groups] = user_payload["customer_groups"] || []

    SessionVersionChecker.new(session).store_current_versions!
  end

  def handle_oauth_error(error, description)
    # Log error for debugging (don't expose to user)
    Rails.logger.warn("OAuth error: #{error} - #{description}")

    reset_session

    message = case error
    when "access_denied"
                "Authentication was cancelled. Please try again if you want to sign in."
    when "invalid_request", "unauthorized_client", "unsupported_response_type"
                "Authentication service configuration error. Please contact support."
    when "server_error", "temporarily_unavailable"
                "Authentication service is temporarily unavailable. Please try again later."
    else
                "Authentication failed. Please try again."
    end

    redirect_to root_path, alert: message
  end
end
