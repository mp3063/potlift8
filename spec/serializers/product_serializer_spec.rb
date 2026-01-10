# Product Serializer Spec
#
# Tests for ProductSerializer that handles basic product list serialization.
#
require 'rails_helper'

RSpec.describe ProductSerializer do
  let(:company) { create(:company) }
  let(:product) do
    create(:product,
           company: company,
           sku: 'TEST-SKU-001',
           name: 'Test Product',
           ean: '1234567890123',
           product_type: :sellable,
           product_status: :active)
  end

  let(:storage) { create(:storage, company: company, code: 'MAIN') }
  let(:serializer) { described_class.new(product) }

  describe '#as_json' do
    let(:json) { serializer.as_json }

    it 'includes id' do
      expect(json[:id]).to eq(product.id)
    end

    it 'includes sku' do
      expect(json[:sku]).to eq('TEST-SKU-001')
    end

    it 'includes name' do
      expect(json[:name]).to eq('Test Product')
    end

    it 'includes ean' do
      expect(json[:ean]).to eq('1234567890123')
    end

    it 'includes product_type' do
      expect(json[:product_type]).to eq('sellable')
    end

    it 'includes product_status' do
      expect(json[:product_status]).to eq('active')
    end

    it 'includes total_saldo' do
      expect(json).to have_key(:total_saldo)
      expect(json[:total_saldo]).to be_a(Integer)
    end

    it 'includes created_at' do
      expect(json[:created_at]).to be_present
      expect(json[:created_at]).to be_a(ActiveSupport::TimeWithZone)
    end

    it 'includes updated_at' do
      expect(json[:updated_at]).to be_present
      expect(json[:updated_at]).to be_a(ActiveSupport::TimeWithZone)
    end

    it 'calculates total_saldo correctly' do
      create(:inventory, product: product, storage: storage, value: 100)

      json = serializer.as_json
      expect(json[:total_saldo]).to eq(100)
    end

    it 'returns zero total_saldo when no inventory' do
      expect(json[:total_saldo]).to eq(0)
    end

    it 'does not include sensitive fields' do
      expect(json).not_to have_key(:company_id)
      expect(json).not_to have_key(:structure)
      expect(json).not_to have_key(:info)
      expect(json).not_to have_key(:cache)
    end

    it 'does not include associations' do
      expect(json).not_to have_key(:inventories)
      expect(json).not_to have_key(:attributes)
      expect(json).not_to have_key(:labels)
      expect(json).not_to have_key(:company)
    end

    context 'with nil values' do
      let(:product) do
        create(:product,
               company: company,
               sku: 'NULL-TEST',
               name: 'Null Test',
               ean: nil)
      end

      it 'handles nil ean' do
        expect(json[:ean]).to be_nil
      end
    end

    context 'with different product types' do
      it 'serializes sellable product' do
        product.update(product_type: :sellable)
        expect(json[:product_type]).to eq('sellable')
      end

      it 'serializes configurable product' do
        product.update(product_type: :configurable, configuration_type: :variant)
        json = serializer.as_json
        expect(json[:product_type]).to eq('configurable')
      end

      it 'serializes bundle product' do
        product.update(product_type: :bundle)
        json = serializer.as_json
        expect(json[:product_type]).to eq('bundle')
      end
    end

    context 'with different product statuses' do
      it 'serializes draft status' do
        product.update(product_status: :draft)
        json = serializer.as_json
        expect(json[:product_status]).to eq('draft')
      end

      it 'serializes active status' do
        product.update(product_status: :active)
        json = serializer.as_json
        expect(json[:product_status]).to eq('active')
      end

      it 'serializes discontinued status' do
        product.update(product_status: :discontinued)
        json = serializer.as_json
        expect(json[:product_status]).to eq('discontinued')
      end
    end

    context 'with multiple inventories' do
      let(:storage1) { create(:storage, company: company, code: 'MAIN') }
      let(:storage2) { create(:storage, company: company, code: 'SECONDARY') }

      it 'sums up inventory from multiple storages' do
        create(:inventory, product: product, storage: storage1, value: 100)
        create(:inventory, product: product, storage: storage2, value: 50)

        json = serializer.as_json
        expect(json[:total_saldo]).to eq(150)
      end
    end
  end

  describe '.collection' do
    let!(:product1) { create(:product, company: company, sku: 'PROD-001', name: 'Product 1') }
    let!(:product2) { create(:product, company: company, sku: 'PROD-002', name: 'Product 2') }
    let!(:product3) { create(:product, company: company, sku: 'PROD-003', name: 'Product 3') }

    let(:products) { [product1, product2, product3] }

    it 'serializes collection of products' do
      result = described_class.collection(products)

      expect(result).to be_an(Array)
      expect(result.length).to eq(3)
    end

    it 'returns array of hashes' do
      result = described_class.collection(products)

      expect(result.first).to be_a(Hash)
      expect(result.first).to have_key(:id)
      expect(result.first).to have_key(:sku)
      expect(result.first).to have_key(:name)
    end

    it 'maintains order of products' do
      result = described_class.collection(products)

      expect(result.map { |p| p[:sku] }).to eq(['PROD-001', 'PROD-002', 'PROD-003'])
    end

    it 'handles empty collection' do
      result = described_class.collection([])

      expect(result).to eq([])
    end

    it 'works with ActiveRecord relation' do
      relation = company.products.where(id: [product1.id, product2.id])
      result = described_class.collection(relation)

      expect(result.length).to eq(2)
    end
  end

  describe 'JSON structure consistency' do
    it 'returns hash with symbol keys' do
      json = serializer.as_json

      expect(json.keys).to all(be_a(Symbol))
    end

    it 'has consistent structure across instances' do
      product1 = create(:product, company: company, sku: 'PROD-A')
      product2 = create(:product, company: company, sku: 'PROD-B')

      json1 = described_class.new(product1).as_json
      json2 = described_class.new(product2).as_json

      expect(json1.keys).to eq(json2.keys)
    end
  end

  describe 'performance' do
    it 'does not trigger N+1 queries for total_saldo' do
      create(:inventory, product: product, storage: storage, value: 100)

      # First call loads the association
      serializer.as_json

      # Second call should use cached associations, allowing minimal queries
      expect do
        serializer.as_json
      end.not_to exceed_query_limit(1)
    end

    it 'is efficient with preloaded associations' do
      products = company.products.includes(:inventories).limit(10)

      # With preloaded associations, should have constant query count (not N+1)
      expect do
        described_class.collection(products)
      end.not_to exceed_query_limit(2)
    end
  end

  describe 'edge cases' do
    it 'handles very long product names' do
      long_name = 'A' * 255
      product.update(name: long_name)

      json = serializer.as_json
      expect(json[:name]).to eq(long_name)
    end

    it 'handles special characters in fields' do
      product.update(name: "Product with 'quotes' and \"double quotes\"")

      json = serializer.as_json
      expect(json[:name]).to include("'quotes'")
    end

    it 'handles negative inventory values' do
      create(:inventory, product: product, storage: storage, value: -50)

      json = serializer.as_json
      expect(json[:total_saldo]).to eq(-50)
    end

    it 'handles very large inventory values' do
      create(:inventory, product: product, storage: storage, value: 999_999_999)

      json = serializer.as_json
      expect(json[:total_saldo]).to eq(999_999_999)
    end
  end
end
