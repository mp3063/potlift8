# frozen_string_literal: true

# Authentication helper for testing
# This module provides utilities for mocking JWT authentication in tests
# without requiring actual Authlift8 API calls.
#
# Usage in tests:
#
#   RSpec.describe SomeController, type: :controller do
#     describe "GET #index" do
#       it "returns success for authenticated user" do
#         sign_in_as(
#           id: 1,
#           email: "user@example.com",
#           first_name: "John",
#           last_name: "Doe",
#           company_id: 123,
#           company_code: "ACME",
#           company_name: "Acme Corp",
#           role: "admin",
#           scopes: ["read", "write"]
#         )
#
#         get :index
#         expect(response).to be_successful
#       end
#     end
#   end
#
# For request specs:
#
#   RSpec.describe "Users API", type: :request do
#     it "returns user data" do
#       token = mock_jwt_token(id: 1, email: "user@example.com")
#
#       get "/api/v1/users", headers: { "Authorization" => "Bearer #{token}" }
#       expect(response).to be_successful
#     end
#   end

module AuthHelper
  # Mock authentication for a user with specified attributes
  # This sets up the session and mocks the Authlift client verification
  #
  # @param user_data [Hash] User attributes to include in JWT payload
  # @option user_data [Integer] :id User ID
  # @option user_data [String] :email User email
  # @option user_data [String] :first_name User first name
  # @option user_data [String] :last_name User last name
  # @option user_data [Integer] :company_id Company ID
  # @option user_data [String] :company_code Company code
  # @option user_data [String] :company_name Company name
  # @option user_data [String] :role User role (e.g., 'admin', 'user')
  # @option user_data [Array<String>] :scopes Permission scopes
  #
  # @return [String] The mocked access token
  def sign_in_as(user_data = {})
    token = mock_jwt_token(user_data)
    session[:access_token] = token
    token
  end

  # Login a user for system tests via test backdoor
  # This visits the test login page which sets up the session
  # properly in the browser via a GET request that triggers a form submission.
  #
  # For Selenium/JS tests, we need to use a GET-based approach since
  # Selenium doesn't support direct POST requests.
  #
  # @param user [User] The user to log in as
  # @param role [String] Optional role override (default: 'admin')
  #
  # @example In a system spec
  #   let(:user) { create(:user) }
  #   before { system_login(user) }
  #
  def system_login(user, role: 'admin')
    # Visit a test login page that will set up the session
    # The test_login route handles this via GET with query params
    visit "/test_login?user_id=#{user.id}&role=#{role}"

    # Wait for the redirect to complete and page to load
    # The test_login controller redirects to root_path after setting session
    expect(page).to have_current_path(root_path, wait: 5)
  end

  # Authenticate user for request specs via POST to test endpoint
  # This properly sets session through an actual HTTP request
  #
  # @param user [User] The user to authenticate
  # @param options [Hash] Optional overrides for session values
  # @option options [Integer] :company_id Override company ID
  # @option options [String] :company_code Override company code
  # @option options [String] :company_name Override company name
  # @option options [String] :role User role (default: 'admin')
  # @option options [Array<String>] :scopes Permission scopes
  # @option options [String] :access_token Custom access token
  # @option options [String] :refresh_token Custom refresh token
  # @option options [Integer] :authenticated_at Timestamp when authenticated
  # @option options [Integer] :expires_at Token expiration timestamp
  #
  # @example Basic usage
  #   authenticate_user(user)
  #
  # @example With custom expiration
  #   authenticate_user(user, expires_at: 2.minutes.from_now.to_i)
  #
  def authenticate_user(user, **options)
    post '/test_login', params: {
      user_id: user.id,
      company_id: options[:company_id],
      company_code: options[:company_code],
      company_name: options[:company_name],
      role: options[:role] || 'admin',
      scopes: options[:scopes],
      access_token: options[:access_token],
      refresh_token: options[:refresh_token],
      authenticated_at: options[:authenticated_at],
      expires_at: options[:expires_at]
    }.compact
  end

  # Authenticate with a token that will expire soon (for refresh tests)
  # @param user [User] The user to authenticate
  # @param expires_in [ActiveSupport::Duration] How long until token expires (default: 2 minutes)
  # @param access_token [String] Access token to use (default: 'test_token_old_access_token')
  # @param refresh_token [String] Refresh token to use (default: 'old_refresh_token')
  def authenticate_with_expiring_token(user, expires_in: 2.minutes, access_token: 'test_token_old_access_token', refresh_token: 'old_refresh_token')
    authenticate_user(user,
      expires_at: expires_in.from_now.to_i,
      authenticated_at: Time.now.to_i,
      access_token: access_token,
      refresh_token: refresh_token
    )
  end

  # Authenticate with a session that has exceeded the 24-hour timeout
  # @param user [User] The user to authenticate
  # @param authenticated_hours_ago [Integer] Hours since authentication (default: 25)
  def authenticate_with_expired_session(user, authenticated_hours_ago: 25)
    authenticate_user(user,
      authenticated_at: authenticated_hours_ago.hours.ago.to_i,
      expires_at: 1.hour.from_now.to_i
    )
  end

  # Generate a mock JWT token with specified user data
  # This token will pass verification when Authlift::Client#verify_token is called
  #
  # @param user_data [Hash] User attributes to include in JWT payload
  # @return [String] The mocked JWT token
  def mock_jwt_token(user_data = {})
    payload = build_jwt_payload(user_data)
    token = "mock_token_#{SecureRandom.hex(16)}"

    # Mock the Authlift client verification
    mock_authlift_verification(token, payload)

    token
  end

  # Sign out the current user by clearing the session
  def sign_out
    session.delete(:access_token)
  end

  # Get the current user data from the session
  # @return [Hash, nil] Current user JWT payload or nil if not signed in
  def current_user_payload
    return nil unless session[:access_token]

    # This would normally call Authlift::Client#verify_token
    # In tests, we return the mocked payload
    @current_user_payload
  end

  private

  # Build a JWT payload with standard structure
  # @param user_data [Hash] User attributes
  # @return [Hash] Complete JWT payload
  def build_jwt_payload(user_data)
    defaults = {
      id: 1,
      email: "test@example.com",
      first_name: "Test",
      last_name: "User",
      company_id: 1,
      company_code: "TEST",
      company_name: "Test Company",
      role: "user",
      scopes: [ "read" ],
      iat: Time.current.to_i,
      exp: 1.hour.from_now.to_i
    }

    defaults.merge(user_data).stringify_keys
  end

  # Mock the Authlift::Client#verify_token method
  # This allows tests to bypass actual JWT verification
  #
  # @param token [String] The mock token
  # @param payload [Hash] The payload to return when token is verified
  def mock_authlift_verification(token, payload)
    @current_user_payload = payload

    # Mock Authlift::Client class if it doesn't exist
    unless defined?(Authlift::Client)
      stub_const("Authlift::Client", Class.new do
        def verify_token(token)
          {}
        end

        def refresh_token(refresh_token)
          {}
        end
      end)
    end

    # Mock the verify_token method to return our payload
    allow_any_instance_of(Authlift::Client).to receive(:verify_token)
      .with(token)
      .and_return(payload)

    # Store the payload for later retrieval
    # This can be accessed in controllers during tests
    @mocked_tokens ||= {}
    @mocked_tokens[token] = payload
  end
end

# Include the auth helper in all controller and request specs
RSpec.configure do |config|
  config.include AuthHelper, type: :controller
  config.include AuthHelper, type: :request
  config.include AuthHelper, type: :system

  # Clean up mocked tokens after each test
  config.after(:each) do
    @mocked_tokens = nil
    @current_user_payload = nil
  end
end
