# Sync Task Processor Service Spec
#
# Tests for SyncTaskProcessor that handles sync tasks from external systems
# with idempotency, multiple event types, and error handling.
#
require 'rails_helper'

RSpec.describe SyncTaskProcessor do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:product) { create(:product, company: company, sku: 'SYNC-TEST-001', name: 'Original Name') }
  let(:storage) { create(:storage, company: company, code: 'MAIN') }

  let(:service) { described_class.new(company) }

  # Helper to clear Redis between tests
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
  end

  after do
    clear_redis
  end

  describe '#initialize' do
    it 'sets company' do
      expect(service.company).to eq(company)
    end

    it 'initializes empty errors array' do
      expect(service.errors).to eq([])
    end
  end

  describe 'EVENT_TYPES constant' do
    it 'defines supported event types' do
      expect(described_class::EVENT_TYPES).to include(
        'product_update',
        'product_create',
        'inventory_update',
        'order_sync',
        'catalog_sync'
      )
    end
  end

  describe 'DIRECTIONS constant' do
    it 'defines supported directions' do
      expect(described_class::DIRECTIONS).to eq(%w[inbound outbound])
    end
  end

  describe '#process' do
    context 'with product_update event' do
      let(:params) do
        {
          origin_event_id: 'evt_product_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'Updated Product Name',
            ean: '1234567890123'
          }
        }
      end

      it 'returns success response' do
        result = service.process(**params)

        expect(result[:success]).to be true
        expect(result[:event_id]).to eq('evt_product_001')
        expect(result[:event_type]).to eq('product_update')
        expect(result[:processed_at]).to be_present
        expect(result[:result]).to be_present
      end

      it 'updates product fields' do
        service.process(**params)

        product.reload
        expect(product.name).to eq('Updated Product Name')
        expect(product.ean).to eq('1234567890123')
      end

      it 'includes product details in result' do
        result = service.process(**params)

        expect(result[:result][:product_id]).to eq(product.id)
        expect(result[:result][:sku]).to eq(product.sku)
        expect(result[:result][:updated]).to be true
      end

      it 'handles product not found' do
        params[:load][:sku] = 'NONEXISTENT'
        params[:key] = 'NONEXISTENT'

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Product not found')
      end

      it 'updates product_status when provided' do
        params[:load][:product_status] = 'active'

        service.process(**params)

        product.reload
        expect(product.product_status).to eq('active')
      end

      it 'updates info JSONB field when provided' do
        params[:load][:info] = { 'description' => 'New description' }

        service.process(**params)

        product.reload
        expect(product.info).to eq({ 'description' => 'New description' })
      end

      it 'handles SKU from load if key not provided' do
        params.delete(:key)

        result = service.process(**params)

        expect(result[:success]).to be true
        product.reload
        expect(product.name).to eq('Updated Product Name')
      end
    end

    context 'with product_create event' do
      let(:params) do
        {
          origin_event_id: 'evt_create_001',
          direction: 'inbound',
          event_type: 'product_create',
          load: {
            sku: 'NEW-PRODUCT-001',
            name: 'New Product',
            product_type: 'sellable'
          }
        }
      end

      it 'returns not implemented error' do
        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Product creation via sync is not yet implemented')
      end
    end

    context 'with inventory_update event' do
      let(:params) do
        {
          origin_event_id: 'evt_inventory_001',
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
      end

      before do
        storage
      end

      it 'returns success response' do
        result = service.process(**params)

        expect(result[:success]).to be true
        expect(result[:event_type]).to eq('inventory_update')
      end

      it 'updates inventory' do
        expect do
          service.process(**params)
        end.to change { product.inventories.count }.by(1)

        inventory = product.inventories.find_by(storage: storage)
        expect(inventory.value).to eq(150)
      end

      it 'includes inventory in result' do
        result = service.process(**params)

        expect(result[:result][:product_id]).to eq(product.id)
        expect(result[:result][:sku]).to eq(product.sku)
        expect(result[:result][:inventory]).to be_present
      end

      it 'handles missing SKU' do
        params[:load].delete(:sku)
        params.delete(:key)

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('SKU is required')
      end

      it 'handles missing updates' do
        params[:load].delete(:updates)

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('updates array is required')
      end

      it 'handles product not found' do
        params[:load][:sku] = 'NONEXISTENT'
        params[:key] = 'NONEXISTENT'

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Product not found')
      end

      it 'uses InventoryUpdateService' do
        expect_any_instance_of(InventoryUpdateService).to receive(:update).and_call_original

        service.process(**params)
      end
    end

    context 'with order_sync event' do
      let(:params) do
        {
          origin_event_id: 'evt_order_001',
          direction: 'inbound',
          event_type: 'order_sync',
          load: { order_id: 'ORD-123' }
        }
      end

      it 'returns not implemented error' do
        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Order sync is not yet implemented')
      end
    end

    context 'with catalog_sync event' do
      let(:params) do
        {
          origin_event_id: 'evt_catalog_001',
          direction: 'inbound',
          event_type: 'catalog_sync',
          load: { catalog_id: 123 }
        }
      end

      it 'returns not implemented error' do
        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Catalog sync is not yet implemented')
      end
    end

    context 'with idempotency' do
      let(:params) do
        {
          origin_event_id: 'evt_idempotent_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'First Update'
          }
        }
      end

      it 'processes first event normally' do
        result = service.process(**params)

        expect(result[:success]).to be true
        expect(result[:duplicate]).to be_nil

        product.reload
        expect(product.name).to eq('First Update')
      end

      it 'detects duplicate event' do
        # First processing
        service.process(**params)

        # Second processing with same event_id
        result = service.process(**params)

        expect(result[:success]).to be true
        expect(result[:duplicate]).to be true
        expect(result[:message]).to include('Event already processed')
      end

      it 'does not reprocess duplicate event' do
        # First update
        service.process(**params)

        # Try to update with different data but same event_id
        params[:load][:name] = 'Second Update'

        service.process(**params)

        product.reload
        expect(product.name).to eq('First Update') # Should not change
      end

      it 'stores event in Redis with 24 hour expiration' do
        service.process(**params)

        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        redis_key = "sync_task:processed:#{company.id}:evt_idempotent_001"

        result = redis.exists?(redis_key)
        # Redis 4.x+ returns integer (0 or 1), older versions return boolean
        expect(result.is_a?(Integer) ? result : (result ? 1 : 0)).to be > 0

        # Check TTL is approximately 24 hours (86400 seconds)
        ttl = redis.ttl(redis_key)
        expect(ttl).to be_between(86300, 86400)
      end

      it 'scopes duplicate detection to company' do
        other_service = described_class.new(other_company)
        other_product = create(:product, company: other_company, sku: 'OTHER-SKU')

        params_other = params.deep_dup
        params_other[:key] = other_product.sku
        params_other[:load][:sku] = other_product.sku

        # Process for first company
        service.process(**params)

        # Process for second company with same event_id
        result = other_service.process(**params_other)

        # Should NOT be duplicate because different company
        expect(result[:duplicate]).to be_nil
      end

      it 'handles Redis errors gracefully' do
        # Simulate Redis error
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        allow(Redis).to receive(:new).and_return(redis)
        allow(redis).to receive(:exists?).and_raise(Redis::BaseError.new('Connection failed'))

        result = service.process(**params)

        # Should still process (assumes not duplicate on Redis error)
        expect(result[:success]).to be true
        expect(result[:duplicate]).to be_nil
      end
    end

    context 'with parameter validation' do
      it 'validates origin_event_id presence' do
        result = service.process(
          origin_event_id: nil,
          direction: 'inbound',
          event_type: 'product_update',
          load: {}
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('origin_event_id is required')
      end

      it 'validates direction' do
        result = service.process(
          origin_event_id: 'evt_001',
          direction: 'sideways',
          event_type: 'product_update',
          load: {}
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid direction')
      end

      it 'validates event_type' do
        result = service.process(
          origin_event_id: 'evt_001',
          direction: 'inbound',
          event_type: 'invalid_type',
          load: {}
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('Invalid event_type')
      end

      it 'validates load is a hash' do
        result = service.process(
          origin_event_id: 'evt_001',
          direction: 'inbound',
          event_type: 'product_update',
          load: 'not a hash'
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('load must be a hash')
      end

      it 'accepts valid directions' do
        %w[inbound outbound].each do |direction|
          result = service.process(
            origin_event_id: "evt_#{direction}",
            direction: direction,
            event_type: 'product_create',
            load: {}
          )

          # Will fail on processing, but should pass validation
          expect(result[:error]).not_to include('Invalid direction')
        end
      end

      it 'accepts all valid event types' do
        described_class::EVENT_TYPES.each do |event_type|
          result = service.process(
            origin_event_id: "evt_#{event_type}",
            direction: 'inbound',
            event_type: event_type,
            load: {}
          )

          # Will fail on processing, but should pass validation
          expect(result[:error]).not_to include('Invalid event_type')
        end
      end
    end

    context 'with error handling' do
      let(:params) do
        {
          origin_event_id: 'evt_error_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'Error Test'
          }
        }
      end

      it 'catches StandardError exceptions' do
        allow_any_instance_of(Product).to receive(:update).and_raise(StandardError.new('Database error'))

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Database error')
      end

      it 'logs errors to Rails logger' do
        allow_any_instance_of(Product).to receive(:update).and_raise(StandardError.new('Test error'))

        expect(Rails.logger).to receive(:error).with(/SyncTaskProcessor error/)

        service.process(**params)
      end

      it 'returns error response structure' do
        allow_any_instance_of(Product).to receive(:update).and_raise(StandardError.new('Test error'))

        result = service.process(**params)

        expect(result).to have_key(:success)
        expect(result).to have_key(:event_id)
        expect(result).to have_key(:event_type)
        expect(result).to have_key(:error)
        expect(result[:success]).to be false
      end
    end

    context 'with response structure' do
      let(:params) do
        {
          origin_event_id: 'evt_response_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'Response Test'
          }
        }
      end

      it 'includes all required fields in success response' do
        result = service.process(**params)

        expect(result).to have_key(:success)
        expect(result).to have_key(:event_id)
        expect(result).to have_key(:event_type)
        expect(result).to have_key(:processed_at)
        expect(result).to have_key(:result)

        expect(result[:success]).to be true
        expect(result[:event_id]).to eq('evt_response_001')
        expect(result[:event_type]).to eq('product_update')
        expect(result[:processed_at]).to be_a(Time)
        expect(result[:result]).to be_a(Hash)
      end

      it 'includes all required fields in error response' do
        params[:load][:sku] = 'NONEXISTENT'
        params[:key] = 'NONEXISTENT'

        result = service.process(**params)

        expect(result).to have_key(:success)
        expect(result).to have_key(:event_id)
        expect(result).to have_key(:event_type)
        expect(result).to have_key(:error)

        expect(result[:success]).to be false
        expect(result[:error]).to be_a(String)
      end

      it 'includes all required fields in duplicate response' do
        # First processing
        service.process(**params)

        # Second processing (duplicate)
        result = service.process(**params)

        expect(result).to have_key(:success)
        expect(result).to have_key(:event_id)
        expect(result).to have_key(:event_type)
        expect(result).to have_key(:duplicate)
        expect(result).to have_key(:message)

        expect(result[:success]).to be true
        expect(result[:duplicate]).to be true
        expect(result[:message]).to be_a(String)
      end
    end

    context 'with multi-tenancy' do
      let(:other_product) { create(:product, company: other_company, sku: 'OTHER-PROD') }

      it 'only updates products in the correct company' do
        params = {
          origin_event_id: 'evt_tenant_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: other_product.sku,
          load: {
            sku: other_product.sku,
            name: 'Hacked Name'
          }
        }

        result = service.process(**params)

        expect(result[:success]).to be false
        expect(result[:error]).to include('Product not found')

        other_product.reload
        expect(other_product.name).not_to eq('Hacked Name')
      end

      it 'scopes Redis keys by company ID' do
        params = {
          origin_event_id: 'evt_scoped_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'Scoped Update'
          }
        }

        service.process(**params)

        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1'))
        redis_key = "sync_task:processed:#{company.id}:evt_scoped_001"
        result = redis.exists?(redis_key)
        # Redis 4.x+ returns integer (0 or 1), older versions return boolean
        expect(result.is_a?(Integer) ? result : (result ? 1 : 0)).to be > 0

        # Verify other company's key does not exist
        other_redis_key = "sync_task:processed:#{other_company.id}:evt_scoped_001"
        other_result = redis.exists?(other_redis_key)
        expect(other_result.is_a?(Integer) ? other_result : (other_result ? 1 : 0)).to eq(0)
      end
    end

    context 'with load parameter variations' do
      it 'handles symbol keys in load' do
        params = {
          origin_event_id: 'evt_symbol_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            sku: product.sku,
            name: 'Symbol Keys'
          }
        }

        result = service.process(**params)

        expect(result[:success]).to be true
      end

      it 'handles string keys in load' do
        params = {
          origin_event_id: 'evt_string_001',
          direction: 'inbound',
          event_type: 'product_update',
          key: product.sku,
          load: {
            'sku' => product.sku,
            'name' => 'String Keys'
          }
        }

        result = service.process(**params)

        expect(result[:success]).to be true
      end
    end
  end
end
