# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe ProductSyncService, 'integration: full sync flow with system + custom metafield attributes', type: :service do
  let(:company) { create(:company) }
  let(:product) { create(:product, :sellable, company: company, sku: 'INT-TEST-001', ean: '5012345678901') }
  let(:catalog) do
    create(:catalog, company: company, info: {
      'sync_target' => 'shopify8',
      'shop_id' => 42
    })
  end
  let(:service) { ProductSyncService.new(product, catalog) }

  # System attributes are auto-created by Company after_create callback
  let(:price_attr) { company.product_attributes.find_by(code: 'price') }
  let(:weight_attr) { company.product_attributes.find_by(code: 'weight') }
  let(:description_html_attr) { company.product_attributes.find_by(code: 'description_html') }
  let(:detailed_description_attr) { company.product_attributes.find_by(code: 'detailed_description') }
  let(:sizechart_attr) { company.product_attributes.find_by(code: 'sizechart') }
  let(:ean_attr) { company.product_attributes.find_by(code: 'ean') }
  let(:brand_attr) { company.product_attributes.find_by(code: 'brand') }
  let(:special_price_attr) { company.product_attributes.find_by(code: 'special_price') }
  let(:vat_group_attr) { company.product_attributes.find_by(code: 'vat_group') }
  let(:purchase_price_attr) { company.product_attributes.find_by(code: 'purchase_price') }

  before do
    ENV['SHOPIFY8_URL'] = 'https://shopify8.test.example.com'
  end

  after do
    ENV.delete('SHOPIFY8_URL')
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 1. Full sync with system attributes
  # ─────────────────────────────────────────────────────────────────────────
  describe 'full sync with system attributes' do
    before do
      # shopify_field attributes
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '2999')
      create(:product_attribute_value, product: product, product_attribute: weight_attr, value: '500')
      create(:product_attribute_value, product: product, product_attribute: description_html_attr, value: '<p>Main description</p>')

      # shopify_metafield attributes
      create(:product_attribute_value, product: product, product_attribute: detailed_description_attr, value: '<p>Extended product details</p>')
      create(:product_attribute_value, product: product, product_attribute: sizechart_attr, value: '<table><tr><td>S</td><td>36</td></tr></table>')
    end

    it 'generates enriched payload entries for shopify_field system attributes' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      # price has shopify_field: :price
      expect(values['price']).to include(
        value: '2999',
        shopify_field: 'price',
        system: true
      )
      expect(values['price']).not_to have_key(:shopify_metafield)

      # weight has shopify_field: :weight
      expect(values['weight']).to include(
        value: '500',
        shopify_field: 'weight',
        system: true
      )

      # description_html has shopify_field: :descriptionHtml
      expect(values['description_html']).to include(
        value: '<p>Main description</p>',
        shopify_field: 'descriptionHtml',
        system: true
      )
    end

    it 'generates enriched payload entries for shopify_metafield system attributes' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      # detailed_description has shopify_metafield config
      expect(values['detailed_description']).to include(
        value: '<p>Extended product details</p>',
        system: true
      )
      expect(values['detailed_description'][:shopify_metafield]).to eq({
        namespace: 'global',
        key: 'detailed_description_html',
        type: 'multi_line_text_field'
      })
      expect(values['detailed_description']).not_to have_key(:shopify_field)

      # sizechart has shopify_metafield config
      expect(values['sizechart']).to include(
        value: '<table><tr><td>S</td><td>36</td></tr></table>',
        system: true
      )
      expect(values['sizechart'][:shopify_metafield]).to eq({
        namespace: 'global',
        key: 'sizechart',
        type: 'multi_line_text_field'
      })
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 2. Full sync with custom metafield opt-in
  # ─────────────────────────────────────────────────────────────────────────
  describe 'full sync with custom metafield opt-in' do
    let!(:thc_attr) do
      create(:product_attribute,
             company: company,
             code: 'thc_percentage',
             name: 'THC Percentage',
             pa_type: :patype_number,
             view_format: :view_format_general,
             system: false,
             shopify_metafield_namespace: 'custom',
             shopify_metafield_key: 'thc_percentage',
             shopify_metafield_type: 'number_decimal')
    end

    before do
      create(:product_attribute_value, product: product, product_attribute: thc_attr, value: '18.5')
    end

    it 'generates metafield mapping in the payload for custom attribute with opt-in' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['thc_percentage']).to include(value: '18.5')
      expect(values['thc_percentage'][:shopify_metafield]).to eq({
        namespace: 'custom',
        key: 'thc_percentage',
        type: 'number_decimal'
      })
      expect(values['thc_percentage']).not_to have_key(:system)
      expect(values['thc_percentage']).not_to have_key(:shopify_field)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 3. Full sync with mixed attributes
  # ─────────────────────────────────────────────────────────────────────────
  describe 'full sync with mixed attribute types' do
    let!(:thc_attr) do
      create(:product_attribute,
             company: company,
             code: 'thc_percentage',
             name: 'THC Percentage',
             pa_type: :patype_number,
             view_format: :view_format_general,
             system: false,
             shopify_metafield_namespace: 'custom',
             shopify_metafield_key: 'thc_pct',
             shopify_metafield_type: 'number_decimal')
    end

    let!(:internal_notes_attr) do
      create(:product_attribute,
             company: company,
             code: 'internal_notes',
             name: 'Internal Notes',
             pa_type: :patype_text,
             view_format: :view_format_general,
             system: false)
    end

    before do
      # System attr with shopify_field
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '4999')
      create(:product_attribute_value, product: product, product_attribute: ean_attr, value: '9876543210123')

      # System attr with shopify_metafield
      create(:product_attribute_value, product: product, product_attribute: detailed_description_attr, value: '<p>Detailed</p>')

      # System attr with custom_handler
      create(:product_attribute_value, product: product, product_attribute: special_price_attr, value: '3999')
      create(:product_attribute_value, product: product, product_attribute: vat_group_attr, value: 'standard')

      # Custom attr with metafield opt-in
      create(:product_attribute_value, product: product, product_attribute: thc_attr, value: '21.0')

      # Custom attr without any mapping
      create(:product_attribute_value, product: product, product_attribute: internal_notes_attr, value: 'For internal use only')
    end

    it 'includes system attributes with shopify_field correctly' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['price']).to include(value: '4999', shopify_field: 'price', system: true)
      expect(values['ean']).to include(value: '9876543210123', shopify_field: 'barcode', system: true)
    end

    it 'includes system attributes with shopify_metafield correctly' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['detailed_description'][:system]).to be true
      expect(values['detailed_description'][:shopify_metafield]).to eq({
        namespace: 'global',
        key: 'detailed_description_html',
        type: 'multi_line_text_field'
      })
    end

    it 'includes system attributes with custom_handler correctly' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['special_price']).to include(custom_handler: 'special_price', system: true)
      expect(values['special_price']).not_to have_key(:shopify_field)

      expect(values['vat_group']).to include(custom_handler: 'vat_tag', system: true)
      expect(values['vat_group']).not_to have_key(:shopify_field)
    end

    it 'includes custom attributes with metafield opt-in correctly' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['thc_percentage']).to include(value: '21.0')
      expect(values['thc_percentage'][:shopify_metafield]).to eq({
        namespace: 'custom',
        key: 'thc_pct',
        type: 'number_decimal'
      })
      expect(values['thc_percentage']).not_to have_key(:system)
      expect(values['thc_percentage']).not_to have_key(:shopify_field)
    end

    it 'includes custom attributes without any mapping (value only)' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['internal_notes']).to eq({ value: 'For internal use only' })
      expect(values['internal_notes']).not_to have_key(:system)
      expect(values['internal_notes']).not_to have_key(:shopify_field)
      expect(values['internal_notes']).not_to have_key(:shopify_metafield)
      expect(values['internal_notes']).not_to have_key(:custom_handler)
    end

    it 'includes all attribute types in a single payload' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expected_codes = %w[price ean detailed_description special_price vat_group thc_percentage internal_notes]
      expected_codes.each do |code|
        expect(values).to have_key(code), "Expected payload to include '#{code}' attribute"
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 4. Catalog override integration
  # ─────────────────────────────────────────────────────────────────────────
  describe 'catalog override integration' do
    let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    before do
      # Product-level values
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '2999')
      create(:product_attribute_value, product: product, product_attribute: description_html_attr, value: '<p>Product description</p>')

      # Catalog-level overrides (price and description_html are product_and_catalog_scope)
      create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '3499')
      create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: description_html_attr, value: '<p>Catalog-specific description</p>')
    end

    it 'uses overridden values from catalog while preserving shopify mapping' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      # Price should be the catalog override
      expect(values['price'][:value]).to eq('3499')
      # But mapping info comes from the ProductAttribute, not the value
      expect(values['price'][:shopify_field]).to eq('price')
      expect(values['price'][:system]).to be true
    end

    it 'uses overridden description from catalog while preserving shopify_field mapping' do
      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['description_html'][:value]).to eq('<p>Catalog-specific description</p>')
      expect(values['description_html'][:shopify_field]).to eq('descriptionHtml')
      expect(values['description_html'][:system]).to be true
    end

    it 'falls back to product-level values for non-overridden attributes' do
      # Add a product-level weight (product_scope only, no catalog override)
      create(:product_attribute_value, product: product, product_attribute: weight_attr, value: '750')

      payload = service.build_payload
      values = payload[:attributes][:values]

      expect(values['weight'][:value]).to eq('750')
      expect(values['weight'][:shopify_field]).to eq('weight')
      expect(values['weight'][:system]).to be true
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 5. Subproduct/variant attribute enrichment
  # ─────────────────────────────────────────────────────────────────────────
  describe 'subproduct/variant attribute enrichment' do
    let(:configurable) { create(:product, :configurable_variant, company: company, sku: 'CFG-001') }
    let(:variant_small) { create(:product, :sellable, company: company, sku: 'CFG-001-S', name: 'Config Small') }
    let(:variant_large) { create(:product, :sellable, company: company, sku: 'CFG-001-L', name: 'Config Large') }
    let(:variant_service) { ProductSyncService.new(configurable, catalog) }

    let!(:custom_metafield_attr) do
      create(:product_attribute,
             company: company,
             code: 'cbd_percentage',
             name: 'CBD Percentage',
             pa_type: :patype_number,
             view_format: :view_format_general,
             system: false,
             shopify_metafield_namespace: 'custom',
             shopify_metafield_key: 'cbd_pct',
             shopify_metafield_type: 'number_decimal')
    end

    before do
      create(:product_configuration,
             superproduct: configurable,
             subproduct: variant_small,
             configuration_position: 1,
             info: { 'variant_config' => { 'size' => 'Small' } })
      create(:product_configuration,
             superproduct: configurable,
             subproduct: variant_large,
             configuration_position: 2,
             info: { 'variant_config' => { 'size' => 'Large' } })

      # Variant attributes - system with shopify_field
      create(:product_attribute_value, product: variant_small, product_attribute: price_attr, value: '1999')
      create(:product_attribute_value, product: variant_large, product_attribute: price_attr, value: '2499')

      # Variant attributes - system with shopify_field
      create(:product_attribute_value, product: variant_small, product_attribute: ean_attr, value: '1111111111111')
      create(:product_attribute_value, product: variant_large, product_attribute: ean_attr, value: '2222222222222')

      # Variant attributes - custom with metafield
      create(:product_attribute_value, product: variant_small, product_attribute: custom_metafield_attr, value: '5.2')
    end

    it 'includes enriched attributes for each subproduct' do
      payload = variant_service.build_payload
      subproducts = payload[:subproducts]

      expect(subproducts.length).to eq(2)

      small_sub = subproducts.find { |s| s[:product][:sku] == 'CFG-001-S' }
      large_sub = subproducts.find { |s| s[:product][:sku] == 'CFG-001-L' }

      # Small variant - system attrs with shopify_field
      expect(small_sub[:attributes]['price']).to include(
        value: '1999',
        shopify_field: 'price',
        system: true
      )
      expect(small_sub[:attributes]['ean']).to include(
        value: '1111111111111',
        shopify_field: 'barcode',
        system: true
      )

      # Large variant - system attrs with shopify_field
      expect(large_sub[:attributes]['price']).to include(
        value: '2499',
        shopify_field: 'price',
        system: true
      )
      expect(large_sub[:attributes]['ean']).to include(
        value: '2222222222222',
        shopify_field: 'barcode',
        system: true
      )
    end

    it 'includes custom metafield attributes on subproducts' do
      payload = variant_service.build_payload
      subproducts = payload[:subproducts]

      small_sub = subproducts.find { |s| s[:product][:sku] == 'CFG-001-S' }

      expect(small_sub[:attributes]['cbd_percentage']).to include(value: '5.2')
      expect(small_sub[:attributes]['cbd_percentage'][:shopify_metafield]).to eq({
        namespace: 'custom',
        key: 'cbd_pct',
        type: 'number_decimal'
      })
      expect(small_sub[:attributes]['cbd_percentage']).not_to have_key(:system)
    end

    it 'does not include attributes that have no value for a subproduct' do
      payload = variant_service.build_payload
      subproducts = payload[:subproducts]

      large_sub = subproducts.find { |s| s[:product][:sku] == 'CFG-001-L' }

      # Large variant has no cbd_percentage value
      expect(large_sub[:attributes]).not_to have_key('cbd_percentage')
    end
  end

  # ─────────────────────────────────────────────────────────────────────────
  # 6. HTTP sync sends enriched payload
  # ─────────────────────────────────────────────────────────────────────────
  describe 'HTTP sync sends enriched payload' do
    let!(:thc_attr) do
      create(:product_attribute,
             company: company,
             code: 'thc_percentage',
             name: 'THC Percentage',
             pa_type: :patype_number,
             view_format: :view_format_general,
             system: false,
             shopify_metafield_namespace: 'custom',
             shopify_metafield_key: 'thc_percentage',
             shopify_metafield_type: 'number_decimal')
    end

    before do
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '2999')
      create(:product_attribute_value, product: product, product_attribute: detailed_description_attr, value: '<p>Extended</p>')
      create(:product_attribute_value, product: product, product_attribute: thc_attr, value: '18.5')

      catalog.update!(info: catalog.info.merge('shopify_api_token' => 'test_token_shopify8'))
    end

    it 'sends the enriched attribute format in the HTTP POST body' do
      stub_request(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .to_return(status: 200, body: { status: 'ok', id: 123 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.sync_to_external_system

      expect(result.success?).to be true

      # Verify the request was made
      expect(WebMock).to have_requested(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .once
    end

    it 'wraps payload in sync_task format with enriched attributes in info.load' do
      captured_body = nil

      stub_request(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .with { |request| captured_body = JSON.parse(request.body); true }
        .to_return(status: 200, body: { status: 'ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

      service.sync_to_external_system

      # Verify sync_task wrapper structure
      sync_task = captured_body['sync_task']
      expect(sync_task).to be_present
      expect(sync_task['event_type']).to eq('product_changed')
      expect(sync_task['shop_id']).to eq(42)
      expect(sync_task['origin_target_id']).to eq('INT-TEST-001')

      # Verify enriched attributes inside load
      load_data = sync_task['info']['load']
      expect(load_data['sku']).to eq('INT-TEST-001')

      attributes = load_data['attributes']
      values = attributes['values']

      # System attr with shopify_field - verify it's a hash, not a flat string
      price_entry = values['price']
      expect(price_entry).to be_a(Hash)
      expect(price_entry['value']).to eq('2999')
      expect(price_entry['shopify_field']).to eq('price')
      expect(price_entry['system']).to be true

      # System attr with shopify_metafield
      detailed_entry = values['detailed_description']
      expect(detailed_entry).to be_a(Hash)
      expect(detailed_entry['value']).to eq('<p>Extended</p>')
      expect(detailed_entry['system']).to be true
      expect(detailed_entry['shopify_metafield']).to eq({
        'namespace' => 'global',
        'key' => 'detailed_description_html',
        'type' => 'multi_line_text_field'
      })

      # Custom attr with metafield opt-in
      thc_entry = values['thc_percentage']
      expect(thc_entry).to be_a(Hash)
      expect(thc_entry['value']).to eq('18.5')
      expect(thc_entry).not_to have_key('system')
      expect(thc_entry['shopify_metafield']).to eq({
        'namespace' => 'custom',
        'key' => 'thc_percentage',
        'type' => 'number_decimal'
      })
    end

    it 'includes Authorization header with API token' do
      stub_request(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .with(headers: { 'Authorization' => 'Bearer test_token_shopify8' })
        .to_return(status: 200, body: { status: 'ok' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.sync_to_external_system

      expect(result.success?).to be true
      expect(WebMock).to have_requested(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .with(headers: { 'Authorization' => 'Bearer test_token_shopify8' })
    end

    it 'returns failure result when Shopify8 returns an error' do
      stub_request(:post, 'https://shopify8.test.example.com/api/v1/sync_tasks')
        .to_return(status: 422, body: { error: 'Unprocessable' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = service.sync_to_external_system

      expect(result.success?).to be false
      expect(result.error).to include('API error')
      expect(result.error).to include('422')
    end
  end
end
