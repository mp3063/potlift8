# frozen_string_literal: true

require 'rails_helper'

RSpec.describe StorageInventoriesController, type: :request do
  # Use let! to ensure company is created before other factories
  let!(:company) { create(:company) }
  let!(:storage) { create(:storage, company: company, code: 'MAIN-WAREHOUSE') }
  let!(:product1) { create(:product, company: company, sku: 'PROD-001', name: 'Product 1', product_type: :sellable, product_status: :active) }
  let!(:product2) { create(:product, company: company, sku: 'PROD-002', name: 'Product 2', product_type: :sellable, product_status: :active) }
  let!(:product3) { create(:product, company: company, sku: 'PROD-003', name: 'Product 3', product_type: :configurable, product_status: :active) }

  # Mock authentication by setting session
  before do
    # Simulate authenticated user session
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      'id' => company.id,
      'code' => company.code,
      'name' => company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return({
      'id' => 1,
      'email' => 'test@example.com',
      'name' => 'Test User'
    })
  end

  describe 'GET #new' do
    context 'with no existing inventory' do
      it 'returns http success' do
        get new_storage_inventory_path(storage)
        expect(response).to have_http_status(:success)
      end

      it 'shows all active products' do
        get new_storage_inventory_path(storage)
        expect(assigns(:available_products)).to include(product1, product2, product3)
      end

      it 'assigns storage' do
        get new_storage_inventory_path(storage)
        expect(assigns(:storage)).to eq(storage)
      end

      it 'assigns labels for filtering' do
        label = create(:label, company: company, name: 'Electronics')
        get new_storage_inventory_path(storage)
        expect(assigns(:labels)).to include(label)
      end
    end

    context 'with existing inventory' do
      before do
        create(:inventory, storage: storage, product: product1, value: 10, company: company)
      end

      it 'excludes products already in storage' do
        get new_storage_inventory_path(storage)
        expect(assigns(:available_products)).not_to include(product1)
        expect(assigns(:available_products)).to include(product2, product3)
      end
    end

    context 'with search filter' do
      it 'filters by SKU' do
        get new_storage_inventory_path(storage), params: { search: 'PROD-001' }
        expect(assigns(:available_products)).to include(product1)
        expect(assigns(:available_products)).not_to include(product2, product3)
      end

      it 'filters by name' do
        get new_storage_inventory_path(storage), params: { search: 'Product 2' }
        expect(assigns(:available_products)).to include(product2)
        expect(assigns(:available_products)).not_to include(product1, product3)
      end

      it 'is case insensitive' do
        get new_storage_inventory_path(storage), params: { search: 'product 1' }
        expect(assigns(:available_products)).to include(product1)
      end
    end

    context 'with product type filter' do
      it 'filters by sellable type' do
        get new_storage_inventory_path(storage), params: { product_type: '1' }
        expect(assigns(:available_products)).to include(product1, product2)
        expect(assigns(:available_products)).not_to include(product3)
      end

      it 'filters by configurable type' do
        get new_storage_inventory_path(storage), params: { product_type: '2' }
        expect(assigns(:available_products)).to include(product3)
        expect(assigns(:available_products)).not_to include(product1, product2)
      end
    end

    context 'with label filter' do
      let!(:label) { create(:label, company: company, name: 'Electronics') }
      let!(:product_label) { create(:product_label, product: product1, label: label) }

      it 'filters by label' do
        get new_storage_inventory_path(storage), params: { label_id: label.id }
        expect(assigns(:available_products)).to include(product1)
        expect(assigns(:available_products)).not_to include(product2, product3)
      end
    end

    context 'with many products' do
      before do
        # Create 150 products
        110.times do |i|
          create(:product, company: company, sku: "PROD-#{100 + i}", name: "Product #{100 + i}", product_status: :active)
        end
      end

      it 'limits results to 100 products' do
        get new_storage_inventory_path(storage)
        expect(assigns(:available_products).count).to eq(100)
      end
    end

    context 'with turbo_stream format' do
      it 'responds to turbo_stream' do
        get new_storage_inventory_path(storage), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          product_ids: [product1.id, product2.id],
          quantities: {
            product1.id.to_s => '10',
            product2.id.to_s => '20'
          }
        }
      end

      it 'creates inventory records' do
        expect {
          post storage_inventories_path(storage), params: valid_params
        }.to change(Inventory, :count).by(2)
      end

      it 'sets correct quantities' do
        post storage_inventories_path(storage), params: valid_params

        inventory1 = storage.inventories.find_by(product: product1)
        inventory2 = storage.inventories.find_by(product: product2)

        expect(inventory1.value).to eq(10)
        expect(inventory2.value).to eq(20)
      end

      it 'associates with correct company' do
        post storage_inventories_path(storage), params: valid_params

        inventory = storage.inventories.first
        expect(inventory.company).to eq(company)
      end

      it 'redirects to storage inventory page' do
        post storage_inventories_path(storage), params: valid_params
        expect(response).to redirect_to(inventory_storage_path(storage))
      end

      it 'sets success flash message' do
        post storage_inventories_path(storage), params: valid_params
        expect(flash[:notice]).to eq("Successfully added 2 products to #{storage.name}.")
      end
    end

    context 'with zero quantities' do
      let(:params_with_zero) do
        {
          product_ids: [product1.id],
          quantities: {
            product1.id.to_s => '0'
          }
        }
      end

      it 'creates inventory with zero value' do
        post storage_inventories_path(storage), params: params_with_zero

        inventory = storage.inventories.find_by(product: product1)
        expect(inventory.value).to eq(0)
      end
    end

    context 'with missing quantities' do
      let(:params_no_qty) do
        {
          product_ids: [product1.id],
          quantities: {}
        }
      end

      it 'defaults to zero quantity' do
        post storage_inventories_path(storage), params: params_no_qty

        inventory = storage.inventories.find_by(product: product1)
        expect(inventory.value).to eq(0)
      end
    end

    context 'with no products selected' do
      let(:empty_params) do
        {
          product_ids: []
        }
      end

      it 'does not create inventory records' do
        expect {
          post storage_inventories_path(storage), params: empty_params
        }.not_to change(Inventory, :count)
      end

      it 'redirects back with alert' do
        post storage_inventories_path(storage), params: empty_params
        expect(response).to redirect_to(new_storage_inventory_path(storage))
        expect(flash[:alert]).to eq("Please select at least one product to add.")
      end
    end

    context 'with invalid product IDs' do
      let(:invalid_params) do
        {
          product_ids: [99999, product1.id]
        }
      end

      it 'does not create inventory records' do
        expect {
          post storage_inventories_path(storage), params: invalid_params
        }.not_to change(Inventory, :count)
      end

      it 'redirects with error message' do
        post storage_inventories_path(storage), params: invalid_params
        expect(response).to redirect_to(new_storage_inventory_path(storage))
        expect(flash[:alert]).to match(/could not be found/)
      end
    end

    context 'with products from different company' do
      let!(:other_company) { create(:company, code: 'OTHER') }
      let!(:other_product) { create(:product, company: other_company, sku: 'OTHER-001') }

      let(:cross_company_params) do
        {
          product_ids: [other_product.id]
        }
      end

      it 'does not create inventory records' do
        expect {
          post storage_inventories_path(storage), params: cross_company_params
        }.not_to change(Inventory, :count)
      end

      it 'redirects with error message' do
        post storage_inventories_path(storage), params: cross_company_params
        expect(flash[:alert]).to match(/don't belong to your company/)
      end
    end

    context 'with duplicate inventory' do
      before do
        create(:inventory, storage: storage, product: product1, value: 5, company: company)
      end

      let(:duplicate_params) do
        {
          product_ids: [product1.id, product2.id],
          quantities: {
            product1.id.to_s => '10',
            product2.id.to_s => '20'
          }
        }
      end

      it 'skips existing inventory' do
        expect {
          post storage_inventories_path(storage), params: duplicate_params
        }.to change(Inventory, :count).by(1) # Only product2 is added
      end

      it 'still creates new inventory for other products' do
        post storage_inventories_path(storage), params: duplicate_params

        # product1 inventory should remain unchanged
        inventory1 = storage.inventories.find_by(product: product1)
        expect(inventory1.value).to eq(5)

        # product2 should be created
        inventory2 = storage.inventories.find_by(product: product2)
        expect(inventory2.value).to eq(20)
      end
    end

    context 'with partial success' do
      # Simulate validation failure by stubbing save
      before do
        allow_any_instance_of(Inventory).to receive(:save).and_return(false, true)
      end

      let(:multi_params) do
        {
          product_ids: [product1.id, product2.id],
          quantities: {
            product1.id.to_s => '10',
            product2.id.to_s => '20'
          }
        }
      end

      it 'reports partial success' do
        post storage_inventories_path(storage), params: multi_params
        expect(flash[:alert]).to match(/Added \d+ products\. Failed to add:/)
      end
    end

    context 'with turbo_stream format' do
      let(:valid_params) do
        {
          product_ids: [product1.id],
          quantities: { product1.id.to_s => '10' }
        }
      end

      it 'responds to turbo_stream on success' do
        post storage_inventories_path(storage), params: valid_params, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'responds to turbo_stream on failure' do
        post storage_inventories_path(storage), params: { product_ids: [] }, headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'authentication and authorization' do
    context 'when not authenticated' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      end

      it 'redirects new action to login' do
        get new_storage_inventory_path(storage)
        expect(response).to redirect_to(auth_login_path)
      end

      it 'redirects create action to login' do
        post storage_inventories_path(storage), params: { product_ids: [product1.id] }
        expect(response).to redirect_to(auth_login_path)
      end
    end

    context 'when accessing storage from different company' do
      let!(:other_company) { create(:company, code: 'OTHER') }
      let!(:other_storage) { create(:storage, company: other_company, code: 'OTHER-WAREHOUSE') }

      it 'raises RecordNotFound for new action' do
        expect {
          get new_storage_inventory_path(other_storage)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'raises RecordNotFound for create action' do
        expect {
          post storage_inventories_path(other_storage), params: { product_ids: [product1.id] }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
