# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication Flow', type: :request do
  let(:authlift_client) { instance_double(Authlift::Client) }
  let(:company) { create(:company, code: 'ABC123', name: 'ACME Corp') }

  before do
    allow_any_instance_of(SessionsController).to receive(:authlift_client).and_return(authlift_client)
    allow_any_instance_of(ApplicationController).to receive(:authlift_client).and_return(authlift_client)
  end

  describe 'Full OAuth flow integration' do
    let(:auth_url) { 'https://authlift8.test/oauth/authorize?client_id=test&state=abc123' }
    let(:state_token) { 'secure_state_token_123' }
    let(:auth_code) { 'authorization_code_abc' }
    let(:access_token) { 'access_token_xyz' }
    let(:refresh_token) { 'refresh_token_123' }

    let(:oauth_payload) do
      {
        'sub' => 'oauth_user_456',
        'user' => {
          'id' => 789,
          'email' => 'alice@example.com',
          'first_name' => 'Alice',
          'last_name' => 'Smith',
          'locale' => 'en'
        },
        'company' => {
          'id' => company.id,
          'code' => company.code,
          'name' => company.name
        },
        'membership' => {
          'role' => 'admin',
          'scopes' => ['read', 'write', 'delete']
        }
      }
    end

    let(:tokens) do
      {
        access_token: access_token,
        refresh_token: refresh_token,
        id_token: nil, # Authlift8 doesn't use separate id_token
        expires_at: 1.hour.from_now.to_i,
        user_payload: oauth_payload
      }
    end

    before do
      allow(authlift_client).to receive(:authorization_url).and_return(auth_url)
      allow(authlift_client).to receive(:exchange_code).and_return(tokens)
    end

    it 'completes OAuth login successfully' do
      # Step 1: User initiates login
      get auth_login_path
      expect(response).to redirect_to(auth_url)
      follow_redirect!

      # Verify OAuth state is stored in session
      expect(session[:oauth_state]).to be_present
      expect(session[:oauth_initiated_at]).to be_present
      stored_state = session[:oauth_state]

      # Step 2: User returns from Authlift8 with code
      get auth_callback_path, params: { code: auth_code, state: stored_state }
      expect(response).to redirect_to(root_path)

      # Verify user is created/updated
      user = User.find_by(oauth_sub: 'oauth_user_456')
      expect(user).to be_present
      expect(user.email).to eq('alice@example.com')
      expect(user.name).to eq('Alice Smith')

      # Verify session is established
      expect(session[:user_id]).to eq(user.id)
      expect(session[:access_token]).to eq(access_token)
      expect(session[:refresh_token]).to eq(refresh_token)
      expect(session[:company_id]).to eq(company.id)
      expect(session[:role]).to eq('admin')

      # Step 3: User can access protected resources
      get '/'
      expect(response).to be_successful
    end

    it 'handles OAuth error gracefully' do
      get auth_callback_path, params: { error: 'access_denied', error_description: 'User cancelled' }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Authentication was cancelled. Please try again if you want to sign in.')
      expect(session[:user_id]).to be_nil
    end

    it 'validates state token (CSRF protection)' do
      # Initiate OAuth
      get auth_login_path
      stored_state = session[:oauth_state]

      # Try to callback with wrong state
      allow(authlift_client).to receive(:exchange_code)
        .and_raise(Authlift::Client::AuthenticationError, 'State mismatch')

      get auth_callback_path, params: { code: auth_code, state: 'wrong_state' }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Authentication failed. Please try again.')
      expect(session[:user_id]).to be_nil
    end

    it 'enforces state timeout (5 minutes)' do
      # Simulate expired state
      get auth_login_path
      stored_state = session[:oauth_state]

      # Set oauth_initiated_at to 6 minutes ago
      travel_to 6.minutes.ago do
        session[:oauth_initiated_at] = Time.now.to_i
      end

      get auth_callback_path, params: { code: auth_code, state: stored_state }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Authentication session expired. Please try again.')
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'Token refresh during session' do
    let(:user) { create(:user, company: company) }
    let(:new_tokens) do
      {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        expires_at: 1.hour.from_now.to_i
      }
    end

    before do
      # Set up authenticated session with expiring token
      session[:user_id] = user.id
      session[:access_token] = 'old_access_token'
      session[:refresh_token] = 'old_refresh_token'
      session[:authenticated_at] = Time.now.to_i
      session[:expires_at] = 2.minutes.from_now.to_i # Will expire in < 5 minutes
      session[:company_id] = company.id
      session[:company_code] = company.code
      session[:company_name] = company.name

      allow(authlift_client).to receive(:refresh_token).and_return(new_tokens)
    end

    it 'automatically refreshes token on authenticated request' do
      get '/'

      expect(authlift_client).to have_received(:refresh_token).with('old_refresh_token')
      expect(session[:access_token]).to eq('new_access_token')
      expect(session[:refresh_token]).to eq('new_refresh_token')
    end

    context 'when token refresh fails' do
      before do
        allow(authlift_client).to receive(:refresh_token)
          .and_raise(Authlift::Client::AuthenticationError, 'Invalid refresh token')
      end

      it 'logs user out and redirects to login' do
        get '/'

        expect(response).to redirect_to(auth_login_path)
        expect(session[:user_id]).to be_nil
        expect(session[:access_token]).to be_nil
      end
    end
  end

  describe 'Session timeout (24 hours)' do
    let(:user) { create(:user, company: company) }

    before do
      session[:user_id] = user.id
      session[:access_token] = 'valid_token'
      session[:authenticated_at] = 25.hours.ago.to_i
      session[:expires_at] = 1.hour.from_now.to_i
      session[:company_id] = company.id
    end

    it 'logs out user after 24 hours' do
      get '/'

      expect(response).to redirect_to(auth_login_path)
      expect(session[:user_id]).to be_nil
    end
  end

  describe 'Logout' do
    let(:user) { create(:user) }

    before do
      session[:user_id] = user.id
      session[:access_token] = 'access_token'
      session[:company_id] = 123
    end

    it 'clears session and redirects' do
      delete auth_logout_path

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to eq('Successfully signed out.')
      expect(session[:user_id]).to be_nil
      expect(session[:access_token]).to be_nil
    end
  end

  describe 'Return URL after authentication' do
    it 'redirects to stored return URL after login' do
      # Try to access protected page
      get '/products'
      expect(response).to redirect_to(auth_login_path)

      # Login flow
      get auth_login_path
      stored_state = session[:oauth_state]
      expect(session[:return_to]).to eq('/products')

      # Complete OAuth
      get auth_callback_path, params: { code: 'code', state: stored_state }

      expect(response).to redirect_to('/products')
      expect(session[:return_to]).to be_nil
    end

    it 'does not store return URL for XHR requests' do
      get '/products', xhr: true

      expect(session[:return_to]).to be_nil
    end
  end

  describe 'Company context helpers' do
    let(:user) { create(:user, company: company) }

    before do
      session[:user_id] = user.id
      session[:access_token] = 'token'
      session[:authenticated_at] = Time.now.to_i
      session[:expires_at] = 1.hour.from_now.to_i
      session[:company_id] = company.id
      session[:company_code] = company.code
      session[:company_name] = company.name
    end

    it 'provides current_company hash' do
      get '/'

      # We can't directly test the controller helper from request spec,
      # but we can verify session data is set correctly
      expect(session[:company_id]).to eq(company.id)
      expect(session[:company_code]).to eq('ABC123')
      expect(session[:company_name]).to eq('ACME Corp')
    end
  end

  describe 'Multi-company access' do
    let(:company1) { create(:company, code: 'COMP1', name: 'Company 1') }
    let(:company2) { create(:company, code: 'COMP2', name: 'Company 2') }
    let(:user) { create(:user, company: company1) }

    before do
      create(:company_membership, user: user, company: company1, role: 'admin')
      create(:company_membership, user: user, company: company2, role: 'member')
    end

    it 'allows user to access multiple companies' do
      expect(user.accessible_companies).to include(company1, company2)
      expect(user.company_memberships.count).to eq(2)
    end

    it 'maintains different roles per company' do
      admin_membership = user.company_memberships.find_by(company: company1)
      member_membership = user.company_memberships.find_by(company: company2)

      expect(admin_membership.role).to eq('admin')
      expect(member_membership.role).to eq('member')
    end
  end

  describe 'Security considerations' do
    it 'requires authentication for protected routes' do
      get '/'

      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'allows unauthenticated access to OAuth routes' do
      allow(authlift_client).to receive(:authorization_url).and_return('http://auth.test')

      get auth_login_path
      expect(response).to have_http_status(:redirect)
      expect(response).not_to redirect_to(auth_login_path)
    end

    it 'validates JWT tokens are properly decoded' do
      get auth_login_path
      stored_state = session[:oauth_state]

      # Mock invalid token
      allow(authlift_client).to receive(:exchange_code)
        .and_raise(Authlift::Client::TokenValidationError, 'Invalid signature')

      get auth_callback_path, params: { code: 'code', state: stored_state }

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq('Invalid authentication token. Please try again.')
      expect(session[:user_id]).to be_nil
    end
  end
end
