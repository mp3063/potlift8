# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Catalogs::ShopifyConnection', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:catalog) { create(:catalog, company: company, code: 'WEB-EUR') }

  before do
    # Set up authenticated session
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe 'GET /catalogs/:code/shopify_connection' do
    let(:mock_service) { instance_double(ShopifyConnectionService) }

    before do
      allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
    end

    context 'when catalog is not connected to Shopify' do
      before do
        allow(mock_service).to receive(:connected?).and_return(false)
      end

      it 'returns successful response' do
        get shopify_connection_catalog_path(catalog)
        expect(response).to be_successful
      end

      it 'does not fetch shop details' do
        expect(mock_service).not_to receive(:shop_details)
        get shopify_connection_catalog_path(catalog)
      end
    end

    context 'when catalog is connected to Shopify' do
      let(:shop_details) do
        {
          id: 123,
          shopify_domain: 'my-store.myshopify.com',
          api_key_hint: 'abc...xyz',
          location_id: 'gid://shopify/Location/456'
        }
      end
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: shop_details)
      end

      before do
        allow(mock_service).to receive(:connected?).and_return(true)
        allow(mock_service).to receive(:shop_details).and_return(success_result)
      end

      it 'returns successful response' do
        get shopify_connection_catalog_path(catalog)
        expect(response).to be_successful
      end

      it 'fetches shop details' do
        expect(mock_service).to receive(:shop_details)
        get shopify_connection_catalog_path(catalog)
      end
    end

    context 'when catalog is connected but shop_details fails' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'API error')
      end

      before do
        allow(mock_service).to receive(:connected?).and_return(true)
        allow(mock_service).to receive(:shop_details).and_return(failure_result)
      end

      it 'returns successful response (gracefully handles error)' do
        get shopify_connection_catalog_path(catalog)
        expect(response).to be_successful
      end
    end

    context 'with turbo_stream format' do
      before do
        allow(mock_service).to receive(:connected?).and_return(false)
      end

      it 'responds to turbo_stream format' do
        get shopify_connection_catalog_path(catalog), as: :turbo_stream
        expect(response).to be_successful
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company, code: 'OTHER') }

      it 'prevents access to other company catalogs' do
        expect {
          get shopify_connection_catalog_path(other_catalog)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'POST /catalogs/:code/connect_shopify' do
    let(:mock_service) { instance_double(ShopifyConnectionService) }
    let(:valid_params) do
      {
        shopify_domain: 'my-store.myshopify.com',
        shopify_api_key: 'api_key_123',
        shopify_password: 'api_secret_456',
        location_id: 'gid://shopify/Location/789'
      }
    end

    before do
      allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
    end

    context 'with valid parameters - success' do
      let(:shop_data) do
        {
          id: 123,
          shopify_domain: 'my-store.myshopify.com',
          location_id: 'gid://shopify/Location/789'
        }
      end
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: shop_data)
      end

      before do
        allow(mock_service).to receive(:connect).and_return(success_result)
      end

      it 'calls the service with correct parameters' do
        expect(mock_service).to receive(:connect) do |params|
          expect(params[:shopify_domain]).to eq('my-store.myshopify.com')
          expect(params[:shopify_api_key]).to eq('api_key_123')
          expect(params[:shopify_password]).to eq('api_secret_456')
          expect(params[:location_id]).to eq('gid://shopify/Location/789')
          success_result
        end
        post connect_shopify_catalog_path(catalog), params: valid_params
      end

      it 'redirects to catalog edit page' do
        post connect_shopify_catalog_path(catalog), params: valid_params
        expect(response).to redirect_to(edit_catalog_path(catalog))
      end

      it 'sets success flash notice' do
        post connect_shopify_catalog_path(catalog), params: valid_params
        expect(flash[:notice]).to eq('Successfully connected to Shopify store.')
      end
    end

    context 'with valid parameters - API failure' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'Invalid API credentials')
      end

      before do
        allow(mock_service).to receive(:connect).and_return(failure_result)
      end

      it 'redirects to catalog edit page' do
        post connect_shopify_catalog_path(catalog), params: valid_params
        expect(response).to redirect_to(edit_catalog_path(catalog))
      end

      it 'sets error flash alert' do
        post connect_shopify_catalog_path(catalog), params: valid_params
        expect(flash[:alert]).to eq('Invalid API credentials')
      end
    end

    context 'with missing required parameters' do
      let(:invalid_params) do
        {
          shopify_domain: 'my-store.myshopify.com',
          shopify_api_key: '',
          shopify_password: ''
        }
      end
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'API key is required, API secret is required')
      end

      before do
        allow(mock_service).to receive(:connect).and_return(failure_result)
      end

      it 'redirects to catalog edit page with error' do
        post connect_shopify_catalog_path(catalog), params: invalid_params
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:alert]).to include('required')
      end
    end

    context 'with turbo_stream format - success' do
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: { id: 123 })
      end

      before do
        allow(mock_service).to receive(:connect).and_return(success_result)
      end

      it 'redirects with success notice' do
        post connect_shopify_catalog_path(catalog), params: valid_params, as: :turbo_stream
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:notice]).to eq('Successfully connected to Shopify store.')
      end
    end

    context 'with turbo_stream format - failure' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'Connection failed')
      end

      before do
        allow(mock_service).to receive(:connect).and_return(failure_result)
      end

      it 'redirects with error alert' do
        post connect_shopify_catalog_path(catalog), params: valid_params, as: :turbo_stream
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:alert]).to eq('Connection failed')
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company, code: 'OTHER') }

      it 'prevents connecting to other company catalogs' do
        expect {
          post connect_shopify_catalog_path(other_catalog), params: valid_params
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /catalogs/:code/disconnect_shopify' do
    let(:mock_service) { instance_double(ShopifyConnectionService) }

    before do
      allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
    end

    context 'when connected - success' do
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: { disconnected: true })
      end

      before do
        allow(mock_service).to receive(:disconnect).and_return(success_result)
      end

      it 'calls the service disconnect method' do
        expect(mock_service).to receive(:disconnect)
        delete disconnect_shopify_catalog_path(catalog)
      end

      it 'redirects to catalog edit page' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(response).to redirect_to(edit_catalog_path(catalog))
      end

      it 'sets success flash notice' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(flash[:notice]).to eq('Successfully disconnected from Shopify store.')
      end
    end

    context 'when not connected - failure' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'Catalog is not connected to Shopify')
      end

      before do
        allow(mock_service).to receive(:disconnect).and_return(failure_result)
      end

      it 'redirects to catalog edit page' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(response).to redirect_to(edit_catalog_path(catalog))
      end

      it 'sets error flash alert' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(flash[:alert]).to eq('Catalog is not connected to Shopify')
      end
    end

    context 'when disconnect fails unexpectedly' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'Unexpected error: Database connection lost')
      end

      before do
        allow(mock_service).to receive(:disconnect).and_return(failure_result)
      end

      it 'redirects with error alert' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:alert]).to include('Unexpected error')
      end
    end

    context 'with turbo_stream format - success' do
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: { disconnected: true })
      end

      before do
        allow(mock_service).to receive(:disconnect).and_return(success_result)
      end

      it 'redirects with success notice' do
        delete disconnect_shopify_catalog_path(catalog), as: :turbo_stream
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:notice]).to eq('Successfully disconnected from Shopify store.')
      end
    end

    context 'with turbo_stream format - failure' do
      let(:failure_result) do
        ShopifyConnectionService::Result.new(success: false, error: 'Disconnect failed')
      end

      before do
        allow(mock_service).to receive(:disconnect).and_return(failure_result)
      end

      it 'redirects with error alert' do
        delete disconnect_shopify_catalog_path(catalog), as: :turbo_stream
        expect(response).to redirect_to(edit_catalog_path(catalog))
        expect(flash[:alert]).to eq('Disconnect failed')
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company, code: 'OTHER') }

      it 'prevents disconnecting other company catalogs' do
        expect {
          delete disconnect_shopify_catalog_path(other_catalog)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'authentication requirements' do
    before do
      # Reset authentication mocks to test authentication requirement
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(nil)
    end

    it 'requires authentication for shopify_connection' do
      get shopify_connection_catalog_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for connect_shopify' do
      post connect_shopify_catalog_path(catalog), params: { shopify_domain: 'test.myshopify.com' }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for disconnect_shopify' do
      delete disconnect_shopify_catalog_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end
  end

  describe 'integration with real ShopifyConnectionService' do
    # These tests use real service but stub the API client
    let(:connected_catalog) do
      create(:catalog, company: company, code: 'CONNECTED', info: {
        'shop_id' => 123,
        'shopify_domain_cache' => 'test.myshopify.com',
        'shopify_api_token' => 'test_api_token'
      })
    end
    let(:disconnected_catalog) do
      create(:catalog, company: company, code: 'DISCONNECTED', info: {
        'shopify_api_token' => 'test_api_token'
      })
    end

    describe 'GET /catalogs/:code/shopify_connection' do
      context 'with disconnected catalog (no mocking)' do
        it 'returns successful response' do
          get shopify_connection_catalog_path(disconnected_catalog)
          expect(response).to be_successful
        end
      end

      context 'with connected catalog (API stubbed)' do
        let(:mock_api_client) { instance_double(Shopify8ApiClient) }
        let(:credentials_result) do
          Shopify8ApiClient::Result.new(
            success: true,
            data: {
              id: 123,
              shopify_domain: 'test.myshopify.com',
              api_key_hint: 'abc...xyz'
            }
          )
        end

        before do
          allow(Shopify8ApiClient).to receive(:new).and_return(mock_api_client)
          allow(mock_api_client).to receive(:get_credentials).with(123).and_return(credentials_result)
        end

        it 'returns successful response' do
          get shopify_connection_catalog_path(connected_catalog)
          expect(response).to be_successful
        end
      end
    end

    describe 'POST /catalogs/:code/connect_shopify' do
      let(:mock_api_client) { instance_double(Shopify8ApiClient) }
      let(:valid_params) do
        {
          shopify_domain: 'new-store.myshopify.com',
          shopify_api_key: 'api_key',
          shopify_password: 'api_secret'
        }
      end

      before do
        allow(Shopify8ApiClient).to receive(:new).and_return(mock_api_client)
      end

      context 'when API call succeeds' do
        let(:create_result) do
          Shopify8ApiClient::Result.new(
            success: true,
            data: { id: 456, shopify_domain: 'new-store.myshopify.com' }
          )
        end

        before do
          allow(mock_api_client).to receive(:create_shop).and_return(create_result)
        end

        it 'creates the connection and redirects with success' do
          post connect_shopify_catalog_path(disconnected_catalog), params: valid_params

          expect(response).to redirect_to(edit_catalog_path(disconnected_catalog))
          expect(flash[:notice]).to eq('Successfully connected to Shopify store.')

          disconnected_catalog.reload
          expect(disconnected_catalog.shop_id).to eq(456)
          expect(disconnected_catalog.shopify_domain).to eq('new-store.myshopify.com')
        end
      end

      context 'when API call fails' do
        let(:failure_result) do
          Shopify8ApiClient::Result.new(
            success: false,
            error: 'Invalid credentials'
          )
        end

        before do
          allow(mock_api_client).to receive(:create_shop).and_return(failure_result)
        end

        it 'redirects with error and does not update catalog' do
          post connect_shopify_catalog_path(disconnected_catalog), params: valid_params

          expect(response).to redirect_to(edit_catalog_path(disconnected_catalog))
          expect(flash[:alert]).to eq('Invalid credentials')

          disconnected_catalog.reload
          expect(disconnected_catalog.shop_id).to be_nil
        end
      end
    end

    describe 'DELETE /catalogs/:code/disconnect_shopify' do
      context 'when catalog is connected' do
        it 'disconnects and redirects with success' do
          delete disconnect_shopify_catalog_path(connected_catalog)

          expect(response).to redirect_to(edit_catalog_path(connected_catalog))
          expect(flash[:notice]).to eq('Successfully disconnected from Shopify store.')

          connected_catalog.reload
          expect(connected_catalog.shop_id).to be_nil
          expect(connected_catalog.shopify_domain).to be_nil
        end
      end

      context 'when catalog is not connected' do
        it 'redirects with error' do
          delete disconnect_shopify_catalog_path(disconnected_catalog)

          expect(response).to redirect_to(edit_catalog_path(disconnected_catalog))
          expect(flash[:alert]).to eq('Catalog is not connected to Shopify')
        end
      end
    end
  end
end
