# API V1 Inventories Request Spec
#
# Tests for Inventory API endpoints with Bearer token authentication.
# Comprehensive tests for inventory update functionality including multi-storage
# updates, ETA handling, and error scenarios.
#
require 'rails_helper'

RSpec.describe 'Api::V1::Inventories', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:valid_token) { company.api_token }
  let(:invalid_token) { 'invalid_token_12345' }

  let(:product) { create(:product, company: company, sku: 'TEST-SKU-001', product_status: :active) }
  let(:storage_main) { create(:storage, company: company, code: 'MAIN', name: 'Main Storage') }
  let(:storage_incoming) { create(:storage, company: company, code: 'INCOMING', name: 'Incoming Storage', storage_type: :incoming) }

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

  describe 'POST /api/v1/inventories/update' do
    context 'with valid authentication' do
      before do
        # Ensure storages exist
        storage_main
        storage_incoming
      end

      context 'with single storage update' do
        let(:valid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 100 }
              ]
            }
          }
        end

        it 'updates inventory successfully' do
          post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['product']['sku']).to eq('TEST-SKU-001')
          expect(json['inventory']).to be_present
          expect(json['updates']).to be_an(Array)
          expect(json['updates'].first['storage_code']).to eq('MAIN')
          expect(json['updates'].first['value']).to eq(100)
          expect(json['updates'].first['updated']).to be true
        end

        it 'updates the inventory record in database' do
          expect do
            post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers
          end.to change { product.inventories.count }.by(1)

          inventory = product.inventories.find_by(storage: storage_main)
          expect(inventory.value).to eq(100)
        end

        it 'updates existing inventory if already present' do
          # Create existing inventory
          create(:inventory, product: product, storage: storage_main, value: 50)

          expect do
            post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers
          end.not_to change { product.inventories.count }

          inventory = product.inventories.find_by(storage: storage_main)
          expect(inventory.value).to eq(100)
        end
      end

      context 'with multiple storage updates' do
        let(:valid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 150 },
                { storage_code: 'INCOMING', value: 50 }
              ]
            }
          }
        end

        it 'updates multiple storages successfully' do
          post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['updates'].length).to eq(2)

          main_update = json['updates'].find { |u| u['storage_code'] == 'MAIN' }
          incoming_update = json['updates'].find { |u| u['storage_code'] == 'INCOMING' }

          expect(main_update['value']).to eq(150)
          expect(incoming_update['value']).to eq(50)
        end

        it 'creates inventory records for all storages' do
          expect do
            post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers
          end.to change { product.inventories.count }.by(2)

          main_inventory = product.inventories.find_by(storage: storage_main)
          incoming_inventory = product.inventories.find_by(storage: storage_incoming)

          expect(main_inventory.value).to eq(150)
          expect(incoming_inventory.value).to eq(50)
        end
      end

      context 'with ETA dates' do
        let(:eta_date) { '2025-11-15' }
        let(:valid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'INCOMING', value: 75, eta: eta_date }
              ]
            }
          }
        end

        it 'stores ETA date correctly' do
          post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true

          inventory = product.inventories.find_by(storage: storage_incoming)
          expect(inventory.eta).to eq(Date.parse(eta_date))
        end

        it 'includes ETA in response' do
          post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

          json = JSON.parse(response.body)
          update = json['updates'].first
          expect(update['eta']).to eq(Date.parse(eta_date).to_s)
        end

        it 'handles nil ETA gracefully' do
          params = {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 100, eta: nil }
              ]
            }
          }

          post '/api/v1/inventories/update', params: params.to_json, headers: headers

          expect(response).to have_http_status(:ok)
          inventory = product.inventories.find_by(storage: storage_main)
          expect(inventory.eta).to be_nil
        end
      end

      context 'with invalid SKU' do
        let(:invalid_params) do
          {
            sku: 'NONEXISTENT-SKU',
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 100 }
              ]
            }
          }
        end

        it 'returns 404 not found' do
          post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:not_found)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('Product not found')
        end
      end

      context 'with invalid storage code' do
        let(:invalid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'INVALID_STORAGE', value: 100 }
              ]
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('Storage not found')
        end
      end

      context 'with missing SKU' do
        let(:invalid_params) do
          {
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 100 }
              ]
            }
          }
        end

        it 'returns 400 bad request' do
          post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('SKU is required')
        end
      end

      context 'with missing inventory updates' do
        let(:invalid_params) do
          {
            sku: product.sku,
            inventory: {}
          }
        end

        it 'returns 400 bad request' do
          post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('inventory.updates must be a non-empty array')
        end
      end

      context 'with invalid inventory value' do
        let(:invalid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 'not_a_number' }
              ]
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['message']).to include('Invalid value')
        end
      end

      context 'with transaction rollback' do
        let(:valid_params) do
          {
            sku: product.sku,
            inventory: {
              updates: [
                { storage_code: 'MAIN', value: 100 },
                { storage_code: 'INVALID', value: 50 } # This will fail
              ]
            }
          }
        end

        it 'rolls back all updates on error' do
          expect do
            post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers
          end.not_to change { product.inventories.count }

          expect(response).to have_http_status(:unprocessable_entity)
        end
      end
    end

    context 'with multi-tenancy isolation' do
      let(:other_company_product) { create(:product, company: other_company, sku: 'OTHER-SKU') }
      let(:other_storage) { create(:storage, company: other_company, code: 'OTHER') }

      before do
        other_storage
      end

      it 'cannot update other company products' do
        params = {
          sku: other_company_product.sku,
          inventory: {
            updates: [
              { storage_code: 'OTHER', value: 100 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: params.to_json, headers: headers

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)['message']).to include('Product not found')
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized without token' do
        params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 100 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: params.to_json

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Missing')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized with invalid token' do
        params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 100 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: params.to_json, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Invalid')
      end
    end

    context 'with response structure validation' do
      let(:valid_params) do
        {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 200 },
              { storage_code: 'INCOMING', value: 50, eta: '2025-12-01' }
            ]
          }
        }
      end

      before do
        storage_main
        storage_incoming
      end

      it 'returns correct response structure' do
        post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Verify top-level structure
        expect(json).to have_key('success')
        expect(json).to have_key('product')
        expect(json).to have_key('inventory')
        expect(json).to have_key('updates')

        # Verify product structure
        expect(json['product']).to have_key('id')
        expect(json['product']).to have_key('sku')
        expect(json['product']).to have_key('name')

        # Verify inventory structure
        expect(json['inventory']).to have_key('available')
        expect(json['inventory']).to have_key('incoming')
        expect(json['inventory']).to have_key('eta')

        # Verify updates structure
        expect(json['updates']).to be_an(Array)
        expect(json['updates'].first).to have_key('storage_code')
        expect(json['updates'].first).to have_key('value')
        expect(json['updates'].first).to have_key('updated')
      end
    end
  end
end
