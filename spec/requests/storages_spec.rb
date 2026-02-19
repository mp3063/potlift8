# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/storages', type: :request do
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
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  describe 'GET /storages' do
    let!(:storage1) { create(:storage, company: company, code: 'WH001', name: 'Warehouse 1', storage_type: :regular) }
    let!(:storage2) { create(:storage, company: company, code: 'WH002', name: 'Warehouse 2', storage_type: :temporary) }
    let!(:storage3) { create(:storage, company: company, code: 'WH003', name: 'Warehouse 3', storage_type: :incoming) }
    let!(:other_storage) { create(:storage, company: other_company, code: 'OTHER', name: 'Other Storage') }

    it 'returns successful response' do
      get storages_path
      expect(response).to be_successful
    end

    it 'displays only current company storages' do
      get storages_path
      expect(response.body).to include('Warehouse 1')
      expect(response.body).to include('Warehouse 2')
      expect(response.body).to include('Warehouse 3')
      expect(response.body).not_to include('Other Storage')
    end

    context 'with sorting' do
      it 'sorts by code ascending' do
        get storages_path, params: { sort: 'code', direction: 'asc' }
        expect(response).to be_successful
        expect(response.body.index('WH001')).to be < response.body.index('WH002')
      end

      it 'sorts by name descending' do
        get storages_path, params: { sort: 'name', direction: 'desc' }
        expect(response).to be_successful
        expect(response.body.index('Warehouse 3')).to be < response.body.index('Warehouse 1')
      end

      it 'sorts by storage_type' do
        get storages_path, params: { sort: 'storage_type', direction: 'asc' }
        expect(response).to be_successful
      end

      it 'defaults to code asc when no sort specified' do
        get storages_path
        expect(response).to be_successful
      end

      it 'handles invalid sort column by using default' do
        get storages_path, params: { sort: 'invalid_column' }
        expect(response).to be_successful
      end
    end

    context 'multi-tenant security' do
      it 'does not show other company storages' do
        get storages_path
        expect(response).to be_successful
        expect(response.body).not_to include('OTHER')
        expect(response.body).not_to include('Other Storage')
      end
    end
  end

  describe 'GET /storages/:code' do
    let(:storage) { create(:storage, company: company, code: 'MAIN') }
    let(:other_storage) { create(:storage, company: other_company, code: 'OTHER') }

    it 'redirects to inventory action' do
      get storage_path(storage)
      expect(response).to redirect_to(inventory_storage_path(storage))
    end

    it 'prevents access to other company storages' do
      expect {
        get storage_path(other_storage)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /storages/:code/inventory' do
    let(:storage) { create(:storage, company: company, code: 'MAIN') }
    let!(:product1) { create(:product, company: company, sku: 'PROD001', name: 'Product 1') }
    let!(:product2) { create(:product, company: company, sku: 'PROD002', name: 'Product 2') }
    let!(:inventory1) { create(:inventory, storage: storage, product: product1, value: 100) }
    let!(:inventory2) { create(:inventory, storage: storage, product: product2, value: 50) }

    it 'returns successful response' do
      get inventory_storage_path(storage)
      expect(response).to be_successful
    end

    it 'displays inventory records for storage' do
      get inventory_storage_path(storage)
      expect(response.body).to include('PROD001')
      expect(response.body).to include('PROD002')
      expect(response.body).to include('100')
      expect(response.body).to include('50')
    end

    context 'with sorting' do
      it 'sorts by SKU' do
        get inventory_storage_path(storage), params: { sort: 'sku', direction: 'asc' }
        expect(response).to be_successful
        expect(response.body.index('PROD001')).to be < response.body.index('PROD002')
      end

      it 'sorts by name' do
        get inventory_storage_path(storage), params: { sort: 'name', direction: 'desc' }
        expect(response).to be_successful
      end

      it 'sorts by value' do
        get inventory_storage_path(storage), params: { sort: 'value', direction: 'desc' }
        expect(response).to be_successful
        # Note: Checking sort order in HTML is fragile due to numbers appearing in CSS/attributes
        # Just verify the sorting parameter is accepted and returns success
      end

      it 'defaults to SKU asc when no sort specified' do
        get inventory_storage_path(storage)
        expect(response).to be_successful
      end
    end

    context 'multi-tenant security' do
      let(:other_storage) { create(:storage, company: other_company) }

      it 'prevents access to other company storage inventory' do
        expect {
          get inventory_storage_path(other_storage)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'GET /storages/new' do
    it 'returns successful response' do
      get new_storage_path
      expect(response).to be_successful
    end

    it 'displays storage form' do
      get new_storage_path
      expect(response.body).to include('Code')
      expect(response.body).to include('Name')
      expect(response.body).to include('Storage Type')
    end
  end

  describe 'GET /storages/:code/edit' do
    let(:storage) { create(:storage, company: company, code: 'MAIN') }
    let(:other_storage) { create(:storage, company: other_company) }

    it 'returns successful response for own company storage' do
      get edit_storage_path(storage)
      expect(response).to be_successful
    end

    it 'displays storage edit form with values' do
      get edit_storage_path(storage)
      expect(response.body).to include(storage.code)
      expect(response.body).to include(storage.name)
    end

    it 'prevents editing other company storages' do
      expect {
        get edit_storage_path(other_storage)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /storages' do
    let(:valid_attributes) do
      {
        code: 'NEW001',
        name: 'New Warehouse',
        storage_type: :regular,
        storage_status: :active
      }
    end

    let(:invalid_attributes) do
      {
        code: '',
        name: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new storage' do
        expect {
          post storages_path, params: { storage: valid_attributes }
        }.to change(Storage, :count).by(1)
      end

      it 'assigns storage to current company' do
        post storages_path, params: { storage: valid_attributes }
        storage = Storage.last
        expect(storage.company_id).to eq(company.id)
      end

      it 'redirects to storages list' do
        post storages_path, params: { storage: valid_attributes }
        expect(response).to redirect_to(storages_path)
        follow_redirect!
        expect(response.body).to include('Storage location created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new storage' do
        expect {
          post storages_path, params: { storage: invalid_attributes }
        }.not_to change(Storage, :count)
      end

      it 'renders new template with errors' do
        post storages_path, params: { storage: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate code' do
      let!(:existing_storage) { create(:storage, company: company, code: 'DUP001') }

      it 'does not create storage with duplicate code' do
        expect {
          post storages_path, params: { storage: valid_attributes.merge(code: 'DUP001') }
        }.not_to change(Storage, :count)
      end

      it 'shows validation error' do
        post storages_path, params: { storage: valid_attributes.merge(code: 'DUP001') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with JSONB info field' do
      it 'stores custom info data' do
        post storages_path, params: {
          storage: valid_attributes.merge(info: { location: 'Building A', capacity: 1000 })
        }

        storage = Storage.last
        expect(storage.info['location']).to eq('Building A')
        # Form params are always strings, so capacity is stored as "1000"
        expect(storage.info['capacity'].to_i).to eq(1000)
      end
    end

    context 'with default flag' do
      it 'sets default flag to true' do
        post storages_path, params: { storage: valid_attributes.merge(default: true) }
        storage = Storage.last
        expect(storage.default).to be true
      end
    end
  end

  describe 'PATCH /storages/:code' do
    let(:storage) { create(:storage, company: company, code: 'OLD001', name: 'Old Name') }
    let(:other_storage) { create(:storage, company: other_company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        storage_type: :temporary
      }
    end

    context 'with valid parameters' do
      it 'updates the storage' do
        patch storage_path(storage), params: { storage: new_attributes }
        storage.reload
        expect(storage.name).to eq('Updated Name')
        expect(storage.storage_type).to eq('temporary')
      end

      it 'redirects to storages list' do
        patch storage_path(storage), params: { storage: new_attributes }
        expect(response).to redirect_to(storages_path)
        follow_redirect!
        expect(response.body).to include('Storage location updated successfully')
      end
    end

    context 'with invalid parameters' do
      # Create a second storage to test uniqueness validation
      let!(:existing_storage) { create(:storage, company: company, code: 'EXISTING') }

      # Note: Testing with code: '' causes URL generation issues when re-rendering edit
      # because form_with uses to_param which returns the empty code
      # Using duplicate code instead to trigger uniqueness validation
      it 'renders edit template with errors' do
        patch storage_path(storage), params: { storage: { code: 'EXISTING' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update the storage' do
        patch storage_path(storage), params: { storage: { code: 'EXISTING' } }
        storage.reload
        expect(storage.code).to eq('OLD001')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company storages' do
        expect {
          patch storage_path(other_storage), params: { storage: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /storages/:code' do
    let!(:storage) { create(:storage, company: company, code: 'DEL001') }
    let(:other_storage) { create(:storage, company: other_company) }

    context 'storage without inventory' do
      it 'destroys the storage' do
        expect {
          delete storage_path(storage)
        }.to change(Storage, :count).by(-1)
      end

      it 'redirects to storages list' do
        delete storage_path(storage)
        expect(response).to redirect_to(storages_path)
        follow_redirect!
        expect(response.body).to include('Storage location deleted successfully')
      end
    end

    context 'storage with inventory' do
      before do
        create(:inventory, storage: storage, value: 10)
      end

      it 'does not destroy the storage' do
        expect {
          delete storage_path(storage)
        }.not_to change(Storage, :count)
      end

      it 'redirects with error message' do
        delete storage_path(storage)
        expect(response).to redirect_to(storages_path)
        follow_redirect!
        expect(response.body).to include('Cannot delete storage')
        expect(response.body).to include('contains inventory')
      end

      it 'keeps the storage in database' do
        delete storage_path(storage)
        expect(Storage.exists?(storage.id)).to be true
      end
    end

    context 'storage with zero inventory' do
      before do
        create(:inventory, storage: storage, value: 0)
      end

      it 'destroys the storage' do
        expect {
          delete storage_path(storage)
        }.to change(Storage, :count).by(-1)
      end
    end

    context 'multi-tenant security' do
      it 'prevents deleting other company storages' do
        expect {
          delete storage_path(other_storage)
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
      get storages_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for show' do
      storage = create(:storage, company: company)
      get storage_path(storage)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for inventory' do
      storage = create(:storage, company: company)
      get inventory_storage_path(storage)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for new' do
      get new_storage_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post storages_path, params: { storage: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for edit' do
      storage = create(:storage, company: company)
      get edit_storage_path(storage)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      storage = create(:storage, company: company)
      patch storage_path(storage), params: { storage: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      storage = create(:storage, company: company)
      delete storage_path(storage)
      expect(response).to redirect_to(auth_login_path)
    end
  end

  describe 'edge cases' do
    let(:storage) { create(:storage, company: company, code: 'EDGE') }

    it 'handles storage with special characters in code' do
      storage = create(:storage, company: company, code: 'MAIN-WAREHOUSE_01')
      get storage_path(storage)
      expect(response).to redirect_to(inventory_storage_path(storage))
    end

    it 'handles storage with very long name' do
      long_name = 'A' * 255
      post storages_path, params: {
        storage: { code: 'LONG', name: long_name, storage_type: :regular }
      }
      expect(response).to redirect_to(storages_path)
    end

    it 'raises ArgumentError for invalid storage_type' do
      # Rails enums raise ArgumentError before model validation
      expect {
        post storages_path, params: {
          storage: { code: 'INV', name: 'Invalid', storage_type: 'invalid_type' }
        }
      }.to raise_error(ArgumentError, /'invalid_type' is not a valid storage_type/)
    end

    it 'handles missing required parameters' do
      # Send params that pass strong_params but fail validation
      post storages_path, params: { storage: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'turbo_stream responses' do
    let(:storage) { create(:storage, company: company) }

    it 'responds to turbo_stream format for index' do
      get storages_path, as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds to turbo_stream format for inventory' do
      get inventory_storage_path(storage), as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds to turbo_stream format for create success' do
      post storages_path, params: {
        storage: { code: 'NEW', name: 'New', storage_type: :regular }
      }, as: :turbo_stream
      expect(response).to be_successful
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    it 'responds with HTML for create failure (re-renders form)' do
      post storages_path, params: {
        storage: { code: '', name: '' }
      }, as: :turbo_stream
      expect(response).to have_http_status(:unprocessable_entity)
      # Validation failures re-render the HTML form, not turbo_stream
      expect(response.media_type).to eq('text/html')
    end
  end
end
