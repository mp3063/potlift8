# frozen_string_literal: true

require 'rails_helper'
require 'csv'

RSpec.describe ProductExportService do
  let(:company) { create(:company) }

  describe '#to_csv' do
    subject(:csv_export) { described_class.new(products).to_csv }

    context 'with no products' do
      let(:products) { Product.none }

      it 'returns CSV with headers only' do
        csv_data = CSV.parse(csv_export, headers: true)

        expect(csv_data.headers).to eq([
          'SKU',
          'Name',
          'Product Type',
          'Description',
          'Active',
          'Labels',
          'Total Inventory',
          'Created At',
          'Updated At'
        ])

        expect(csv_data.count).to eq(0)
      end
    end

    context 'with products' do
      let!(:product1) do
        travel_to(Time.parse('2024-01-15 10:00:00 UTC')) do
          create(:product,
                 company: company,
                 sku: 'PROD001',
                 name: 'Product One',
                 product_type: :sellable,
                 product_status: :active,
                 info: { 'description' => 'First product description' })
        end.tap { |p| p.update_column(:updated_at, Time.parse('2024-01-20 15:30:00 UTC')) }
      end

      let!(:product2) do
        travel_to(Time.parse('2024-01-16 11:00:00 UTC')) do
          create(:product,
                 company: company,
                 sku: 'PROD002',
                 name: 'Product Two',
                 product_type: :configurable,
                 configuration_type: :variant,
                 product_status: :draft,
                 info: { 'description' => 'Second product description' })
        end.tap { |p| p.update_column(:updated_at, Time.parse('2024-01-21 16:30:00 UTC')) }
      end

      let(:products) { Product.where(company: company) }

      it 'exports all products' do
        csv_data = CSV.parse(csv_export, headers: true)

        expect(csv_data.count).to eq(2)
      end

      it 'includes correct product data' do
        csv_data = CSV.parse(csv_export, headers: true)

        # Find the PROD001 row (order might vary)
        first_row = csv_data.find { |row| row['SKU'] == 'PROD001' }
        expect(first_row['Name']).to eq('Product One')
        expect(first_row['Product Type']).to eq('Sellable')
        expect(first_row['Description']).to eq('First product description')
        expect(first_row['Active']).to eq('Yes')
        expect(first_row['Total Inventory']).to eq('0')
        expect(first_row['Created At']).to match(/2024-01-15T10:00:00/)
        expect(first_row['Updated At']).to match(/2024-01-20T15:30:00/)
      end

      it 'formats active status correctly' do
        csv_data = CSV.parse(csv_export, headers: true)

        active_product = csv_data.find { |row| row['SKU'] == 'PROD001' }
        draft_product = csv_data.find { |row| row['SKU'] == 'PROD002' }

        expect(active_product['Active']).to eq('Yes')
        expect(draft_product['Active']).to eq('No')
      end

      it 'formats product type correctly' do
        csv_data = CSV.parse(csv_export, headers: true)

        sellable_product = csv_data.find { |row| row['SKU'] == 'PROD001' }
        configurable_product = csv_data.find { |row| row['SKU'] == 'PROD002' }

        expect(sellable_product['Product Type']).to eq('Sellable')
        expect(configurable_product['Product Type']).to eq('Configurable')
      end

      it 'formats timestamps in ISO8601 format' do
        csv_data = CSV.parse(csv_export, headers: true)

        first_row = csv_data.find { |row| row['SKU'] == 'PROD001' }
        expect(first_row['Created At']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
        expect(first_row['Updated At']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      end
    end

    context 'with labels' do
      let!(:label1) { create(:label, company: company, name: 'Electronics') }
      let!(:label2) { create(:label, company: company, name: 'Featured') }
      let!(:label3) { create(:label, company: company, name: 'New') }

      let!(:product_with_labels) do
        product = create(:product, company: company, sku: 'LABELED')
        create(:product_label, product: product, label: label1)
        create(:product_label, product: product, label: label2)
        create(:product_label, product: product, label: label3)
        product
      end

      let!(:product_without_labels) do
        create(:product, company: company, sku: 'UNLABELED')
      end

      let(:products) { Product.where(company: company) }

      it 'exports labels as comma-separated list' do
        csv_data = CSV.parse(csv_export, headers: true)

        labeled_row = csv_data.find { |row| row['SKU'] == 'LABELED' }
        expect(labeled_row['Labels']).to eq('Electronics, Featured, New')
      end

      it 'handles products without labels' do
        csv_data = CSV.parse(csv_export, headers: true)

        unlabeled_row = csv_data.find { |row| row['SKU'] == 'UNLABELED' }
        expect(unlabeled_row['Labels']).to eq('')
      end
    end

    context 'with inventory' do
      let!(:storage1) { create(:storage, company: company) }
      let!(:storage2) { create(:storage, company: company) }

      let!(:product_with_inventory) do
        product = create(:product, company: company, sku: 'INSTOCK')
        create(:inventory, product: product, storage: storage1, value: 50)
        create(:inventory, product: product, storage: storage2, value: 75)
        product
      end

      let!(:product_no_inventory) do
        create(:product, company: company, sku: 'OUTOFSTOCK')
      end

      let(:products) { Product.where(company: company) }

      it 'exports total inventory correctly' do
        csv_data = CSV.parse(csv_export, headers: true)

        instock_row = csv_data.find { |row| row['SKU'] == 'INSTOCK' }
        expect(instock_row['Total Inventory']).to eq('125')
      end

      it 'exports zero inventory for products without stock' do
        csv_data = CSV.parse(csv_export, headers: true)

        outofstock_row = csv_data.find { |row| row['SKU'] == 'OUTOFSTOCK' }
        expect(outofstock_row['Total Inventory']).to eq('0')
      end
    end

    context 'with different product types' do
      let!(:sellable) do
        create(:product,
               company: company,
               sku: 'SELL001',
               product_type: :sellable,
               configuration_type: nil)
      end

      let!(:configurable) do
        create(:product,
               company: company,
               sku: 'CONF001',
               product_type: :configurable,
               configuration_type: :variant)
      end

      let!(:bundle) do
        create(:product,
               company: company,
               sku: 'BUND001',
               product_type: :bundle,
               configuration_type: nil)
      end

      let(:products) { Product.where(company: company) }

      it 'exports all product types correctly' do
        csv_data = CSV.parse(csv_export, headers: true)

        sellable_row = csv_data.find { |row| row['SKU'] == 'SELL001' }
        configurable_row = csv_data.find { |row| row['SKU'] == 'CONF001' }
        bundle_row = csv_data.find { |row| row['SKU'] == 'BUND001' }

        expect(sellable_row['Product Type']).to eq('Sellable')
        expect(configurable_row['Product Type']).to eq('Configurable')
        expect(bundle_row['Product Type']).to eq('Bundle')
      end
    end

    context 'with nil or empty values' do
      let!(:product_minimal) do
        create(:product,
               company: company,
               sku: 'MINIMAL',
               name: 'Minimal Product',
               product_type: :sellable,
               info: {})
      end

      let(:products) { Product.where(company: company) }

      it 'handles nil description gracefully' do
        csv_data = CSV.parse(csv_export, headers: true)

        minimal_row = csv_data.find { |row| row['SKU'] == 'MINIMAL' }
        expect(minimal_row['Description']).to eq('')
      end

      it 'handles missing labels gracefully' do
        csv_data = CSV.parse(csv_export, headers: true)

        minimal_row = csv_data.find { |row| row['SKU'] == 'MINIMAL' }
        expect(minimal_row['Labels']).to eq('')
      end
    end

    context 'with large dataset' do
      before do
        # Create 250 products to test batch processing
        250.times do |i|
          create(:product,
                 company: company,
                 sku: "BULK#{i.to_s.rjust(4, '0')}",
                 name: "Bulk Product #{i}",
                 product_type: :sellable)
        end
      end

      let(:products) { Product.where(company: company) }

      it 'exports all products using batch processing' do
        csv_data = CSV.parse(csv_export, headers: true)

        expect(csv_data.count).to eq(250)
      end

      it 'maintains correct order' do
        csv_data = CSV.parse(csv_export, headers: true)

        # Get SKUs in order
        skus = csv_data.map { |row| row['SKU'] }
        first_sku = skus.first
        last_sku = skus.last

        # Products should be ordered by ID (created order)
        expect(first_sku).to eq('BULK0000')
        expect(last_sku).to eq('BULK0249')
      end

      it 'generates valid CSV format' do
        # Should not raise any CSV parsing errors
        expect { CSV.parse(csv_export, headers: true) }.not_to raise_error
      end
    end

    context 'with filtered products' do
      let!(:active_product1) do
        create(:product,
               company: company,
               sku: 'ACTIVE1',
               product_status: :active)
      end

      let!(:active_product2) do
        create(:product,
               company: company,
               sku: 'ACTIVE2',
               product_status: :active)
      end

      let!(:draft_product) do
        create(:product,
               company: company,
               sku: 'DRAFT1',
               product_status: :draft)
      end

      let(:products) { Product.where(company: company, product_status: :active) }

      it 'exports only filtered products' do
        csv_data = CSV.parse(csv_export, headers: true)

        expect(csv_data.count).to eq(2)
        expect(csv_data.map { |row| row['SKU'] }).to include('ACTIVE1', 'ACTIVE2')
        expect(csv_data.map { |row| row['SKU'] }).not_to include('DRAFT1')
      end
    end

    context 'memory efficiency' do
      let(:products) { Product.where(company: company) }

      before do
        # Create products to test memory efficiency
        50.times do |i|
          create(:product, company: company, sku: "MEM#{i.to_s.rjust(3, '0')}")
        end
      end

      it 'uses find_each for batch processing' do
        # Create a mock relation that responds to includes, order, and find_each
        relation = products.includes(:labels, :inventories).order(:id)
        allow(products).to receive(:includes).and_return(relation)

        # Verify that find_each is called (it will be called on the relation)
        expect(relation).to receive(:find_each).and_call_original

        described_class.new(products).to_csv
      end

      it 'eager loads associations to prevent N+1 queries' do
        # Expect includes to be called with correct associations
        relation = products.includes(:labels, :inventories).order(:id)
        allow(products).to receive(:includes).and_return(relation)

        expect(products).to receive(:includes).with(:labels, :inventories)

        described_class.new(products).to_csv
      end
    end

    context 'CSV format validation' do
      let!(:product) do
        create(:product,
               company: company,
               sku: 'CSV001',
               name: 'Product with "quotes" and, commas',
               info: { 'description' => 'Description with "quotes"' })
      end

      let(:products) { Product.where(company: company) }

      it 'properly escapes special characters' do
        csv_data = CSV.parse(csv_export, headers: true)

        row = csv_data.first
        expect(row['Name']).to eq('Product with "quotes" and, commas')
      end

      it 'generates parseable CSV' do
        # Parse and regenerate to verify format
        parsed = CSV.parse(csv_export, headers: true)
        regenerated = CSV.generate(headers: true) do |csv|
          csv << parsed.headers
          parsed.each { |row| csv << row }
        end

        expect { CSV.parse(regenerated, headers: true) }.not_to raise_error
      end
    end
  end

  describe 'initialization' do
    it 'accepts an ActiveRecord relation' do
      products = Product.all
      service = described_class.new(products)

      expect(service).to be_a(described_class)
    end

    it 'accepts a filtered relation' do
      company = create(:company)
      products = Product.where(company: company, product_status: :active)
      service = described_class.new(products)

      expect(service).to be_a(described_class)
    end
  end
end
