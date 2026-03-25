# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shopify8ApiClient, type: :service do
  let(:api_token) { 'test_api_token_12345' }
  let(:base_url) { 'http://localhost:3245' }
  let(:client) { described_class.new(api_token: api_token, base_url: base_url) }

  before do
    # Ensure environment variable doesn't interfere with tests
    ENV['SHOPIFY8_URL'] = base_url
  end

  after do
    ENV.delete('SHOPIFY8_URL')
  end

  describe '#initialize' do
    it 'stores api_token' do
      expect(client.api_token).to eq(api_token)
    end

    it 'stores base_url' do
      expect(client.base_url).to eq(base_url)
    end

    context 'when base_url is not provided' do
      let(:client_without_url) { described_class.new(api_token: api_token) }

      it 'uses ENV SHOPIFY8_URL as default' do
        ENV['SHOPIFY8_URL'] = 'http://custom.shopify8.test'
        expect(client_without_url.base_url).to eq('http://custom.shopify8.test')
      end

      it 'defaults to localhost:3245 when ENV is not set' do
        ENV.delete('SHOPIFY8_URL')
        expect(client_without_url.base_url).to eq('http://localhost:3245')
      end
    end
  end

  describe 'Result struct' do
    describe '#success?' do
      it 'returns true when success is true' do
        result = described_class::Result.new(success: true, data: { id: 1 }, error: nil)
        expect(result.success?).to be true
      end

      it 'returns false when success is false' do
        result = described_class::Result.new(success: false, data: nil, error: 'Something went wrong')
        expect(result.success?).to be false
      end
    end

    it 'provides access to data' do
      result = described_class::Result.new(success: true, data: { id: 1, name: 'Test Shop' }, error: nil)
      expect(result.data).to eq({ id: 1, name: 'Test Shop' })
    end

    it 'provides access to error' do
      result = described_class::Result.new(success: false, data: nil, error: 'Connection refused')
      expect(result.error).to eq('Connection refused')
    end
  end

  describe 'HTTP headers' do
    let(:shop_params) do
      {
        shopify_domain: 'test-store.myshopify.com',
        shopify_api_key: 'api_key_123',
        shopify_password: 'secret_password',
        location_id: 'gid://shopify/Location/123'
      }
    end

    before do
      stub_request(:post, "#{base_url}/api/v1/shops")
        .to_return(status: 200, body: { success: true, data: { id: 1 } }.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    it 'sets Authorization header with Bearer token' do
      client.create_shop(shop_params)

      expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/shops")
        .with(headers: { 'Authorization' => "Bearer #{api_token}" })
    end

    it 'sets Content-Type header to application/json' do
      client.create_shop(shop_params)

      expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/shops")
        .with(headers: { 'Content-Type' => 'application/json' })
    end

    it 'sets Accept header to application/json' do
      client.create_shop(shop_params)

      expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/shops")
        .with(headers: { 'Accept' => 'application/json' })
    end
  end

  describe '#create_shop' do
    let(:shop_params) do
      {
        shopify_domain: 'test-store.myshopify.com',
        shopify_api_key: 'api_key_123',
        shopify_password: 'secret_password',
        location_id: 'gid://shopify/Location/123'
      }
    end

    context 'when successful' do
      let(:response_data) do
        {
          id: 42,
          shopify_domain: 'test-store.myshopify.com',
          location_id: 'gid://shopify/Location/123',
          created_at: '2025-01-15T10:00:00Z'
        }
      end

      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .with(body: { shop: shop_params }.to_json)
          .to_return(
            status: 200,
            body: { success: true, data: response_data }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a successful result' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be true
      end

      it 'returns shop data with symbolized keys' do
        result = client.create_shop(shop_params)

        expect(result.data[:id]).to eq(42)
        expect(result.data[:shopify_domain]).to eq('test-store.myshopify.com')
        expect(result.data[:location_id]).to eq('gid://shopify/Location/123')
      end

      it 'sends correct request body' do
        client.create_shop(shop_params)

        expect(WebMock).to have_requested(:post, "#{base_url}/api/v1/shops")
          .with(body: { shop: shop_params }.to_json)
      end

      it 'returns nil error' do
        result = client.create_shop(shop_params)

        expect(result.error).to be_nil
      end
    end

    context 'when API returns error' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_return(
            status: 422,
            body: { success: false, error: 'Shopify domain is invalid' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
      end

      it 'returns error message from response' do
        result = client.create_shop(shop_params)

        expect(result.error).to eq('Shopify domain is invalid')
      end

      it 'returns nil data' do
        result = client.create_shop(shop_params)

        expect(result.data).to be_nil
      end
    end

    context 'when API returns 401 Unauthorized' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_return(
            status: 401,
            body: { error: 'Invalid API token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
        expect(result.error).to eq('Invalid API token')
      end
    end

    context 'when API returns 500 Internal Server Error' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_return(
            status: 500,
            body: 'Internal Server Error',
            headers: { 'Content-Type' => 'text/plain' }
          )
      end

      it 'returns a failed result with status code' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
        expect(result.error).to include('500')
      end
    end
  end

  describe '#update_shop' do
    let(:shop_id) { 42 }
    let(:update_params) do
      {
        shopify_api_key: 'new_api_key',
        shopify_password: 'new_password'
      }
    end

    context 'when successful' do
      let(:response_data) do
        {
          id: 42,
          shopify_domain: 'test-store.myshopify.com',
          updated_at: '2025-01-15T12:00:00Z'
        }
      end

      before do
        stub_request(:patch, "#{base_url}/api/v1/shops/#{shop_id}")
          .with(body: { shop: update_params }.to_json)
          .to_return(
            status: 200,
            body: { success: true, data: response_data }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a successful result' do
        result = client.update_shop(shop_id, update_params)

        expect(result.success?).to be true
      end

      it 'returns updated shop data with symbolized keys' do
        result = client.update_shop(shop_id, update_params)

        expect(result.data[:id]).to eq(42)
        expect(result.data[:shopify_domain]).to eq('test-store.myshopify.com')
      end

      it 'sends PATCH request to correct URL' do
        client.update_shop(shop_id, update_params)

        expect(WebMock).to have_requested(:patch, "#{base_url}/api/v1/shops/#{shop_id}")
      end

      it 'sends correct request body' do
        client.update_shop(shop_id, update_params)

        expect(WebMock).to have_requested(:patch, "#{base_url}/api/v1/shops/#{shop_id}")
          .with(body: { shop: update_params }.to_json)
      end
    end

    context 'when shop not found' do
      before do
        stub_request(:patch, "#{base_url}/api/v1/shops/#{shop_id}")
          .to_return(
            status: 404,
            body: { success: false, error: 'Shop not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.update_shop(shop_id, update_params)

        expect(result.success?).to be false
        expect(result.error).to eq('Shop not found')
      end
    end

    context 'when validation fails' do
      before do
        stub_request(:patch, "#{base_url}/api/v1/shops/#{shop_id}")
          .to_return(
            status: 422,
            body: { success: false, error: 'API key format is invalid' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result with validation error' do
        result = client.update_shop(shop_id, update_params)

        expect(result.success?).to be false
        expect(result.error).to eq('API key format is invalid')
      end
    end
  end

  describe '#get_shop' do
    let(:shop_id) { 42 }

    context 'when successful' do
      let(:response_data) do
        {
          id: 42,
          shopify_domain: 'test-store.myshopify.com',
          location_id: 'gid://shopify/Location/123',
          connected: true,
          sync_enabled: true,
          created_at: '2025-01-15T10:00:00Z'
        }
      end

      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}")
          .to_return(
            status: 200,
            body: { success: true, data: response_data }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a successful result' do
        result = client.get_shop(shop_id)

        expect(result.success?).to be true
      end

      it 'returns shop data with symbolized keys' do
        result = client.get_shop(shop_id)

        expect(result.data[:id]).to eq(42)
        expect(result.data[:shopify_domain]).to eq('test-store.myshopify.com')
        expect(result.data[:connected]).to be true
        expect(result.data[:sync_enabled]).to be true
      end

      it 'sends GET request to correct URL' do
        client.get_shop(shop_id)

        expect(WebMock).to have_requested(:get, "#{base_url}/api/v1/shops/#{shop_id}")
      end
    end

    context 'when shop not found' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}")
          .to_return(
            status: 404,
            body: { success: false, error: 'Shop not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.get_shop(shop_id)

        expect(result.success?).to be false
        expect(result.error).to eq('Shop not found')
      end
    end

    context 'when unauthorized' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}")
          .to_return(
            status: 401,
            body: { error: 'Unauthorized' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.get_shop(shop_id)

        expect(result.success?).to be false
        expect(result.error).to eq('Unauthorized')
      end
    end
  end

  describe '#get_credentials' do
    let(:shop_id) { 42 }

    context 'when successful' do
      let(:response_data) do
        {
          shopify_domain: 'test-store.myshopify.com',
          api_key_hint: 'shpat_****abc123',
          password_hint: '****xyz789',
          location_id: 'gid://shopify/Location/123'
        }
      end

      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}/credentials")
          .to_return(
            status: 200,
            body: { success: true, data: response_data }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a successful result' do
        result = client.get_credentials(shop_id)

        expect(result.success?).to be true
      end

      it 'returns masked credentials with symbolized keys' do
        result = client.get_credentials(shop_id)

        expect(result.data[:shopify_domain]).to eq('test-store.myshopify.com')
        expect(result.data[:api_key_hint]).to eq('shpat_****abc123')
        expect(result.data[:password_hint]).to eq('****xyz789')
        expect(result.data[:location_id]).to eq('gid://shopify/Location/123')
      end

      it 'sends GET request to credentials endpoint' do
        client.get_credentials(shop_id)

        expect(WebMock).to have_requested(:get, "#{base_url}/api/v1/shops/#{shop_id}/credentials")
      end
    end

    context 'when shop not found' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}/credentials")
          .to_return(
            status: 404,
            body: { success: false, error: 'Shop not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.get_credentials(shop_id)

        expect(result.success?).to be false
        expect(result.error).to eq('Shop not found')
      end
    end

    context 'when forbidden' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/#{shop_id}/credentials")
          .to_return(
            status: 403,
            body: { error: 'Access denied' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.get_credentials(shop_id)

        expect(result.success?).to be false
        expect(result.error).to eq('Access denied')
      end
    end
  end

  describe '#list_shops' do
    context 'when successful' do
      let(:response_data) do
        [
          {
            id: 1,
            shopify_domain: 'store-one.myshopify.com',
            connected: true
          },
          {
            id: 2,
            shopify_domain: 'store-two.myshopify.com',
            connected: false
          }
        ]
      end

      before do
        stub_request(:get, "#{base_url}/api/v1/shops")
          .to_return(
            status: 200,
            body: { success: true, data: response_data }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a successful result' do
        result = client.list_shops

        expect(result.success?).to be true
      end

      it 'returns array of shops with symbolized keys' do
        result = client.list_shops

        expect(result.data).to be_an(Array)
        expect(result.data.length).to eq(2)
        expect(result.data[0][:id]).to eq(1)
        expect(result.data[0][:shopify_domain]).to eq('store-one.myshopify.com')
        expect(result.data[0][:connected]).to be true
        expect(result.data[1][:id]).to eq(2)
        expect(result.data[1][:shopify_domain]).to eq('store-two.myshopify.com')
        expect(result.data[1][:connected]).to be false
      end

      it 'sends GET request to shops endpoint' do
        client.list_shops

        expect(WebMock).to have_requested(:get, "#{base_url}/api/v1/shops")
      end
    end

    context 'when no shops exist' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops")
          .to_return(
            status: 200,
            body: { success: true, data: [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns an empty array' do
        result = client.list_shops

        expect(result.success?).to be true
        expect(result.data).to eq([])
      end
    end

    context 'when unauthorized' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops")
          .to_return(
            status: 401,
            body: { error: 'Invalid API token' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns a failed result' do
        result = client.list_shops

        expect(result.success?).to be false
        expect(result.error).to eq('Invalid API token')
      end
    end
  end

  describe 'error handling' do
    let(:shop_params) { { shopify_domain: 'test.myshopify.com' } }

    describe 'timeout errors' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_raise(Faraday::TimeoutError.new('Request timed out'))
      end

      it 'returns a failed result with timeout message' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
        expect(result.error).to include('Request timeout')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/\[Shopify8ApiClient\] Request timeout/)

        client.create_shop(shop_params)
      end
    end

    describe 'connection failed errors' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'returns a failed result with connection error message' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
        expect(result.error).to include('Connection failed')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/\[Shopify8ApiClient\] Connection failed/)

        client.create_shop(shop_params)
      end
    end

    describe 'unexpected errors' do
      before do
        stub_request(:post, "#{base_url}/api/v1/shops")
          .to_raise(StandardError.new('Something unexpected happened'))
      end

      it 'returns a failed result with unexpected error message' do
        result = client.create_shop(shop_params)

        expect(result.success?).to be false
        expect(result.error).to include('Unexpected error')
        expect(result.error).to include('Something unexpected happened')
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/\[Shopify8ApiClient\] Unexpected error/)

        client.create_shop(shop_params)
      end
    end

    describe 'timeout on GET requests' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/42")
          .to_raise(Faraday::TimeoutError.new('Request timed out'))
      end

      it 'returns a failed result with timeout message' do
        result = client.get_shop(42)

        expect(result.success?).to be false
        expect(result.error).to include('Request timeout')
      end
    end

    describe 'connection failed on PATCH requests' do
      before do
        stub_request(:patch, "#{base_url}/api/v1/shops/42")
          .to_raise(Faraday::ConnectionFailed.new('Host unreachable'))
      end

      it 'returns a failed result with connection error message' do
        result = client.update_shop(42, { shopify_domain: 'new.myshopify.com' })

        expect(result.success?).to be false
        expect(result.error).to include('Connection failed')
        expect(result.error).to include('Host unreachable')
      end
    end
  end

  describe 'response parsing' do
    describe 'deep symbolization of keys' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/42")
          .to_return(
            status: 200,
            body: {
              success: true,
              data: {
                id: 42,
                nested: {
                  deeply_nested: {
                    value: 'test'
                  }
                },
                array_field: [
                  { item_id: 1, item_name: 'First' },
                  { item_id: 2, item_name: 'Second' }
                ]
              }
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'symbolizes nested hash keys' do
        result = client.get_shop(42)

        expect(result.data[:nested][:deeply_nested][:value]).to eq('test')
      end

      it 'symbolizes keys in arrays of hashes' do
        result = client.get_shop(42)

        expect(result.data[:array_field][0][:item_id]).to eq(1)
        expect(result.data[:array_field][0][:item_name]).to eq('First')
        expect(result.data[:array_field][1][:item_id]).to eq(2)
      end
    end

    describe 'handling responses without data wrapper' do
      before do
        stub_request(:get, "#{base_url}/api/v1/shops/42")
          .to_return(
            status: 200,
            body: { id: 42, shopify_domain: 'test.myshopify.com' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'handles response without data wrapper' do
        result = client.get_shop(42)

        expect(result.success?).to be true
        expect(result.data[:id]).to eq(42)
        expect(result.data[:shopify_domain]).to eq('test.myshopify.com')
      end
    end

    describe 'extracting error messages' do
      context 'with error key' do
        before do
          stub_request(:get, "#{base_url}/api/v1/shops/42")
            .to_return(
              status: 422,
              body: { error: 'Validation failed' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'extracts error from response body' do
          result = client.get_shop(42)

          expect(result.error).to eq('Validation failed')
        end
      end

      context 'with message key' do
        before do
          stub_request(:get, "#{base_url}/api/v1/shops/42")
            .to_return(
              status: 422,
              body: { message: 'Something went wrong' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'extracts message from response body' do
          result = client.get_shop(42)

          expect(result.error).to eq('Something went wrong')
        end
      end

      context 'with neither error nor message' do
        before do
          stub_request(:get, "#{base_url}/api/v1/shops/42")
            .to_return(
              status: 422,
              body: { unexpected: 'format' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it 'returns generic API error with status code' do
          result = client.get_shop(42)

          expect(result.error).to eq('API error (422)')
        end
      end

      context 'with non-JSON response' do
        before do
          stub_request(:get, "#{base_url}/api/v1/shops/42")
            .to_return(
              status: 500,
              body: 'Internal Server Error - Something crashed',
              headers: { 'Content-Type' => 'text/plain' }
            )
        end

        it 'returns API error with truncated body' do
          result = client.get_shop(42)

          expect(result.error).to include('API error (500)')
          expect(result.error).to include('Internal Server Error')
        end
      end
    end
  end

  describe 'connection configuration' do
    it 'uses correct timeout settings' do
      expect(described_class::CONNECT_TIMEOUT).to eq(5)
      expect(described_class::READ_TIMEOUT).to eq(30)
    end
  end
end
