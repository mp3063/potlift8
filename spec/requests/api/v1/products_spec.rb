# API V1 Products Request Spec
#
# Tests for Products API endpoints with Bearer token authentication.
#
require 'rails_helper'

RSpec.describe 'Api::V1::Products', type: :request do
  let(:company) { create(:company) }
  let(:valid_token) { company.api_token }
  let(:invalid_token) { 'invalid_token_12345' }

  let(:headers) do
    {
      'Authorization' => "Bearer #{valid_token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:invalid_headers) do
    {
      'Authorization' => "Bearer #{invalid_token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /api/v1/products' do
    context 'with valid authentication' do
      let!(:product1) { create(:product, company: company, product_type: :sellable, product_status: :active, sku: 'PROD001') }
      let!(:product2) { create(:product, company: company, product_type: :sellable, product_status: :active, sku: 'PROD002') }
      let!(:other_company_product) { create(:product, product_type: :sellable, product_status: :active) }

      it 'returns list of active, sellable products for the company' do
        get '/api/v1/products', headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['products']).to be_an(Array)
        expect(json['products'].length).to eq(2)
        expect(json['products'].map { |p| p['sku'] }).to contain_exactly('PROD001', 'PROD002')

        # Verify meta pagination
        expect(json['meta']['total']).to eq(2)
        expect(json['meta']['page']).to eq(1)
        expect(json['meta']['per_page']).to eq(50)
      end

      it 'does not return products from other companies' do
        get '/api/v1/products', headers: headers

        json = JSON.parse(response.body)
        skus = json['products'].map { |p| p['sku'] }
        expect(skus).not_to include(other_company_product.sku)
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/products', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Invalid')
      end
    end

    context 'with missing authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/products'

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Missing')
      end
    end
  end

  describe 'GET /api/v1/products/:sku' do
    context 'with valid authentication' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'TEST123',
               name: 'Test Product',
               product_type: :sellable,
               product_status: :active)
      end

      it 'returns product details' do
        get "/api/v1/products/#{product.sku}", headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['product']['sku']).to eq('TEST123')
        expect(json['product']['name']).to eq('Test Product')
        expect(json['product']).to have_key('inventory')
        expect(json['product']).to have_key('attributes')
      end

      it 'returns 404 for non-existent product' do
        get '/api/v1/products/NONEXISTENT', headers: headers

        expect(response).to have_http_status(:not_found)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('not_found')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        get '/api/v1/products/TEST123', headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH /api/v1/products/:sku' do
    context 'with valid authentication' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'UPDATE123',
               name: 'Original Name',
               product_status: :draft)
      end

      it 'updates product successfully' do
        patch "/api/v1/products/#{product.sku}",
              params: {
                product: {
                  name: 'Updated Name',
                  product_status: 'active'
                }
              }.to_json,
              headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)
        expect(json['product']['name']).to eq('Updated Name')
        expect(json['product']['product_status']).to eq('active')

        product.reload
        expect(product.name).to eq('Updated Name')
        expect(product.product_status).to eq('active')
      end

      it 'returns validation errors for invalid data' do
        patch "/api/v1/products/#{product.sku}",
              params: {
                product: {
                  name: '' # Invalid: name is required
                }
              }.to_json,
              headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized' do
        patch '/api/v1/products/UPDATE123',
              params: { product: { name: 'New Name' } }.to_json,
              headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
