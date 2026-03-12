require 'rails_helper'

RSpec.describe ProductSyncService, type: :service do
  let(:company) { create(:company) }
  let(:product) { create(:product, :with_attributes, :with_inventory, company: company) }
  let(:catalog) { create(:catalog, company: company, info: { 'sync_target' => 'shopify8' }) }
  let(:service) { ProductSyncService.new(product, catalog) }

  before do
    # Set up environment variables
    ENV['SHOPIFY8_URL'] = 'https://shopify8.example.com'
    ENV['BIZCART_URL'] = 'https://bizcart.example.com'
  end

  after do
    ENV.delete('SHOPIFY8_URL')
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

      it 'returns enriched attribute values with mapping info' do
        result = service_no_catalog.send(:build_attributes_payload)
        expect(result).to have_key(:values)
        expect(result).to have_key(:localized)
        # Each value should be an enriched hash with :value key
        result[:values].each do |_code, entry|
          expect(entry).to have_key(:value)
        end
      end
    end

    context 'with catalog but no catalog item' do
      it 'returns enriched attribute values' do
        result = service.send(:build_attributes_payload)
        expect(result).to have_key(:values)
        result[:values].each do |_code, entry|
          expect(entry).to have_key(:value)
        end
      end
    end

    context 'with catalog and catalog item' do
      let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '2499')
      end

      it 'returns effective attribute values with catalog overrides' do
        result = service.send(:build_attributes_payload)
        expect(result[:values]['price'][:value]).to eq('2499') # Catalog override
        expect(result[:values]['price'][:shopify_field]).to eq('price')
        expect(result[:values]['price'][:system]).to be true
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
    context 'when sync_target is shopify8' do
      before do
        catalog.info['sync_target'] = 'shopify8'
      end

      it 'returns Shopify8 URL' do
        url = service.send(:determine_target_url)
        expect(url).to eq('https://shopify8.example.com/api/v1/sync_tasks')
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

      it 'defaults to Shopify8' do
        url = service.send(:determine_target_url)
        expect(url).to eq('https://shopify8.example.com/api/v1/sync_tasks')
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
        ENV.delete('SHOPIFY8_URL')
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
        ENV.delete('SHOPIFY8_URL')
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

  describe '#build_labels_payload' do
    let(:test_product) { create(:product, company: company) }
    let(:test_service) { ProductSyncService.new(test_product, catalog) }

    context 'when product has no labels' do
      it 'returns empty array' do
        labels = test_service.send(:build_labels_payload)
        expect(labels).to eq([])
      end
    end

    context 'when product has labels' do
      let!(:category_label) { create(:label, company: company, label_type: 'category', code: 'electronics', name: 'Electronics') }
      let!(:brand_label) { create(:label, company: company, label_type: 'brand', code: 'acme', name: 'ACME Corp') }

      before do
        create(:product_label, product: test_product, label: category_label)
        create(:product_label, product: test_product, label: brand_label)
      end

      it 'returns array of label data' do
        labels = test_service.send(:build_labels_payload)

        expect(labels).to be_an(Array)
        expect(labels.length).to eq(2)
      end

      it 'includes label type, code, and name' do
        labels = test_service.send(:build_labels_payload)
        category = labels.find { |l| l[:code] == 'electronics' }

        expect(category).to include(
          label_type: 'category',
          code: 'electronics',
          name: 'Electronics'
        )
      end

      it 'includes full_code and full_name' do
        labels = test_service.send(:build_labels_payload)
        category = labels.find { |l| l[:code] == 'electronics' }

        expect(category).to have_key(:full_code)
        expect(category).to have_key(:full_name)
      end
    end

    context 'when label has hierarchy' do
      let!(:parent_label) { create(:label, company: company, label_type: 'category', code: 'electronics', name: 'Electronics') }
      let!(:child_label) { create(:label, company: company, label_type: 'category', code: 'phones', name: 'Phones', parent_label: parent_label) }

      before do
        create(:product_label, product: test_product, label: child_label)
      end

      it 'includes full_code with hierarchy' do
        labels = test_service.send(:build_labels_payload)
        phone_label = labels.first

        expect(phone_label[:full_code]).to eq('electronics-phones')
        expect(phone_label[:full_name]).to eq('Electronics > Phones')
      end
    end

    context 'when label has localized values' do
      let!(:label_with_localization) do
        create(:label, :with_localized_info, company: company, label_type: 'category', code: 'summer', name: 'Summer Collection')
      end

      before do
        create(:product_label, product: test_product, label: label_with_localization)
      end

      it 'includes localized_value from info' do
        labels = test_service.send(:build_labels_payload)
        label_data = labels.first

        expect(label_data[:localized_value]).to be_present
        expect(label_data[:localized_value]).to be_a(Hash)
      end
    end
  end

  describe '#build_assets_payload' do
    let(:test_product) { create(:product, company: company) }
    let(:test_service) { ProductSyncService.new(test_product, catalog) }

    context 'when product has no assets' do
      it 'returns empty array' do
        assets = test_service.send(:build_assets_payload)
        expect(assets).to eq([])
      end
    end

    context 'when product has image assets with files' do
      let!(:primary_asset) do
        asset = create(:product_asset, :image, :public_visibility, product: test_product, name: 'primary.jpg', asset_priority: 100)
        # Attach a file for testing
        asset.file.attach(
          io: StringIO.new('fake image content'),
          filename: 'primary.jpg',
          content_type: 'image/jpeg'
        )
        asset
      end

      let!(:secondary_asset) do
        asset = create(:product_asset, :image, :public_visibility, product: test_product, name: 'secondary.jpg', asset_priority: 50)
        asset.file.attach(
          io: StringIO.new('fake image content'),
          filename: 'secondary.jpg',
          content_type: 'image/jpeg'
        )
        asset
      end

      it 'returns array of asset data' do
        assets = test_service.send(:build_assets_payload)

        expect(assets).to be_an(Array)
        expect(assets.length).to eq(2)
      end

      it 'includes asset id, name, and priority' do
        assets = test_service.send(:build_assets_payload)
        primary = assets.first

        expect(primary).to include(
          id: primary_asset.id,
          name: 'primary.jpg',
          priority: 100
        )
      end

      it 'includes visibility and content_type' do
        assets = test_service.send(:build_assets_payload)
        primary = assets.first

        expect(primary[:visibility]).to eq('public_visibility')
        expect(primary[:content_type]).to eq('image/jpeg')
      end

      it 'includes URL' do
        assets = test_service.send(:build_assets_payload)
        primary = assets.first

        expect(primary[:url]).to be_present
      end

      it 'orders by priority descending' do
        assets = test_service.send(:build_assets_payload)

        expect(assets.first[:priority]).to be >= assets.last[:priority]
      end
    end

    context 'when product has private assets' do
      let!(:private_asset) do
        asset = create(:product_asset, :image, :private_visibility, product: test_product, name: 'private.jpg')
        asset.file.attach(
          io: StringIO.new('fake image content'),
          filename: 'private.jpg',
          content_type: 'image/jpeg'
        )
        asset
      end

      it 'excludes private assets' do
        assets = test_service.send(:build_assets_payload)
        expect(assets).to be_empty
      end
    end

    context 'when product has catalog-only assets' do
      let!(:catalog_asset) do
        asset = create(:product_asset, :image, :catalog_only_visibility, product: test_product, name: 'catalog.jpg')
        asset.file.attach(
          io: StringIO.new('fake image content'),
          filename: 'catalog.jpg',
          content_type: 'image/jpeg'
        )
        asset
      end

      it 'includes catalog-only assets' do
        assets = test_service.send(:build_assets_payload)
        expect(assets.length).to eq(1)
        expect(assets.first[:visibility]).to eq('catalog_only_visibility')
      end
    end

    context 'when product has non-image assets' do
      let!(:video_asset) do
        asset = create(:product_asset, :video, :public_visibility, product: test_product)
        asset.file.attach(
          io: StringIO.new('fake video content'),
          filename: 'video.mp4',
          content_type: 'video/mp4'
        )
        asset
      end

      let!(:document_asset) do
        asset = create(:product_asset, :document, :public_visibility, product: test_product)
        asset.file.attach(
          io: StringIO.new('fake pdf content'),
          filename: 'manual.pdf',
          content_type: 'application/pdf'
        )
        asset
      end

      it 'excludes non-image assets' do
        assets = test_service.send(:build_assets_payload)
        expect(assets).to be_empty
      end
    end

    context 'when asset has no file attached' do
      let!(:asset_no_file) { create(:product_asset, :image, :public_visibility, product: test_product, name: 'nofile.jpg') }

      it 'excludes assets without files' do
        assets = test_service.send(:build_assets_payload)
        expect(assets).to be_empty
      end
    end
  end

  describe '#build_translations_payload' do
    let(:test_product) { create(:product, company: company) }
    let(:test_service) { ProductSyncService.new(test_product, catalog) }

    context 'when product has no translations' do
      it 'returns nil' do
        translations = test_service.send(:build_translations_payload)
        expect(translations).to be_nil
      end
    end

    context 'when product has translations' do
      before do
        create(:translation, translatable: test_product, locale: 'en', key: 'name', value: 'English Name')
        create(:translation, translatable: test_product, locale: 'en', key: 'description', value: 'English Description')
        create(:translation, translatable: test_product, locale: 'de', key: 'name', value: 'German Name')
      end

      it 'returns hash organized by locale' do
        translations = test_service.send(:build_translations_payload)

        expect(translations).to be_a(Hash)
        expect(translations.keys).to contain_exactly('en', 'de')
      end

      it 'groups keys under locale' do
        translations = test_service.send(:build_translations_payload)

        expect(translations['en']).to include(
          'name' => 'English Name',
          'description' => 'English Description'
        )
      end

      it 'includes each locale separately' do
        translations = test_service.send(:build_translations_payload)

        expect(translations['de']).to eq({ 'name' => 'German Name' })
      end
    end

    context 'with multiple locales and keys' do
      before do
        %w[en es fr de].each do |locale|
          create(:translation, translatable: test_product, locale: locale, key: 'name', value: "Name in #{locale}")
          create(:translation, translatable: test_product, locale: locale, key: 'short_description', value: "Short desc in #{locale}")
        end
      end

      it 'includes all locales' do
        translations = test_service.send(:build_translations_payload)
        expect(translations.keys).to contain_exactly('en', 'es', 'fr', 'de')
      end

      it 'includes all keys for each locale' do
        translations = test_service.send(:build_translations_payload)

        %w[en es fr de].each do |locale|
          expect(translations[locale].keys).to contain_exactly('name', 'short_description')
        end
      end
    end
  end

  describe '#build_configurations_payload' do
    let(:test_service) { ProductSyncService.new(product, catalog) }

    context 'when product is not configurable' do
      let(:product) { create(:product, :sellable, company: company) }

      it 'returns nil' do
        configurations = test_service.send(:build_configurations_payload)
        expect(configurations).to be_nil
      end
    end

    context 'when product is bundle' do
      let(:product) { create(:product, :bundle, company: company) }

      it 'returns nil' do
        configurations = test_service.send(:build_configurations_payload)
        expect(configurations).to be_nil
      end
    end

    context 'when product is configurable' do
      let(:product) { create(:product, :configurable_variant, company: company) }

      context 'without configurations' do
        it 'returns empty array' do
          configurations = test_service.send(:build_configurations_payload)
          expect(configurations).to eq([])
        end
      end

      context 'with configurations' do
        let!(:size_config) do
          config = create(:configuration, product: product, company: company, code: 'size', name: 'Size', position: 1)
          create(:configuration_value, configuration: config, value: 'Small', position: 1)
          create(:configuration_value, configuration: config, value: 'Medium', position: 2)
          create(:configuration_value, configuration: config, value: 'Large', position: 3)
          config
        end

        let!(:color_config) do
          config = create(:configuration, product: product, company: company, code: 'color', name: 'Color', position: 2)
          create(:configuration_value, configuration: config, value: 'Red', position: 1)
          create(:configuration_value, configuration: config, value: 'Blue', position: 2)
          config
        end

        it 'returns array of configuration data' do
          configurations = test_service.send(:build_configurations_payload)

          expect(configurations).to be_an(Array)
          expect(configurations.length).to eq(2)
        end

        it 'includes configuration id, code, and name' do
          configurations = test_service.send(:build_configurations_payload)
          size = configurations.first

          expect(size).to include(
            id: size_config.id,
            code: 'size',
            name: 'Size',
            position: 1
          )
        end

        it 'includes configuration values' do
          configurations = test_service.send(:build_configurations_payload)
          size = configurations.first

          expect(size[:values]).to be_an(Array)
          expect(size[:values].length).to eq(3)
        end

        it 'includes value id, value, and position' do
          configurations = test_service.send(:build_configurations_payload)
          size_values = configurations.first[:values]
          small = size_values.find { |v| v[:value] == 'Small' }

          expect(small).to include(
            value: 'Small',
            position: 1
          )
          expect(small[:id]).to be_present
        end

        it 'orders configurations by position' do
          configurations = test_service.send(:build_configurations_payload)

          expect(configurations.first[:code]).to eq('size')
          expect(configurations.last[:code]).to eq('color')
        end

        it 'orders values by position within each configuration' do
          configurations = test_service.send(:build_configurations_payload)
          size_values = configurations.first[:values].map { |v| v[:value] }

          expect(size_values).to eq(%w[Small Medium Large])
        end
      end
    end
  end

  describe '#build_subproducts_payload' do
    context 'when product is sellable' do
      let(:product) { create(:product, :sellable, company: company) }
      let(:test_service) { ProductSyncService.new(product, catalog) }

      it 'returns nil' do
        subproducts = test_service.send(:build_subproducts_payload)
        expect(subproducts).to be_nil
      end
    end

    context 'when product is configurable' do
      let(:product) { create(:product, :configurable_variant, company: company) }
      let(:test_service) { ProductSyncService.new(product, catalog) }

      context 'without subproducts' do
        it 'returns empty array' do
          subproducts = test_service.send(:build_subproducts_payload)
          expect(subproducts).to eq([])
        end
      end

      context 'with variant subproducts' do
        let(:variant1) { create(:product, :sellable, company: company, sku: 'VAR-S-RED', name: 'Variant Small Red') }
        let(:variant2) { create(:product, :sellable, company: company, sku: 'VAR-M-BLUE', name: 'Variant Medium Blue') }

        let!(:config1) do
          create(:product_configuration,
                 superproduct: product,
                 subproduct: variant1,
                 configuration_position: 1,
                 info: { 'variant_config' => { 'size' => 'Small', 'color' => 'Red' } })
        end

        let!(:config2) do
          create(:product_configuration,
                 superproduct: product,
                 subproduct: variant2,
                 configuration_position: 2,
                 info: { 'variant_config' => { 'size' => 'Medium', 'color' => 'Blue' } })
        end

        it 'returns array of subproduct data' do
          subproducts = test_service.send(:build_subproducts_payload)

          expect(subproducts).to be_an(Array)
          expect(subproducts.length).to eq(2)
        end

        it 'includes quantity and configuration position' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:quantity]).to eq(1)
          expect(first_variant[:configuration_position]).to eq(1)
        end

        it 'includes variant_config from info' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:variant_config]).to eq({ 'size' => 'Small', 'color' => 'Red' })
        end

        it 'includes product data' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:product]).to include(
            id: variant1.id,
            sku: 'VAR-S-RED',
            name: 'Variant Small Red',
            product_type: 'sellable'
          )
        end

        it 'includes inventory data' do
          storage = create(:storage, company: company)
          create(:inventory, product: variant1, storage: storage, value: 50)

          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:inventory]).to have_key(:total_saldo)
          expect(first_variant[:inventory]).to have_key(:total_max_sellable_saldo)
        end

        it 'includes attributes' do
          price_attr = company.product_attributes.find_by(code: 'price')
          create(:product_attribute_value, product: variant1, product_attribute: price_attr, value: '1999')

          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:attributes]).to be_a(Hash)
          expect(first_variant[:attributes]['price'][:value]).to eq('1999')
          expect(first_variant[:attributes]['price'][:shopify_field]).to eq('price')
        end
      end

      context 'with subproduct translations' do
        let(:variant) { create(:product, :sellable, company: company, sku: 'VAR-001') }

        let!(:config) do
          create(:product_configuration, superproduct: product, subproduct: variant)
        end

        before do
          create(:translation, translatable: variant, locale: 'en', key: 'name', value: 'English Variant')
          create(:translation, translatable: variant, locale: 'de', key: 'name', value: 'German Variant')
        end

        it 'includes translations for subproduct' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_variant = subproducts.first

          expect(first_variant[:translations]).to be_a(Hash)
          expect(first_variant[:translations]['en']).to include('name' => 'English Variant')
          expect(first_variant[:translations]['de']).to include('name' => 'German Variant')
        end
      end
    end

    context 'when product is bundle' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:test_service) { ProductSyncService.new(product, catalog) }

      context 'with bundle components' do
        let(:component1) { create(:product, :sellable, company: company, sku: 'COMP-001', name: 'Component 1') }
        let(:component2) { create(:product, :sellable, company: company, sku: 'COMP-002', name: 'Component 2') }

        let!(:bundle_config1) do
          create(:product_configuration,
                 superproduct: product,
                 subproduct: component1,
                 configuration_position: 1,
                 info: { 'quantity' => 2, 'configuration_details' => { 'required' => true } })
        end

        let!(:bundle_config2) do
          create(:product_configuration,
                 superproduct: product,
                 subproduct: component2,
                 configuration_position: 2,
                 info: { 'quantity' => 3 })
        end

        it 'returns array of component data' do
          subproducts = test_service.send(:build_subproducts_payload)

          expect(subproducts).to be_an(Array)
          expect(subproducts.length).to eq(2)
        end

        it 'includes quantity from info' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_component = subproducts.first

          expect(first_component[:quantity]).to eq(2)
        end

        it 'includes configuration_details from info' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_component = subproducts.first

          expect(first_component[:configuration_details]).to eq({ 'required' => true })
        end

        it 'includes component product data' do
          subproducts = test_service.send(:build_subproducts_payload)
          first_component = subproducts.first

          expect(first_component[:product]).to include(
            sku: 'COMP-001',
            name: 'Component 1',
            product_type: 'sellable'
          )
        end
      end
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
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }
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
        expect(payload[:attributes][:values]['price'][:value]).to eq('1999')
        expect(payload[:catalog][:code]).to eq(catalog.code)
      end
    end

    context 'syncing with catalog attribute overrides' do
      let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '2999')
      end

      it 'uses catalog override for price' do
        payload = service.build_payload

        expect(payload[:attributes][:values]['price'][:value]).to eq('2999')
      end

      it 'syncs with override successfully' do
        result = service.sync_to_external_system

        expect(result.success?).to be true
      end
    end

    context 'syncing to different targets' do
      it 'syncs to Shopify8' do
        catalog.info['sync_target'] = 'shopify8'

        expect_any_instance_of(ProductSyncService).to receive(:send_to_target)
          .with('https://shopify8.example.com/api/v1/sync_tasks', anything, anything)
          .and_return(mock_response)

        result = service.sync_to_external_system
        expect(result.success?).to be true
      end

      it 'syncs to Bizcart' do
        catalog.info['sync_target'] = 'bizcart'
        service = ProductSyncService.new(product, catalog)

        expect(service).to receive(:send_to_target)
          .with('https://bizcart.example.com/api/api/update_catalog', anything, anything)
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
