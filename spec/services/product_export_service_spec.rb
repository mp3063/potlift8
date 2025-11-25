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
        # Expect includes to be called with correct associations including product attributes
        relation = products.includes(:labels, :inventories, product_attribute_values: :product_attribute).order(:id)
        allow(products).to receive(:includes).and_return(relation)

        expect(products).to receive(:includes).with(:labels, :inventories, product_attribute_values: :product_attribute)

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

  describe 'EAV attribute export' do
    let!(:price_attr) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
    let!(:color_attr) { create(:product_attribute, company: company, code: 'color', name: 'Color') }
    let!(:weight_attr) { create(:product_attribute, company: company, code: 'weight', name: 'Weight') }

    let!(:product1) do
      product = create(:product, company: company, sku: 'ATTR001', name: 'Product with Attrs')
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
      create(:product_attribute_value, product: product, product_attribute: color_attr, value: 'blue')
      product
    end

    let!(:product2) do
      product = create(:product, company: company, sku: 'ATTR002', name: 'Another Product')
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '2499')
      create(:product_attribute_value, product: product, product_attribute: weight_attr, value: '500g')
      product
    end

    let!(:product3) do
      create(:product, company: company, sku: 'ATTR003', name: 'Product without Attrs')
    end

    let(:products) { Product.where(company: company) }
    subject(:csv_export) { described_class.new(products).to_csv }

    it 'includes attribute columns in headers with attr_ prefix' do
      csv_data = CSV.parse(csv_export, headers: true)

      # Should have base headers + sorted attribute codes
      expect(csv_data.headers).to include('attr_color', 'attr_price', 'attr_weight')
    end

    it 'exports attribute values for products' do
      csv_data = CSV.parse(csv_export, headers: true)

      product1_row = csv_data.find { |row| row['SKU'] == 'ATTR001' }
      expect(product1_row['attr_price']).to eq('1999')
      expect(product1_row['attr_color']).to eq('blue')
      expect(product1_row['attr_weight']).to eq('') # Not set for this product
    end

    it 'handles products with different attribute combinations' do
      csv_data = CSV.parse(csv_export, headers: true)

      product2_row = csv_data.find { |row| row['SKU'] == 'ATTR002' }
      expect(product2_row['attr_price']).to eq('2499')
      expect(product2_row['attr_weight']).to eq('500g')
      expect(product2_row['attr_color']).to eq('') # Not set for this product
    end

    it 'handles products without any attributes' do
      csv_data = CSV.parse(csv_export, headers: true)

      product3_row = csv_data.find { |row| row['SKU'] == 'ATTR003' }
      expect(product3_row['attr_price']).to eq('')
      expect(product3_row['attr_color']).to eq('')
      expect(product3_row['attr_weight']).to eq('')
    end

    it 'includes all unique attributes across all products' do
      csv_data = CSV.parse(csv_export, headers: true)

      # All three attributes should be present even though no single product has all three
      expect(csv_data.headers).to include('attr_price', 'attr_color', 'attr_weight')
    end

    it 'sorts attribute columns alphabetically by code' do
      csv_data = CSV.parse(csv_export, headers: true)

      # Find positions of attribute columns
      attr_headers = csv_data.headers.select { |h| h.start_with?('attr_') }

      # Should be sorted: color, price, weight
      expect(attr_headers).to eq(['attr_color', 'attr_price', 'attr_weight'])
    end

    context 'with special characters in attribute values' do
      let!(:special_product) do
        product = create(:product, company: company, sku: 'SPECIAL', name: 'Special Product')
        create(:product_attribute_value, product: product, product_attribute: color_attr, value: 'Red, "Crimson"')
        product
      end

      it 'properly escapes attribute values with special characters' do
        csv_data = CSV.parse(csv_export, headers: true)

        special_row = csv_data.find { |row| row['SKU'] == 'SPECIAL' }
        expect(special_row['attr_color']).to eq('Red, "Crimson"')
      end
    end

    context 'with no attributes in system' do
      let(:company_no_attrs) { create(:company) }
      let!(:simple_product) { create(:product, company: company_no_attrs, sku: 'SIMPLE') }
      let(:products_no_attrs) { Product.where(company: company_no_attrs) }

      it 'exports only base columns when no attributes exist' do
        csv_data = CSV.parse(described_class.new(products_no_attrs).to_csv, headers: true)

        # Should only have base headers, no attr_ columns
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
      end
    end

    context 'with large number of attributes' do
      before do
        # Create 20 attributes
        20.times do |i|
          attr = create(:product_attribute, company: company, code: "attr#{i.to_s.rjust(2, '0')}", name: "Attribute #{i}")
          # Assign every other attribute to product1
          create(:product_attribute_value, product: product1, product_attribute: attr, value: "value#{i}") if i.even?
        end
      end

      it 'includes all attribute columns' do
        csv_data = CSV.parse(csv_export, headers: true)

        # Check that attribute columns are present
        # The service only includes attributes that have values on at least one product
        # product1 has 3 original + 10 new (even numbers: 0,2,4,6,8,10,12,14,16,18) = 13 total
        attr_columns = csv_data.headers.select { |h| h.start_with?('attr_') }
        expect(attr_columns.count).to eq(13)
      end

      it 'exports correct values for all attributes' do
        csv_data = CSV.parse(csv_export, headers: true)

        product1_row = csv_data.find { |row| row['SKU'] == 'ATTR001' }

        # Even numbered attributes should have values
        expect(product1_row['attr_attr00']).to eq('value0')
        expect(product1_row['attr_attr02']).to eq('value2')

        # Odd numbered attributes should be empty (CSV returns nil for empty cells, not empty string)
        expect(product1_row['attr_attr01']).to be_nil.or eq('')
        expect(product1_row['attr_attr03']).to be_nil.or eq('')
      end
    end
  end

  describe '#to_json' do
    let!(:product) do
      create(:product,
             company: company,
             sku: 'JSON001',
             name: 'JSON Product',
             product_type: :sellable,
             product_status: :active)
    end

    let!(:label) { create(:label, company: company, name: 'Featured') }
    let!(:price_attr) { create(:product_attribute, company: company, code: 'price', name: 'Price') }

    before do
      create(:product_label, product: product, label: label)
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
    end

    let(:products) { Product.where(company: company) }
    subject(:json_export) { described_class.new(products).to_json }

    it 'returns valid JSON' do
      expect { JSON.parse(json_export) }.not_to raise_error
    end

    it 'includes exported_at timestamp' do
      data = JSON.parse(json_export)
      expect(data['exported_at']).to be_present
      expect(data['exported_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'includes product count' do
      data = JSON.parse(json_export)
      expect(data['count']).to eq(1)
    end

    it 'includes products array' do
      data = JSON.parse(json_export)
      expect(data['products']).to be_an(Array)
      expect(data['products'].length).to eq(1)
    end

    it 'includes product attributes in correct format' do
      data = JSON.parse(json_export)
      product_data = data['products'].first

      expect(product_data['sku']).to eq('JSON001')
      expect(product_data['name']).to eq('JSON Product')
      expect(product_data['product_type']).to eq('sellable')
      expect(product_data['product_status']).to eq('active')
      expect(product_data['active']).to eq(true)
    end

    it 'includes labels as array of names' do
      data = JSON.parse(json_export)
      product_data = data['products'].first

      expect(product_data['labels']).to eq(['Featured'])
    end

    it 'includes attributes as hash' do
      data = JSON.parse(json_export)
      product_data = data['products'].first

      expect(product_data['attributes']).to eq({ 'price' => '1999' })
    end

    it 'includes total_inventory' do
      data = JSON.parse(json_export)
      product_data = data['products'].first

      expect(product_data['total_inventory']).to eq(0)
    end

    it 'includes ISO8601 timestamps' do
      data = JSON.parse(json_export)
      product_data = data['products'].first

      expect(product_data['created_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
      expect(product_data['updated_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/)
    end

    it 'formats JSON with pretty printing' do
      expect(json_export).to include("\n")
      expect(json_export).to include("  ")
    end
  end
end
