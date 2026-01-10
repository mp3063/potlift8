# frozen_string_literal: true

# Test-only controller for system test authentication
# This controller is only available in the test environment
# and provides a backdoor for setting up authenticated sessions
# without going through the full OAuth flow.
#
# SECURITY: This controller should NEVER be enabled in production.
# The routes for this controller are only defined when Rails.env.test?
class TestSessionsController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :check_session_version
  skip_forgery_protection # Allow test requests without CSRF token

  # GET/POST /test_login
  # Sets up an authenticated session for system tests
  #
  # @param user_id [Integer] The user's database ID
  # @param role [String] Optional role (default: 'admin')
  # @param redirect_to [String] Optional URL to redirect after login
  # @param access_token [String] Optional custom access token
  # @param refresh_token [String] Optional custom refresh token
  # @param authenticated_at [Integer] Optional custom timestamp (unix epoch)
  # @param expires_at [Integer] Optional custom expiration timestamp (unix epoch)
  # @param company_id [Integer] Optional company ID override
  # @param company_code [String] Optional company code override
  # @param company_name [String] Optional company name override
  def create
    unless Rails.env.test?
      head :not_found
      return
    end

    user = User.find(params[:user_id])
    company = user.company

    # Set up session exactly as SessionsController does
    session[:user_id] = user.id
    session[:email] = user.email
    session[:user_name] = user.name
    session[:company_id] = params[:company_id].present? ? params[:company_id].to_i : company.id
    session[:company_code] = params[:company_code].presence || company.code
    session[:company_name] = params[:company_name].presence || company.name
    session[:role] = params[:role] || 'admin'
    session[:scopes] = params[:scopes] || ['read', 'write']
    session[:access_token] = params[:access_token].presence || "test_token_#{SecureRandom.hex(16)}"
    session[:refresh_token] = params[:refresh_token].presence || "test_refresh_#{SecureRandom.hex(16)}"
    session[:expires_at] = params[:expires_at].present? ? params[:expires_at].to_i : 1.hour.from_now.to_i
    session[:authenticated_at] = params[:authenticated_at].present? ? params[:authenticated_at].to_i : Time.now.to_i
    session[:customer_groups] = []

    # For GET requests (Selenium), redirect to root or specified URL
    # For POST requests (Rack::Test), return 200 OK
    if request.get?
      redirect_to params[:redirect_to] || root_path
    else
      head :ok
    end
  end

  # DELETE /test_logout
  # Clears the authenticated session for system tests
  def destroy
    unless Rails.env.test?
      head :not_found
      return
    end

    reset_session
    head :ok
  end
end
