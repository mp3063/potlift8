class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Include Pagy backend for pagination
  include Pagy::Backend

  # Make authentication helpers available in views
  helper_method :current_user, :current_company, :authenticated?, :current_user_name, :current_potlift_company, :current_customer_groups

  # Enforce authentication for all controllers by default
  # Controllers can skip with: skip_before_action :require_authentication
  before_action :require_authentication

  # Check if session data needs refresh from Authlift8
  # Called after authentication is verified
  before_action :check_session_version

  private

  # Check if session data needs to be refreshed from Authlift8
  #
  # This is called on every authenticated request but is very fast (< 1ms)
  # because it only does a Redis lookup. API call only happens when
  # data has actually changed in Authlift8.
  def check_session_version
    return unless authenticated?

    checker = SessionVersionChecker.new(session)

    if checker.needs_refresh?
      Rails.logger.info(
        "[SessionVersion] Session stale for user #{session[:user_id]}, refreshing"
      )

      unless checker.refresh_session!
        # If refresh fails, invalidate session and force re-login
        Rails.logger.warn(
          "[SessionVersion] Refresh failed for user #{session[:user_id]}, forcing re-login"
        )
        reset_session
        redirect_to auth_login_path, alert: 'Your session has expired. Please sign in again.'
      end
    end
  end

  # Get current customer groups from session
  #
  # @return [Array<Hash>] Array of customer group hashes with id, name, group_type, pricing_rules
  #
  # @example In controller
  #   def index
  #     @customer_groups = current_customer_groups
  #   end
  #
  # @example In view
  #   <% current_customer_groups.each do |group| %>
  #     <p><%= group['name'] %></p>
  #   <% end %>
  def current_customer_groups
    return [] unless authenticated?
    session[:customer_groups] || []
  end

  # Require user to be authenticated
  #
  # Security:
  # - Checks for valid session
  # - Validates token expiration
  # - Automatically refreshes expired tokens
  # - Stores return URL for redirect after login
  #
  # @example Skip authentication for public actions
  #   class PublicController < ApplicationController
  #     skip_before_action :require_authentication
  #   end
  def require_authentication
    return if authenticated?

    # Store the URL the user tried to access
    store_location_for_return

    # Redirect to login
    redirect_to auth_login_path, alert: 'Please sign in to continue.'
  end

  # Check if user is authenticated
  #
  # Security:
  # - Validates session data presence
  # - Enforces 24-hour session timeout
  # - Validates JWT token expiration
  # - Attempts token refresh if expired
  # - Validates token with Authlift8 on refresh
  # - Validates user exists in database (prevents deleted user access)
  #
  # @return [Boolean] true if user has valid session
  def authenticated?
    # Check if session has required authentication data
    return false unless session[:user_id].present? && session[:access_token].present?

    # SECURITY FIX: Validate user exists in database BEFORE allowing access
    # This prevents authentication bypass when user is deleted from database
    # but still has valid session cookie
    unless User.exists?(id: session[:user_id])
      Rails.logger.warn("User #{session[:user_id]} not found in database, clearing session")
      reset_session
      return false
    end

    # Check if session has not timed out (24 hours)
    authenticated_at = session[:authenticated_at]
    if authenticated_at.nil? || Time.now.to_i - authenticated_at > 86400
      Rails.logger.info("Session timeout for user: #{session[:user_id]}")
      reset_session
      return false
    end

    # Validate JWT token is still valid (decode will fail if revoked/invalid)
    begin
      authlift_client.decode_jwt(session[:access_token])
    rescue Authlift::Client::TokenValidationError => e
      Rails.logger.warn("JWT validation failed: #{e.message}")
      # Token may be expired, try refresh
      if session[:refresh_token].present?
        begin
          refresh_access_token
        rescue StandardError => refresh_error
          Rails.logger.error("Token refresh failed: #{refresh_error.message}")
          reset_session
          return false
        end
      else
        reset_session
        return false
      end
    end

    # Additional check: if token is about to expire, refresh proactively
    if token_expired?
      begin
        refresh_access_token
      rescue StandardError => e
        Rails.logger.error("Proactive token refresh failed: #{e.message}")
        reset_session
        return false
      end
    end

    true
  end

  # Get current authenticated user
  #
  # Security:
  # - Validates user exists in database
  # - Clears session if user record is missing (prevents broken auth state)
  # - Forces re-authentication when user is deleted
  #
  # @return [User, nil] User model instance or nil if not authenticated
  #
  # @example In controller
  #   def show
  #     @user_email = current_user.email
  #   end
  #
  # @example In view
  #   <p>Welcome, <%= current_user.name %></p>
  def current_user
    return nil unless authenticated?

    @current_user ||= User.find_by(id: session[:user_id])

    # SECURITY FIX: If user doesn't exist, clear session and force re-authentication
    # This prevents broken authentication state when user is deleted from database
    if @current_user.nil? && session[:user_id].present?
      Rails.logger.warn("User #{session[:user_id]} not found in database, clearing session")
      reset_session
      return nil
    end

    @current_user
  end

  # Get current user's name
  #
  # @return [String, nil] User's name or nil
  def current_user_name
    current_user&.name
  end

  # Get current authenticated user's company information
  #
  # @return [Hash, nil] Company information from session or nil if not authenticated
  #
  # @example In controller
  #   def index
  #     @company_code = current_company[:code]
  #     @company_name = current_company[:name]
  #   end
  #
  # @example In view
  #   <p>Company: <%= current_company[:name] %></p>
  def current_company
    return nil unless authenticated? && session[:company_code].present?

    @current_company ||= {
      id: session[:company_id],
      code: session[:company_code],
      name: session[:company_name]
    }
  end

  # Get current Potlift company model instance
  #
  # Synchronizes company from Authlift8 OAuth provider and returns
  # the local Company model instance for multi-tenancy.
  #
  # Security:
  # - Validates company exists in database
  # - Clears session if company record is missing (prevents broken auth state)
  # - Forces re-authentication when company is deleted
  #
  # This method:
  # 1. Gets company data from OAuth session (current_company)
  # 2. Syncs with local database using Company.from_authlift8
  # 3. Returns memoized Company model instance
  #
  # @return [Company, nil] Company model instance or nil if not authenticated
  #
  # @example In controller
  #   def index
  #     @products = current_potlift_company.products
  #   end
  #
  # @example In view
  #   <p>Company: <%= current_potlift_company.name %></p>
  #
  def current_potlift_company
    return nil unless current_company.present?

    @current_potlift_company ||= begin
      company_data = {
        'id' => session[:company_id],
        'code' => session[:company_code],
        'name' => session[:company_name]
      }
      Company.from_authlift8(company_data)
    end

    # SECURITY FIX: If company doesn't exist, clear session and force re-authentication
    # This prevents broken authentication state when company is deleted from database
    if @current_potlift_company.nil? && current_company.present?
      Rails.logger.warn("Company #{current_company['id']} not found in database, clearing session")
      reset_session
      return nil
    end

    @current_potlift_company
  end

  # Check if access token is expired or about to expire
  #
  # @return [Boolean] true if token should be refreshed
  def token_expired?
    expires_at = session[:expires_at]
    return true if expires_at.nil?

    # Refresh if token expires in less than 5 minutes
    Time.now.to_i >= (expires_at - 300)
  end

  # Refresh access token using refresh token
  #
  # @raise [StandardError] if refresh fails
  def refresh_access_token
    refresh_token = session[:refresh_token]
    return unless refresh_token.present?

    Rails.logger.info("Refreshing access token for user: #{session[:user_id]}")

    tokens = authlift_client.refresh_token(refresh_token)

    # Update session with new tokens
    session[:access_token] = tokens[:access_token]
    session[:refresh_token] = tokens[:refresh_token] if tokens[:refresh_token].present?
    session[:expires_at] = tokens[:expires_at]

    Rails.logger.info("Access token refreshed successfully")
  rescue Authlift::Client::AuthenticationError => e
    Rails.logger.error("Token refresh failed, user needs to re-authenticate: #{e.message}")
    raise
  end

  # Store the current URL for redirect after authentication
  def store_location_for_return
    return unless request.get?
    return if request.xhr? # Don't store AJAX requests
    return if request.path == auth_login_path

    session[:return_to] = request.fullpath
  end

  # Get or create Authlift client instance
  #
  # @return [Authlift::Client] OAuth2 client
  def authlift_client
    @authlift_client ||= Authlift::Client.new
  end
end
