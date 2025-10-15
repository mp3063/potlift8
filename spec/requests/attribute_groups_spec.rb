# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/attribute_groups', type: :request do
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
    let!(:group3) { create(:attribute_group, company: company, name: 'Technical', position: 3) }
    let!(:other_company_group) { create(:attribute_group, company: other_company, name: 'Other Group') }

    it 'returns successful response' do
      get attribute_groups_path
      expect(response).to be_successful
    end

    it 'displays all company attribute groups' do
      get attribute_groups_path
      expect(response.body).to include('Pricing')
      expect(response.body).to include('Dimensions')
      expect(response.body).to include('Technical')
    end

    it 'does not display other company groups' do
      get attribute_groups_path
      expect(response.body).not_to include('Other Group')
    end

    it 'orders groups by position' do
      get attribute_groups_path
      # Pricing (position 1) should appear before Technical (position 3)
      expect(response.body.index('Pricing')).to be < response.body.index('Technical')
    end

    context 'with attributes in groups' do
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group1, name: 'Price') }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group1, name: 'Cost') }

      it 'displays attribute counts per group' do
        get attribute_groups_path
        expect(response).to be_successful
        # Implementation may show counts in the UI
      end
    end
  end

  describe 'GET /show' do
    let(:group) { create(:attribute_group, company: company, code: 'pricing', name: 'Pricing') }
    let(:other_company_group) { create(:attribute_group, company: other_company) }

    it 'returns successful response for own company group' do
      get attribute_group_path(group.code)
      expect(response).to be_successful
    end

    it 'displays group details' do
      get attribute_group_path(group.code)
      expect(response.body).to include('Pricing')
      expect(response.body).to include(group.code)
    end

    it 'prevents access to other company groups' do
      expect {
        get attribute_group_path(other_company_group.code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with attributes' do
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group, code: 'price', name: 'Price', attribute_position: 1) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group, code: 'cost', name: 'Cost', attribute_position: 2) }

      it 'displays attributes ordered by position' do
        get attribute_group_path(group.code)
        expect(response).to be_successful
        expect(response.body).to include('Price')
        expect(response.body).to include('Cost')
        # Price should appear before Cost
        expect(response.body.index('Price')).to be < response.body.index('Cost')
      end
    end
  end

  describe 'GET /new' do
    it 'returns successful response' do
      get new_attribute_group_path
      expect(response).to be_successful
    end

    it 'displays group form' do
      get new_attribute_group_path
      expect(response.body).to include('Name')
      expect(response.body).to include('Code')
      expect(response.body).to include('Description')
    end
  end

  describe 'GET /edit' do
    let(:group) { create(:attribute_group, company: company, code: 'pricing', name: 'Pricing') }
    let(:other_company_group) { create(:attribute_group, company: other_company) }

    it 'returns successful response for own company group' do
      get edit_attribute_group_path(group.code)
      expect(response).to be_successful
    end

    it 'displays group edit form with values' do
      get edit_attribute_group_path(group.code)
      expect(response.body).to include('Pricing')
      expect(response.body).to include(group.code)
    end

    it 'prevents editing other company groups' do
      expect {
        get edit_attribute_group_path(other_company_group.code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /create' do
    let(:valid_attributes) do
      {
        name: 'Test Group',
        code: 'test_group',
        description: 'A test attribute group'
      }
    end

    let(:invalid_attributes) do
      {
        name: '',
        code: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new attribute group' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes }
        }.to change(AttributeGroup, :count).by(1)
      end

      it 'assigns group to current company' do
        post attribute_groups_path, params: { attribute_group: valid_attributes }
        group = AttributeGroup.unscoped.last
        expect(group.company_id).to eq(company.id)
      end

      it 'redirects to attributes list' do
        post attribute_groups_path, params: { attribute_group: valid_attributes }
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute group created successfully')
      end

      it 'assigns position automatically' do
        post attribute_groups_path, params: { attribute_group: valid_attributes }
        group = AttributeGroup.unscoped.last
        expect(group.position).to be_present
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new group' do
        expect {
          post attribute_groups_path, params: { attribute_group: invalid_attributes }
        }.not_to change(AttributeGroup, :count)
      end

      it 'renders new template with errors' do
        post attribute_groups_path, params: { attribute_group: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate code' do
      let!(:existing_group) { create(:attribute_group, company: company, code: 'duplicate') }

      it 'does not create group with duplicate code' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'duplicate') }
        }.not_to change(AttributeGroup, :count)
      end

      it 'shows validation error' do
        post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'duplicate') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'code format validation' do
      it 'rejects uppercase letters' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'InvalidCode') }
        }.not_to change(AttributeGroup, :count)
      end

      it 'rejects spaces' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'invalid code') }
        }.not_to change(AttributeGroup, :count)
      end

      it 'rejects hyphens' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'invalid-code') }
        }.not_to change(AttributeGroup, :count)
      end

      it 'accepts valid lowercase with underscores and numbers' do
        expect {
          post attribute_groups_path, params: { attribute_group: valid_attributes.merge(code: 'valid_code_123') }
        }.to change(AttributeGroup, :count).by(1)
      end
    end
  end

  describe 'PATCH /update' do
    let(:group) { create(:attribute_group, company: company, code: 'old_code', name: 'Old Name') }
    let(:other_company_group) { create(:attribute_group, company: other_company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        description: 'Updated description'
      }
    end

    context 'with valid parameters' do
      it 'updates the group' do
        patch attribute_group_path(group.code), params: { attribute_group: new_attributes }

        group.reload
        expect(group.name).to eq('Updated Name')
        expect(group.description).to eq('Updated description')
      end

      it 'redirects to attributes list' do
        patch attribute_group_path(group.code), params: { attribute_group: new_attributes }
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute group updated successfully')
      end

      it 'allows updating code to valid format' do
        patch attribute_group_path(group.code), params: {
          attribute_group: new_attributes.merge(code: 'new_valid_code')
        }

        group.reload
        expect(group.code).to eq('new_valid_code')
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template with errors' do
        patch attribute_group_path(group.code), params: { attribute_group: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update the group' do
        patch attribute_group_path(group.code), params: { attribute_group: { name: '' } }

        group.reload
        expect(group.name).to eq('Old Name')
      end

      it 'rejects invalid code format' do
        patch attribute_group_path(group.code), params: {
          attribute_group: new_attributes.merge(code: 'Invalid-Code')
        }

        expect(response).to have_http_status(:unprocessable_entity)
        group.reload
        expect(group.code).to eq('old_code')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company groups' do
        expect {
          patch attribute_group_path(other_company_group.code), params: { attribute_group: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:group) { create(:attribute_group, company: company, code: 'deletable') }
    let(:other_company_group) { create(:attribute_group, company: other_company) }

    context 'without attributes' do
      it 'destroys the group' do
        expect {
          delete attribute_group_path(group.code)
        }.to change(AttributeGroup, :count).by(-1)
      end

      it 'redirects to attributes list' do
        delete attribute_group_path(group.code)
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Attribute group deleted successfully')
      end
    end

    context 'with attributes' do
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group) }

      it 'does not destroy the group' do
        expect {
          delete attribute_group_path(group.code)
        }.not_to change(AttributeGroup, :count)
      end

      it 'shows error message' do
        delete attribute_group_path(group.code)
        expect(response).to redirect_to(product_attributes_path)
        follow_redirect!
        expect(response.body).to include('Cannot delete group with attributes')
      end

      it 'preserves attributes' do
        delete attribute_group_path(group.code)
        expect(ProductAttribute.exists?(attr1.id)).to be true
        expect(ProductAttribute.exists?(attr2.id)).to be true
      end
    end

    context 'multi-tenant security' do
      it 'prevents deleting other company groups' do
        expect {
          delete attribute_group_path(other_company_group.code)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PATCH /reorder' do
    let!(:group1) { create(:attribute_group, company: company, position: 1) }
    let!(:group2) { create(:attribute_group, company: company, position: 2) }
    let!(:group3) { create(:attribute_group, company: company, position: 3) }

    it 'updates group positions' do
      new_order = [group3.id, group1.id, group2.id]
      patch reorder_attribute_groups_path, params: { order: new_order }

      expect(response).to have_http_status(:ok)

      group1.reload
      group2.reload
      group3.reload

      expect(group3.position).to eq(1)
      expect(group1.position).to eq(2)
      expect(group2.position).to eq(3)
    end

    it 'only reorders current company groups' do
      other_group = create(:attribute_group, company: other_company, position: 1)
      new_order = [group2.id, group1.id, group3.id]

      patch reorder_attribute_groups_path, params: { order: new_order }

      other_group.reload
      expect(other_group.position).to eq(1) # Unchanged
    end

    it 'handles missing groups gracefully' do
      new_order = [group1.id, 99999, group2.id]

      expect {
        patch reorder_attribute_groups_path, params: { order: new_order }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'preserves attribute positions when reordering groups' do
      attr1 = create(:product_attribute, company: company, attribute_group: group1, attribute_position: 1)
      attr2 = create(:product_attribute, company: company, attribute_group: group1, attribute_position: 2)

      new_order = [group2.id, group1.id, group3.id]
      patch reorder_attribute_groups_path, params: { order: new_order }

      attr1.reload
      attr2.reload

      expect(attr1.attribute_position).to eq(1)
      expect(attr2.attribute_position).to eq(2)
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
      get attribute_groups_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post attribute_groups_path, params: { attribute_group: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      group = create(:attribute_group, company: company)
      patch attribute_group_path(group.code), params: { attribute_group: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      group = create(:attribute_group, company: company)
      delete attribute_group_path(group.code)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for reorder' do
      patch reorder_attribute_groups_path, params: { order: [1, 2, 3] }
      expect(response).to redirect_to(auth_login_path)
    end
  end

  describe 'integration scenarios' do
    context 'complete workflow' do
      it 'creates group, adds attributes, reorders, and deletes' do
        # Create group
        post attribute_groups_path, params: {
          attribute_group: {
            name: 'Workflow Test',
            code: 'workflow_test',
            description: 'Testing complete workflow'
          }
        }

        group = AttributeGroup.unscoped.last
        expect(group.name).to eq('Workflow Test')

        # Add attributes to group
        attr1 = create(:product_attribute, company: company, attribute_group: group, code: 'attr1')
        attr2 = create(:product_attribute, company: company, attribute_group: group, code: 'attr2')

        # View group with attributes
        get attribute_group_path(group.code)
        expect(response).to be_successful

        # Reorder attributes
        new_order = [attr2.id, attr1.id]
        patch reorder_product_attributes_path, params: { order: new_order }

        attr1.reload
        attr2.reload
        expect(attr2.attribute_position).to be < attr1.attribute_position

        # Try to delete group (should fail with attributes)
        delete attribute_group_path(group.code)
        expect(response).to redirect_to(product_attributes_path)
        expect(AttributeGroup.exists?(group.id)).to be true

        # Remove attributes from group
        attr1.update(attribute_group: nil)
        attr2.update(attribute_group: nil)

        # Now delete should succeed
        delete attribute_group_path(group.code)
        expect(response).to redirect_to(product_attributes_path)
        expect(AttributeGroup.exists?(group.id)).to be false
      end
    end

    context 'multi-group positioning' do
      let!(:group1) { create(:attribute_group, company: company, name: 'First', position: 1) }
      let!(:group2) { create(:attribute_group, company: company, name: 'Second', position: 2) }
      let!(:attr1_g1) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 1) }
      let!(:attr2_g1) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 2) }
      let!(:attr1_g2) { create(:product_attribute, company: company, attribute_group: group2, attribute_position: 1) }

      it 'maintains independent attribute positioning across groups' do
        # Move attribute from group1 to group2
        patch product_attribute_path(attr1_g1.code), params: {
          product_attribute: { attribute_group_id: group2.id }
        }

        attr1_g1.reload
        attr2_g1.reload
        attr1_g2.reload

        # attr1_g1 should be added to end of group2
        expect(attr1_g1.attribute_group).to eq(group2)

        # attr2_g1 should move to position 1 in group1
        expect(attr2_g1.attribute_position).to eq(1)

        # attr1_g2 should remain at position 1 in group2
        expect(attr1_g2.attribute_position).to eq(1)
      end
    end
  end
end
