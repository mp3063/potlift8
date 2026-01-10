# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/product_attributes', type: :request do
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

  describe 'GET /index' do
    let!(:group1) { create(:attribute_group, company: company, name: 'Pricing', position: 1) }
    let!(:group2) { create(:attribute_group, company: company, name: 'Dimensions', position: 2) }
    let!(:attr1) { create(:product_attribute, company: company, attribute_group: group1, code: 'price', name: 'Price') }
    let!(:attr2) { create(:product_attribute, company: company, attribute_group: group1, code: 'cost', name: 'Cost') }
    let!(:attr3) { create(:product_attribute, company: company, attribute_group: group2, code: 'weight', name: 'Weight') }
    let!(:ungrouped_attr) { create(:product_attribute, company: company, attribute_group: nil, code: 'sku', name: 'SKU') }
    let!(:other_company_attr) { create(:product_attribute, company: other_company) }

    it 'returns successful response' do
      get product_attributes_path
      expect(response).to be_successful
    end

    it 'displays attribute groups ordered by position' do
      get product_attributes_path
      expect(response.body).to include('Pricing')
      expect(response.body).to include('Dimensions')
    end

    it 'displays grouped attributes' do
      get product_attributes_path
      expect(response.body).to include('Price')
      expect(response.body).to include('Cost')
      expect(response.body).to include('Weight')
    end

    it 'displays ungrouped attributes' do
      get product_attributes_path
      expect(response.body).to include('SKU')
    end

    it 'does not display other company attributes' do
      get product_attributes_path
      expect(response.body).not_to include(other_company_attr.name)
    end

    it 'orders groups by position' do
      get product_attributes_path
      # Pricing (position 1) should appear before Dimensions (position 2)
      expect(response.body.index('Pricing')).to be < response.body.index('Dimensions')
    end
  end

  describe 'GET /show' do
    let(:attribute) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
    let(:other_company_attribute) { create(:product_attribute, company: other_company) }

    it 'returns successful response for own company attribute' do
      get product_attribute_path(attribute.code)
      expect(response).to be_successful
    end

    it 'displays attribute details' do
      get product_attribute_path(attribute.code)
      expect(response.body).to include('Price')
      expect(response.body).to include(attribute.code)
    end

    it 'prevents access to other company attributes' do
      expect {
        get product_attribute_path(other_company_attribute.code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with attribute values' do
      let(:product) { create(:product, company: company, name: 'Test Product') }
      let!(:attribute_value) do
        create(:product_attribute_value,
               product: product,
               product_attribute: attribute,
               value: '1999')
      end

      it 'displays products using this attribute' do
        get product_attribute_path(attribute.code)
        expect(response).to be_successful
        expect(response.body).to include('Test Product')
      end
    end
  end

  describe 'GET /new' do
    it 'returns successful response' do
      get new_product_attribute_path
      expect(response).to be_successful
    end

    it 'displays attribute form' do
      get new_product_attribute_path
      expect(response.body).to include('Name')
      expect(response.body).to include('Code')
      expect(response.body).to include('Type')
    end

    context 'with attribute groups' do
      let!(:group) { create(:attribute_group, company: company, name: 'Pricing') }

      it 'displays attribute groups for selection' do
        get new_product_attribute_path
        expect(response.body).to include('Pricing')
      end
    end
  end

  describe 'GET /edit' do
    let(:attribute) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
    let(:other_company_attribute) { create(:product_attribute, company: other_company) }

    it 'returns successful response for own company attribute' do
      get edit_product_attribute_path(attribute.code)
      expect(response).to be_successful
    end

    it 'displays attribute edit form with values' do
      get edit_product_attribute_path(attribute.code)
      expect(response.body).to include('Price')
      expect(response.body).to include(attribute.code)
    end

    it 'prevents editing other company attributes' do
      expect {
        get edit_product_attribute_path(other_company_attribute.code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /create' do
    let(:group) { create(:attribute_group, company: company) }

    let(:valid_attributes) do
      {
        name: 'Test Attribute',
        code: 'test_attr',
        pa_type: :patype_text,
        view_format: :view_format_general,
        product_attribute_scope: :product_scope,
        mandatory: false
      }
    end

    let(:invalid_attributes) do
      {
        name: '',
        code: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new attribute' do
        expect {
          post product_attributes_path, params: { product_attribute: valid_attributes }
        }.to change(ProductAttribute, :count).by(1)
      end

      it 'assigns attribute to current company' do
        post product_attributes_path, params: { product_attribute: valid_attributes }
        attribute = ProductAttribute.unscoped.last
        expect(attribute.company_id).to eq(company.id)
      end

      it 'redirects to attributes list' do
        post product_attributes_path, params: { product_attribute: valid_attributes }
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute created successfully')
      end

      it 'creates attribute with group' do
        attrs = valid_attributes.merge(attribute_group_id: group.id)
        post product_attributes_path, params: { product_attribute: attrs }

        attribute = ProductAttribute.unscoped.last
        expect(attribute.attribute_group).to eq(group)
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new attribute' do
        expect {
          post product_attributes_path, params: { product_attribute: invalid_attributes }
        }.not_to change(ProductAttribute, :count)
      end

      it 'renders new template with errors' do
        post product_attributes_path, params: { product_attribute: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate code' do
      let!(:existing_attribute) { create(:product_attribute, company: company, code: 'duplicate') }

      it 'does not create attribute with duplicate code' do
        expect {
          post product_attributes_path, params: { product_attribute: valid_attributes.merge(code: 'duplicate') }
        }.not_to change(ProductAttribute, :count)
      end

      it 'shows validation error' do
        post product_attributes_path, params: { product_attribute: valid_attributes.merge(code: 'duplicate') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with options for select type' do
      let(:select_attributes) do
        valid_attributes.merge(
          pa_type: :patype_select,
          view_format: :view_format_selectable,
          options: [ 'Option 1', 'Option 2', 'Option 3' ]
        )
      end

      it 'stores options in info field' do
        post product_attributes_path, params: { product_attribute: select_attributes }

        attribute = ProductAttribute.unscoped.last
        expect(attribute.info['options']).to eq([ 'Option 1', 'Option 2', 'Option 3' ])
      end

      it 'filters out blank options' do
        attrs = select_attributes.merge(options: [ 'Option 1', '', 'Option 2', nil ])
        post product_attributes_path, params: { product_attribute: attrs }

        attribute = ProductAttribute.unscoped.last
        expect(attribute.info['options']).to eq([ 'Option 1', 'Option 2' ])
      end
    end

    context 'with multiselect type' do
      let(:multiselect_attributes) do
        valid_attributes.merge(
          pa_type: :patype_multiselect,
          view_format: :view_format_selectable,
          options: [ 'Tag 1', 'Tag 2', 'Tag 3' ]
        )
      end

      it 'stores options in info field' do
        post product_attributes_path, params: { product_attribute: multiselect_attributes }

        attribute = ProductAttribute.unscoped.last
        expect(attribute.info['options']).to eq([ 'Tag 1', 'Tag 2', 'Tag 3' ])
      end
    end
  end

  describe 'PATCH /update' do
    let(:attribute) { create(:product_attribute, company: company, code: 'old_code', name: 'Old Name') }
    let(:other_company_attribute) { create(:product_attribute, company: other_company) }
    let(:group) { create(:attribute_group, company: company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        mandatory: true
      }
    end

    context 'with valid parameters' do
      it 'updates the attribute' do
        patch product_attribute_path(attribute.code), params: { product_attribute: new_attributes }

        attribute.reload
        expect(attribute.name).to eq('Updated Name')
        expect(attribute.mandatory).to be true
      end

      it 'redirects to attributes list' do
        patch product_attribute_path(attribute.code), params: { product_attribute: new_attributes }
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute updated successfully')
      end

      it 'updates attribute group' do
        patch product_attribute_path(attribute.code), params: {
          product_attribute: new_attributes.merge(attribute_group_id: group.id)
        }

        attribute.reload
        expect(attribute.attribute_group).to eq(group)
      end

      it 'removes attribute from group' do
        attribute.update(attribute_group: group)
        patch product_attribute_path(attribute.code), params: {
          product_attribute: new_attributes.merge(attribute_group_id: nil)
        }

        attribute.reload
        expect(attribute.attribute_group).to be_nil
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template with errors' do
        patch product_attribute_path(attribute.code), params: { product_attribute: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update the attribute' do
        patch product_attribute_path(attribute.code), params: { product_attribute: { name: '' } }

        attribute.reload
        expect(attribute.name).to eq('Old Name')
      end
    end

    context 'with options update' do
      let(:select_attribute) { create(:product_attribute, :select_type, company: company) }
      let(:new_options) { [ 'New Option 1', 'New Option 2' ] }

      it 'updates options in info field' do
        patch product_attribute_path(select_attribute.code), params: {
          product_attribute: { options: new_options }
        }

        select_attribute.reload
        expect(select_attribute.info['options']).to eq(new_options)
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company attributes' do
        expect {
          patch product_attribute_path(other_company_attribute.code), params: { product_attribute: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:attribute) { create(:product_attribute, company: company, code: 'deletable') }
    let(:other_company_attribute) { create(:product_attribute, company: other_company) }

    context 'without attribute values' do
      it 'destroys the attribute' do
        expect {
          delete product_attribute_path(attribute.code)
        }.to change(ProductAttribute, :count).by(-1)
      end

      it 'redirects to attributes list' do
        delete product_attribute_path(attribute.code)
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute deleted successfully')
      end
    end

    context 'with existing attribute values' do
      let(:product) { create(:product, company: company) }

      before do
        create(:product_attribute_value, product: product, product_attribute: attribute, value: 'test')
      end

      it 'does not destroy the attribute' do
        expect {
          delete product_attribute_path(attribute.code)
        }.not_to change(ProductAttribute, :count)
      end

      it 'shows error message' do
        delete product_attribute_path(attribute.code)
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Cannot delete attribute with existing values')
      end
    end

    context 'multi-tenant security' do
      it 'prevents deleting other company attributes' do
        expect {
          delete product_attribute_path(other_company_attribute.code)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PATCH /reorder' do
    let!(:attr1) { create(:product_attribute, company: company, attribute_position: 1) }
    let!(:attr2) { create(:product_attribute, company: company, attribute_position: 2) }
    let!(:attr3) { create(:product_attribute, company: company, attribute_position: 3) }

    it 'updates attribute positions' do
      new_order = [ attr3.id, attr1.id, attr2.id ]
      patch reorder_product_attributes_path, params: { order: new_order }

      expect(response).to have_http_status(:ok)

      attr1.reload
      attr2.reload
      attr3.reload

      expect(attr3.attribute_position).to eq(1)
      expect(attr1.attribute_position).to eq(2)
      expect(attr2.attribute_position).to eq(3)
    end

    it 'only reorders current company attributes' do
      other_attr = create(:product_attribute, company: other_company, attribute_position: 1)
      new_order = [ attr2.id, attr1.id, attr3.id ]

      patch reorder_product_attributes_path, params: { order: new_order }

      other_attr.reload
      expect(other_attr.attribute_position).to eq(1) # Unchanged
    end

    it 'handles missing attributes gracefully' do
      new_order = [ attr1.id, 99999, attr2.id ]

      expect {
        patch reorder_product_attributes_path, params: { order: new_order }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /validate_code' do
    let!(:existing_attribute) { create(:product_attribute, company: company, code: 'existing_code') }

    context 'with valid code format' do
      it 'returns valid for available code' do
        get validate_code_product_attributes_path, params: { code: 'new_code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be true
      end

      it 'returns invalid for existing code' do
        get validate_code_product_attributes_path, params: { code: 'existing_code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
        expect(json['message']).to eq('Code already exists')
      end

      it 'allows same code when editing same attribute' do
        get validate_code_product_attributes_path, params: {
          code: 'existing_code',
          id: existing_attribute.id
        }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be true
      end

      it 'is case insensitive' do
        get validate_code_product_attributes_path, params: { code: 'EXISTING_CODE' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end
    end

    context 'with invalid code format' do
      it 'rejects uppercase letters' do
        get validate_code_product_attributes_path, params: { code: 'InvalidCode' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
        expect(json['message']).to include('lowercase letters, numbers, and underscores')
      end

      it 'rejects spaces' do
        get validate_code_product_attributes_path, params: { code: 'invalid code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end

      it 'rejects hyphens' do
        get validate_code_product_attributes_path, params: { code: 'invalid-code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end

      it 'rejects special characters' do
        get validate_code_product_attributes_path, params: { code: 'invalid@code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be false
      end
    end

    context 'multi-tenant scoping' do
      let!(:other_company_attribute) { create(:product_attribute, company: other_company, code: 'other_code') }

      it 'allows code that exists in other company' do
        get validate_code_product_attributes_path, params: { code: 'other_code' }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['valid']).to be true
      end
    end
  end

  describe 'authentication requirements' do
    before do
      # Reset authentication mocks
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(nil)
    end

    it 'requires authentication for index' do
      get product_attributes_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post product_attributes_path, params: { product_attribute: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      attribute = create(:product_attribute, company: company)
      patch product_attribute_path(attribute.code), params: { product_attribute: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      attribute = create(:product_attribute, company: company)
      delete product_attribute_path(attribute.code)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for reorder' do
      patch reorder_product_attributes_path, params: { order: [ 1, 2, 3 ] }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for validate_code' do
      get validate_code_product_attributes_path, params: { code: 'test' }
      expect(response).to redirect_to(auth_login_path)
    end
  end
end
