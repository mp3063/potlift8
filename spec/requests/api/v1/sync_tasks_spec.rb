# API V1 Sync Tasks Request Spec
#
# Tests for Sync Tasks API endpoints with Bearer token authentication.
# Comprehensive tests for sync task processing including idempotency,
# different event types, and error scenarios.
#
require 'rails_helper'

RSpec.describe 'Api::V1::SyncTasks', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:valid_token) { company.api_token }
  let(:invalid_token) { 'invalid_token_12345' }

  let(:product) { create(:product, company: company, sku: 'SYNC-PROD-001', product_status: :active) }
  let(:storage) { create(:storage, company: company, code: 'MAIN', name: 'Main Storage') }

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

  # Helper method to clear Redis cache between tests
  def clear_redis_cache
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
      redis.flushdb
    rescue Redis::BaseError => e
      Rails.logger.warn("Could not clear Redis: #{e.message}")
    end
  end

  before do
    clear_redis_cache
  end

  after do
    clear_redis_cache
  end

  describe 'POST /api/v1/sync_tasks' do
    context 'with valid authentication' do
      context 'product_update event' do
        let(:valid_params) do
          {
            sync_task: {
              origin_event_id: 'evt_product_update_001',
              direction: 'inbound',
              event_type: 'product_update',
              key: product.sku,
              load: {
                sku: product.sku,
                name: 'Updated Product Name',
                product_status: 'active'
              }
            }
          }
        end

        it 'processes product update successfully' do
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['event_id']).to eq('evt_product_update_001')
          expect(json['event_type']).to eq('product_update')
          expect(json['processed_at']).to be_present
          expect(json['result']['product_id']).to eq(product.id)
          expect(json['result']['sku']).to eq(product.sku)
          expect(json['result']['updated']).to be true
        end

        it 'updates the product in database' do
          expect do
            post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers
          end.to change { product.reload.name }.to('Updated Product Name')
        end

        it 'does not update if product not found' do
          params = valid_params.deep_dup
          params[:sync_task][:load][:sku] = 'NONEXISTENT'
          params[:sync_task][:key] = 'NONEXISTENT'

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['error']).to include('Product not found')
        end
      end

      context 'inventory_update event' do
        let(:valid_params) do
          {
            sync_task: {
              origin_event_id: 'evt_inventory_update_001',
              direction: 'inbound',
              event_type: 'inventory_update',
              key: product.sku,
              load: {
                sku: product.sku,
                updates: [
                  { storage_code: 'MAIN', value: 250 }
                ]
              }
            }
          }
        end

        before do
          storage
        end

        it 'processes inventory update successfully' do
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['event_type']).to eq('inventory_update')
          expect(json['result']['inventory']).to be_present
        end

        it 'updates inventory in database' do
          expect do
            post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers
          end.to change { product.inventories.count }.by(1)

          inventory = product.inventories.find_by(storage: storage)
          expect(inventory.value).to eq(250)
        end

        it 'handles missing updates parameter' do
          params = valid_params.deep_dup
          params[:sync_task][:load].delete(:updates)

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['error']).to include('updates array is required')
        end

        it 'handles missing SKU in load' do
          params = valid_params.deep_dup
          params[:sync_task][:load].delete(:sku)
          params[:sync_task].delete(:key)

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['error']).to include('SKU is required')
        end
      end

      context 'idempotency with duplicate events' do
        let(:valid_params) do
          {
            sync_task: {
              origin_event_id: 'evt_duplicate_test_001',
              direction: 'inbound',
              event_type: 'product_update',
              key: product.sku,
              load: {
                sku: product.sku,
                name: 'First Update'
              }
            }
          }
        end

        it 'processes first event normally' do
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['duplicate']).to be_nil
        end

        it 'returns duplicate response for second identical event' do
          # First request
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers
          expect(response).to have_http_status(:ok)

          # Second request with same event_id
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

          expect(response).to have_http_status(:ok)

          json = JSON.parse(response.body)
          expect(json['success']).to be true
          expect(json['duplicate']).to be true
          expect(json['message']).to include('Event already processed')
        end

        it 'does not update product twice' do
          # First update
          post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

          # Change the name in second request
          params = valid_params.deep_dup
          params[:sync_task][:load][:name] = 'Second Update'

          # Second request should be ignored
          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          product.reload
          expect(product.name).to eq('First Update') # Should still be first update
        end
      end

      context 'with missing required parameters' do
        it 'returns 400 for missing origin_event_id' do
          params = {
            sync_task: {
              direction: 'inbound',
              event_type: 'product_update',
              load: { sku: product.sku }
            }
          }

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('origin_event_id is required')
        end

        it 'returns 400 for missing direction' do
          params = {
            sync_task: {
              origin_event_id: 'evt_001',
              event_type: 'product_update',
              load: { sku: product.sku }
            }
          }

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('direction is required')
        end

        it 'returns 400 for missing event_type' do
          params = {
            sync_task: {
              origin_event_id: 'evt_001',
              direction: 'inbound',
              load: { sku: product.sku }
            }
          }

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('event_type is required')
        end

        it 'returns 400 for missing load' do
          params = {
            sync_task: {
              origin_event_id: 'evt_001',
              direction: 'inbound',
              event_type: 'product_update'
            }
          }

          post '/api/v1/sync_tasks', params: params.to_json, headers: headers

          expect(response).to have_http_status(:bad_request)

          json = JSON.parse(response.body)
          expect(json['message']).to include('load is required')
        end
      end

      context 'with invalid event type' do
        let(:invalid_params) do
          {
            sync_task: {
              origin_event_id: 'evt_invalid_001',
              direction: 'inbound',
              event_type: 'invalid_event_type',
              load: { data: 'test' }
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          post '/api/v1/sync_tasks', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['error']).to include('Invalid event_type')
        end
      end

      context 'with invalid direction' do
        let(:invalid_params) do
          {
            sync_task: {
              origin_event_id: 'evt_invalid_002',
              direction: 'sideways',
              event_type: 'product_update',
              load: { sku: product.sku }
            }
          }
        end

        it 'returns 422 unprocessable entity' do
          post '/api/v1/sync_tasks', params: invalid_params.to_json, headers: headers

          expect(response).to have_http_status(:unprocessable_entity)

          json = JSON.parse(response.body)
          expect(json['success']).to be false
          expect(json['error']).to include('Invalid direction')
        end
      end
    end

    context 'with multi-tenancy isolation' do
      let(:other_product) { create(:product, company: other_company, sku: 'OTHER-PROD') }

      it 'cannot update other company products' do
        params = {
          sync_task: {
            origin_event_id: 'evt_other_company_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: other_product.sku,
            load: {
              sku: other_product.sku,
              name: 'Hacked Name'
            }
          }
        }

        post '/api/v1/sync_tasks', params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['error']).to include('Product not found')

        # Verify product was not updated
        other_product.reload
        expect(other_product.name).not_to eq('Hacked Name')
      end

      it 'stores events in company-scoped Redis keys' do
        params = {
          sync_task: {
            origin_event_id: 'evt_scoped_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: product.sku,
            load: {
              sku: product.sku,
              name: 'Updated'
            }
          }
        }

        post '/api/v1/sync_tasks', params: params.to_json, headers: headers

        # Check that Redis key includes company ID
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        redis_key = "sync_task:processed:#{company.id}:evt_scoped_001"
        result = redis.exists?(redis_key)
        # Redis 4.x+ returns integer (0 or 1), older versions return boolean
        expect(result.is_a?(Integer) ? result : (result ? 1 : 0)).to be > 0
      end
    end

    context 'without authentication' do
      it 'returns 401 unauthorized without token' do
        params = {
          sync_task: {
            origin_event_id: 'evt_unauth_001',
            direction: 'inbound',
            event_type: 'product_update',
            load: { sku: product.sku }
          }
        }

        post '/api/v1/sync_tasks', params: params.to_json

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Missing')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 unauthorized with invalid token' do
        params = {
          sync_task: {
            origin_event_id: 'evt_invalid_auth_001',
            direction: 'inbound',
            event_type: 'product_update',
            load: { sku: product.sku }
          }
        }

        post '/api/v1/sync_tasks', params: params.to_json, headers: invalid_headers

        expect(response).to have_http_status(:unauthorized)

        json = JSON.parse(response.body)
        expect(json['error']).to eq('unauthorized')
        expect(json['message']).to include('Invalid')
      end
    end

    context 'with response structure validation' do
      let(:valid_params) do
        {
          sync_task: {
            origin_event_id: 'evt_structure_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: product.sku,
            load: {
              sku: product.sku,
              name: 'Structure Test Product'
            }
          }
        }
      end

      it 'returns correct success response structure' do
        post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Verify top-level structure
        expect(json).to have_key('success')
        expect(json).to have_key('event_id')
        expect(json).to have_key('event_type')
        expect(json).to have_key('processed_at')
        expect(json).to have_key('result')

        # Verify data types
        expect(json['success']).to be_a(TrueClass)
        expect(json['event_id']).to be_a(String)
        expect(json['event_type']).to be_a(String)
        expect(json['processed_at']).to be_a(String)
        expect(json['result']).to be_a(Hash)
      end

      it 'returns correct duplicate response structure' do
        # First request
        post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

        # Second request (duplicate)
        post '/api/v1/sync_tasks', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        json = JSON.parse(response.body)

        # Verify duplicate-specific fields
        expect(json).to have_key('success')
        expect(json).to have_key('event_id')
        expect(json).to have_key('event_type')
        expect(json).to have_key('duplicate')
        expect(json).to have_key('message')

        expect(json['duplicate']).to be true
        expect(json['message']).to be_a(String)
      end
    end
  end
end
