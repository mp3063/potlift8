class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  include Pagy::Backend

  include Pundit::Authorization

  helper_method :current_user, :current_company, :authenticated?, :current_user_name, :current_potlift_company, :current_customer_groups

  before_action :set_current_request_id

  before_action :require_authentication

  before_action :check_session_version
  before_action :set_paper_trail_whodunnit

  # Pundit safety net — raises if a controller action forgets to authorize.
  # Controllers that don't need authorization (e.g. DashboardController) must
  # call `skip_authorization` or skip these after_actions.
  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  # Override Pundit's default to pass UserContext instead of bare User.
  # This gives policies access to role, scopes, and company.
  def user_for_paper_trail
    current_user&.name || current_user&.email || "System"
  end

  def pundit_user
    @pundit_user ||= UserContext.new(
      current_user,
      session[:role],
      session[:scopes],
      current_potlift_company
    )
  end

  def user_not_authorized
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: "You are not authorized to perform this action.") }
      format.turbo_stream { head :forbidden }
      format.json { render json: { error: "forbidden" }, status: :forbidden }
    end
  end

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
        Rails.logger.warn(
          "[SessionVersion] Refresh failed for user #{session[:user_id]}, forcing re-login"
        )
        reset_session
        redirect_to auth_login_path, alert: "Your session has expired. Please sign in again."
      end
    end
  end

  def current_customer_groups
    return [] unless authenticated?
    session[:customer_groups] || []
  end

  # Security:
  # - Checks for valid session
  # - Validates token expiration
  # - Automatically refreshes expired tokens
  # - Stores return URL for redirect after login
  def require_authentication
    return if authenticated?

    store_location_for_return

    redirect_to auth_login_path, alert: "Please sign in to continue."
  end

  # Security:
  # - Validates session data presence
  # - Enforces 24-hour session timeout
  # - Validates JWT token expiration
  # - Attempts token refresh if expired
  # - Validates token with Authlift8 on refresh
  # - Validates user exists in database (prevents deleted user access)
  def authenticated?
    return false unless session[:user_id].present? && session[:access_token].present?

    # SECURITY FIX: Validate user exists in database BEFORE allowing access
    # This prevents authentication bypass when user is deleted from database
    # but still has valid session cookie
    unless User.exists?(id: session[:user_id])
      Rails.logger.warn("User #{session[:user_id]} not found in database, clearing session")
      reset_session
      return false
    end

    authenticated_at = session[:authenticated_at]
    if authenticated_at.nil? || Time.now.to_i - authenticated_at > 86400
      Rails.logger.info("Session timeout for user: #{session[:user_id]}")
      reset_session
      return false
    end

    # Validate JWT token is still valid (decode will fail if revoked/invalid)
    # Skip JWT validation for test tokens in test environment
    unless Rails.env.test? && session[:access_token]&.start_with?("test_token_")
      begin
        authlift_client.decode_jwt(session[:access_token])
      rescue Authlift::Client::TokenValidationError => e
        Rails.logger.warn("JWT validation failed: #{e.message}")
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
    end

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

  # Security:
  # - Validates user exists in database
  # - Clears session if user record is missing (prevents broken auth state)
  # - Forces re-authentication when user is deleted
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

  def current_user_name
    current_user&.name
  end

  def current_company
    return nil unless authenticated? && session[:company_code].present?

    @current_company ||= {
      id: session[:company_id],
      code: session[:company_code],
      name: session[:company_name]
    }
  end

  # Security:
  # - Validates company exists in database
  # - Clears session if company record is missing (prevents broken auth state)
  # - Forces re-authentication when company is deleted
  # This method:
  # 1. Gets company data from OAuth session (current_company)
  # 2. Syncs with local database using Company.from_authlift8
  # 3. Returns memoized Company model instance
  def current_potlift_company
    return nil unless current_company.present?

    @current_potlift_company ||= begin
      company_data = {
        "id" => session[:company_id],
        "code" => session[:company_code],
        "name" => session[:company_name]
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

  def token_expired?
    expires_at = session[:expires_at]
    return true if expires_at.nil?

    Time.now.to_i >= (expires_at - 300)
  end

  def refresh_access_token
    refresh_token = session[:refresh_token]
    return unless refresh_token.present?

    Rails.logger.info("Refreshing access token for user: #{session[:user_id]}")

    tokens = authlift_client.refresh_token(refresh_token)

    session[:access_token] = tokens[:access_token]
    session[:refresh_token] = tokens[:refresh_token] if tokens[:refresh_token].present?
    session[:expires_at] = tokens[:expires_at]

    Rails.logger.info("Access token refreshed successfully")
  rescue Authlift::Client::AuthenticationError => e
    Rails.logger.error("Token refresh failed, user needs to re-authenticate: #{e.message}")
    raise
  end

  def store_location_for_return
    return unless request.get?
    return if request.xhr? # Don't store AJAX requests
    return if request.path == auth_login_path

    session[:return_to] = request.fullpath
  end

  def authlift_client
    @authlift_client ||= Authlift::Client.new
  end

  def set_current_request_id
    Current.request_id = request.request_id
  end

  def append_info_to_payload(payload)
    super
    payload[:user_id] = current_user&.id
    payload[:company_id] = current_company&.dig(:id)
  end
end
