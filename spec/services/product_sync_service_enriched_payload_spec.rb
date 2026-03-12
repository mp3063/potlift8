# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductSyncService, 'enriched payload format', type: :service do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, company: company, info: { 'sync_target' => 'shopify8' }) }
  let(:service) { ProductSyncService.new(product, catalog) }

  before do
    ENV['SHOPIFY8_URL'] = 'https://shopify8.example.com'
  end

  after do
    ENV.delete('SHOPIFY8_URL')
  end

  describe '#build_attribute_entry' do
    context 'for a system attribute with shopify_field mapping' do
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }

      it 'includes shopify_field from registry' do
        entry = service.send(:build_attribute_entry, price_attr, '1999')
        expect(entry[:shopify_field]).to eq('price')
      end

      it 'includes system: true flag' do
        entry = service.send(:build_attribute_entry, price_attr, '1999')
        expect(entry[:system]).to be true
      end

      it 'includes the value' do
        entry = service.send(:build_attribute_entry, price_attr, '1999')
        expect(entry[:value]).to eq('1999')
      end

      it 'does not include custom_handler for price' do
        entry = service.send(:build_attribute_entry, price_attr, '1999')
        expect(entry).not_to have_key(:custom_handler)
      end
    end

    context 'for a system attribute with custom_handler mapping' do
      let(:special_price_attr) { company.product_attributes.find_by(code: 'special_price') }

      it 'includes custom_handler from registry' do
        entry = service.send(:build_attribute_entry, special_price_attr, '999')
        expect(entry[:custom_handler]).to eq('special_price')
      end

      it 'does not include shopify_field' do
        entry = service.send(:build_attribute_entry, special_price_attr, '999')
        expect(entry).not_to have_key(:shopify_field)
      end
    end

    context 'for a system attribute with shopify_metafield config' do
      let(:detailed_desc) { company.product_attributes.find_by(code: 'detailed_description') }

      it 'includes shopify_metafield hash' do
        entry = service.send(:build_attribute_entry, detailed_desc, '<p>Details</p>')
        expect(entry[:shopify_metafield]).to eq({
          namespace: 'global',
          key: 'detailed_description_html',
          type: 'multi_line_text_field'
        })
      end
    end

    context 'for a custom attribute without any mapping' do
      let(:custom_attr) { create(:product_attribute, company: company, code: 'custom_field', system: false) }

      it 'does not include shopify_field' do
        entry = service.send(:build_attribute_entry, custom_attr, 'some value')
        expect(entry).not_to have_key(:shopify_field)
      end

      it 'does not include custom_handler' do
        entry = service.send(:build_attribute_entry, custom_attr, 'some value')
        expect(entry).not_to have_key(:custom_handler)
      end

      it 'does not include shopify_metafield' do
        entry = service.send(:build_attribute_entry, custom_attr, 'some value')
        expect(entry).not_to have_key(:shopify_metafield)
      end

      it 'does not include system flag' do
        entry = service.send(:build_attribute_entry, custom_attr, 'some value')
        expect(entry).not_to have_key(:system)
      end

      it 'includes the value' do
        entry = service.send(:build_attribute_entry, custom_attr, 'some value')
        expect(entry[:value]).to eq('some value')
      end
    end

    context 'for a custom attribute with user-configured shopify_metafield' do
      let(:custom_attr) do
        create(:product_attribute,
               company: company,
               code: 'thc_percentage',
               system: false,
               shopify_metafield_namespace: 'custom',
               shopify_metafield_key: 'thc_pct',
               shopify_metafield_type: 'number_decimal')
      end

      it 'includes shopify_metafield from DB columns' do
        entry = service.send(:build_attribute_entry, custom_attr, '21.5')
        expect(entry[:shopify_metafield]).to eq({
          namespace: 'custom',
          key: 'thc_pct',
          type: 'number_decimal'
        })
      end

      it 'does not include system flag' do
        entry = service.send(:build_attribute_entry, custom_attr, '21.5')
        expect(entry).not_to have_key(:system)
      end
    end
  end

  describe '#build_attributes_payload with enriched format' do
    let(:price_attr) { company.product_attributes.find_by(code: 'price') }
    let(:ean_attr) { company.product_attributes.find_by(code: 'ean') }

    before do
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '2999')
      create(:product_attribute_value, product: product, product_attribute: ean_attr, value: '1234567890123')
    end

    it 'returns enriched format with :values and :localized keys' do
      result = service.send(:build_attributes_payload)
      expect(result).to have_key(:values)
      expect(result).to have_key(:localized)
    end

    it 'each value entry is an enriched hash, not a flat string' do
      result = service.send(:build_attributes_payload)
      price_entry = result[:values]['price']

      expect(price_entry).to be_a(Hash)
      expect(price_entry[:value]).to eq('2999')
      expect(price_entry[:shopify_field]).to eq('price')
      expect(price_entry[:system]).to be true
    end

    it 'includes mapping info for ean' do
      result = service.send(:build_attributes_payload)
      ean_entry = result[:values]['ean']

      expect(ean_entry[:value]).to eq('1234567890123')
      expect(ean_entry[:shopify_field]).to eq('barcode')
      expect(ean_entry[:system]).to be true
    end
  end

  describe '#build_subproduct_attributes with enriched format' do
    let(:configurable) { create(:product, :configurable_variant, company: company) }
    let(:variant) { create(:product, :sellable, company: company, sku: 'VAR-001') }
    let(:price_attr) { company.product_attributes.find_by(code: 'price') }
    let(:test_service) { ProductSyncService.new(configurable, catalog) }

    before do
      create(:product_configuration, superproduct: configurable, subproduct: variant)
      create(:product_attribute_value, product: variant, product_attribute: price_attr, value: '1599')
    end

    it 'returns enriched attributes for subproduct' do
      result = test_service.send(:build_subproduct_attributes, variant)
      expect(result['price'][:value]).to eq('1599')
      expect(result['price'][:shopify_field]).to eq('price')
      expect(result['price'][:system]).to be true
    end
  end
end
