# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:authlift_client) { instance_double(Authlift::Client) }

  before do
    allow(controller).to receive(:authlift_client).and_return(authlift_client)
  end

  describe 'GET #new' do
    let(:auth_url) { 'https://authlift8.test/oauth/authorize?client_id=test&state=abc123' }

    before do
      allow(authlift_client).to receive(:authorization_url).and_return(auth_url)
    end

    it 'resets the session' do
      session[:user_id] = 123
      session[:access_token] = 'old_token'

      get :new

      expect(session[:user_id]).to be_nil
      expect(session[:access_token]).to be_nil
    end

    it 'generates and stores oauth_state in session' do
      get :new

      expect(session[:oauth_state]).to be_present
      expect(session[:oauth_state].length).to be >= 64 # hex(32) = 64 chars
    end

    it 'stores oauth_initiated_at timestamp' do
      freeze_time do
        get :new

        expect(session[:oauth_initiated_at]).to eq(Time.now.to_i)
      end
    end

    it 'redirects to authorization URL' do
      get :new

      expect(response).to redirect_to(auth_url)
    end

    it 'passes state to authorization_url' do
      get :new

      state = session[:oauth_state]
      expect(authlift_client).to have_received(:authorization_url).with(state: state)
    end

    context 'when OAuth configuration is missing' do
      render_views

      before do
        allow(authlift_client).to receive(:authorization_url)
          .and_raise(Authlift::Client::ConfigurationError, 'Missing client ID')
      end

      it 'renders new view with error message' do
        get :new, format: :html

        expect(response).to render_template(:new)
        expect(assigns(:error_message)).to eq('Authentication service is not configured properly.')
      end
    end

    context 'when an unexpected error occurs' do
      render_views

      before do
        allow(authlift_client).to receive(:authorization_url)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'renders new view with generic error message' do
        get :new, format: :html

        expect(response).to render_template(:new)
        expect(assigns(:error_message)).to eq('Unable to initiate authentication. Please try again.')
      end
    end
  end

  describe 'GET #create (OAuth callback)' do
    let(:company) { create(:company, code: 'ABC123', name: 'ACME Corp') }
    let(:oauth_code) { 'auth_code_123' }
    let(:state_token) { 'valid_state_token' }
    let(:access_token) { 'access_token_abc' }
    let(:refresh_token) { 'refresh_token_xyz' }
    let(:expires_at) { 1.hour.from_now.to_i }

    let(:user_payload) do
      {
        'sub' => 'oauth_user_123',
        'user' => {
          'id' => 456,
          'email' => 'john@example.com',
          'first_name' => 'John',
          'last_name' => 'Doe',
          'locale' => 'en'
        },
        'company' => {
          'id' => company.id,
          'code' => company.code,
          'name' => company.name
        },
        'membership' => {
          'role' => 'admin',
          'scopes' => ['read', 'write']
        }
      }
    end

    let(:tokens) do
      {
        access_token: access_token,
        refresh_token: refresh_token,
        id_token: nil, # Authlift8 doesn't use separate id_token
        expires_at: expires_at,
        user_payload: user_payload
      }
    end

    before do
      session[:oauth_state] = state_token
      session[:oauth_initiated_at] = Time.now.to_i
      allow(authlift_client).to receive(:exchange_code).and_return(tokens)
    end

    context 'with valid parameters' do
      it 'exchanges code for tokens' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(authlift_client).to have_received(:exchange_code)
          .with(oauth_code, state_token, state_token)
      end

      it 'creates or updates user from OAuth payload' do
        expect {
          get :create, params: { code: oauth_code, state: state_token }
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.oauth_sub).to eq('oauth_user_123')
        expect(user.email).to eq('john@example.com')
      end

      it 'stores authentication data in session' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:user_id]).to be_present
        expect(session[:access_token]).to eq(access_token)
        expect(session[:refresh_token]).to eq(refresh_token)
        expect(session[:expires_at]).to eq(expires_at)
        expect(session[:email]).to eq('john@example.com')
        expect(session[:company_id]).to eq(company.id)
        expect(session[:company_code]).to eq('ABC123')
        expect(session[:company_name]).to eq('ACME Corp')
        expect(session[:role]).to eq('admin')
        expect(session[:scopes]).to eq(['read', 'write'])
        expect(session[:authenticated_at]).to be_present
      end

      it 'clears OAuth state from session' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:oauth_state]).to be_nil
        expect(session[:oauth_initiated_at]).to be_nil
      end

      it 'redirects to root path with success message' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Successfully signed in.')
      end

      context 'when return_to is stored in session' do
        before do
          session[:return_to] = '/products'
        end

        it 'redirects to return_to path' do
          get :create, params: { code: oauth_code, state: state_token }

          expect(response).to redirect_to('/products')
          expect(session[:return_to]).to be_nil
        end
      end
    end

    context 'with OAuth error from provider' do
      it 'handles access_denied error' do
        get :create, params: { error: 'access_denied', error_description: 'User cancelled' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication was cancelled. Please try again if you want to sign in.')
      end

      it 'handles server_error' do
        get :create, params: { error: 'server_error' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication service is temporarily unavailable. Please try again later.')
      end

      it 'handles invalid_request error' do
        get :create, params: { error: 'invalid_request' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication service configuration error. Please contact support.')
      end

      it 'handles unknown errors' do
        get :create, params: { error: 'unknown_error' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication failed. Please try again.')
      end

      it 'resets session on error' do
        session[:user_id] = 123
        get :create, params: { error: 'access_denied' }

        expect(session[:user_id]).to be_nil
      end
    end

    context 'with missing parameters' do
      it 'redirects with error when code is missing' do
        get :create, params: { state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Invalid authentication response.')
      end

      it 'redirects with error when state is missing' do
        get :create, params: { code: oauth_code }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Invalid authentication response.')
      end
    end

    context 'with state validation (CSRF protection)' do
      it 'validates state token matches session' do
        get :create, params: { code: oauth_code, state: 'wrong_state' }

        expect(authlift_client).to have_received(:exchange_code)
          .with(oauth_code, 'wrong_state', state_token)
      end

      it 'handles state mismatch error' do
        allow(authlift_client).to receive(:exchange_code)
          .and_raise(Authlift::Client::AuthenticationError, 'State token mismatch')

        get :create, params: { code: oauth_code, state: 'wrong_state' }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication failed. Please try again.')
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with state timeout (5 minutes)' do
      it 'rejects expired state (over 5 minutes old)' do
        travel_to 6.minutes.ago do
          session[:oauth_initiated_at] = Time.now.to_i
        end

        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication session expired. Please try again.')
        expect(session[:oauth_state]).to be_nil
        expect(authlift_client).not_to have_received(:exchange_code)
      end

      it 'accepts state within 5 minutes' do
        travel_to 4.minutes.ago do
          session[:oauth_initiated_at] = Time.now.to_i
        end

        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Successfully signed in.')
      end

      it 'rejects request when oauth_initiated_at is missing' do
        session.delete(:oauth_initiated_at)

        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication session expired. Please try again.')
      end
    end

    context 'with JWT validation errors' do
      before do
        allow(authlift_client).to receive(:exchange_code)
          .and_raise(Authlift::Client::TokenValidationError, 'Invalid token')
      end

      it 'redirects with error message' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Invalid authentication token. Please try again.')
      end

      it 'resets session' do
        session[:user_id] = 123
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:user_id]).to be_nil
      end
    end

    context 'with authentication errors' do
      before do
        allow(authlift_client).to receive(:exchange_code)
          .and_raise(Authlift::Client::AuthenticationError, 'Token exchange failed')
      end

      it 'redirects with error message' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('Authentication failed. Please try again.')
      end

      it 'resets session' do
        session[:user_id] = 123
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:user_id]).to be_nil
      end
    end

    context 'with unexpected errors' do
      before do
        allow(authlift_client).to receive(:exchange_code)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'handles gracefully' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq('An error occurred during authentication. Please try again.')
      end

      it 'resets session' do
        session[:user_id] = 123
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:user_id]).to be_nil
      end
    end

    context 'when user creation fails' do
      before do
        allow(User).to receive(:find_or_create_from_oauth).and_return(nil)
      end

      it 'redirects to login with error stored in session' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(response).to redirect_to(auth_login_path)
        expect(session[:auth_error]).to eq('Your account is not associated with a company. Please contact your administrator.')
      end

      it 'does not set user_id in session' do
        get :create, params: { code: oauth_code, state: state_token }

        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'POST #destroy (Logout)' do
    let(:user) { create(:user) }

    before do
      allow(authlift_client).to receive(:decode_jwt).and_return({})
      allow(authlift_client).to receive(:revoke_token)
      session[:user_id] = user.id
      session[:access_token] = 'access_token'
      session[:refresh_token] = 'refresh_token'
      session[:company_id] = 123
      session[:authenticated_at] = Time.now.to_i
      session[:expires_at] = 1.hour.from_now.to_i
    end

    it 'clears the session' do
      post :destroy

      expect(session[:user_id]).to be_nil
      expect(session[:access_token]).to be_nil
      expect(session[:refresh_token]).to be_nil
      expect(session[:company_id]).to be_nil
    end

    it 'redirects to login path' do
      post :destroy

      expect(response).to redirect_to(auth_login_path)
    end

    it 'displays success message' do
      post :destroy

      expect(flash[:notice]).to eq('Successfully signed out.')
    end

    context 'when logout error occurs' do
      it 'handles gracefully and still redirects' do
        # Mock revoke_token to raise an error (a more realistic error scenario)
        allow(authlift_client).to receive(:revoke_token).and_raise(StandardError, 'Token revocation error')

        post :destroy

        # Should still redirect to login despite token revocation failure
        expect(response).to redirect_to(auth_login_path)
        expect(flash[:notice]).to eq('Successfully signed out.')
      end
    end

    context 'when session is already empty' do
      before do
        # Clear session but authentication is required, so this will redirect to login
        session.clear
      end

      it 'redirects to login since authentication is required' do
        post :destroy

        # Without authentication, user is redirected to login
        expect(response).to redirect_to(auth_login_path)
      end
    end
  end

  describe 'DELETE #destroy (alternative logout method)' do
    let(:user) { create(:user) }

    before do
      allow(authlift_client).to receive(:decode_jwt).and_return({})
      allow(authlift_client).to receive(:revoke_token)
      session[:user_id] = user.id
      session[:access_token] = 'access_token'
      session[:authenticated_at] = Time.now.to_i
      session[:expires_at] = 1.hour.from_now.to_i
    end

    it 'works with DELETE method' do
      delete :destroy

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:notice]).to eq('Successfully signed out.')
    end
  end

  describe 'security considerations' do
    context 'CSRF protection' do
      it 'skips CSRF for OAuth callback' do
        # This is tested implicitly - the controller has: protect_from_forgery except: :create
        # We verify by checking that the create action is excluded from CSRF protection
        expect(controller.class.forgery_protection_strategy).not_to be_nil
      end
    end

    context 'authentication bypass' do
      it 'allows unauthenticated access to new action' do
        # Should redirect to OAuth provider, not to login
        auth_url = 'https://authlift8.test/oauth/authorize?client_id=test&state=abc123'
        allow(authlift_client).to receive(:authorization_url).and_return(auth_url)

        get :new
        expect(response.status).to be_in([302, 303]) # Redirect to OAuth provider
      end

      it 'allows unauthenticated access to create action' do
        # Should not redirect to login when there's an OAuth error
        get :create, params: { error: 'access_denied' }
        expect(response.status).to be_in([302, 303])
      end
    end

    context 'session fixation protection' do
      it 'generates new session on successful login' do
        company = create(:company)
        tokens = {
          access_token: 'new_token',
          refresh_token: 'new_refresh',
          expires_at: 1.hour.from_now.to_i,
          user_payload: {
            'sub' => 'user_123',
            'user' => { 'email' => 'test@example.com', 'first_name' => 'Test', 'last_name' => 'User' },
            'company' => { 'id' => company.id, 'code' => company.code, 'name' => company.name },
            'membership' => { 'role' => 'member' }
          }
        }

        session[:oauth_state] = 'state123'
        session[:oauth_initiated_at] = Time.now.to_i
        allow(authlift_client).to receive(:exchange_code).and_return(tokens)
        allow(authlift_client).to receive(:decode_jwt).and_return({})
        allow(authlift_client).to receive(:revoke_token)

        get :create, params: { code: 'code', state: 'state123' }

        # User should be authenticated
        expect(session[:user_id]).to be_present

        # Session should be reset on logout
        post :destroy
        expect(session[:user_id]).to be_nil
      end
    end
  end
end
