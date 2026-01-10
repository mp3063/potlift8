# Product Detail Serializer Spec
#
# Tests for ProductDetailSerializer that handles detailed product serialization
# including attributes, inventory, labels, and relationships.
#
require 'rails_helper'

RSpec.describe ProductDetailSerializer do
  let(:company) { create(:company) }
  let(:product) do
    create(:product,
           company: company,
           sku: 'DETAIL-001',
           name: 'Detail Test Product',
           ean: '9876543210123',
           product_type: :sellable,
           product_status: :active,
           structure: { 'config' => 'value' },
           info: { 'description' => 'Test description' },
           cache: { 'cached_value' => 123 })
  end

  let(:storage_main) { create(:storage, company: company, code: 'MAIN') }
  let(:storage_incoming) { create(:storage, company: company, code: 'INCOMING', storage_type: :incoming) }
  let(:serializer) { described_class.new(product) }

  describe '#as_json' do
    let(:json) { serializer.as_json }

    context 'basic fields' do
      it 'includes id' do
        expect(json[:id]).to eq(product.id)
      end

      it 'includes sku' do
        expect(json[:sku]).to eq('DETAIL-001')
      end

      it 'includes name' do
        expect(json[:name]).to eq('Detail Test Product')
      end

      it 'includes ean' do
        expect(json[:ean]).to eq('9876543210123')
      end

      it 'includes product_type' do
        expect(json[:product_type]).to eq('sellable')
      end

      it 'includes configuration_type' do
        expect(json).to have_key(:configuration_type)
      end

      it 'includes product_status' do
        expect(json[:product_status]).to eq('active')
      end

      it 'includes created_at' do
        expect(json[:created_at]).to be_present
      end

      it 'includes updated_at' do
        expect(json[:updated_at]).to be_present
      end
    end

    context 'JSONB fields' do
      it 'includes structure' do
        expect(json[:structure]).to eq({ 'config' => 'value' })
      end

      it 'includes info' do
        expect(json[:info]).to eq({ 'description' => 'Test description' })
      end

      it 'includes cache' do
        expect(json[:cache]).to eq({ 'cached_value' => 123 })
      end

      it 'returns empty hash for empty structure' do
        product.update(structure: {})
        json = serializer.as_json
        expect(json[:structure]).to eq({})
      end

      it 'returns empty hash for empty info' do
        product.update(info: {})
        json = serializer.as_json
        expect(json[:info]).to eq({})
      end

      it 'returns empty hash for empty cache' do
        product.update(cache: {})
        json = serializer.as_json
        expect(json[:cache]).to eq({})
      end
    end

    context 'inventory serialization' do
      it 'includes inventory key' do
        expect(json).to have_key(:inventory)
      end

      it 'calls single_inventory_with_eta method' do
        expect(product).to receive(:single_inventory_with_eta).and_call_original
        serializer.as_json
      end

      it 'includes inventory with available, incoming, and eta' do
        storage_main
        storage_incoming
        create(:inventory, product: product, storage: storage_main, value: 100)
        create(:inventory, product: product, storage: storage_incoming, value: 50, eta: Date.parse('2025-12-01'))

        json = serializer.as_json

        expect(json[:inventory]).to have_key(:available)
        expect(json[:inventory]).to have_key(:incoming)
        expect(json[:inventory]).to have_key(:eta)
      end

      it 'handles products without inventory' do
        expect(json[:inventory]).to be_present
      end
    end

    context 'attributes serialization' do
      let(:price_attr) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
      let(:color_attr) { create(:product_attribute, company: company, code: 'color', name: 'Color') }

      before do
        # Ensure attributes exist before writing values
        price_attr
        color_attr
        product.write_attribute_value('price', '1999')
        product.write_attribute_value('color', 'blue')
      end

      it 'includes attributes key' do
        expect(json).to have_key(:attributes)
      end

      it 'calls attribute_values_hash method' do
        expect(product).to receive(:attribute_values_hash).and_call_original
        serializer.as_json
      end

      it 'includes all product attributes as hash' do
        json = serializer.as_json

        expect(json[:attributes]).to be_a(Hash)
        expect(json[:attributes]).to have_key('price')
        expect(json[:attributes]).to have_key('color')
        expect(json[:attributes]['price']).to eq('1999')
        expect(json[:attributes]['color']).to eq('blue')
      end

      it 'returns empty hash for products without attributes' do
        product = create(:product, company: company)
        json = described_class.new(product).as_json

        expect(json[:attributes]).to eq({})
      end
    end

    context 'labels serialization' do
      let(:label1) { create(:label, company: company, code: 'category', name: 'Category') }
      let(:label2) { create(:label, company: company, code: 'brand', name: 'Brand') }

      before do
        create(:product_label, product: product, label: label1)
        create(:product_label, product: product, label: label2)
      end

      it 'includes labels key' do
        expect(json).to have_key(:labels)
      end

      it 'returns array of label objects' do
        json = serializer.as_json

        expect(json[:labels]).to be_an(Array)
        expect(json[:labels].length).to eq(2)
      end

      it 'includes label code and name' do
        json = serializer.as_json

        label = json[:labels].first
        expect(label).to have_key(:code)
        expect(label).to have_key(:name)
      end

      it 'serializes all labels correctly' do
        json = serializer.as_json

        codes = json[:labels].map { |l| l[:code] }
        names = json[:labels].map { |l| l[:name] }

        expect(codes).to contain_exactly('category', 'brand')
        expect(names).to contain_exactly('Category', 'Brand')
      end

      it 'returns empty array for products without labels' do
        product = create(:product, company: company)
        json = described_class.new(product).as_json

        expect(json[:labels]).to eq([])
      end
    end

    context 'with configurable product' do
      let(:configurable_product) do
        create(:product,
               company: company,
               sku: 'CONFIG-001',
               product_type: :configurable,
               configuration_type: :variant)
      end

      it 'includes configuration_type for configurable products' do
        json = described_class.new(configurable_product).as_json

        expect(json[:configuration_type]).to eq('variant')
      end

      it 'includes null configuration_type for non-configurable products' do
        expect(json[:configuration_type]).to be_nil
      end
    end

    context 'with bundle product' do
      let(:bundle) do
        create(:product,
               company: company,
               sku: 'BUNDLE-001',
               product_type: :bundle)
      end

      it 'serializes bundle product' do
        json = described_class.new(bundle).as_json

        expect(json[:product_type]).to eq('bundle')
        expect(json[:configuration_type]).to be_nil
      end
    end
  end

  describe 'JSON structure' do
    it 'returns hash with symbol keys' do
      json = serializer.as_json

      expect(json.keys).to all(be_a(Symbol))
    end

    it 'has all required top-level keys' do
      json = serializer.as_json

      expect(json).to have_key(:id)
      expect(json).to have_key(:sku)
      expect(json).to have_key(:name)
      expect(json).to have_key(:ean)
      expect(json).to have_key(:product_type)
      expect(json).to have_key(:configuration_type)
      expect(json).to have_key(:product_status)
      expect(json).to have_key(:structure)
      expect(json).to have_key(:info)
      expect(json).to have_key(:cache)
      expect(json).to have_key(:inventory)
      expect(json).to have_key(:attributes)
      expect(json).to have_key(:labels)
      expect(json).to have_key(:created_at)
      expect(json).to have_key(:updated_at)
    end

    it 'does not include sensitive or internal fields' do
      json = serializer.as_json

      expect(json).not_to have_key(:company_id)
      expect(json).not_to have_key(:sync_lock_id)
      expect(json).not_to have_key(:company)
    end
  end

  describe 'comparison with ProductSerializer' do
    it 'includes all ProductSerializer fields' do
      basic_json = ProductSerializer.new(product).as_json
      detail_json = serializer.as_json

      basic_json.each_key do |key|
        expect(detail_json).to have_key(key)
      end
    end

    it 'includes additional fields beyond ProductSerializer' do
      basic_json = ProductSerializer.new(product).as_json
      detail_json = serializer.as_json

      expect(detail_json.keys.length).to be > basic_json.keys.length
      expect(detail_json).to have_key(:inventory)
      expect(detail_json).to have_key(:attributes)
      expect(detail_json).to have_key(:labels)
      expect(detail_json).to have_key(:structure)
      expect(detail_json).to have_key(:info)
      expect(detail_json).to have_key(:cache)
    end
  end

  describe 'performance' do
    it 'does not trigger N+1 queries with preloaded associations' do
      # Preload associations
      product_with_preload = company.products
                                    .includes(:inventories, :product_attribute_values, :labels)
                                    .find(product.id)

      # With preloaded associations, should have constant query count (not N+1)
      expect do
        described_class.new(product_with_preload).as_json
      end.not_to exceed_query_limit(5)
    end
  end

  describe 'edge cases' do
    it 'handles product with complex structure' do
      complex_structure = {
        'variants' => [
          { 'size' => 'S', 'color' => 'red' },
          { 'size' => 'M', 'color' => 'blue' }
        ],
        'options' => {
          'gift_wrap' => true
        }
      }

      product.update(structure: complex_structure)

      json = serializer.as_json
      expect(json[:structure]).to eq(complex_structure)
    end

    it 'handles product with complex info' do
      complex_info = {
        'description' => 'Long description',
        'specifications' => {
          'weight' => '1.5kg',
          'dimensions' => '10x20x30cm'
        },
        'metadata' => {
          'tags' => [ 'new', 'featured' ],
          'seo' => {
            'title' => 'SEO Title',
            'keywords' => [ 'keyword1', 'keyword2' ]
          }
        }
      }

      product.update(info: complex_info)

      json = serializer.as_json
      expect(json[:info]).to eq(complex_info)
    end

    it 'handles products with many labels' do
      10.times do |i|
        label = create(:label, company: company, code: "label_#{i}", name: "Label #{i}")
        create(:product_label, product: product, label: label)
      end

      json = serializer.as_json
      expect(json[:labels].length).to eq(10)
    end

    it 'handles products with many attributes' do
      10.times do |i|
        attr = create(:product_attribute, company: company, code: "attr_#{i}", name: "Attribute #{i}")
        product.write_attribute_value("attr_#{i}", "value_#{i}")
      end

      json = serializer.as_json
      expect(json[:attributes].keys.length).to eq(10)
    end

    it 'handles nil EAN' do
      product.update(ean: nil)

      json = serializer.as_json
      expect(json[:ean]).to be_nil
    end

    it 'handles empty string values' do
      product.update(ean: '')

      json = serializer.as_json
      expect(json[:ean]).to eq('')
    end

    it 'handles special characters in JSONB fields' do
      product.update(info: { 'description' => "Contains 'quotes' and \"double quotes\" and \nnewlines" })

      json = serializer.as_json
      expect(json[:info]['description']).to include("'quotes'")
      expect(json[:info]['description']).to include('"double quotes"')
    end
  end

  describe 'consistency' do
    it 'produces consistent output for same product' do
      json1 = serializer.as_json
      json2 = serializer.as_json

      expect(json1).to eq(json2)
    end

    it 'produces different output for different products' do
      product2 = create(:product, company: company, sku: 'DIFFERENT-SKU')

      json1 = serializer.as_json
      json2 = described_class.new(product2).as_json

      expect(json1[:sku]).not_to eq(json2[:sku])
    end
  end
end
