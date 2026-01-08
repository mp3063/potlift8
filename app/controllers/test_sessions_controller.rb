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
    session[:company_id] = company.id
    session[:company_code] = company.code
    session[:company_name] = company.name
    session[:role] = params[:role] || 'admin'
    session[:scopes] = params[:scopes] || ['read', 'write']
    session[:access_token] = "test_token_#{SecureRandom.hex(16)}"
    session[:refresh_token] = "test_refresh_#{SecureRandom.hex(16)}"
    session[:expires_at] = 1.hour.from_now.to_i
    session[:authenticated_at] = Time.now.to_i
    session[:customer_groups] = []

    # For GET requests (Selenium), redirect to root or specified URL
    # For POST requests (Rack::Test), return 200 OK
    if request.get?
      redirect_to params[:redirect_to] || root_path
    else
      head :ok
    end
  end
end
