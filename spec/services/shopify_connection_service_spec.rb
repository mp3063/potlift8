# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ShopifyConnectionService, type: :service do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company, info: { 'shopify_api_token' => 'test_api_token' }) }
  let(:service) { described_class.new(catalog) }

  # Common connection params
  let(:valid_params) do
    {
      shopify_domain: 'my-store.myshopify.com',
      shopify_api_key: 'test_api_key_123',
      shopify_password: 'test_secret_456',
      location_id: 'gid://shopify/Location/12345'
    }
  end

  # Mock API client
  let(:api_client) { instance_double(Shopify8ApiClient) }

  before do
    allow(Shopify8ApiClient).to receive(:new).and_return(api_client)
  end

  describe '#initialize' do
    it 'stores the catalog' do
      expect(service.catalog).to eq(catalog)
    end

    it 'initializes empty errors array' do
      expect(service.errors).to eq([])
    end
  end

  describe '#connect' do
    context 'with valid params' do
      let(:shop_data) do
        {
          id: 42,
          shopify_domain: 'my-store.myshopify.com',
          location_id: 'gid://shopify/Location/12345'
        }
      end

      let(:success_result) do
        Shopify8ApiClient::Result.new(success: true, data: shop_data)
      end

      before do
        allow(api_client).to receive(:create_shop).and_return(success_result)
      end

      it 'creates shop in Shopify8' do
        expect(api_client).to receive(:create_shop).with(valid_params)

        service.connect(valid_params)
      end

      it 'returns success result' do
        result = service.connect(valid_params)

        expect(result.success?).to be true
        expect(result.data).to eq(shop_data)
      end

      it 'stores shop_id in catalog' do
        service.connect(valid_params)

        expect(catalog.reload.shop_id).to eq(42)
      end

      it 'caches shopify_domain in catalog info' do
        service.connect(valid_params)

        expect(catalog.reload.shopify_domain).to eq('my-store.myshopify.com')
      end

      it 'persists the catalog changes' do
        service.connect(valid_params)

        catalog.reload
        expect(catalog.info['shop_id']).to eq(42)
        expect(catalog.info['shopify_domain_cache']).to eq('my-store.myshopify.com')
      end
    end

    context 'with invalid params' do
      it 'returns error when shopify_domain is blank' do
        params = valid_params.merge(shopify_domain: '')

        result = service.connect(params)

        expect(result.success?).to be false
        expect(result.error).to include('Shopify domain is required')
      end

      it 'returns error when shopify_api_key is blank' do
        params = valid_params.merge(shopify_api_key: nil)

        result = service.connect(params)

        expect(result.success?).to be false
        expect(result.error).to include('API key is required')
      end

      it 'returns error when shopify_password is blank' do
        params = valid_params.merge(shopify_password: '')

        result = service.connect(params)

        expect(result.success?).to be false
        expect(result.error).to include('API secret is required')
      end

      it 'returns combined errors when multiple fields are missing' do
        params = { shopify_domain: '', shopify_api_key: '', shopify_password: '' }

        result = service.connect(params)

        expect(result.success?).to be false
        expect(result.error).to include('Shopify domain is required')
        expect(result.error).to include('API key is required')
        expect(result.error).to include('API secret is required')
      end

      it 'does not call the API client' do
        expect(api_client).not_to receive(:create_shop)

        service.connect(shopify_domain: '', shopify_api_key: '', shopify_password: '')
      end

      it 'returns error for invalid domain format' do
        params = valid_params.merge(shopify_domain: 'invalid-domain.com')

        result = service.connect(params)

        expect(result.success?).to be false
        expect(result.error).to include('must be in format: store-name.myshopify.com')
      end
    end

    context 'when API token not configured' do
      let(:catalog) { create(:catalog, company: company, info: {}) }

      it 'returns error requiring API token configuration' do
        result = service.connect(valid_params)

        expect(result.success?).to be false
        expect(result.error).to include('API token not configured')
      end

      it 'does not call the API client' do
        expect(api_client).not_to receive(:create_shop)

        service.connect(valid_params)
      end
    end

    context 'when API returns error' do
      let(:error_result) do
        Shopify8ApiClient::Result.new(success: false, error: 'Invalid API credentials')
      end

      before do
        allow(api_client).to receive(:create_shop).and_return(error_result)
      end

      it 'returns failure result with API error' do
        result = service.connect(valid_params)

        expect(result.success?).to be false
        expect(result.error).to eq('Invalid API credentials')
      end

      it 'does not update catalog' do
        service.connect(valid_params)

        expect(catalog.reload.shop_id).to be_nil
      end
    end

    context 'when already connected (updates existing shop)' do
      let(:existing_shop_id) { 99 }
      let(:existing_shop_data) do
        {
          id: existing_shop_id,
          shopify_domain: 'old-store.myshopify.com',
          location_id: 'gid://shopify/Location/12345'
        }
      end
      let(:updated_shop_data) do
        {
          id: existing_shop_id,
          shopify_domain: 'updated-store.myshopify.com',
          location_id: 'gid://shopify/Location/67890'
        }
      end

      let(:verify_result) do
        Shopify8ApiClient::Result.new(success: true, data: existing_shop_data)
      end
      let(:update_result) do
        Shopify8ApiClient::Result.new(success: true, data: updated_shop_data)
      end

      before do
        catalog.shop_id = existing_shop_id
        catalog.info['shopify_domain_cache'] = 'old-store.myshopify.com'
        catalog.save!

        allow(api_client).to receive(:get_shop).and_return(verify_result)
        allow(api_client).to receive(:update_shop).and_return(update_result)
      end

      it 'verifies shop exists before updating' do
        expect(api_client).to receive(:get_shop).with(existing_shop_id)

        service.connect(valid_params)
      end

      it 'calls update_shop instead of create_shop' do
        expect(api_client).to receive(:update_shop).with(existing_shop_id, valid_params)
        expect(api_client).not_to receive(:create_shop)

        service.connect(valid_params)
      end

      it 'returns success result with updated data' do
        result = service.connect(valid_params)

        expect(result.success?).to be true
        expect(result.data[:shopify_domain]).to eq('updated-store.myshopify.com')
      end

      it 'updates cached domain' do
        service.connect(valid_params)

        expect(catalog.reload.shopify_domain).to eq('updated-store.myshopify.com')
      end

      it 'keeps same shop_id' do
        service.connect(valid_params)

        expect(catalog.reload.shop_id).to eq(existing_shop_id)
      end

      context 'when shop verification fails' do
        let(:verify_error) do
          Shopify8ApiClient::Result.new(success: false, error: 'Shop not found')
        end

        before do
          allow(api_client).to receive(:get_shop).and_return(verify_error)
        end

        it 'returns error without updating' do
          result = service.connect(valid_params)

          expect(result.success?).to be false
          expect(result.error).to include('Cannot access linked shop')
        end

        it 'does not call update_shop' do
          expect(api_client).not_to receive(:update_shop)

          service.connect(valid_params)
        end
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(api_client).to receive(:create_shop).and_raise(StandardError.new('Network error'))
      end

      it 'returns failure result with error message' do
        result = service.connect(valid_params)

        expect(result.success?).to be false
        expect(result.error).to include('Unexpected error')
        expect(result.error).to include('Network error')
      end
    end
  end

  describe '#disconnect' do
    context 'when connected' do
      before do
        catalog.shop_id = 42
        catalog.info['shopify_domain_cache'] = 'my-store.myshopify.com'
        catalog.save!
      end

      it 'returns success result' do
        result = service.disconnect

        expect(result.success?).to be true
        expect(result.data).to eq({ disconnected: true })
      end

      it 'removes shop_id from catalog' do
        service.disconnect

        expect(catalog.reload.shop_id).to be_nil
      end

      it 'removes cached shopify_domain' do
        service.disconnect

        expect(catalog.reload.shopify_domain).to be_nil
      end

      it 'persists the changes' do
        service.disconnect

        catalog.reload
        expect(catalog.info['shop_id']).to be_nil
        expect(catalog.info['shopify_domain_cache']).to be_nil
      end
    end

    context 'when not connected' do
      before do
        catalog.info = {}
        catalog.save!
      end

      it 'returns error result' do
        result = service.disconnect

        expect(result.success?).to be false
        expect(result.error).to include('not connected to Shopify')
      end

      it 'does not modify catalog' do
        expect { service.disconnect }.not_to change { catalog.reload.info }
      end
    end

    context 'when catalog save fails' do
      before do
        catalog.shop_id = 42
        catalog.save!

        allow(catalog).to receive(:save).and_return(false)
        allow(catalog).to receive(:errors).and_return(
          double(full_messages: ['Code is invalid'])
        )
      end

      it 'returns failure result with validation errors' do
        result = service.disconnect

        expect(result.success?).to be false
        expect(result.error).to include('Code is invalid')
      end
    end

    context 'when unexpected error occurs' do
      before do
        catalog.shop_id = 42
        catalog.save!

        allow(catalog).to receive(:save).and_raise(StandardError.new('Database error'))
      end

      it 'returns failure result with error message' do
        result = service.disconnect

        expect(result.success?).to be false
        expect(result.error).to include('Unexpected error')
        expect(result.error).to include('Database error')
      end
    end
  end

  describe '#connected?' do
    context 'when shop_id is present' do
      before do
        catalog.shop_id = 42
        catalog.save!
      end

      it 'returns true' do
        expect(service.connected?).to be true
      end
    end

    context 'when shop_id is nil' do
      before do
        catalog.info = {}
        catalog.save!
      end

      it 'returns false' do
        expect(service.connected?).to be false
      end
    end

    context 'when shop_id was removed' do
      before do
        catalog.shop_id = 42
        catalog.save!
        catalog.shop_id = nil
        catalog.save!
      end

      it 'returns false' do
        expect(service.connected?).to be false
      end
    end
  end

  describe '#shop_details' do
    context 'when connected' do
      let(:credentials_data) do
        {
          id: 42,
          shopify_domain: 'my-store.myshopify.com',
          api_key_hint: 'test_api...23',
          password_hint: 'test_sec...56',
          location_id: 'gid://shopify/Location/12345'
        }
      end

      let(:credentials_result) do
        Shopify8ApiClient::Result.new(success: true, data: credentials_data)
      end

      before do
        catalog.shop_id = 42
        catalog.save!

        allow(api_client).to receive(:get_credentials).and_return(credentials_result)
      end

      it 'fetches credentials from Shopify8' do
        expect(api_client).to receive(:get_credentials).with(42)

        service.shop_details
      end

      it 'returns success result with shop details' do
        result = service.shop_details

        expect(result.success?).to be true
        expect(result.data[:shopify_domain]).to eq('my-store.myshopify.com')
        expect(result.data[:api_key_hint]).to eq('test_api...23')
        expect(result.data[:password_hint]).to eq('test_sec...56')
      end
    end

    context 'when not connected' do
      before do
        catalog.info = {}
        catalog.save!
      end

      it 'returns error result' do
        result = service.shop_details

        expect(result.success?).to be false
        expect(result.error).to include('not connected to Shopify')
      end

      it 'does not call the API client' do
        expect(api_client).not_to receive(:get_credentials)

        service.shop_details
      end
    end

    context 'when API returns error' do
      let(:error_result) do
        Shopify8ApiClient::Result.new(success: false, error: 'Shop not found')
      end

      before do
        catalog.shop_id = 42
        catalog.save!

        allow(api_client).to receive(:get_credentials).and_return(error_result)
      end

      it 'returns the API error result' do
        result = service.shop_details

        expect(result.success?).to be false
        expect(result.error).to eq('Shop not found')
      end
    end

    context 'when unexpected error occurs' do
      before do
        catalog.shop_id = 42
        catalog.save!

        allow(api_client).to receive(:get_credentials).and_raise(StandardError.new('Timeout'))
      end

      it 'returns failure result with error message' do
        result = service.shop_details

        expect(result.success?).to be false
        expect(result.error).to include('Unexpected error')
        expect(result.error).to include('Timeout')
      end
    end
  end

  describe '#get_shop' do
    context 'when connected' do
      let(:shop_data) do
        {
          id: 42,
          shopify_domain: 'my-store.myshopify.com',
          location_id: 'gid://shopify/Location/12345',
          created_at: '2025-01-15T10:00:00Z',
          updated_at: '2025-01-20T15:30:00Z'
        }
      end

      let(:shop_result) do
        Shopify8ApiClient::Result.new(success: true, data: shop_data)
      end

      before do
        catalog.shop_id = 42
        catalog.save!

        allow(api_client).to receive(:get_shop).and_return(shop_result)
      end

      it 'fetches shop from Shopify8' do
        expect(api_client).to receive(:get_shop).with(42)

        service.get_shop
      end

      it 'returns success result with full shop data' do
        result = service.get_shop

        expect(result.success?).to be true
        expect(result.data[:id]).to eq(42)
        expect(result.data[:shopify_domain]).to eq('my-store.myshopify.com')
      end
    end

    context 'when not connected' do
      it 'returns error result' do
        result = service.get_shop

        expect(result.success?).to be false
        expect(result.error).to include('not connected to Shopify')
      end
    end
  end

  describe 'private methods' do
    describe '#api_client' do
      context 'with shopify_api_token in catalog info' do
        before do
          catalog.info = { 'shopify_api_token' => 'catalog_specific_token' }
          catalog.save!
        end

        it 'uses token from catalog info' do
          expect(Shopify8ApiClient).to receive(:new).with(
            api_token: 'catalog_specific_token'
          )

          service.send(:api_client)
        end
      end

      context 'without shopify_api_token in catalog info' do
        let(:catalog) { create(:catalog, company: company, info: {}) }

        before do
          ENV['SHOPIFY8_API_TOKEN'] = 'env_token'
        end

        after do
          ENV.delete('SHOPIFY8_API_TOKEN')
        end

        it 'does NOT fall back to ENV token (security)' do
          expect(Shopify8ApiClient).to receive(:new).with(
            api_token: nil
          )

          service.send(:api_client)
        end
      end

      context 'with no token available' do
        before do
          catalog.info = {}
          catalog.save!
          ENV.delete('SHOPIFY8_API_TOKEN')
        end

        it 'passes nil token' do
          expect(Shopify8ApiClient).to receive(:new).with(
            api_token: nil
          )

          service.send(:api_client)
        end
      end
    end
  end

  describe 'Result struct' do
    let(:result_class) { ShopifyConnectionService::Result }

    it 'responds to success?' do
      result = result_class.new(success: true, data: {})

      expect(result.success?).to be true
    end

    it 'returns false for failed result' do
      result = result_class.new(success: false, error: 'Error')

      expect(result.success?).to be false
    end

    it 'stores data' do
      result = result_class.new(success: true, data: { id: 1 })

      expect(result.data).to eq({ id: 1 })
    end

    it 'stores error' do
      result = result_class.new(success: false, error: 'Something went wrong')

      expect(result.error).to eq('Something went wrong')
    end
  end
end
