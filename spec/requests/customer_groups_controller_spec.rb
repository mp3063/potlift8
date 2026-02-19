require 'rails_helper'

RSpec.describe CustomerGroupsController, type: :request do
  let(:company) { create(:company) }
  let(:user) { { id: 1, email: 'test@example.com', name: 'Test User' } }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  describe 'GET /customer_groups' do
    it 'returns a successful response' do
      get customer_groups_path
      expect(response).to be_successful
    end

    it 'lists all customer groups' do
      create_list(:customer_group, 3, company: company)
      get customer_groups_path
      expect(response.body).to include('Customer Groups')
    end
  end

  describe 'GET /customer_groups/:id' do
    let!(:customer_group) { create(:customer_group, company: company, name: 'VIP Customers', discount_percent: 20) }
    let!(:product) { create(:product, company: company) }
    let!(:price) { create(:price, customer_group: customer_group, product: product, value: 80) }

    it 'returns a successful response' do
      get customer_group_path(customer_group)
      expect(response).to be_successful
    end

    it 'displays customer group name' do
      get customer_group_path(customer_group)
      expect(response.body).to include('VIP Customers')
    end

    it 'displays customer group code' do
      get customer_group_path(customer_group)
      expect(response.body).to include(customer_group.code)
    end

    it 'displays discount percentage' do
      get customer_group_path(customer_group)
      expect(response.body).to include('20')
    end

    it 'displays products count' do
      get customer_group_path(customer_group)
      expect(response.body).to include('1')
    end

    it 'displays product pricing information' do
      get customer_group_path(customer_group)
      expect(response.body).to include(product.name)
      expect(response.body).to include(product.sku)
    end

    it 'displays active status badge' do
      get customer_group_path(customer_group)
      expect(response.body).to include('Active')
    end

    it 'shows edit button' do
      get customer_group_path(customer_group)
      expect(response.body).to include('Edit')
    end

    it 'shows back button' do
      get customer_group_path(customer_group)
      expect(response.body).to include('Back')
    end

    context 'with no products' do
      let!(:empty_group) { create(:customer_group, company: company, name: 'Empty Group') }

      it 'shows empty state' do
        get customer_group_path(empty_group)
        expect(response.body).to include('No products with group pricing')
      end
    end

    context 'with multiple products' do
      let!(:product2) { create(:product, company: company) }
      let!(:price2) { create(:price, customer_group: customer_group, product: product2, value: 160) }

      it 'displays all products' do
        get customer_group_path(customer_group)
        expect(response.body).to include(product.name)
        expect(response.body).to include(product2.name)
      end

      it 'shows correct products count' do
        get customer_group_path(customer_group)
        expect(response.body).to include('2')
      end
    end
  end

  describe 'GET /customer_groups/new' do
    it 'returns a successful response' do
      get new_customer_group_path
      expect(response).to be_successful
    end
  end

  describe 'POST /customer_groups' do
    let(:valid_attributes) do
      {
        customer_group: {
          name: 'Wholesale',
          code: 'WHOLESALE',
          discount_percent: 15
        }
      }
    end

    it 'creates a new customer group' do
      expect {
        post customer_groups_path, params: valid_attributes
      }.to change(CustomerGroup, :count).by(1)
    end

    it 'redirects to customer groups index' do
      post customer_groups_path, params: valid_attributes
      expect(response).to redirect_to(customer_groups_path)
    end

    it 'sets the correct company' do
      post customer_groups_path, params: valid_attributes
      expect(CustomerGroup.last.company).to eq(company)
    end
  end

  describe 'GET /customer_groups/:id/edit' do
    let!(:customer_group) { create(:customer_group, company: company) }

    it 'returns a successful response' do
      get edit_customer_group_path(customer_group)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /customer_groups/:id' do
    let!(:customer_group) { create(:customer_group, company: company, name: 'Old Name') }

    let(:update_attributes) do
      {
        customer_group: {
          name: 'New Name',
          discount_percent: 25
        }
      }
    end

    it 'updates the customer group' do
      patch customer_group_path(customer_group), params: update_attributes
      customer_group.reload
      expect(customer_group.name).to eq('New Name')
      expect(customer_group.discount_percent).to eq(25)
    end

    it 'redirects to customer groups index' do
      patch customer_group_path(customer_group), params: update_attributes
      expect(response).to redirect_to(customer_groups_path)
    end
  end

  describe 'DELETE /customer_groups/:id' do
    let!(:customer_group) { create(:customer_group, company: company) }

    context 'when customer group has no prices' do
      it 'deletes the customer group' do
        expect {
          delete customer_group_path(customer_group)
        }.to change(CustomerGroup, :count).by(-1)
      end

      it 'redirects to customer groups index' do
        delete customer_group_path(customer_group)
        expect(response).to redirect_to(customer_groups_path)
      end
    end

    context 'when customer group has prices' do
      let!(:product) { create(:product, company: company) }
      let!(:price) { create(:price, customer_group: customer_group, product: product) }

      it 'does not delete the customer group' do
        expect {
          delete customer_group_path(customer_group)
        }.not_to change(CustomerGroup, :count)
      end

      it 'redirects with an alert' do
        delete customer_group_path(customer_group)
        expect(response).to redirect_to(customer_groups_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
