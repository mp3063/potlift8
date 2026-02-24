require 'rails_helper'

RSpec.describe ProductImportService do
  let(:company) { create(:company) }
  let(:user) { create(:user) }
  let(:service) { described_class.new(company, csv_content, user) }

  describe '#import!' do
    context 'with valid CSV data' do
      let(:csv_content) do
        <<~CSV
          sku,name,description,active,labels
          ABC123,Widget,A great widget,true,"electronics,featured"
          DEF456,Gadget,An amazing gadget,yes,electronics
          GHI789,Tool,A useful tool,1,tools
        CSV
      end

      it 'imports all products successfully' do
        expect { service.import! }.to change { company.products.count }.by(3)
      end

      it 'returns correct counts' do
        result = service.import!

        expect(result[:imported_count]).to eq(3)
        expect(result[:updated_count]).to eq(0)
        expect(result[:errors]).to be_empty
      end

      it 'creates products with correct attributes' do
        service.import!

        product = company.products.find_by(sku: 'ABC123')
        expect(product.name).to eq('Widget')
        expect(product.description).to eq('A great widget')
        expect(product.active).to be true
      end

      it 'parses boolean active field correctly' do
        service.import!

        abc = company.products.find_by(sku: 'ABC123')
        def_product = company.products.find_by(sku: 'DEF456')
        ghi = company.products.find_by(sku: 'GHI789')

        expect(abc.active).to be true
        expect(def_product.active).to be true
        expect(ghi.active).to be true
      end

      it 'creates labels and associates them with products' do
        service.import!

        product = company.products.find_by(sku: 'ABC123')
        expect(product.labels.pluck(:name)).to contain_exactly('electronics', 'featured')
      end

      it 'reuses existing labels' do
        create(:label, company: company, name: 'electronics')

        expect { service.import! }.to change { company.labels.count }.by(2) # only 'featured' and 'tools'
      end
    end

    context 'with existing products (updates)' do
      let!(:existing_product) { create(:product, company: company, sku: 'ABC123', name: 'Old Name') }

      let(:csv_content) do
        <<~CSV
          sku,name,description,active
          ABC123,Updated Widget,Updated description,true
          DEF456,New Product,New description,true
        CSV
      end

      it 'updates existing product' do
        expect { service.import! }.to change { company.products.count }.by(1)

        existing_product.reload
        expect(existing_product.name).to eq('Updated Widget')
        expect(existing_product.description).to eq('Updated description')
      end

      it 'returns correct counts' do
        result = service.import!

        expect(result[:imported_count]).to eq(1)
        expect(result[:updated_count]).to eq(1)
        expect(result[:errors]).to be_empty
      end
    end

    context 'with product attributes' do
      let!(:price_attr) { create(:product_attribute, company: company, code: 'price') }
      let!(:color_attr) { create(:product_attribute, company: company, code: 'color') }
      let!(:weight_attr) { create(:product_attribute, company: company, code: 'weight') }

      let(:csv_content) do
        <<~CSV
          sku,name,attr_price,attr_color,attr_weight
          ABC123,Widget,1999,blue,500
          DEF456,Gadget,2499,red,750
        CSV
      end

      it 'imports products with attributes' do
        service.import!

        product = company.products.find_by(sku: 'ABC123')
        expect(product.read_attribute_value('price')).to eq('1999')
        expect(product.read_attribute_value('color')).to eq('blue')
        expect(product.read_attribute_value('weight')).to eq('500')
      end

      it 'updates existing attribute values' do
        product = create(:product, company: company, sku: 'ABC123')
        product.write_attribute_value('price', '999')

        service.import!

        product.reload
        expect(product.read_attribute_value('price')).to eq('1999')
      end

      it 'ignores attributes that do not exist' do
        csv_with_invalid_attr = <<~CSV
          sku,name,attr_nonexistent
          ABC123,Widget,some_value
        CSV

        service_with_invalid = described_class.new(company, csv_with_invalid_attr, user)
        result = service_with_invalid.import!

        product = company.products.find_by(sku: 'ABC123')
        expect(product).to be_present
        expect(result[:imported_count]).to eq(1)
      end
    end

    context 'with batch processing' do
      let(:csv_content) do
        rows = (1..250).map do |i|
          "SKU#{i},Product #{i},Description #{i},true"
        end

        "sku,name,description,active\n" + rows.join("\n")
      end

      it 'processes products in batches' do
        expect { service.import! }.to change { company.products.count }.by(250)
      end

      it 'processes batches of BATCH_SIZE' do
        expect(service).to receive(:process_batch).at_least(3).times.and_call_original
        service.import!
      end

      it 'returns correct total count' do
        result = service.import!
        expect(result[:imported_count]).to eq(250)
      end
    end

    context 'with invalid data' do
      let(:csv_content) do
        <<~CSV
          sku,name,description,active
          ABC123,Widget,Description,true
          ,Missing SKU,Description,true
          DEF456,Missing Name,,true
          GHI789,Valid Product,Description,true
        CSV
      end

      it 'collects errors for invalid rows' do
        result = service.import!

        expect(result[:errors]).not_to be_empty
        expect(result[:errors].length).to be >= 1
      end

      it 'continues importing valid products' do
        result = service.import!

        expect(result[:imported_count]).to be >= 2 # ABC123 and GHI789 should succeed
        expect(company.products.find_by(sku: 'ABC123')).to be_present
        expect(company.products.find_by(sku: 'GHI789')).to be_present
      end

      it 'includes row number in error messages' do
        result = service.import!

        error = result[:errors].first
        expect(error[:row]).to be_present
        expect(error[:error]).to be_present
      end
    end

    context 'with empty CSV' do
      let(:csv_content) do
        <<~CSV
          sku,name,description,active
        CSV
      end

      it 'imports nothing' do
        expect { service.import! }.not_to change { company.products.count }
      end

      it 'returns zero counts' do
        result = service.import!

        expect(result[:imported_count]).to eq(0)
        expect(result[:updated_count]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context 'with malformed CSV' do
      let(:csv_content) { 'not,valid,csv,data,{@#$%' }

      it 'handles parsing errors' do
        expect { service.import! }.not_to raise_error
      end
    end

    context 'with missing SKU' do
      let(:csv_content) do
        <<~CSV
          sku,name,description,active
          ,Product Without SKU,Description,true
        CSV
      end

      it 'rejects product with missing SKU' do
        result = service.import!

        expect(result[:imported_count]).to eq(0)
        expect(result[:errors].length).to eq(1)
        expect(result[:errors].first[:error]).to eq('SKU is required')
      end
    end

    context 'with boolean parsing' do
      let(:csv_content) do
        <<~CSV
          sku,name,active
          SKU1,Product 1,true
          SKU2,Product 2,TRUE
          SKU3,Product 3,yes
          SKU4,Product 4,YES
          SKU5,Product 5,1
          SKU6,Product 6,false
          SKU7,Product 7,FALSE
          SKU8,Product 8,no
          SKU9,Product 9,NO
          SKU10,Product 10,0
          SKU11,Product 11,
        CSV
      end

      it 'parses various truthy values correctly' do
        service.import!

        %w[SKU1 SKU2 SKU3 SKU4 SKU5].each do |sku|
          product = company.products.find_by(sku: sku)
          expect(product.active).to be(true), "Expected #{sku} to be active"
        end
      end

      it 'parses various falsy values correctly' do
        service.import!

        %w[SKU6 SKU7 SKU8 SKU9 SKU10].each do |sku|
          product = company.products.find_by(sku: sku)
          expect(product.active).to be(false), "Expected #{sku} to be inactive"
        end
      end

      it 'parses blank as inactive (draft status)' do
        service.import!

        product = company.products.find_by(sku: 'SKU11')
        # When active is blank/nil, the product status is set to draft (inactive)
        expect(product.active).to be false
        expect(product.product_status_draft?).to be true
      end
    end


    context 'error handling' do
      let(:csv_content) do
        <<~CSV
          sku,name,description,active
          ABC123,Valid Product,Description,true
          ,Product With No SKU,Description,true
          DEF456,Another Valid,Description,true
        CSV
      end

      it 'continues processing after errors' do
        result = service.import!

        # Should import 2 valid products and have 1 error for the missing SKU
        expect(result[:imported_count]).to eq(2)
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first[:error]).to eq('SKU is required')
      end
    end

    context 'with on_progress callback' do
      let(:csv_content) do
        # 100 rows = 1 batch = 1 callback
        rows = (1..100).map { |i| "SKU#{i},Product #{i},Description #{i},true" }
        "sku,name,description,active\n" + rows.join("\n")
      end

      it 'calls the callback after each batch with processed and total counts' do
        progress_calls = []
        service = described_class.new(company, csv_content, user, on_progress: ->(processed, total) {
          progress_calls << [processed, total]
        })
        service.import!

        expect(progress_calls).to eq([[100, 100]])
      end

      it 'calls the callback multiple times for multiple batches' do
        # 250 rows = 3 batches (100, 100, 50)
        rows = (1..250).map { |i| "SKU#{i},Product #{i},Description #{i},true" }
        large_csv = "sku,name,description,active\n" + rows.join("\n")

        progress_calls = []
        service = described_class.new(company, large_csv, user, on_progress: ->(processed, total) {
          progress_calls << [processed, total]
        })
        service.import!

        expect(progress_calls).to eq([[100, 250], [200, 250], [250, 250]])
      end

      it 'works without a callback (default nil)' do
        service = described_class.new(company, csv_content, user)
        expect { service.import! }.not_to raise_error
      end
    end

    context 'with unrecognized boolean values' do
      let(:csv_content) do
        <<~CSV
          sku,name,active
          SKU1,Product 1,Y
          SKU2,Product 2,TRUE
          SKU3,Product 3,maybe
          SKU4,Product 4,true
        CSV
      end

      it 'reports errors for unrecognized active values' do
        result = service.import!

        error_rows = result[:errors].map { |e| e[:row] }
        expect(error_rows).to include(2) # "Y" is unrecognized
        expect(error_rows).to include(4) # "maybe" is unrecognized
      end

      it 'does not report errors for recognized active values' do
        result = service.import!

        error_messages = result[:errors].map { |e| e[:error] }
        # "TRUE" (no space) matches /^(true|yes|1)$/i — so no error
        expect(error_messages).not_to include(match(/TRUE/))
        # "true" is recognized
        expect(error_messages).not_to include(match(/'true'/))
      end

      it 'still creates the product even with unrecognized active value' do
        service.import!

        expect(company.products.find_by(sku: 'SKU1')).to be_present
        expect(company.products.find_by(sku: 'SKU3')).to be_present
      end

      it 'includes helpful message in error' do
        result = service.import!

        error = result[:errors].find { |e| e[:row] == 2 }
        expect(error[:error]).to include("Unrecognized active value")
        expect(error[:error]).to include("true/false/yes/no/1/0")
      end
    end
  end

  describe 'private methods' do
    let(:csv_content) do
      <<~CSV
        sku,name
        ABC123,Product
      CSV
    end

    describe '#parse_boolean' do
      it 'returns true for truthy strings' do
        expect(service.send(:parse_boolean, 'true')).to be true
        expect(service.send(:parse_boolean, 'TRUE')).to be true
        expect(service.send(:parse_boolean, 'yes')).to be true
        expect(service.send(:parse_boolean, 'YES')).to be true
        expect(service.send(:parse_boolean, '1')).to be true
      end

      it 'returns false for falsy strings' do
        expect(service.send(:parse_boolean, 'false')).to be false
        expect(service.send(:parse_boolean, 'FALSE')).to be false
        expect(service.send(:parse_boolean, 'no')).to be false
        expect(service.send(:parse_boolean, 'NO')).to be false
        expect(service.send(:parse_boolean, '0')).to be false
      end

      it 'returns nil for other values' do
        expect(service.send(:parse_boolean, '')).to be_nil
        expect(service.send(:parse_boolean, 'maybe')).to be_nil
        expect(service.send(:parse_boolean, nil)).to be_nil
      end
    end
  end
end
