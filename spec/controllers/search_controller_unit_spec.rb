# frozen_string_literal: true

require 'rails_helper'

# Unit tests for SearchController private methods
# These test the internal logic without making HTTP requests
RSpec.describe SearchController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Mock authentication for all tests
  before do
    allow(controller).to receive(:authenticated?).and_return(true)
    allow(controller).to receive(:current_user).and_return(user)  # Return user object, not hash
    allow(controller).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow(controller).to receive(:current_potlift_company).and_return(company)
  end

  describe 'private methods' do
    describe '#sanitize_query' do
      it 'escapes percent signs' do
        result = controller.send(:sanitize_query, '50%')
        expect(result).to eq('50\\%')
      end

      it 'escapes underscores' do
        result = controller.send(:sanitize_query, 'test_query')
        expect(result).to eq('test\\_query')
      end

      it 'escapes backslashes' do
        result = controller.send(:sanitize_query, 'path\\to\\file')
        expect(result).to eq('path\\\\to\\\\file')
      end

      it 'handles nil input' do
        result = controller.send(:sanitize_query, nil)
        expect(result).to eq('')
      end

      it 'handles empty string' do
        result = controller.send(:sanitize_query, '')
        expect(result).to eq('')
      end
    end

    describe '#results_found?' do
      it 'returns true when results exist' do
        results = { products: [ double ] }
        expect(controller.send(:results_found?, results)).to be true
      end

      it 'returns false when results are empty' do
        results = { products: [], storage: [] }
        expect(controller.send(:results_found?, results)).to be false
      end

      it 'returns false when results hash is blank' do
        expect(controller.send(:results_found?, {})).to be false
        expect(controller.send(:results_found?, nil)).to be false
      end

      it 'returns true when at least one scope has results' do
        results = { products: [], storage: [ double ], labels: [] }
        expect(controller.send(:results_found?, results)).to be true
      end
    end

    # Note: #store_recent_search tests are in spec/requests/search_spec.rb
    # Testing private methods that interact with cache is better done through
    # integration tests where the full request cycle is available.

    describe '#recent_searches_cache_key' do
      it 'generates correct cache key for user' do
        result = controller.send(:recent_searches_cache_key)
        expect(result).to eq("recent_searches:#{user.id}")
      end
    end

    describe '#format_products_json' do
      let!(:product) { create(:product, company: company, name: 'Test Product', sku: 'TEST-1', product_type: :sellable, product_status: :active) }

      it 'formats products with required fields' do
        products = [ product ]
        result = controller.send(:format_products_json, products)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          id: product.id,
          sku: 'TEST-1',
          name: 'Test Product',
          product_type: 'sellable',
          product_status: 'active'
        )
        expect(result.first).to have_key(:url)
      end

      it 'handles empty array' do
        result = controller.send(:format_products_json, [])
        expect(result).to eq([])
      end
    end

    describe '#format_storage_json' do
      let!(:storage) { create(:storage, company: company, name: 'Test Storage', code: 'STORE-1', storage_type: :regular) }

      it 'formats storages with required fields' do
        storages = [ storage ]
        result = controller.send(:format_storage_json, storages)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          id: storage.id,
          code: 'STORE-1',
          name: 'Test Storage',
          storage_type: 'regular'
        )
        expect(result.first).to have_key(:url)
      end
    end

    describe '#format_attributes_json' do
      let!(:attribute) { create(:product_attribute, company: company, name: 'Price', code: 'price', pa_type: :patype_text) }

      it 'formats attributes with required fields' do
        attributes = [ attribute ]
        result = controller.send(:format_attributes_json, attributes)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          id: attribute.id,
          code: 'price',
          name: 'Price',
          pa_type: 'patype_text'
        )
        expect(result.first).to have_key(:url)
      end
    end

    describe '#format_labels_json' do
      let!(:label) { create(:label, company: company, name: 'Electronics', code: 'electronics', label_type: 'category') }

      it 'formats labels with required fields' do
        labels = [ label ]
        result = controller.send(:format_labels_json, labels)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          id: label.id,
          code: 'electronics',
          name: 'Electronics',
          label_type: 'category'
        )
        expect(result.first).to have_key(:url)
        expect(result.first).to have_key(:full_name)
      end
    end

    describe '#format_catalogs_json' do
      let!(:catalog) { create(:catalog, company: company, name: 'Webshop', code: 'webshop', catalog_type: :webshop, currency_code: :eur) }

      it 'formats catalogs with required fields' do
        catalogs = [ catalog ]
        result = controller.send(:format_catalogs_json, catalogs)

        expect(result).to be_an(Array)
        expect(result.first).to include(
          id: catalog.id,
          code: 'webshop',
          name: 'Webshop',
          catalog_type: 'webshop',
          currency_code: 'eur'
        )
        expect(result.first).to have_key(:url)
      end
    end

    describe '#format_json_response' do
      let!(:product) { create(:product, company: company, name: 'Test', sku: 'TEST') }
      let!(:storage) { create(:storage, company: company, name: 'Test', code: 'TEST') }

      it 'formats all result scopes' do
        results = {
          products: [ product ],
          storage: [ storage ],
          attributes: [],
          labels: [],
          catalogs: []
        }

        formatted = controller.send(:format_json_response, results)

        expect(formatted).to have_key(:products)
        expect(formatted).to have_key(:storage)
        expect(formatted[:products]).to be_an(Array)
        expect(formatted[:storage]).to be_an(Array)
      end
    end
  end
end
