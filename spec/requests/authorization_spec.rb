# frozen_string_literal: true

require 'rails_helper'

# Comprehensive authorization integration tests for Pundit policies.
#
# Verifies that viewers (role: "viewer", scopes: ["read"]) are denied write
# and destructive operations across all critical controllers, and that admins
# (role: "admin", scopes: ["read", "write"]) are allowed.
#
# Uses `authenticate_user` helper which POSTs to /test_login to set up
# a real session with role and scopes, so Pundit's UserContext is built
# from actual session data — no mocking of policies or authorization.
#
RSpec.describe 'Authorization integration', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # ---------------------------------------------------------------------------
  # ProductsController
  # ---------------------------------------------------------------------------
  describe 'ProductsController authorization' do
    let!(:product) do
      create(:product, company: company, sku: 'AUTH-PROD-001', name: 'Auth Test Product',
             product_type: :sellable, product_status: :active)
    end

    let(:valid_product_params) do
      { product: { sku: 'NEW-AUTH-001', name: 'New Auth Product', product_type: :sellable } }
    end

    context 'as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'allows viewing products index' do
        get products_path
        expect(response).to be_successful
      end

      it 'allows viewing product details' do
        get product_path(product)
        expect(response).to be_successful
      end

      it 'denies creating a product' do
        post products_path, params: valid_product_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist a product on denied create' do
        expect {
          post products_path, params: valid_product_params
        }.not_to change(Product, :count)
      end

      it 'denies updating a product' do
        patch product_path(product), params: { product: { name: 'Hacked Name' } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist changes on denied update' do
        patch product_path(product), params: { product: { name: 'Hacked Name' } }
        expect(product.reload.name).to eq('Auth Test Product')
      end

      it 'denies destroying a product' do
        delete product_path(product)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not destroy on denied delete' do
        expect {
          delete product_path(product)
        }.not_to change(Product, :count)
      end

      it 'denies duplicating a product' do
        post duplicate_product_path(product)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not create a duplicate on denied request' do
        expect {
          post duplicate_product_path(product)
        }.not_to change(Product, :count)
      end

      it 'denies toggling product active status' do
        patch toggle_active_product_path(product)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not change status on denied toggle' do
        patch toggle_active_product_path(product)
        expect(product.reload.product_status).to eq('active')
      end
    end

    context 'as member with write scope' do
      before { authenticate_user(user, role: 'member', scopes: %w[read write]) }

      it 'allows creating a product' do
        expect {
          post products_path, params: valid_product_params
        }.to change(Product, :count).by(1)
      end

      it 'allows updating a product' do
        patch product_path(product), params: { product: { name: 'Updated by Member' } }
        expect(product.reload.name).to eq('Updated by Member')
      end

      it 'allows duplicating a product' do
        expect {
          post duplicate_product_path(product)
        }.to change(Product, :count).by(1)
      end

      it 'allows toggling product active status' do
        draft_product = create(:product, company: company, product_status: :draft)
        patch toggle_active_product_path(draft_product)
        expect(draft_product.reload.product_status).to eq('active')
      end

      it 'denies destroying a product (admin-only)' do
        delete product_path(product)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context 'as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      it 'allows creating a product' do
        expect {
          post products_path, params: valid_product_params
        }.to change(Product, :count).by(1)
      end

      it 'allows updating a product' do
        patch product_path(product), params: { product: { name: 'Updated by Admin' } }
        expect(product.reload.name).to eq('Updated by Admin')
      end

      it 'allows destroying a product' do
        expect {
          delete product_path(product)
        }.to change(Product, :count).by(-1)
      end

      it 'allows duplicating a product' do
        expect {
          post duplicate_product_path(product)
        }.to change(Product, :count).by(1)
      end

      it 'allows toggling product active status' do
        draft_product = create(:product, company: company, product_status: :draft)
        patch toggle_active_product_path(draft_product)
        expect(draft_product.reload.product_status).to eq('active')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # CatalogsController
  # ---------------------------------------------------------------------------
  describe 'CatalogsController authorization' do
    let!(:catalog) do
      create(:catalog, company: company, code: 'AUTH-CAT', name: 'Auth Test Catalog',
             catalog_type: :webshop, currency_code: 'eur')
    end

    let(:valid_catalog_params) do
      { catalog: { code: 'NEW-AUTH-CAT', name: 'New Auth Catalog', catalog_type: :webshop, currency_code: 'eur' } }
    end

    context 'as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'allows viewing catalogs index' do
        get catalogs_path
        expect(response).to be_successful
      end

      it 'denies creating a catalog' do
        post catalogs_path, params: valid_catalog_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist a catalog on denied create' do
        expect {
          post catalogs_path, params: valid_catalog_params
        }.not_to change(Catalog, :count)
      end

      it 'denies updating a catalog' do
        patch catalog_path(catalog), params: { catalog: { name: 'Hacked Catalog' } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist changes on denied update' do
        patch catalog_path(catalog), params: { catalog: { name: 'Hacked Catalog' } }
        expect(catalog.reload.name).to eq('Auth Test Catalog')
      end

      it 'denies destroying a catalog' do
        delete catalog_path(catalog)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not destroy on denied delete' do
        expect {
          delete catalog_path(catalog)
        }.not_to change(Catalog, :count)
      end
    end

    context 'connect_shopify / disconnect_shopify — as member with write scope' do
      before { authenticate_user(user, role: 'member', scopes: %w[read write]) }

      let(:mock_service) { instance_double(ShopifyConnectionService) }
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: { id: 123 })
      end

      before do
        allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:connect).and_return(success_result)
        allow(mock_service).to receive(:disconnect).and_return(success_result)
      end

      it 'denies connect_shopify (admin-only)' do
        post connect_shopify_catalog_path(catalog), params: {
          shopify_domain: 'test.myshopify.com',
          shopify_api_key: 'key',
          shopify_password: 'secret'
        }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'denies disconnect_shopify (admin-only)' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context 'connect_shopify / disconnect_shopify — as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      let(:mock_service) { instance_double(ShopifyConnectionService) }

      before do
        allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
      end

      it 'denies connect_shopify' do
        post connect_shopify_catalog_path(catalog), params: {
          shopify_domain: 'test.myshopify.com',
          shopify_api_key: 'key',
          shopify_password: 'secret'
        }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'denies disconnect_shopify' do
        delete disconnect_shopify_catalog_path(catalog)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'allows viewing shopify_connection status' do
        allow(mock_service).to receive(:connected?).and_return(false)
        get shopify_connection_catalog_path(catalog)
        expect(response).to be_successful
      end
    end

    context 'connect_shopify / disconnect_shopify — as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      let(:mock_service) { instance_double(ShopifyConnectionService) }
      let(:success_result) do
        ShopifyConnectionService::Result.new(success: true, data: { id: 123, shopify_domain: 'test.myshopify.com' })
      end

      before do
        allow(ShopifyConnectionService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:connect).and_return(success_result)
        allow(mock_service).to receive(:disconnect).and_return(success_result)
      end

      it 'allows connect_shopify' do
        post connect_shopify_catalog_path(catalog), params: {
          shopify_domain: 'test.myshopify.com',
          shopify_api_key: 'key',
          shopify_password: 'secret'
        }
        # Admin should not get redirected to root with "not authorized"
        expect(response).not_to redirect_to(root_path)
      end

      it 'allows disconnect_shopify' do
        delete disconnect_shopify_catalog_path(catalog)
        # Admin should not get redirected to root with "not authorized"
        expect(response).not_to redirect_to(root_path)
      end
    end

    context 'as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      it 'allows creating a catalog' do
        expect {
          post catalogs_path, params: valid_catalog_params
        }.to change(Catalog, :count).by(1)
      end

      it 'allows updating a catalog' do
        patch catalog_path(catalog), params: { catalog: { name: 'Updated by Admin' } }
        expect(catalog.reload.name).to eq('Updated by Admin')
      end

      it 'allows destroying a catalog' do
        expect {
          delete catalog_path(catalog)
        }.to change(Catalog, :count).by(-1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # LabelsController
  # ---------------------------------------------------------------------------
  describe 'LabelsController authorization' do
    let!(:label) do
      create(:label, company: company, code: 'auth_test', name: 'Auth Test Label',
             label_type: 'category')
    end

    let(:valid_label_params) do
      { label: { code: 'new_auth_label', name: 'New Auth Label', label_type: 'category' } }
    end

    context 'as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'allows viewing labels index' do
        get labels_path
        expect(response).to be_successful
      end

      it 'allows viewing label details' do
        get label_path(label.full_code)
        expect(response).to be_successful
      end

      it 'denies creating a label' do
        post labels_path, params: valid_label_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist a label on denied create' do
        expect {
          post labels_path, params: valid_label_params
        }.not_to change(Label, :count)
      end

      it 'denies updating a label' do
        patch label_path(label.full_code), params: { label: { name: 'Hacked Label' } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist changes on denied update' do
        patch label_path(label.full_code), params: { label: { name: 'Hacked Label' } }
        expect(label.reload.name).to eq('Auth Test Label')
      end

      it 'denies destroying a label' do
        delete label_path(label.full_code)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not destroy on denied delete' do
        expect {
          delete label_path(label.full_code)
        }.not_to change(Label, :count)
      end
    end

    context 'as member with write scope' do
      before { authenticate_user(user, role: 'member', scopes: %w[read write]) }

      it 'allows creating a label' do
        expect {
          post labels_path, params: valid_label_params
        }.to change(Label, :count).by(1)
      end

      it 'allows updating a label' do
        patch label_path(label.full_code), params: { label: { name: 'Updated by Member' } }
        expect(label.reload.name).to eq('Updated by Member')
      end

      it 'denies destroying a label (admin-only)' do
        delete label_path(label.full_code)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context 'as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      it 'allows creating a label' do
        expect {
          post labels_path, params: valid_label_params
        }.to change(Label, :count).by(1)
      end

      it 'allows updating a label' do
        patch label_path(label.full_code), params: { label: { name: 'Updated by Admin' } }
        expect(label.reload.name).to eq('Updated by Admin')
      end

      it 'allows destroying a label' do
        expect {
          delete label_path(label.full_code)
        }.to change(Label, :count).by(-1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # StoragesController
  # ---------------------------------------------------------------------------
  describe 'StoragesController authorization' do
    let!(:storage) do
      create(:storage, company: company, code: 'AUTH-WH', name: 'Auth Test Warehouse',
             storage_type: :regular, storage_status: :active)
    end

    let(:valid_storage_params) do
      { storage: { code: 'NEW-AUTH-WH', name: 'New Auth Warehouse', storage_type: :regular } }
    end

    context 'as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'allows viewing storages index' do
        get storages_path
        expect(response).to be_successful
      end

      it 'allows viewing storage inventory' do
        get inventory_storage_path(storage)
        expect(response).to be_successful
      end

      it 'denies creating a storage' do
        post storages_path, params: valid_storage_params
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist a storage on denied create' do
        expect {
          post storages_path, params: valid_storage_params
        }.not_to change(Storage, :count)
      end

      it 'denies updating a storage' do
        patch storage_path(storage), params: { storage: { name: 'Hacked Warehouse' } }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not persist changes on denied update' do
        patch storage_path(storage), params: { storage: { name: 'Hacked Warehouse' } }
        expect(storage.reload.name).to eq('Auth Test Warehouse')
      end

      it 'denies destroying a storage' do
        delete storage_path(storage)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end

      it 'does not destroy on denied delete' do
        expect {
          delete storage_path(storage)
        }.not_to change(Storage, :count)
      end
    end

    context 'as member with write scope' do
      before { authenticate_user(user, role: 'member', scopes: %w[read write]) }

      it 'allows creating a storage' do
        expect {
          post storages_path, params: valid_storage_params
        }.to change(Storage, :count).by(1)
      end

      it 'allows updating a storage' do
        patch storage_path(storage), params: { storage: { name: 'Updated by Member' } }
        expect(storage.reload.name).to eq('Updated by Member')
      end

      it 'denies destroying a storage (admin-only)' do
        delete storage_path(storage)
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context 'as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      it 'allows creating a storage' do
        expect {
          post storages_path, params: valid_storage_params
        }.to change(Storage, :count).by(1)
      end

      it 'allows updating a storage' do
        patch storage_path(storage), params: { storage: { name: 'Updated by Admin' } }
        expect(storage.reload.name).to eq('Updated by Admin')
      end

      it 'allows destroying a storage' do
        expect {
          delete storage_path(storage)
        }.to change(Storage, :count).by(-1)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # ImportsController
  # ---------------------------------------------------------------------------
  describe 'ImportsController authorization' do
    context 'as viewer' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'allows viewing imports index' do
        get imports_path
        expect(response).to be_successful
      end

      it 'denies creating an import' do
        csv_file = Rack::Test::UploadedFile.new(
          StringIO.new("sku,name\nTEST-001,Test Product"),
          'text/csv',
          original_filename: 'import.csv'
        )
        post imports_path, params: { file: csv_file, import_type: 'products' }
        expect(response).to redirect_to(root_path)
        follow_redirect!
        expect(response.body).to include('not authorized')
      end
    end

    context 'as admin' do
      before { authenticate_user(user, role: 'admin', scopes: %w[read write]) }

      it 'allows viewing imports index' do
        get imports_path
        expect(response).to be_successful
      end

      it 'allows accessing new import form' do
        get new_import_path
        expect(response).to be_successful
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Cross-cutting authorization edge cases
  # ---------------------------------------------------------------------------
  describe 'authorization response format' do
    let!(:product) { create(:product, company: company) }

    context 'as viewer with turbo_stream request' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'returns 403 forbidden for turbo_stream format' do
        delete product_path(product), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'as viewer with JSON request' do
      before { authenticate_user(user, role: 'viewer', scopes: [ 'read' ]) }

      it 'returns 403 forbidden with error JSON' do
        delete product_path(product), as: :json
        expect(response).to have_http_status(:forbidden)
        expect(JSON.parse(response.body)).to eq('error' => 'forbidden')
      end
    end
  end
end
