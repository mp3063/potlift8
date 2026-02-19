# frozen_string_literal: true

require 'rails_helper'

# Test controller to test ApplicationController functionality
class TestController < ApplicationController
  skip_after_action :verify_authorized

  def index
    render plain: 'OK'
  end

  def public_action
    render plain: 'Public OK'
  end
end

RSpec.describe ApplicationController, type: :controller do
  controller(TestController) do
    skip_before_action :require_authentication, only: [ :public_action ]
  end

  before do
    routes.draw do
      get 'index' => 'test#index'
      get 'public_action' => 'test#public_action'
    end
  end

  describe '#require_authentication' do
    context 'when user is not authenticated' do
      it 'redirects to login page' do
        get :index

        expect(response).to redirect_to(auth_login_path)
        expect(flash[:alert]).to eq('Please sign in to continue.')
      end

      it 'stores return URL in session' do
        get :index, params: { id: 123 }

        expect(session[:return_to]).to eq('/index?id=123')
      end

      it 'does not store return URL for POST requests' do
        post :index

        expect(session[:return_to]).to be_nil
      end

      it 'does not store return URL for XHR requests' do
        get :index, xhr: true

        expect(session[:return_to]).to be_nil
      end
    end

    context 'when user is authenticated' do
      let(:company) { create(:company) }
      let(:user) { create(:user, company: company) }
      let(:authlift_client) { instance_double(Authlift::Client) }

      before do
        allow_any_instance_of(ApplicationController).to receive(:authlift_client).and_return(authlift_client)
        allow(authlift_client).to receive(:decode_jwt).and_return({})

        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'allows access to protected actions' do
        get :index

        expect(response).to be_successful
        expect(response.body).to eq('OK')
      end

      it 'does not redirect to login' do
        get :index

        # Check response is successful (not a redirect)
        expect(response).to be_successful
        expect(response).not_to be_redirect
      end
    end

    context 'when action skips authentication' do
      it 'allows unauthenticated access' do
        get :public_action

        expect(response).to be_successful
        expect(response.body).to eq('Public OK')
      end
    end
  end

  describe '#authenticated?' do
    let(:authlift_client) { instance_double(Authlift::Client) }

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
    end

    context 'with valid session' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'returns true' do
        expect(controller.send(:authenticated?)).to be true
      end
    end

    context 'without user_id in session' do
      it 'returns false' do
        expect(controller.send(:authenticated?)).to be false
      end
    end

    context 'without access_token in session' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
      end

      it 'returns false' do
        expect(controller.send(:authenticated?)).to be false
      end
    end

    context 'with expired session (24 hours)' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = 25.hours.ago.to_i
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'returns false' do
        expect(controller.send(:authenticated?)).to be false
      end

      it 'clears the session' do
        controller.send(:authenticated?)

        expect(session[:user_id]).to be_nil
        expect(session[:access_token]).to be_nil
      end
    end

    context 'when authenticated_at is missing' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'returns false' do
        expect(controller.send(:authenticated?)).to be false
      end
    end

    context 'when user has been deleted from database' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i

        # Delete user from database after session is established
        user.destroy
      end

      it 'returns false' do
        expect(controller.send(:authenticated?)).to be false
      end

      it 'clears the session' do
        controller.send(:authenticated?)

        expect(session[:user_id]).to be_nil
        expect(session[:access_token]).to be_nil
      end

      it 'logs warning about missing user' do
        expect(Rails.logger).to receive(:warn).with(/User .* not found in database/)

        controller.send(:authenticated?)
      end
    end
  end

  describe '#current_user' do
    let(:authlift_client) { instance_double(Authlift::Client) }

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
    end

    context 'when authenticated' do
      let(:user) { create(:user) }

      before do
        session[:user_id] = user.id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'returns the current user' do
        expect(controller.send(:current_user)).to eq(user)
      end

      it 'memoizes the user' do
        expect(User).to receive(:find_by).once.and_return(user)

        2.times { controller.send(:current_user) }
      end
    end

    context 'when not authenticated' do
      it 'returns nil' do
        expect(controller.send(:current_user)).to be_nil
      end
    end

    context 'when user_id is invalid' do
      before do
        session[:user_id] = 99999
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
      end

      it 'returns nil' do
        expect(controller.send(:current_user)).to be_nil
      end
    end
  end

  describe '#current_user_name' do
    let(:user) { create(:user, name: 'John Doe') }
    let(:authlift_client) { instance_double(Authlift::Client) }

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
      session[:user_id] = user.id
      session[:access_token] = 'valid_token'
      session[:authenticated_at] = Time.now.to_i
      session[:expires_at] = 1.hour.from_now.to_i
    end

    it 'returns the current user name' do
      expect(controller.send(:current_user_name)).to eq('John Doe')
    end

    context 'when not authenticated' do
      before do
        session.clear
      end

      it 'returns nil' do
        expect(controller.send(:current_user_name)).to be_nil
      end
    end
  end

  describe '#current_company' do
    let(:authlift_client) { instance_double(Authlift::Client) }

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
    end

    context 'when authenticated with company data' do
      before do
        session[:user_id] = create(:user).id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
        session[:company_id] = 123
        session[:company_code] = 'ABC123'
        session[:company_name] = 'ACME Corp'
      end

      it 'returns company hash from session' do
        company = controller.send(:current_company)

        expect(company).to eq({
          id: 123,
          code: 'ABC123',
          name: 'ACME Corp'
        })
      end

      it 'memoizes the company hash' do
        2.times do
          expect(controller.send(:current_company)[:id]).to eq(123)
        end
      end
    end

    context 'when not authenticated' do
      it 'returns nil' do
        expect(controller.send(:current_company)).to be_nil
      end
    end

    context 'when company_code is missing' do
      before do
        session[:user_id] = create(:user).id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
      end

      it 'returns nil' do
        expect(controller.send(:current_company)).to be_nil
      end
    end
  end

  describe '#current_potlift_company' do
    let(:company) { create(:company, code: 'ABC123', name: 'ACME Corp') }
    let(:authlift_client) { instance_double(Authlift::Client) }

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
    end

    context 'when authenticated with company data' do
      before do
        session[:user_id] = create(:user, company: company).id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 1.hour.from_now.to_i
        session[:company_id] = company.id
        session[:company_code] = company.code
        session[:company_name] = company.name
      end

      it 'returns Company model instance' do
        result = controller.send(:current_potlift_company)

        expect(result).to be_a(Company)
        expect(result.code).to eq('ABC123')
        expect(result.name).to eq('ACME Corp')
      end

      it 'calls Company.from_authlift8 with session data' do
        expect(Company).to receive(:from_authlift8).with(
          hash_including(
            'id' => company.id,
            'code' => 'ABC123',
            'name' => 'ACME Corp'
          )
        ).and_return(company)

        controller.send(:current_potlift_company)
      end

      it 'memoizes the company model' do
        expect(Company).to receive(:from_authlift8).once.and_return(company)

        2.times { controller.send(:current_potlift_company) }
      end
    end

    context 'when not authenticated' do
      it 'returns nil' do
        expect(controller.send(:current_potlift_company)).to be_nil
      end
    end

    context 'when company data is missing' do
      before do
        session[:user_id] = create(:user).id
        session[:access_token] = 'valid_token'
        session[:authenticated_at] = Time.now.to_i
      end

      it 'returns nil' do
        expect(controller.send(:current_potlift_company)).to be_nil
      end
    end
  end

  describe '#token_expired?' do
    context 'when expires_at is nil' do
      it 'returns true' do
        session[:expires_at] = nil
        expect(controller.send(:token_expired?)).to be true
      end
    end

    context 'when token expires in less than 5 minutes' do
      it 'returns true' do
        session[:expires_at] = 4.minutes.from_now.to_i
        expect(controller.send(:token_expired?)).to be true
      end
    end

    context 'when token already expired' do
      it 'returns true' do
        session[:expires_at] = 1.minute.ago.to_i
        expect(controller.send(:token_expired?)).to be true
      end
    end

    context 'when token expires in more than 5 minutes' do
      it 'returns false' do
        session[:expires_at] = 10.minutes.from_now.to_i
        expect(controller.send(:token_expired?)).to be false
      end
    end
  end

  describe '#refresh_access_token' do
    let(:authlift_client) { instance_double(Authlift::Client) }
    let(:new_tokens) do
      {
        access_token: 'new_access_token',
        refresh_token: 'new_refresh_token',
        expires_at: 1.hour.from_now.to_i
      }
    end

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      session[:user_id] = create(:user).id
      session[:refresh_token] = 'old_refresh_token'
    end

    it 'calls authlift_client.refresh_token' do
      allow(authlift_client).to receive(:refresh_token).and_return(new_tokens)

      controller.send(:refresh_access_token)

      expect(authlift_client).to have_received(:refresh_token).with('old_refresh_token')
    end

    it 'updates session with new tokens' do
      allow(authlift_client).to receive(:refresh_token).and_return(new_tokens)

      controller.send(:refresh_access_token)

      expect(session[:access_token]).to eq('new_access_token')
      expect(session[:refresh_token]).to eq('new_refresh_token')
      expect(session[:expires_at]).to eq(new_tokens[:expires_at])
    end

    context 'when refresh_token returns new refresh_token' do
      it 'updates refresh_token in session' do
        tokens_with_refresh = new_tokens.merge(refresh_token: 'newer_refresh_token')
        allow(authlift_client).to receive(:refresh_token).and_return(tokens_with_refresh)

        controller.send(:refresh_access_token)

        expect(session[:refresh_token]).to eq('newer_refresh_token')
      end
    end

    context 'when refresh_token is missing' do
      before do
        session.delete(:refresh_token)
        allow(authlift_client).to receive(:refresh_token)
      end

      it 'does not call authlift_client' do
        controller.send(:refresh_access_token)

        expect(authlift_client).not_to have_received(:refresh_token)
      end
    end

    context 'when refresh fails' do
      before do
        allow(authlift_client).to receive(:refresh_token)
          .and_raise(Authlift::Client::AuthenticationError, 'Refresh failed')
      end

      it 'raises the error' do
        expect {
          controller.send(:refresh_access_token)
        }.to raise_error(Authlift::Client::AuthenticationError)
      end
    end
  end

  describe 'token refresh in authenticated?' do
    let(:authlift_client) { instance_double(Authlift::Client) }
    let(:user) { create(:user) }
    let(:new_tokens) do
      {
        access_token: 'new_token',
        expires_at: 1.hour.from_now.to_i
      }
    end

    before do
      allow(controller).to receive(:authlift_client).and_return(authlift_client)
      allow(authlift_client).to receive(:decode_jwt).and_return({})
      allow(authlift_client).to receive(:refresh_token).and_return(new_tokens)
    end

    context 'when token is expired' do
      before do
        session[:user_id] = user.id
        session[:access_token] = 'old_token'
        session[:refresh_token] = 'refresh_token'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 2.minutes.from_now.to_i # Will expire in < 5 minutes
      end

      it 'automatically refreshes the token' do
        result = controller.send(:authenticated?)

        expect(result).to be true
        expect(session[:access_token]).to eq('new_token')
        expect(authlift_client).to have_received(:refresh_token)
      end
    end

    context 'when token refresh fails' do
      before do
        session[:user_id] = user.id
        session[:access_token] = 'old_token'
        session[:refresh_token] = 'invalid_refresh'
        session[:authenticated_at] = Time.now.to_i
        session[:expires_at] = 2.minutes.from_now.to_i

        allow(authlift_client).to receive(:refresh_token)
          .and_raise(Authlift::Client::AuthenticationError, 'Invalid refresh token')
      end

      it 'returns false and clears session' do
        result = controller.send(:authenticated?)

        expect(result).to be false
        expect(session[:user_id]).to be_nil
        expect(session[:access_token]).to be_nil
      end
    end
  end

  describe '#store_location_for_return' do
    it 'stores GET request path' do
      get :index, params: { id: 123 }

      expect(session[:return_to]).to eq('/index?id=123')
    end

    it 'does not store POST requests' do
      post :index

      expect(session[:return_to]).to be_nil
    end

    it 'does not store XHR requests' do
      get :index, xhr: true

      expect(session[:return_to]).to be_nil
    end

    it 'does not store login path' do
      # Simulate login path
      allow(controller).to receive(:auth_login_path).and_return('/auth/login')
      allow(controller).to receive_message_chain(:request, :path).and_return('/auth/login')
      allow(controller).to receive_message_chain(:request, :get?).and_return(true)
      allow(controller).to receive_message_chain(:request, :xhr?).and_return(false)

      controller.send(:store_location_for_return)

      expect(session[:return_to]).to be_nil
    end
  end

  describe 'helper methods availability' do
    it 'makes current_user available in views' do
      expect(controller.class._helpers.instance_methods).to include(:current_user)
    end

    it 'makes current_company available in views' do
      expect(controller.class._helpers.instance_methods).to include(:current_company)
    end

    it 'makes authenticated? available in views' do
      expect(controller.class._helpers.instance_methods).to include(:authenticated?)
    end

    it 'makes current_user_name available in views' do
      expect(controller.class._helpers.instance_methods).to include(:current_user_name)
    end

    it 'makes current_potlift_company available in views' do
      expect(controller.class._helpers.instance_methods).to include(:current_potlift_company)
    end
  end
end
