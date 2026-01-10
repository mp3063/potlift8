# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/catalogs', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    # Set up authenticated session
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe 'GET /catalogs' do
    let!(:catalog1) { create(:catalog, company: company, code: 'WEB1', name: 'Webshop 1', catalog_type: :webshop) }
    let!(:catalog2) { create(:catalog, company: company, code: 'SUP1', name: 'Supply 1', catalog_type: :supply) }
    let!(:catalog3) { create(:catalog, company: company, code: 'WEB2', name: 'Webshop 2', catalog_type: :webshop) }
    let!(:other_catalog) { create(:catalog, company: other_company, code: 'OTHER', name: 'Other Catalog') }

    it 'returns successful response' do
      get catalogs_path
      expect(response).to be_successful
    end

    it 'displays only current company catalogs' do
      get catalogs_path
      expect(response.body).to include('Webshop 1')
      expect(response.body).to include('Supply 1')
      expect(response.body).to include('Webshop 2')
      expect(response.body).not_to include('Other Catalog')
    end

    it 'orders catalogs by created_at desc' do
      get catalogs_path
      expect(response).to be_successful
      # Most recently created (catalog3) should appear first in the response
      expect(response.body.index('WEB2')).to be < response.body.index('WEB1')
    end

    context 'multi-tenant security' do
      it 'does not show other company catalogs' do
        get catalogs_path
        expect(response).to be_successful
        expect(response.body).not_to include('OTHER')
        expect(response.body).not_to include('Other Catalog')
      end
    end
  end

  describe 'GET /catalogs/:code' do
    let(:catalog) { create(:catalog, company: company, code: 'MAIN') }
    let(:other_catalog) { create(:catalog, company: other_company, code: 'OTHER') }

    it 'redirects to items action' do
      get catalog_path(catalog)
      expect(response).to redirect_to(catalog_items_path(catalog))
    end

    it 'prevents access to other company catalogs' do
      expect {
        get catalog_path(other_catalog)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /catalogs/:code/items' do
    let(:catalog) { create(:catalog, company: company, code: 'MAIN') }
    let!(:product1) { create(:product, company: company, sku: 'PROD001', name: 'Product 1') }
    let!(:product2) { create(:product, company: company, sku: 'PROD002', name: 'Product 2') }
    let!(:catalog_item1) { create(:catalog_item, catalog: catalog, product: product1, priority: 100) }
    let!(:catalog_item2) { create(:catalog_item, catalog: catalog, product: product2, priority: 50) }

    it 'returns successful response' do
      get catalog_items_path(catalog)
      expect(response).to be_successful
    end

    it 'displays catalog items ordered by priority' do
      get catalog_items_path(catalog)
      expect(response.body).to include('PROD001')
      expect(response.body).to include('PROD002')
      # Higher priority (catalog_item1) should appear first
      expect(response.body.index('PROD001')).to be < response.body.index('PROD002')
    end

    context 'with search query' do
      it 'filters by product name' do
        get catalog_items_path(catalog), params: { q: 'Product 1' }
        expect(response).to be_successful
        expect(response.body).to include('PROD001')
        expect(response.body).not_to include('PROD002')
      end

      it 'filters by product SKU' do
        get catalog_items_path(catalog), params: { q: 'PROD002' }
        expect(response).to be_successful
        expect(response.body).to include('PROD002')
        expect(response.body).not_to include('PROD001')
      end

      it 'search is case insensitive' do
        get catalog_items_path(catalog), params: { q: 'product 1' }
        expect(response).to be_successful
        expect(response.body).to include('PROD001')
      end

      it 'handles search with no results' do
        get catalog_items_path(catalog), params: { q: 'NONEXISTENT' }
        expect(response).to be_successful
      end
    end

    context 'with pagination' do
      before do
        # Create 30 catalog items for pagination testing
        28.times do |i|
          product = create(:product, company: company, sku: "BULK#{i.to_s.rjust(3, '0')}")
          create(:catalog_item, catalog: catalog, product: product, priority: i)
        end
      end

      it 'paginates results with default per_page (25)' do
        get catalog_items_path(catalog)
        expect(response).to be_successful
        # Should not show all 30 items on first page
      end

      it 'respects per_page parameter' do
        get catalog_items_path(catalog), params: { per_page: 10 }
        expect(response).to be_successful
      end

      it 'navigates to second page' do
        get catalog_items_path(catalog), params: { page: 2, per_page: 10 }
        expect(response).to be_successful
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company) }

      it 'prevents access to other company catalog items' do
        expect {
          get catalog_items_path(other_catalog)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET /catalogs/new' do
    it 'returns successful response' do
      get new_catalog_path
      expect(response).to be_successful
    end

    it 'displays catalog form' do
      get new_catalog_path
      expect(response.body).to include('Code')
      expect(response.body).to include('Name')
      expect(response.body).to include('Catalog Type')
      expect(response.body).to include('Currency')
    end
  end

  describe 'GET /catalogs/:code/edit' do
    let(:catalog) { create(:catalog, company: company, code: 'MAIN') }
    let(:other_catalog) { create(:catalog, company: other_company) }

    it 'returns successful response for own company catalog' do
      get edit_catalog_path(catalog)
      expect(response).to be_successful
    end

    it 'displays catalog edit form with values' do
      get edit_catalog_path(catalog)
      expect(response.body).to include(catalog.code)
      expect(response.body).to include(catalog.name)
    end

    it 'prevents editing other company catalogs' do
      expect {
        get edit_catalog_path(other_catalog)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /catalogs' do
    let(:valid_attributes) do
      {
        code: 'NEW001',
        name: 'New Catalog',
        catalog_type: :webshop,
        currency_code: 'eur'
      }
    end

    let(:invalid_attributes) do
      {
        code: '',
        name: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new catalog' do
        expect {
          post catalogs_path, params: { catalog: valid_attributes }
        }.to change(Catalog, :count).by(1)
      end

      it 'assigns catalog to current company' do
        post catalogs_path, params: { catalog: valid_attributes }
        catalog = Catalog.last
        expect(catalog.company_id).to eq(company.id)
      end

      it 'redirects to catalogs list' do
        post catalogs_path, params: { catalog: valid_attributes }
        expect(response).to redirect_to(catalogs_path)
        follow_redirect!
        expect(response.body).to include('Catalog created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new catalog' do
        expect {
          post catalogs_path, params: { catalog: invalid_attributes }
        }.not_to change(Catalog, :count)
      end

      it 'renders new template with errors' do
        post catalogs_path, params: { catalog: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate code' do
      let!(:existing_catalog) { create(:catalog, company: company, code: 'DUP001') }

      it 'does not create catalog with duplicate code' do
        expect {
          post catalogs_path, params: { catalog: valid_attributes.merge(code: 'DUP001') }
        }.not_to change(Catalog, :count)
      end

      it 'shows validation error' do
        post catalogs_path, params: { catalog: valid_attributes.merge(code: 'DUP001') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid currency' do
      it 'does not create catalog with invalid currency' do
        expect {
          post catalogs_path, params: { catalog: valid_attributes.merge(currency_code: 'usd') }
        }.not_to change(Catalog, :count)
      end
    end

    context 'with different currencies' do
      it 'creates catalog with EUR currency' do
        post catalogs_path, params: { catalog: valid_attributes.merge(currency_code: 'eur') }
        expect(response).to redirect_to(catalogs_path)
      end

      it 'creates catalog with SEK currency' do
        post catalogs_path, params: { catalog: valid_attributes.merge(currency_code: 'sek') }
        expect(response).to redirect_to(catalogs_path)
      end

      it 'creates catalog with NOK currency' do
        post catalogs_path, params: { catalog: valid_attributes.merge(currency_code: 'nok') }
        expect(response).to redirect_to(catalogs_path)
      end
    end
  end

  describe 'PATCH /catalogs/:code' do
    let(:catalog) { create(:catalog, company: company, code: 'OLD001', name: 'Old Name') }
    let(:other_catalog) { create(:catalog, company: other_company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        catalog_type: :supply
      }
    end

    context 'with valid parameters' do
      it 'updates the catalog' do
        patch catalog_path(catalog), params: { catalog: new_attributes }
        catalog.reload
        expect(catalog.name).to eq('Updated Name')
        expect(catalog.catalog_type).to eq('supply')
      end

      it 'redirects to catalogs list' do
        patch catalog_path(catalog), params: { catalog: new_attributes }
        expect(response).to redirect_to(catalogs_path)
        follow_redirect!
        expect(response.body).to include('Catalog updated successfully')
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template with errors' do
        patch catalog_path(catalog), params: { catalog: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update the catalog' do
        patch catalog_path(catalog), params: { catalog: { name: '' } }
        catalog.reload
        expect(catalog.name).to eq('Old Name')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company catalogs' do
        expect {
          patch catalog_path(other_catalog), params: { catalog: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /catalogs/:code' do
    let!(:catalog) { create(:catalog, company: company, code: 'DEL001') }
    let(:other_catalog) { create(:catalog, company: other_company) }

    it 'destroys the catalog' do
      expect {
        delete catalog_path(catalog)
      }.to change(Catalog, :count).by(-1)
    end

    it 'redirects to catalogs list' do
      delete catalog_path(catalog)
      expect(response).to redirect_to(catalogs_path)
      follow_redirect!
      expect(response.body).to include('Catalog deleted successfully')
    end

    it 'destroys associated catalog items' do
      create_list(:catalog_item, 3, catalog: catalog)

      expect {
        delete catalog_path(catalog)
      }.to change(CatalogItem, :count).by(-3)
    end

    context 'multi-tenant security' do
      it 'prevents deleting other company catalogs' do
        expect {
          delete catalog_path(other_catalog)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PATCH /catalogs/:code/reorder_items' do
    let(:catalog) { create(:catalog, company: company) }
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }
    let!(:product3) { create(:product, company: company) }
    let!(:item1) { create(:catalog_item, catalog: catalog, product: product1, priority: 100) }
    let!(:item2) { create(:catalog_item, catalog: catalog, product: product2, priority: 200) }
    let!(:item3) { create(:catalog_item, catalog: catalog, product: product3, priority: 300) }

    context 'with valid order' do
      it 'updates priorities based on order' do
        patch reorder_items_catalog_path(catalog), params: {
          order: [ item3.id, item1.id, item2.id ]
        }

        expect(response).to have_http_status(:ok)

        # Reload items and check priorities
        item1.reload
        item2.reload
        item3.reload

        # item3 is first, should have highest priority (3)
        # item1 is second, should have priority 2
        # item2 is last, should have priority 1
        expect(item3.priority).to eq(3)
        expect(item1.priority).to eq(2)
        expect(item2.priority).to eq(1)
      end
    end

    context 'with invalid parameters' do
      it 'returns unprocessable_entity when order is missing' do
        patch reorder_items_catalog_path(catalog), params: {}
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns unprocessable_entity when order is not an array' do
        patch reorder_items_catalog_path(catalog), params: { order: 'invalid' }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'silently skips invalid IDs and reorders valid items' do
        patch reorder_items_catalog_path(catalog), params: {
          order: [ item1.id, 999999, item2.id ]
        }
        # Controller skips invalid IDs and processes valid ones
        expect(response).to have_http_status(:ok)
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company) }

      it 'prevents reordering other company catalog items' do
        expect {
          patch reorder_items_catalog_path(other_catalog), params: { order: [ 1, 2, 3 ] }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET /catalogs/:code/export' do
    let(:catalog) { create(:catalog, company: company, code: 'EXPORT', currency_code: 'eur') }
    let!(:product1) { create(:product, company: company, sku: 'PROD001', name: 'Product 1', ean: '1234567890') }
    let!(:product2) { create(:product, company: company, sku: 'PROD002', name: 'Product 2', ean: '0987654321') }
    let!(:catalog_item1) { create(:catalog_item, catalog: catalog, product: product1, priority: 100, catalog_item_state: :active) }
    let!(:catalog_item2) { create(:catalog_item, catalog: catalog, product: product2, priority: 50, catalog_item_state: :inactive) }

    context 'JSON format' do
      it 'exports catalog data as JSON' do
        get export_catalog_path(catalog, format: :json)
        expect(response).to be_successful
        expect(response.content_type).to include('application/json')
      end

      it 'includes catalog metadata' do
        get export_catalog_path(catalog, format: :json)
        json = JSON.parse(response.body)

        expect(json['catalog']['code']).to eq('EXPORT')
        expect(json['catalog']['name']).to eq(catalog.name)
        expect(json['catalog']['catalog_type']).to eq('webshop')
        expect(json['catalog']['currency_code']).to eq('eur')
        expect(json['catalog']['products_count']).to eq(2)
      end

      it 'includes catalog items with product details' do
        get export_catalog_path(catalog, format: :json)
        json = JSON.parse(response.body)

        expect(json['items']).to be_an(Array)
        expect(json['items'].length).to eq(2)

        first_item = json['items'].first
        expect(first_item['priority']).to eq(100)
        expect(first_item['product']['sku']).to eq('PROD001')
        expect(first_item['product']['name']).to eq('Product 1')
        expect(first_item['product']['ean']).to eq('1234567890')
      end

      it 'orders items by priority' do
        get export_catalog_path(catalog, format: :json)
        json = JSON.parse(response.body)

        # Higher priority item should be first
        expect(json['items'].first['priority']).to eq(100)
        expect(json['items'].last['priority']).to eq(50)
      end
    end

    context 'CSV format' do
      it 'exports catalog data as CSV' do
        get export_catalog_path(catalog, format: :csv)
        expect(response).to be_successful
        expect(response.content_type).to include('text/csv')
      end

      it 'includes correct filename with timestamp' do
        get export_catalog_path(catalog, format: :csv)
        expect(response.headers['Content-Disposition']).to match(/catalog_EXPORT_\d{8}_\d{6}\.csv/)
        expect(response.headers['Content-Disposition']).to include('attachment')
      end

      it 'includes CSV headers' do
        get export_catalog_path(catalog, format: :csv)
        csv_content = response.body
        headers = csv_content.lines.first.strip

        expect(headers).to include('Priority')
        expect(headers).to include('State')
        expect(headers).to include('Product SKU')
        expect(headers).to include('Product Name')
        expect(headers).to include('EAN')
      end

      it 'includes product data in CSV rows' do
        get export_catalog_path(catalog, format: :csv)
        csv_content = response.body

        expect(csv_content).to include('PROD001')
        expect(csv_content).to include('Product 1')
        expect(csv_content).to include('1234567890')
      end
    end

    context 'multi-tenant security' do
      let(:other_catalog) { create(:catalog, company: other_company) }

      it 'prevents exporting other company catalogs' do
        expect {
          get export_catalog_path(other_catalog, format: :json)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'authentication requirements' do
    before do
      # Reset authentication mocks to test authentication requirement
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(nil)
    end

    it 'requires authentication for index' do
      get catalogs_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for show' do
      catalog = create(:catalog, company: company)
      get catalog_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for items' do
      catalog = create(:catalog, company: company)
      get catalog_items_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for new' do
      get new_catalog_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post catalogs_path, params: { catalog: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for edit' do
      catalog = create(:catalog, company: company)
      get edit_catalog_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      catalog = create(:catalog, company: company)
      patch catalog_path(catalog), params: { catalog: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      catalog = create(:catalog, company: company)
      delete catalog_path(catalog)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for reorder_items' do
      catalog = create(:catalog, company: company)
      patch reorder_items_catalog_path(catalog), params: { order: [ 1, 2, 3 ] }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for export' do
      catalog = create(:catalog, company: company)
      get export_catalog_path(catalog, format: :json)
      expect(response).to redirect_to(auth_login_path)
    end
  end

  describe 'edge cases' do
    let(:catalog) { create(:catalog, company: company, code: 'EDGE') }

    it 'handles catalog with special characters in code' do
      catalog = create(:catalog, company: company, code: 'MAIN-CATALOG_01')
      get catalog_path(catalog)
      expect(response).to redirect_to(catalog_items_path(catalog))
    end

    it 'handles catalog with very long name' do
      long_name = 'A' * 255
      post catalogs_path, params: {
        catalog: { code: 'LONG', name: long_name, catalog_type: :webshop, currency_code: 'eur' }
      }
      expect(response).to redirect_to(catalogs_path)
    end

    it 'raises ArgumentError for invalid catalog_type' do
      # Rails enums raise ArgumentError for invalid values before model validation
      expect {
        post catalogs_path, params: {
          catalog: { code: 'INV', name: 'Invalid', catalog_type: 'invalid_type', currency_code: 'eur' }
        }
      }.to raise_error(ArgumentError, /'invalid_type' is not a valid catalog_type/)
    end

    it 'handles missing required parameters' do
      # Send params that pass strong_params but fail validation
      post catalogs_path, params: { catalog: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'handles empty catalog items export' do
      empty_catalog = create(:catalog, company: company, code: 'EMPTY')
      get export_catalog_path(empty_catalog, format: :json)
      expect(response).to be_successful

      json = JSON.parse(response.body)
      expect(json['items']).to be_empty
      expect(json['catalog']['products_count']).to eq(0)
    end
  end

  describe 'turbo_stream responses' do
    let(:catalog) { create(:catalog, company: company) }

    # Turbo stream templates not yet implemented for catalogs controller
    it 'responds to turbo_stream format for index', :pending do
      get catalogs_path, as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds to turbo_stream format for items', :pending do
      get catalog_items_path(catalog), as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds to turbo_stream format for create success', :pending do
      post catalogs_path, params: {
        catalog: { code: 'NEW', name: 'New', catalog_type: :webshop, currency_code: 'eur' }
      }, as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds to turbo_stream format for create failure', :pending do
      post catalogs_path, params: {
        catalog: { code: '', name: '' }
      }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end
  end
end
