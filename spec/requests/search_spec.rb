# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search API', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Helper to set up authenticated session
  def sign_in_user(user, company)
    # Set session variables that ApplicationController expects
    # This mimics what SessionsController#callback does
    post '/test_session_setup', params: {
      session_data: {
        user_id: user.id,
        access_token: 'test_access_token',
        refresh_token: 'test_refresh_token',
        expires_at: 1.hour.from_now.to_i,
        authenticated_at: Time.now.to_i,
        company_id: company.id,
        company_code: company.code,
        company_name: company.name
      }
    }
  end

  # Bypass authentication for tests
  before do
    # Mock ApplicationController methods to avoid actual OAuth flow
    allow_any_instance_of(SearchController).to receive(:require_authentication).and_return(true)
    allow_any_instance_of(SearchController).to receive(:current_user).and_return(user)
    allow_any_instance_of(SearchController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(SearchController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(SearchController).to receive(:authenticated?).and_return(true)
  end

  describe 'GET /search' do
    context 'with no query parameter' do
      it 'returns empty results' do
        get search_path

        expect(response).to have_http_status(:success)
      end

      it 'responds successfully with HTML' do
        get search_path

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include('text/html')
      end

      it 'returns empty JSON results' do
        get search_path, params: {}, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to eq({})
      end
    end

    context 'with blank query' do
      it 'returns empty results' do
        get search_path, params: { q: '' }, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json).to eq({})
      end
    end

    context 'with query and scope=all' do
      let!(:product) { create(:product, company: company, name: 'Test Product', sku: 'TEST-123') }
      let!(:storage) { create(:storage, company: company, name: 'Test Storage', code: 'STORE-1') }
      let!(:label) { create(:label, company: company, name: 'Test Label', code: 'test-label') }
      let!(:product_attribute) { create(:product_attribute, company: company, name: 'Test Attribute', code: 'test-attr') }
      let!(:catalog) { create(:catalog, company: company, name: 'Test Catalog', code: 'test-cat') }

      it 'searches across all scopes' do
        get search_path, params: { q: 'Test', scope: 'all' }, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json.keys).to match_array(%w[products storage attributes labels catalogs])
      end

      it 'limits results to 5 per scope' do
        # Create 10 products
        10.times { |i| create(:product, company: company, name: "Test Product #{i}", sku: "TEST-#{i}") }

        get search_path, params: { q: 'Test', scope: 'all' }, as: :json

        json = JSON.parse(response.body)
        expect(json['products'].size).to be <= 5
      end

      it 'stores recent search in cache' do
        expect(Rails.cache).to receive(:write).with(
          "recent_searches:#{user.id}",
          ['Test'],
          expires_in: 30.days
        )

        get search_path, params: { q: 'Test', scope: 'all' }, as: :json
      end
    end

    context 'with query and scope=products' do
      let!(:product1) { create(:product, company: company, name: 'iPhone 15', sku: 'IP-15') }
      let!(:product2) { create(:product, company: company, name: 'Samsung Galaxy', sku: 'SG-23') }
      let!(:product3) { create(:product, company: company, name: 'Google Pixel', sku: 'GP-8') }

      it 'searches only products by name' do
        get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)

        product_ids = json['products'].map { |p| p['id'] }
        expect(product_ids).to include(product1.id)
        expect(product_ids).not_to include(product2.id, product3.id)
      end

      it 'searches products by SKU' do
        get search_path, params: { q: 'IP-15', scope: 'products' }, as: :json

        json = JSON.parse(response.body)
        product_ids = json['products'].map { |p| p['id'] }
        expect(product_ids).to include(product1.id)
      end

      it 'limits results to 50' do
        get search_path, params: { q: 'phone', scope: 'products' }, as: :json

        json = JSON.parse(response.body)
        expect(json['products'].size).to be <= 50
      end

      it 'returns JSON format' do
        get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json

        expect(response.content_type).to include('application/json')
        json = JSON.parse(response.body)
        expect(json).to have_key('products')
      end
    end

    context 'with query and scope=storage' do
      let!(:storage1) { create(:storage, company: company, name: 'Main Warehouse', code: 'WH-01') }
      let!(:storage2) { create(:storage, company: company, name: 'Backup Storage', code: 'WH-02') }

      it 'searches only storages' do
        get search_path, params: { q: 'Main', scope: 'storage' }, as: :json

        json = JSON.parse(response.body)
        storage_ids = json['storage'].map { |s| s['id'] }
        expect(storage_ids).to include(storage1.id)
        expect(storage_ids).not_to include(storage2.id)
      end

      it 'searches storages by code' do
        get search_path, params: { q: 'WH-01', scope: 'storage' }, as: :json

        json = JSON.parse(response.body)
        storage_ids = json['storage'].map { |s| s['id'] }
        expect(storage_ids).to include(storage1.id)
      end
    end

    context 'with query and scope=attributes' do
      let!(:attr1) { create(:product_attribute, company: company, name: 'Price', code: 'price') }
      let!(:attr2) { create(:product_attribute, company: company, name: 'Weight', code: 'weight') }

      it 'searches only product attributes' do
        get search_path, params: { q: 'Price', scope: 'attributes' }, as: :json

        json = JSON.parse(response.body)
        attribute_ids = json['attributes'].map { |a| a['id'] }
        expect(attribute_ids).to include(attr1.id)
        expect(attribute_ids).not_to include(attr2.id)
      end
    end

    context 'with query and scope=labels' do
      let!(:label1) { create(:label, company: company, name: 'Electronics', code: 'electronics') }
      let!(:label2) { create(:label, company: company, name: 'Clothing', code: 'clothing') }

      it 'searches only labels' do
        get search_path, params: { q: 'Electronics', scope: 'labels' }, as: :json

        json = JSON.parse(response.body)
        label_ids = json['labels'].map { |l| l['id'] }
        expect(label_ids).to include(label1.id)
        expect(label_ids).not_to include(label2.id)
      end
    end

    context 'with query and scope=catalogs' do
      let!(:catalog1) { create(:catalog, company: company, name: 'Webshop EU', code: 'web-eu') }
      let!(:catalog2) { create(:catalog, company: company, name: 'Supply Chain', code: 'supply') }

      it 'searches only catalogs' do
        get search_path, params: { q: 'Webshop', scope: 'catalogs' }, as: :json

        json = JSON.parse(response.body)
        catalog_ids = json['catalogs'].map { |c| c['id'] }
        expect(catalog_ids).to include(catalog1.id)
        expect(catalog_ids).not_to include(catalog2.id)
      end
    end

    context 'with SQL injection attempt' do
      let!(:product) { create(:product, company: company, name: 'Test Product', sku: 'TEST-1') }

      it 'sanitizes query to prevent SQL injection' do
        expect {
          get search_path, params: { q: "'; DROP TABLE products; --", scope: 'products' }, as: :json
        }.not_to raise_error

        expect(response).to have_http_status(:success)
      end

      it 'escapes ILIKE special characters' do
        product_with_percent = create(:product, company: company, name: '50% Off', sku: 'SALE-50')

        get search_path, params: { q: '50%', scope: 'products' }, as: :json

        json = JSON.parse(response.body)
        product_ids = json['products'].map { |p| p['id'] }
        expect(product_ids).to include(product_with_percent.id)
      end
    end

    context 'multi-tenancy' do
      let(:other_company) { create(:company) }
      let!(:own_product) { create(:product, company: company, name: 'Our Product', sku: 'OUR-1') }
      let!(:other_product) { create(:product, company: other_company, name: 'Their Product', sku: 'THEIR-1') }

      it 'only searches within current company' do
        get search_path, params: { q: 'Product', scope: 'products' }, as: :json

        json = JSON.parse(response.body)
        product_ids = json['products'].map { |p| p['id'] }
        expect(product_ids).to include(own_product.id)
        expect(product_ids).not_to include(other_product.id)
      end
    end
  end

  describe 'GET /search/recent' do
    before do
      # Clear cache before each test
      Rails.cache.clear
    end

    it 'returns empty array when no recent searches' do
      get search_recent_path, as: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to eq([])
    end

    it 'returns recent searches from cache' do
      # Write directly to cache using the user ID
      cache_key = "recent_searches:#{user.id}"
      Rails.cache.write(cache_key, ['iPhone', 'Samsung', 'Google'], expires_in: 30.days)

      get search_recent_path, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to eq(['iPhone', 'Samsung', 'Google'])
    end

    it 'returns searches in correct order (most recent first)' do
      cache_key = "recent_searches:#{user.id}"
      Rails.cache.write(cache_key, ['Latest', 'Middle', 'Oldest'], expires_in: 30.days)

      get search_recent_path, as: :json

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json.first).to eq('Latest')
      expect(json.last).to eq('Oldest')
    end
  end

  describe 'Recent search behavior' do
    let!(:product1) { create(:product, company: company, name: 'iPhone 15', sku: 'IP-15') }
    let!(:product2) { create(:product, company: company, name: 'Samsung Galaxy', sku: 'SG-23') }

    before do
      Rails.cache.clear
    end

    it 'stores search in cache after successful query' do
      get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json

      cache_key = "recent_searches:#{user.id}"
      recent = Rails.cache.read(cache_key)
      expect(recent).to include('iPhone')
    end

    it 'limits to 10 recent searches' do
      # Perform 15 searches
      15.times do |i|
        product = create(:product, company: company, name: "Product #{i}", sku: "PROD-#{i}")
        get search_path, params: { q: "Product #{i}", scope: 'products' }, as: :json
      end

      cache_key = "recent_searches:#{user.id}"
      recent = Rails.cache.read(cache_key)
      expect(recent.size).to eq(10)
    end

    it 'removes duplicates from recent searches' do
      get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json
      get search_path, params: { q: 'Samsung', scope: 'products' }, as: :json
      get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json

      cache_key = "recent_searches:#{user.id}"
      recent = Rails.cache.read(cache_key)
      expect(recent.count('iPhone')).to eq(1)
    end

    it 'puts most recent search first' do
      get search_path, params: { q: 'iPhone', scope: 'products' }, as: :json
      get search_path, params: { q: 'Samsung', scope: 'products' }, as: :json

      cache_key = "recent_searches:#{user.id}"
      recent = Rails.cache.read(cache_key)
      expect(recent.first).to eq('Samsung')
    end

    it 'does not store searches with no results' do
      get search_path, params: { q: 'NonexistentProduct12345', scope: 'products' }, as: :json

      cache_key = "recent_searches:#{user.id}"
      recent = Rails.cache.read(cache_key)
      expect(recent).to be_nil.or be_empty
    end
  end

  describe 'JSON response format' do
    let!(:product) { create(:product, company: company, name: 'Test Product', sku: 'TEST-1', product_type: :sellable) }
    let!(:storage) { create(:storage, company: company, name: 'Test Storage', code: 'STORE-1', storage_type: :regular) }
    let!(:label) { create(:label, company: company, name: 'Test Label', code: 'test-label', label_type: 'category') }

    it 'formats products correctly' do
      get search_path, params: { q: 'Test', scope: 'products' }, as: :json

      json = JSON.parse(response.body)
      product_data = json['products'].first

      expect(product_data).to include(
        'id' => product.id,
        'sku' => 'TEST-1',
        'name' => 'Test Product',
        'product_type' => 'sellable'
      )
      expect(product_data).to have_key('url')
    end

    it 'formats storages correctly' do
      get search_path, params: { q: 'Test', scope: 'storage' }, as: :json

      json = JSON.parse(response.body)
      storage_data = json['storage'].first

      expect(storage_data).to include(
        'id' => storage.id,
        'code' => 'STORE-1',
        'name' => 'Test Storage',
        'storage_type' => 'regular'
      )
      expect(storage_data).to have_key('url')
    end

    it 'formats labels correctly' do
      get search_path, params: { q: 'Test', scope: 'labels' }, as: :json

      json = JSON.parse(response.body)
      label_data = json['labels'].first

      expect(label_data).to include(
        'id' => label.id,
        'code' => 'test-label',
        'name' => 'Test Label',
        'label_type' => 'category'
      )
      expect(label_data).to have_key('url')
    end
  end
end
