require 'rails_helper'

RSpec.describe 'CatalogItems', type: :request do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product1) { create(:product, company: company, sku: 'PROD-001', name: 'Test Product 1') }
  let(:product2) { create(:product, company: company, sku: 'PROD-002', name: 'Test Product 2') }
  let(:product3) { create(:product, company: company, sku: 'PROD-003', name: 'Test Product 3') }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
  end

  describe 'GET /catalogs/:catalog_code/products/new' do
    context 'with no existing catalog items' do
      it 'returns products not in catalog' do
        product1
        product2
        product3

        get catalog_new_product_path(catalog.code)

        expect(response).to be_successful
        expect(response.body).to include(product1.name)
        expect(response.body).to include(product2.name)
        expect(response.body).to include(product3.name)
      end
    end

    context 'with existing catalog items' do
      before do
        catalog.catalog_items.create!(product: product1, catalog_item_state: :active)
      end

      it 'excludes products already in catalog' do
        product2
        product3

        get catalog_new_product_path(catalog.code)

        expect(response).to be_successful
        expect(response.body).not_to include(product1.name)
        expect(response.body).to include(product2.name)
        expect(response.body).to include(product3.name)
      end
    end

    context 'with search query' do
      it 'filters products by name' do
        product1
        product2
        product3

        get catalog_new_product_path(catalog.code, q: 'Product 1')

        expect(response).to be_successful
        expect(response.body).to include(product1.name)
        expect(response.body).not_to include(product2.name)
      end

      it 'filters products by SKU' do
        product1
        product2
        product3

        get catalog_new_product_path(catalog.code, q: 'PROD-002')

        expect(response).to be_successful
        expect(response.body).to include(product2.name)
        expect(response.body).not_to include(product1.name)
      end
    end

    context 'with product type filter' do
      let(:bundle_product) { create(:product, company: company, product_type: :bundle, name: 'Bundle Product') }

      it 'filters by product type' do
        product1
        bundle_product

        get catalog_new_product_path(catalog.code, product_type: 'bundle')

        expect(response).to be_successful
        expect(response.body).to include(bundle_product.name)
        expect(response.body).not_to include(product1.name)
      end
    end

    context 'with status filter' do
      let(:draft_product) { create(:product, company: company, product_status: :draft, name: 'Draft Product') }

      it 'filters by product status' do
        product1
        draft_product

        get catalog_new_product_path(catalog.code, status: 'draft')

        expect(response).to be_successful
        expect(response.body).to include(draft_product.name)
      end
    end
  end

  describe 'POST /catalogs/:catalog_code/products' do
    context 'with valid product IDs' do
      it 'adds products to catalog' do
        expect {
          post catalog_products_path(catalog.code), params: { product_ids: [ product1.id, product2.id ] }
        }.to change(catalog.catalog_items, :count).by(2)

        expect(response).to redirect_to(catalog_items_path(catalog))
        follow_redirect!
        expect(response.body).to match(/Successfully added 2 products/)
      end

      it 'sets default state to active' do
        post catalog_products_path(catalog.code), params: { product_ids: [ product1.id ] }

        catalog_item = catalog.catalog_items.find_by(product: product1)
        expect(catalog_item.catalog_item_state).to eq('active')
      end

      it 'sets priority to max + 1' do
        catalog.catalog_items.create!(product: product3, catalog_item_state: :active, priority: 10)

        post catalog_products_path(catalog.code), params: { product_ids: [ product1.id ] }

        catalog_item = catalog.catalog_items.find_by(product: product1)
        expect(catalog_item.priority).to eq(11)
      end

      it 'respects custom catalog_item_state' do
        post catalog_products_path(catalog.code), params: { product_ids: [ product1.id ], catalog_item_state: 'inactive' }

        catalog_item = catalog.catalog_items.find_by(product: product1)
        expect(catalog_item.catalog_item_state).to eq('inactive')
      end
    end

    context 'with products already in catalog' do
      before do
        catalog.catalog_items.create!(product: product1, catalog_item_state: :active)
      end

      it 'skips duplicate products' do
        expect {
          post catalog_products_path(catalog.code), params: { product_ids: [ product1.id, product2.id ] }
        }.to change(catalog.catalog_items, :count).by(1)

        follow_redirect!
        expect(response.body).to match(/Successfully added 1 product/)
      end
    end

    context 'with no product IDs' do
      it 'returns error' do
        post catalog_products_path(catalog.code), params: { product_ids: [] }

        expect(response).to redirect_to(catalog_items_path(catalog))
        # Check flash alert is set (flash is rendered via component, not plain text)
        expect(flash[:alert]).to eq('No products selected.')
      end
    end

    context 'with invalid product ID' do
      it 'skips invalid products' do
        expect {
          post catalog_products_path(catalog.code), params: { product_ids: [ 999999, product1.id ] }
        }.to change(catalog.catalog_items, :count).by(1)
      end
    end
  end

  describe 'DELETE /catalogs/:catalog_code/items/:id' do
    let!(:catalog_item) { catalog.catalog_items.create!(product: product1, catalog_item_state: :active) }

    context 'with valid product ID' do
      it 'removes product from catalog' do
        expect {
          delete catalog_item_path(catalog.code, product1.id)
        }.to change(catalog.catalog_items, :count).by(-1)

        expect(response).to redirect_to(catalog_items_path(catalog))
        follow_redirect!
        expect(response.body).to include('Product removed from catalog.')
      end

      it 'responds to turbo_stream format' do
        delete catalog_item_path(catalog.code, product1.id), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response).to be_successful
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'with product not in catalog' do
      it 'returns error' do
        delete catalog_item_path(catalog.code, product2.id)

        expect(response).to redirect_to(catalog_items_path(catalog))
        follow_redirect!
        expect(response.body).to include('Product not found in catalog.')
      end
    end

    context 'with invalid product ID' do
      it 'returns error' do
        delete catalog_item_path(catalog.code, 999999)

        expect(response).to redirect_to(catalog_items_path(catalog))
        follow_redirect!
        expect(response.body).to include('Product not found.')
      end
    end
  end

  describe 'authorization' do
    let(:other_company) { create(:company) }
    let(:other_catalog) { create(:catalog, company: other_company) }

    it 'prevents access to catalogs from other companies' do
      expect {
        get catalog_new_product_path(other_catalog.code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
