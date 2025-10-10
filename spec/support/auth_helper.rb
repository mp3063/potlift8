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
      scopes: ["read"],
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
