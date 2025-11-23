require 'rails_helper'

RSpec.describe CatalogItemsController, type: :controller do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product1) { create(:product, company: company, sku: 'PROD-001', name: 'Test Product 1') }
  let(:product2) { create(:product, company: company, sku: 'PROD-002', name: 'Test Product 2') }
  let(:product3) { create(:product, company: company, sku: 'PROD-003', name: 'Test Product 3') }

  before do
    # Mock authentication
    allow(controller).to receive(:current_potlift_company).and_return(company)
    allow(controller).to receive(:authenticated?).and_return(true)
  end

  describe 'GET #new' do
    context 'with no existing catalog items' do
      it 'returns products not in catalog' do
        get :new, params: { catalog_code: catalog.code }
        expect(response).to be_successful
        expect(assigns(:products)).to include(product1, product2, product3)
      end
    end

    context 'with existing catalog items' do
      before do
        catalog.catalog_items.create!(product: product1, catalog_item_state: :active)
      end

      it 'excludes products already in catalog' do
        get :new, params: { catalog_code: catalog.code }
        expect(response).to be_successful
        expect(assigns(:products)).not_to include(product1)
        expect(assigns(:products)).to include(product2, product3)
      end
    end

    context 'with search query' do
      it 'filters products by name' do
        get :new, params: { catalog_code: catalog.code, q: 'Product 1' }
        expect(assigns(:products)).to include(product1)
        expect(assigns(:products)).not_to include(product2, product3)
      end

      it 'filters products by SKU' do
        get :new, params: { catalog_code: catalog.code, q: 'PROD-002' }
        expect(assigns(:products)).to include(product2)
        expect(assigns(:products)).not_to include(product1, product3)
      end
    end

    context 'with product type filter' do
      let(:bundle_product) { create(:product, company: company, product_type: :bundle) }

      it 'filters by product type' do
        get :new, params: { catalog_code: catalog.code, product_type: 'bundle' }
        expect(assigns(:products)).to include(bundle_product)
        expect(assigns(:products)).not_to include(product1)
      end
    end

    context 'with status filter' do
      let(:draft_product) { create(:product, company: company, product_status: :draft) }

      it 'filters by product status' do
        get :new, params: { catalog_code: catalog.code, status: 'draft' }
        expect(assigns(:products)).to include(draft_product)
      end
    end
  end

  describe 'POST #create' do
    context 'with valid product IDs' do
      it 'adds products to catalog' do
        expect {
          post :create, params: { catalog_code: catalog.code, product_ids: [product1.id, product2.id] }
        }.to change(catalog.catalog_items, :count).by(2)

        expect(response).to redirect_to(catalog_items_path(catalog))
        expect(flash[:notice]).to match(/Successfully added 2 products/)
      end

      it 'sets default state to active' do
        post :create, params: { catalog_code: catalog.code, product_ids: [product1.id] }
        catalog_item = catalog.catalog_items.find_by(product: product1)
        expect(catalog_item.catalog_item_state).to eq('active')
      end

      it 'sets priority to max + 1' do
        catalog.catalog_items.create!(product: product3, catalog_item_state: :active, priority: 10)

        post :create, params: { catalog_code: catalog.code, product_ids: [product1.id] }
        catalog_item = catalog.catalog_items.find_by(product: product1)
        expect(catalog_item.priority).to eq(11)
      end

      it 'respects custom catalog_item_state' do
        post :create, params: { catalog_code: catalog.code, product_ids: [product1.id], catalog_item_state: 'inactive' }
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
          post :create, params: { catalog_code: catalog.code, product_ids: [product1.id, product2.id] }
        }.to change(catalog.catalog_items, :count).by(1)

        expect(flash[:notice]).to match(/Successfully added 1 product/)
      end
    end

    context 'with no product IDs' do
      it 'returns error' do
        post :create, params: { catalog_code: catalog.code, product_ids: [] }
        expect(response).to redirect_to(catalog_items_path(catalog))
        expect(flash[:alert]).to eq('No products selected.')
      end
    end

    context 'with invalid product ID' do
      it 'skips invalid products' do
        expect {
          post :create, params: { catalog_code: catalog.code, product_ids: [999999, product1.id] }
        }.to change(catalog.catalog_items, :count).by(1)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:catalog_item) { catalog.catalog_items.create!(product: product1, catalog_item_state: :active) }

    context 'with valid product ID' do
      it 'removes product from catalog' do
        expect {
          delete :destroy, params: { catalog_code: catalog.code, id: product1.id }
        }.to change(catalog.catalog_items, :count).by(-1)

        expect(response).to redirect_to(catalog_items_path(catalog))
        expect(flash[:notice]).to eq('Product removed from catalog.')
      end

      it 'responds to turbo_stream format' do
        delete :destroy, params: { catalog_code: catalog.code, id: product1.id }, format: :turbo_stream
        expect(response).to be_successful
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end

    context 'with product not in catalog' do
      it 'returns error' do
        delete :destroy, params: { catalog_code: catalog.code, id: product2.id }
        expect(response).to redirect_to(catalog_items_path(catalog))
        expect(flash[:alert]).to eq('Product not found in catalog.')
      end
    end

    context 'with invalid product ID' do
      it 'returns error' do
        delete :destroy, params: { catalog_code: catalog.code, id: 999999 }
        expect(response).to redirect_to(catalog_items_path(catalog))
        expect(flash[:alert]).to eq('Product not found.')
      end
    end
  end

  describe 'authorization' do
    let(:other_company) { create(:company) }
    let(:other_catalog) { create(:catalog, company: other_company) }

    it 'prevents access to catalogs from other companies' do
      expect {
        get :new, params: { catalog_code: other_catalog.code }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
