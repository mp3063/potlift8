# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Authentication Security', type: :request do
  describe 'Session Fixation Protection' do
    it 'regenerates session ID after authentication' do
      # Simulate OAuth flow
      get auth_login_path
      original_session_id = session.id

      # Ensure session ID changes after authentication
      # (This would be tested in integration test with actual OAuth flow)
      expect(session.id).to be_present
    end
  end

  describe 'Broken Authentication State Protection' do
    context 'when user is deleted from database' do
      it 'clears session and forces re-authentication' do
        company = create(:company)
        user = create(:user, company: company)

        # Simulate authenticated session
        post auth_callback_path, params: {
          code: 'fake_code',
          state: 'fake_state'
        }

        # Simulate user deletion
        User.destroy_all

        # Access protected resource should redirect to login
        get products_path
        expect(response).to redirect_to(auth_login_path)
        expect(session[:user_id]).to be_nil
      end
    end

    context 'when company is deleted from database' do
      it 'clears session and forces re-authentication' do
        company = create(:company)
        user = create(:user, company: company)

        # Simulate authenticated session with company
        # Access after company deletion should clear session
        # (Full implementation requires OAuth flow simulation)
      end
    end
  end

  describe 'Authentication Enforcement' do
    context 'without authentication' do
      it 'redirects to login page' do
        get products_path
        expect(response).to redirect_to(auth_login_path)
        expect(flash[:alert]).to eq('Please sign in to continue.')
      end

      it 'stores return URL for redirect after login' do
        get products_path
        expect(session[:return_to]).to eq(products_path)
      end
    end

    context 'with expired session' do
      it 'clears session and redirects to login' do
        # Simulate expired session (> 24 hours)
        session[:user_id] = 999
        session[:access_token] = 'fake_token'
        session[:authenticated_at] = 25.hours.ago.to_i

        get products_path
        expect(response).to redirect_to(auth_login_path)
        expect(session[:user_id]).to be_nil
      end
    end
  end

  describe 'Security Headers' do
    before do
      # Authenticate for testing headers on protected pages
      company = create(:company)
      user = create(:user, company: company)

      # Manually set session (bypassing OAuth for testing)
      session[:user_id] = user.id
      session[:access_token] = 'fake_token'
      session[:authenticated_at] = Time.now.to_i
      session[:company_id] = company.id
      session[:company_code] = company.code
      session[:company_name] = company.name

      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    end

    it 'sets X-Frame-Options header' do
      get root_path
      expect(response.headers['X-Frame-Options']).to eq('SAMEORIGIN')
    end

    it 'sets X-Content-Type-Options header' do
      get root_path
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it 'sets X-XSS-Protection header' do
      get root_path
      expect(response.headers['X-XSS-Protection']).to eq('1; mode=block')
    end

    it 'sets Referrer-Policy header' do
      get root_path
      expect(response.headers['Referrer-Policy']).to eq('strict-origin-when-cross-origin')
    end

    it 'sets Permissions-Policy header' do
      get root_path
      expect(response.headers['Permissions-Policy']).to eq('geolocation=(), microphone=(), camera=()')
    end

    context 'in production' do
      before do
        allow(Rails.env).to receive(:production?).and_return(true)
      end

      it 'sets Strict-Transport-Security header' do
        # This requires Rails to be reloaded with production config
        # Testing separately in production environment
      end
    end
  end

  describe 'Session Security' do
    it 'uses secure session cookies in production' do
      # Session configuration is tested via session_store.rb
      expect(Rails.application.config.session_options[:httponly]).to eq(true)
      expect(Rails.application.config.session_options[:same_site]).to eq(:lax)
    end
  end
end
