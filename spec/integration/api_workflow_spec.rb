# API Workflow Integration Spec
#
# End-to-end integration tests for complete API workflows.
# Tests realistic scenarios combining multiple API endpoints and services.
#
require 'rails_helper'

RSpec.describe 'API Workflow Integration', type: :request do
  let(:company) { create(:company) }
  let(:headers) do
    {
      'Authorization' => "Bearer #{company.api_token}",
      'Content-Type' => 'application/json'
    }
  end

  let(:storage_main) { create(:storage, company: company, code: 'MAIN', name: 'Main Storage') }
  let(:storage_incoming) { create(:storage, company: company, code: 'INCOMING', name: 'Incoming Storage', storage_type: :incoming) }
  let(:catalog) { create(:catalog, company: company, code: 'WEBSHOP', catalog_type: :webshop) }

  def clear_redis
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
      redis.flushdb
    rescue Redis::BaseError => e
      Rails.logger.warn("Could not clear Redis: #{e.message}")
    end
  end

  before do
    clear_redis
    storage_main
    storage_incoming
  end

  after do
    clear_redis
  end

  describe 'Complete Product Sync Workflow' do
    # Scenario: External system creates product → activates it → syncs to catalog
    #
    # Steps:
    # 1. Receive product_update sync task to update product details
    # 2. Verify product is updated
    # 3. Receive product_update sync task to activate product
    # 4. Verify product is activated
    # 5. Product should trigger sync to catalogs via ChangePropagator
    # 6. Fetch product details via API
    # 7. Verify all data is consistent
    #
    context 'from creation to activation' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'WORKFLOW-001',
               name: 'Initial Product',
               product_status: :draft)
      end

      let!(:catalog_item) do
        create(:catalog_item, catalog: catalog, product: product, catalog_item_state: :inactive)
      end

      it 'processes complete workflow successfully', :aggregate_failures do
        # Step 1: Update product details via sync task
        sync_params = {
          sync_task: {
            origin_event_id: 'evt_workflow_update_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: product.sku,
            load: {
              sku: product.sku,
              name: 'Updated Product Name',
              ean: '1234567890123'
            }
          }
        }

        post '/api/v1/sync_tasks', params: sync_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true

        # Step 2: Verify product is updated
        product.reload
        expect(product.name).to eq('Updated Product Name')
        expect(product.ean).to eq('1234567890123')

        # Step 3: Activate product via sync task
        activation_params = {
          sync_task: {
            origin_event_id: 'evt_workflow_activate_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: product.sku,
            load: {
              sku: product.sku,
              product_status: 'active'
            }
          }
        }

        post '/api/v1/sync_tasks', params: activation_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true

        # Step 4: Verify product is activated
        product.reload
        expect(product.product_status).to eq('active')

        # Step 5: Product sync jobs should be enqueued (via ChangePropagator)
        # Note: This happens via after_commit callback

        # Step 6: Fetch product details via API
        get "/api/v1/products/#{product.sku}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Step 7: Verify all data is consistent
        expect(json['product']['sku']).to eq('WORKFLOW-001')
        expect(json['product']['name']).to eq('Updated Product Name')
        expect(json['product']['ean']).to eq('1234567890123')
        expect(json['product']['product_status']).to eq('active')
      end
    end
  end

  describe 'Inventory Update Cascade Workflow' do
    # Scenario: Update inventory → triggers product sync to catalog
    #
    # Steps:
    # 1. Create active product in catalog
    # 2. Update inventory via API
    # 3. Verify inventory is updated
    # 4. Update inventory via sync task
    # 5. Verify inventory reflects latest update
    # 6. Fetch product and verify inventory totals
    #
    context 'with inventory updates triggering sync' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'INV-WORKFLOW-001',
               name: 'Inventory Test Product',
               product_status: :active)
      end

      let!(:catalog_item) do
        create(:catalog_item, catalog: catalog, product: product, catalog_item_state: :active)
      end

      it 'processes inventory updates and syncs', :aggregate_failures do
        # Step 1: Product is already created and in catalog

        # Step 2: Update inventory via API
        inventory_params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 100 },
              { storage_code: 'INCOMING', value: 50, eta: '2025-12-01' }
            ]
          }
        }

        post '/api/v1/inventories/update', params: inventory_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Step 3: Verify inventory is updated
        expect(json['success']).to be true
        expect(json['updates'].length).to eq(2)

        product.reload
        main_inventory = product.inventories.find_by(storage: storage_main)
        incoming_inventory = product.inventories.find_by(storage: storage_incoming)

        expect(main_inventory.value).to eq(100)
        expect(incoming_inventory.value).to eq(50)
        expect(incoming_inventory.eta).to eq(Date.parse('2025-12-01'))

        # Step 4: Update inventory again via sync task
        sync_params = {
          sync_task: {
            origin_event_id: 'evt_inventory_sync_001',
            direction: 'inbound',
            event_type: 'inventory_update',
            key: product.sku,
            load: {
              sku: product.sku,
              updates: [
                { storage_code: 'MAIN', value: 150 }
              ]
            }
          }
        }

        post '/api/v1/sync_tasks', params: sync_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true

        # Step 5: Verify inventory reflects latest update
        product.reload
        main_inventory.reload
        expect(main_inventory.value).to eq(150)

        # Step 6: Fetch product and verify inventory totals
        get "/api/v1/products/#{product.sku}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['product']['inventory']).to be_present
        expect(json['product']['inventory']['available']).to be_present
        expect(json['product']['inventory']['incoming']).to be_present
      end
    end
  end

  describe 'Idempotent Sync Operations' do
    # Scenario: Same event received multiple times should be processed once
    #
    # Steps:
    # 1. Send sync task event
    # 2. Verify it's processed
    # 3. Send same event again
    # 4. Verify it's marked as duplicate
    # 5. Verify product state didn't change on second attempt
    #
    context 'with duplicate event IDs' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'IDEMPOTENT-001',
               name: 'Original Name',
               product_status: :draft)
      end

      it 'handles duplicate events correctly', :aggregate_failures do
        # Step 1: Send first sync task
        sync_params = {
          sync_task: {
            origin_event_id: 'evt_idempotent_unique_001',
            direction: 'inbound',
            event_type: 'product_update',
            key: product.sku,
            load: {
              sku: product.sku,
              name: 'First Update'
            }
          }
        }

        post '/api/v1/sync_tasks', params: sync_params.to_json, headers: headers

        # Step 2: Verify it's processed
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['duplicate']).to be_nil

        product.reload
        expect(product.name).to eq('First Update')

        # Step 3: Send same event again with different data
        sync_params[:sync_task][:load][:name] = 'Second Update Attempt'

        post '/api/v1/sync_tasks', params: sync_params.to_json, headers: headers

        # Step 4: Verify it's marked as duplicate
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true
        expect(json['duplicate']).to be true
        expect(json['message']).to include('Event already processed')

        # Step 5: Verify product state didn't change
        product.reload
        expect(product.name).to eq('First Update') # Should not be 'Second Update Attempt'
      end
    end
  end

  describe 'Multi-Step Product Update' do
    # Scenario: Update product attributes, then inventory, then fetch full details
    #
    # Steps:
    # 1. Update product basic info
    # 2. Add product attributes via EAV
    # 3. Update inventory
    # 4. Add labels
    # 5. Fetch complete product details
    # 6. Verify all data is present and correct
    #
    context 'with complete product setup' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'MULTISTEP-001',
               name: 'Original',
               product_status: :draft)
      end

      let!(:price_attr) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
      let!(:label) { create(:label, company: company, code: 'featured', name: 'Featured') }

      it 'completes multi-step setup workflow', :aggregate_failures do
        # Step 1: Update product basic info
        patch "/api/v1/products/#{product.sku}",
              params: {
                product: {
                  name: 'Updated Multi-Step Product',
                  product_status: 'active'
                }
              }.to_json,
              headers: headers

        expect(response).to have_http_status(:ok)

        # Step 2: Add product attributes
        product.reload
        product.write_attribute_value('price', '2999')

        # Step 3: Update inventory
        inventory_params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 200 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: inventory_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)

        # Step 4: Add labels
        create(:product_label, product: product, label: label)

        # Step 5: Fetch complete product details
        get "/api/v1/products/#{product.sku}", headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        # Step 6: Verify all data is present and correct
        product_data = json['product']

        expect(product_data['sku']).to eq('MULTISTEP-001')
        expect(product_data['name']).to eq('Updated Multi-Step Product')
        expect(product_data['product_status']).to eq('active')

        expect(product_data['attributes']).to have_key('price')
        expect(product_data['attributes']['price']).to eq('2999')

        expect(product_data['inventory']).to be_present
        expect(product_data['inventory']['available']).to be_present

        expect(product_data['labels']).to be_an(Array)
        expect(product_data['labels'].first['code']).to eq('featured')
      end
    end
  end

  describe 'Error Recovery Scenarios' do
    # Scenario: Handle errors gracefully and maintain data consistency
    #
    context 'with invalid data followed by valid data' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'ERROR-RECOVERY-001',
               name: 'Error Test',
               product_status: :draft)
      end

      it 'recovers from errors and processes valid requests', :aggregate_failures do
        # Attempt 1: Invalid inventory update (bad storage)
        invalid_params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'INVALID_STORAGE', value: 100 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['success']).to be false

        # Verify no inventory was created
        expect(product.inventories.count).to eq(0)

        # Attempt 2: Valid inventory update
        valid_params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 100 }
            ]
          }
        }

        post '/api/v1/inventories/update', params: valid_params.to_json, headers: headers

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['success']).to be true

        # Verify inventory was created
        product.reload
        expect(product.inventories.count).to eq(1)
        expect(product.inventories.first.value).to eq(100)

        # Verify product can still be fetched
        get "/api/v1/products/#{product.sku}", headers: headers

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with transaction rollback' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'ROLLBACK-001',
               name: 'Rollback Test')
      end

      it 'maintains data consistency on partial failures', :aggregate_failures do
        # Attempt to update multiple inventories where one will fail
        params = {
          sku: product.sku,
          inventory: {
            updates: [
              { storage_code: 'MAIN', value: 100 },
              { storage_code: 'INVALID', value: 50 } # This will fail
            ]
          }
        }

        post '/api/v1/inventories/update', params: params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_entity)

        # Verify NO inventory was created (transaction rolled back)
        product.reload
        expect(product.inventories.count).to eq(0)

        # Verify product state is unchanged
        expect(product.name).to eq('Rollback Test')
      end
    end
  end

  describe 'Product List and Detail Consistency' do
    # Scenario: Verify list and detail endpoints return consistent data
    #
    context 'with multiple products' do
      let!(:product1) do
        create(:product,
               company: company,
               sku: 'CONSISTENCY-001',
               name: 'Product 1',
               product_status: :active,
               product_type: :sellable)
      end

      let!(:product2) do
        create(:product,
               company: company,
               sku: 'CONSISTENCY-002',
               name: 'Product 2',
               product_status: :active,
               product_type: :sellable)
      end

      before do
        create(:inventory, product: product1, storage: storage_main, value: 100)
        create(:inventory, product: product2, storage: storage_main, value: 200)
      end

      it 'maintains consistency between list and detail views', :aggregate_failures do
        # Fetch product list
        get '/api/v1/products', headers: headers

        expect(response).to have_http_status(:ok)
        list_json = JSON.parse(response.body)

        expect(list_json['products'].length).to eq(2)

        # Fetch each product's details
        product1_data = list_json['products'].find { |p| p['sku'] == 'CONSISTENCY-001' }

        get "/api/v1/products/#{product1_data['sku']}", headers: headers

        expect(response).to have_http_status(:ok)
        detail_json = JSON.parse(response.body)

        # Verify basic fields match
        expect(detail_json['product']['sku']).to eq(product1_data['sku'])
        expect(detail_json['product']['name']).to eq(product1_data['name'])
        expect(detail_json['product']['product_status']).to eq(product1_data['product_status'])

        # Detail view should have additional data
        expect(detail_json['product']).to have_key('inventory')
        expect(detail_json['product']).to have_key('attributes')
        expect(detail_json['product']).to have_key('labels')
      end
    end
  end

  describe 'Authentication Flow' do
    # Scenario: Verify authentication is enforced across all endpoints
    #
    context 'without valid authentication' do
      let(:invalid_headers) do
        {
          'Authorization' => 'Bearer invalid_token',
          'Content-Type' => 'application/json'
        }
      end

      it 'blocks all API access without valid token', :aggregate_failures do
        # Test products list
        get '/api/v1/products', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)

        # Test product detail
        get '/api/v1/products/TEST-SKU', headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)

        # Test product update
        patch '/api/v1/products/TEST-SKU',
              params: { product: { name: 'Hacked' } }.to_json,
              headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)

        # Test inventory update
        post '/api/v1/inventories/update',
             params: { sku: 'TEST-SKU', inventory: { updates: [] } }.to_json,
             headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)

        # Test sync task
        post '/api/v1/sync_tasks',
             params: { sync_task: { origin_event_id: 'evt_001' } }.to_json,
             headers: invalid_headers
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
