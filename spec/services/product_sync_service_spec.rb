require 'rails_helper'

RSpec.describe ProductSyncService, type: :service do
  let(:company) { create(:company) }
  let(:product) { create(:product, :with_attributes, :with_inventory, company: company) }
  let(:catalog) { create(:catalog, company: company, info: { 'sync_target' => 'shopify3' }) }
  let(:service) { ProductSyncService.new(product, catalog) }

  before do
    # Set up environment variables
    ENV['SHOPIFY3_URL'] = 'https://shopify3.example.com'
    ENV['BIZCART_URL'] = 'https://bizcart.example.com'
  end

  after do
    ENV.delete('SHOPIFY3_URL')
    ENV.delete('BIZCART_URL')
  end

  describe '#initialize' do
    it 'stores product and catalog' do
      expect(service.product).to eq(product)
      expect(service.catalog).to eq(catalog)
      expect(service.errors).to eq([])
    end

    it 'accepts product without catalog' do
      service_no_catalog = ProductSyncService.new(product)
      expect(service_no_catalog.product).to eq(product)
      expect(service_no_catalog.catalog).to be_nil
    end
  end

  describe '#build_payload' do
    it 'builds complete payload structure' do
      payload = service.build_payload

      expect(payload).to have_key(:product)
      expect(payload).to have_key(:attributes)
      expect(payload).to have_key(:inventory)
      expect(payload).to have_key(:catalog)
      expect(payload).to have_key(:sync_metadata)
    end

    it 'includes product basic data' do
      payload = service.build_payload

      expect(payload[:product][:id]).to eq(product.id)
      expect(payload[:product][:sku]).to eq(product.sku)
      expect(payload[:product][:name]).to eq(product.name)
      expect(payload[:product][:product_type]).to eq(product.product_type)
    end

    it 'includes inventory data' do
      payload = service.build_payload

      expect(payload[:inventory]).to have_key(:total_saldo)
      expect(payload[:inventory]).to have_key(:total_max_sellable_saldo)
      expect(payload[:inventory]).to have_key(:by_warehouse)
    end

    it 'includes sync metadata' do
      payload = service.build_payload

      expect(payload[:sync_metadata][:source_system]).to eq('potlift8')
      expect(payload[:sync_metadata][:api_version]).to eq('v1')
      expect(payload[:sync_metadata][:synced_at]).to be_present
    end
  end

  describe '#build_product_data' do
    it 'includes all basic product fields' do
      data = service.send(:build_product_data)

      expect(data).to include(
        id: product.id,
        sku: product.sku,
        ean: product.ean,
        name: product.name,
        product_type: product.product_type,
        product_status: product.product_status
      )
    end

    it 'includes inventory calculations' do
      data = service.send(:build_product_data)

      expect(data).to have_key(:total_saldo)
      expect(data).to have_key(:total_max_sellable_saldo)
    end
  end

  describe '#build_attributes_payload' do
    context 'without catalog' do
      let(:service_no_catalog) { ProductSyncService.new(product) }

      it 'returns product attribute values' do
        attributes = service_no_catalog.send(:build_attributes_payload)
        expect(attributes).to eq(product.attribute_values_hash)
      end
    end

    context 'with catalog but no catalog item' do
      it 'returns product attribute values' do
        attributes = service.send(:build_attributes_payload)
        expect(attributes).to eq(product.attribute_values_hash)
      end
    end

    context 'with catalog and catalog item' do
      let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
      let(:price_attr) { create(:product_attribute, company: company, code: 'price', product_attribute_scope: :product_and_catalog_scope) }

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '2499')
      end

      it 'returns effective attribute values with catalog overrides' do
        attributes = service.send(:build_attributes_payload)
        expect(attributes['price']).to eq('2499') # Catalog override
      end
    end
  end

  describe '#build_inventory_payload' do
    let(:storage1) { create(:storage, company: company, code: 'MAIN') }
    let(:storage2) { create(:storage, company: company, code: 'BACKUP') }
    let(:test_product) { create(:product, company: company) }
    let(:test_service) { ProductSyncService.new(test_product, catalog) }

    before do
      create(:inventory, product: test_product, storage: storage1, value: 50)
      create(:inventory, product: test_product, storage: storage2, value: 30)
    end

    it 'includes total saldo' do
      inventory = test_service.send(:build_inventory_payload)
      expect(inventory[:total_saldo]).to eq(80)
    end

    it 'includes warehouse breakdown' do
      inventory = test_service.send(:build_inventory_payload)
      warehouses = inventory[:by_warehouse]

      expect(warehouses).to be_an(Array)
      expect(warehouses.length).to eq(2)
      expect(warehouses.map { |w| w[:storage_code] }).to contain_exactly('MAIN', 'BACKUP')
    end

    it 'includes warehouse details' do
      inventory = test_service.send(:build_inventory_payload)
      main_warehouse = inventory[:by_warehouse].find { |w| w[:storage_code] == 'MAIN' }

      expect(main_warehouse).to include(
        storage_code: 'MAIN',
        value: 50
      )
      expect(main_warehouse).to have_key(:storage_type)
      expect(main_warehouse).to have_key(:eta)
    end
  end

  describe '#build_catalog_data' do
    context 'without catalog' do
      let(:service_no_catalog) { ProductSyncService.new(product) }

      it 'returns nil' do
        data = service_no_catalog.send(:build_catalog_data)
        expect(data).to be_nil
      end
    end

    context 'with catalog' do
      it 'includes catalog information' do
        data = service.send(:build_catalog_data)

        expect(data).to include(
          id: catalog.id,
          code: catalog.code,
          name: catalog.name,
          catalog_type: catalog.catalog_type,
          currency_code: catalog.currency_code
        )
      end

      context 'with catalog item' do
        let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

        it 'includes catalog item data' do
          data = service.send(:build_catalog_data)

          expect(data[:catalog_item]).to be_present
          expect(data[:catalog_item]).to include(
            id: catalog_item.id,
            catalog_item_state: catalog_item.catalog_item_state
          )
        end
      end
    end
  end

  describe '#determine_target_url' do
    context 'when sync_target is shopify3' do
      before do
        catalog.info['sync_target'] = 'shopify3'
      end

      it 'returns Shopify3 URL' do
        url = service.send(:determine_target_url)
        expect(url).to eq('https://shopify3.example.com/sync_tasks')
      end
    end

    context 'when sync_target is bizcart' do
      before do
        catalog.info['sync_target'] = 'bizcart'
      end

      it 'returns Bizcart URL' do
        url = service.send(:determine_target_url)
        expect(url).to eq('https://bizcart.example.com/api/api/update_catalog')
      end
    end

    context 'when sync_target is not specified' do
      before do
        catalog.info.delete('sync_target')
      end

      it 'defaults to Shopify3' do
        url = service.send(:determine_target_url)
        expect(url).to eq('https://shopify3.example.com/sync_tasks')
      end
    end

    context 'without catalog' do
      let(:service_no_catalog) { ProductSyncService.new(product) }

      it 'returns nil' do
        url = service_no_catalog.send(:determine_target_url)
        expect(url).to be_nil
      end
    end

    context 'when environment variable is not set' do
      before do
        ENV.delete('SHOPIFY3_URL')
      end

      it 'returns nil' do
        url = service.send(:determine_target_url)
        expect(url).to be_nil
      end
    end
  end

  describe '#sync_to_external_system' do
    let(:mock_response) { instance_double(Faraday::Response, success?: true, status: 200, body: { 'status' => 'ok' }) }

    before do
      allow(service).to receive(:send_to_target).and_return(mock_response)
    end

    context 'with valid prerequisites' do
      it 'builds payload and sends to target' do
        expect(service).to receive(:build_payload).and_call_original
        expect(service).to receive(:send_to_target).and_return(mock_response)

        result = service.sync_to_external_system

        expect(result.success?).to be true
      end

      it 'returns success result' do
        result = service.sync_to_external_system

        expect(result).to be_a(SyncLockable::SyncLockResult)
        expect(result.success?).to be true
        expect(result.data).to eq({ 'status' => 'ok' })
      end

      it 'logs sync operation' do
        expect(Rails.logger).to receive(:info).with(/Syncing product/)

        service.sync_to_external_system
      end
    end

    context 'with validation errors' do
      let(:invalid_product) { build(:product, company: nil) }
      let(:invalid_service) { ProductSyncService.new(invalid_product, catalog) }

      it 'returns failure result without syncing' do
        result = invalid_service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('Validation failed')
      end

      it 'does not send to target' do
        expect(invalid_service).not_to receive(:send_to_target)

        invalid_service.sync_to_external_system
      end
    end

    context 'when target URL is not configured' do
      before do
        ENV.delete('SHOPIFY3_URL')
      end

      it 'returns failure result' do
        result = service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('No sync target configured')
      end
    end

    context 'when API returns error' do
      let(:error_response) { instance_double(Faraday::Response, success?: false, status: 422, body: 'Invalid data') }

      before do
        allow(service).to receive(:send_to_target).and_return(error_response)
      end

      it 'returns failure result with error details' do
        result = service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('API error')
        expect(result.error).to include('422')
      end
    end

    context 'when network timeout occurs' do
      before do
        allow(service).to receive(:send_to_target).and_raise(Faraday::TimeoutError, 'Timeout')
      end

      it 'returns failure result with timeout message' do
        result = service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('timeout')
      end
    end

    context 'when connection fails' do
      before do
        allow(service).to receive(:send_to_target).and_raise(Faraday::ConnectionFailed, 'Connection refused')
      end

      it 'returns failure result with connection error' do
        result = service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('Connection failed')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow(service).to receive(:build_payload).and_raise(StandardError, 'Unexpected error')
      end

      it 'returns failure result with error message' do
        result = service.sync_to_external_system

        expect(result.success?).to be false
        expect(result.error).to include('Unexpected error')
      end
    end
  end

  describe '#send_to_target' do
    let(:url) { 'https://api.example.com/sync' }
    let(:payload) { { product: { sku: 'TEST123' } } }
    let(:stub_connection) { instance_double(Faraday::Connection) }
    let(:stub_response) { instance_double(Faraday::Response, status: 200, body: { 'ok' => true }) }
    let(:request_stub) { double('request', headers: {}) }

    before do
      allow(Faraday).to receive(:new).and_return(stub_connection)
      allow(request_stub).to receive(:body=)
      allow(stub_connection).to receive(:post).and_yield(request_stub).and_return(stub_response)
    end

    it 'creates Faraday connection with correct URL' do
      expect(Faraday).to receive(:new).with(hash_including(url: url))

      service.send(:send_to_target, url, payload)
    end

    it 'sends POST request with JSON payload' do
      expect(stub_connection).to receive(:post)

      service.send(:send_to_target, url, payload)
    end

    it 'sets correct headers' do
      headers = {}
      allow(request_stub).to receive(:headers).and_return(headers)

      service.send(:send_to_target, url, payload)

      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['Accept']).to eq('application/json')
    end

    it 'logs request and response' do
      expect(Rails.logger).to receive(:info).with(/Sending payload/)
      expect(Rails.logger).to receive(:info).with(/Response:/)

      service.send(:send_to_target, url, payload)
    end

    it 'returns response' do
      response = service.send(:send_to_target, url, payload)

      expect(response).to eq(stub_response)
    end
  end

  # Integration tests
  describe 'integration scenarios' do
    let(:mock_response) { instance_double(Faraday::Response, success?: true, status: 200, body: { 'synced' => true }) }

    before do
      allow_any_instance_of(ProductSyncService).to receive(:send_to_target).and_return(mock_response)
    end

    context 'syncing product with all data' do
      let(:test_product) { create(:product, company: company) }
      let(:test_service) { ProductSyncService.new(test_product, catalog) }
      let(:storage) { create(:storage, company: company, code: 'MAIN', default: true) }
      let(:price_attr) { create(:product_attribute, company: company, code: 'price') }
      let!(:inventory) { create(:inventory, product: test_product, storage: storage, value: 100) }
      let!(:price_value) { create(:product_attribute_value, product: test_product, product_attribute: price_attr, value: '1999') }

      before do
        allow(test_service).to receive(:send_to_target).and_return(mock_response)
      end

      it 'syncs successfully' do
        result = test_service.sync_to_external_system

        expect(result.success?).to be true
      end

      it 'includes complete payload' do
        payload = test_service.build_payload

        expect(payload[:product][:sku]).to eq(test_product.sku)
        expect(payload[:inventory][:total_saldo]).to eq(100)
        expect(payload[:attributes]['price']).to eq('1999')
        expect(payload[:catalog][:code]).to eq(catalog.code)
      end
    end

    context 'syncing with catalog attribute overrides' do
      let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
      let(:price_attr) { create(:product_attribute, company: company, code: 'price', product_attribute_scope: :product_and_catalog_scope) }

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '2999')
      end

      it 'uses catalog override for price' do
        payload = service.build_payload

        expect(payload[:attributes]['price']).to eq('2999')
      end

      it 'syncs with override successfully' do
        result = service.sync_to_external_system

        expect(result.success?).to be true
      end
    end

    context 'syncing to different targets' do
      it 'syncs to Shopify3' do
        catalog.info['sync_target'] = 'shopify3'

        expect_any_instance_of(ProductSyncService).to receive(:send_to_target)
          .with('https://shopify3.example.com/sync_tasks', anything)
          .and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end

      it 'syncs to Bizcart' do
        catalog.info['sync_target'] = 'bizcart'
        service = ProductSyncService.new(product, catalog)

        expect(service).to receive(:send_to_target)
          .with('https://bizcart.example.com/api/api/update_catalog', anything)
          .and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end
    end

    context 'handling different product types' do
      it 'syncs sellable product' do
        sellable = create(:product, :sellable, company: company)
        service = ProductSyncService.new(sellable, catalog)

        allow(service).to receive(:send_to_target).and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end

      it 'syncs configurable product' do
        configurable = create(:product, :configurable_variant, company: company)
        service = ProductSyncService.new(configurable, catalog)

        allow(service).to receive(:send_to_target).and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end

      it 'syncs bundle product' do
        bundle = create(:product, :bundle, company: company)
        service = ProductSyncService.new(bundle, catalog)

        allow(service).to receive(:send_to_target).and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end
    end
  end
end
