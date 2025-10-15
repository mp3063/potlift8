# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/labels', type: :request do
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
    let!(:root1) { create(:label, company: company, code: 'electronics', name: 'Electronics', label_positions: 1) }
    let!(:root2) { create(:label, company: company, code: 'clothing', name: 'Clothing', label_positions: 2) }
    let!(:root3) { create(:label, company: company, code: 'food', name: 'Food', label_positions: 3) }
    let!(:child1) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: root1, label_positions: 1) }
    let!(:other_company_label) { create(:label, company: other_company, name: 'Other Label') }

    context 'without parent_id (root labels)' do
      it 'returns successful response' do
        get labels_path
        expect(response).to be_successful
      end

      it 'displays all company root labels' do
        get labels_path
        expect(response.body).to include('Electronics')
        expect(response.body).to include('Clothing')
        expect(response.body).to include('Food')
      end

      it 'includes child labels in tree structure (hidden by default)' do
        get labels_path
        # Child labels are included in HTML for tree functionality but hidden
        expect(response.body).to include('Phones')
        expect(response.body).to include('class="hidden"')
      end

      it 'does not display other company labels' do
        get labels_path
        expect(response.body).not_to include('Other Label')
      end

      it 'orders labels by label_positions' do
        get labels_path
        # Electronics (position 1) should appear before Food (position 3)
        expect(response.body.index('Electronics')).to be < response.body.index('Food')
      end
    end

    context 'with parent_id (sublabels)' do
      let!(:child2) { create(:label, company: company, code: 'laptops', name: 'Laptops', parent_label: root1, label_positions: 2) }

      it 'returns successful response' do
        get labels_path, params: { parent_id: root1.id }
        expect(response).to be_successful
      end

      it 'displays sublabels of parent' do
        get labels_path, params: { parent_id: root1.id }
        expect(response.body).to include('Phones')
        expect(response.body).to include('Laptops')
      end

      it 'does not display root labels' do
        get labels_path, params: { parent_id: root1.id }
        expect(response.body).not_to include('Clothing')
      end

      it 'does not display labels from other parents' do
        get labels_path, params: { parent_id: root1.id }
        expect(response.body).not_to include('Electronics')
      end
    end

    context 'with search query' do
      it 'filters labels by name' do
        get labels_path, params: { q: 'Electronics' }
        expect(response).to be_successful
        expect(response.body).to include('Electronics')
        expect(response.body).not_to include('Clothing')
      end

      it 'filters labels by code' do
        get labels_path, params: { q: 'food' }
        expect(response).to be_successful
        expect(response.body).to include('Food')
      end

      it 'is case insensitive' do
        get labels_path, params: { q: 'ELECTRONICS' }
        expect(response).to be_successful
        expect(response.body).to include('Electronics')
      end
    end
  end

  describe 'GET /show' do
    let(:label) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
    let(:other_company_label) { create(:label, company: other_company) }
    let!(:sublabel1) { create(:label, company: company, parent_label: label, name: 'Phones') }
    let!(:sublabel2) { create(:label, company: company, parent_label: label, name: 'Laptops') }
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }

    before do
      create(:product_label, label: label, product: product1)
      create(:product_label, label: label, product: product2)
    end

    it 'returns successful response for own company label' do
      get label_path(label.full_code)
      expect(response).to be_successful
    end

    it 'displays label details' do
      get label_path(label.full_code)
      expect(response.body).to include('Electronics')
    end

    it 'displays sublabels' do
      get label_path(label.full_code)
      expect(response.body).to include('Phones')
      expect(response.body).to include('Laptops')
    end

    it 'displays associated products' do
      get label_path(label.full_code)
      expect(response.body).to include(product1.name)
      expect(response.body).to include(product2.name)
    end

    it 'prevents access to other company labels' do
      expect {
        get label_path(other_company_label.full_code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /new' do
    it 'returns successful response' do
      get new_label_path
      expect(response).to be_successful
    end

    it 'displays label form' do
      get new_label_path
      expect(response.body).to include('Name')
      expect(response.body).to include('Code')
    end

    context 'with parent_id' do
      let(:parent_label) { create(:label, company: company, name: 'Parent') }

      it 'returns successful response' do
        get new_label_path, params: { parent_id: parent_label.id }
        expect(response).to be_successful
      end

      it 'displays parent context' do
        get new_label_path, params: { parent_id: parent_label.id }
        expect(response.body).to include('Parent')
      end
    end
  end

  describe 'GET /edit' do
    let(:label) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
    let(:other_company_label) { create(:label, company: other_company) }

    it 'returns successful response for own company label' do
      get edit_label_path(label.full_code)
      expect(response).to be_successful
    end

    it 'displays label edit form with values' do
      get edit_label_path(label.full_code)
      expect(response.body).to include('Electronics')
      expect(response.body).to include(label.code)
    end

    it 'prevents editing other company labels' do
      expect {
        get edit_label_path(other_company_label.full_code)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /create' do
    let(:valid_attributes) do
      {
        name: 'Test Label',
        code: 'test_label',
        label_type: 'category',
        description: 'A test label'
      }
    end

    let(:invalid_attributes) do
      {
        name: '',
        code: '',
        label_type: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new label' do
        expect {
          post labels_path, params: { label: valid_attributes }
        }.to change(Label, :count).by(1)
      end

      it 'assigns label to current company' do
        post labels_path, params: { label: valid_attributes }
        label = Label.unscoped.last
        expect(label.company_id).to eq(company.id)
      end

      it 'redirects to labels list' do
        post labels_path, params: { label: valid_attributes }
        expect(response).to redirect_to(labels_path)
        follow_redirect!
        expect(response.body).to include('Label')
        expect(response.body).to include('created successfully')
      end

      it 'generates full_code and full_name' do
        post labels_path, params: { label: valid_attributes }
        label = Label.unscoped.last
        expect(label.full_code).to eq('test_label')
        expect(label.full_name).to eq('Test Label')
      end

      context 'with parent label' do
        let(:parent) { create(:label, company: company, code: 'parent', name: 'Parent') }

        it 'creates child label with hierarchical codes' do
          post labels_path, params: {
            label: valid_attributes.merge(parent_label_id: parent.id)
          }

          label = Label.unscoped.last
          expect(label.parent_label).to eq(parent)
          expect(label.full_code).to eq('parent-test_label')
          expect(label.full_name).to eq('Parent > Test Label')
        end

        it 'inherits company from parent' do
          post labels_path, params: {
            label: valid_attributes.except(:company_id).merge(parent_label_id: parent.id)
          }

          label = Label.unscoped.last
          expect(label.company).to eq(parent.company)
        end
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new label' do
        expect {
          post labels_path, params: { label: invalid_attributes }
        }.not_to change(Label, :count)
      end

      it 'renders new template with errors' do
        post labels_path, params: { label: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with duplicate full_code' do
      let!(:existing_label) { create(:label, company: company, code: 'duplicate', name: 'Duplicate') }

      it 'does not create label with duplicate full_code' do
        expect {
          post labels_path, params: { label: valid_attributes.merge(code: 'duplicate') }
        }.not_to change(Label, :count)
      end

      it 'shows validation error' do
        post labels_path, params: { label: valid_attributes.merge(code: 'duplicate') }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /update' do
    let(:label) { create(:label, company: company, code: 'old_code', name: 'Old Name') }
    let(:other_company_label) { create(:label, company: other_company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        description: 'Updated description'
      }
    end

    context 'with valid parameters' do
      it 'updates the label' do
        patch label_path(label.full_code), params: { label: new_attributes }

        label.reload
        expect(label.name).to eq('Updated Name')
        expect(label.description).to eq('Updated description')
      end

      it 'updates full_name when name changes' do
        patch label_path(label.full_code), params: { label: new_attributes }

        label.reload
        expect(label.full_name).to eq('Updated Name')
      end

      it 'redirects to labels list' do
        patch label_path(label.full_code), params: { label: new_attributes }
        expect(response).to redirect_to(labels_path)
        follow_redirect!
        expect(response.body).to include('updated successfully')
      end

      context 'changing parent label' do
        let(:new_parent) { create(:label, company: company, code: 'new_parent', name: 'New Parent') }
        let(:child) { create(:label, company: company, code: 'child', name: 'Child', parent_label: label) }

        it 'updates label hierarchy' do
          patch label_path(label.full_code), params: {
            label: { parent_label_id: new_parent.id }
          }

          label.reload
          expect(label.parent_label).to eq(new_parent)
          expect(label.full_code).to eq('new_parent-old_code')
        end

        it 'cascades changes to children' do
          child # Create child before update
          patch label_path(label.full_code), params: {
            label: { parent_label_id: new_parent.id }
          }

          child.reload
          expect(child.full_code).to eq('new_parent-old_code-child')
        end
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template with errors' do
        patch label_path(label.full_code), params: { label: { name: '' } }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not update the label' do
        patch label_path(label.full_code), params: { label: { name: '' } }

        label.reload
        expect(label.name).to eq('Old Name')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company labels' do
        expect {
          patch label_path(other_company_label.full_code), params: { label: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:label) { create(:label, company: company, code: 'deletable') }
    let(:other_company_label) { create(:label, company: other_company) }

    context 'without sublabels or products' do
      it 'destroys the label' do
        expect {
          delete label_path(label.full_code)
        }.to change(Label, :count).by(-1)
      end

      it 'redirects to labels list' do
        delete label_path(label.full_code)
        expect(response).to redirect_to(labels_path)
        follow_redirect!
        expect(response.body).to include('deleted successfully')
      end
    end

    context 'with sublabels' do
      let!(:child1) { create(:label, company: company, parent_label: label) }
      let!(:child2) { create(:label, company: company, parent_label: label) }

      it 'does not destroy the label' do
        expect {
          delete label_path(label.full_code)
        }.not_to change(Label, :count)
      end

      it 'shows error message about sublabels' do
        delete label_path(label.full_code)
        expect(response).to redirect_to(labels_path)
        follow_redirect!
        expect(response.body).to include('Cannot delete')
        expect(response.body).to include('sublabel')
      end

      it 'preserves sublabels' do
        delete label_path(label.full_code)
        expect(Label.exists?(child1.id)).to be true
        expect(Label.exists?(child2.id)).to be true
      end
    end

    context 'with products' do
      let!(:product1) { create(:product, company: company) }
      let!(:product2) { create(:product, company: company) }

      before do
        create(:product_label, label: label, product: product1)
        create(:product_label, label: label, product: product2)
      end

      it 'does not destroy the label' do
        expect {
          delete label_path(label.full_code)
        }.not_to change(Label, :count)
      end

      it 'shows error message about products' do
        delete label_path(label.full_code)
        expect(response).to redirect_to(labels_path)
        follow_redirect!
        expect(response.body).to include('Cannot delete')
        expect(response.body).to include('product')
      end

      it 'preserves products' do
        delete label_path(label.full_code)
        expect(Product.exists?(product1.id)).to be true
        expect(Product.exists?(product2.id)).to be true
      end
    end

    context 'multi-tenant security' do
      it 'prevents deleting other company labels' do
        expect {
          delete label_path(other_company_label.full_code)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'PATCH /reorder' do
    context 'reordering root labels' do
      let!(:label1) { create(:label, company: company, label_positions: 1) }
      let!(:label2) { create(:label, company: company, label_positions: 2) }
      let!(:label3) { create(:label, company: company, label_positions: 3) }

      it 'updates label positions' do
        new_order = [label3.id, label1.id, label2.id]
        patch reorder_labels_path, params: { order: new_order }, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)['success']).to be true

        label1.reload
        label2.reload
        label3.reload

        expect(label3.label_positions).to eq(0)
        expect(label1.label_positions).to eq(1)
        expect(label2.label_positions).to eq(2)
      end

      it 'only reorders current company labels' do
        other_label = create(:label, company: other_company, label_positions: 1)
        new_order = [label2.id, label1.id, label3.id]

        patch reorder_labels_path, params: { order: new_order }, as: :json

        other_label.reload
        expect(other_label.label_positions).to eq(1) # Unchanged
      end
    end

    context 'reordering sublabels' do
      let(:parent) { create(:label, company: company) }
      let!(:child1) { create(:label, company: company, parent_label: parent, label_positions: 1) }
      let!(:child2) { create(:label, company: company, parent_label: parent, label_positions: 2) }
      let!(:child3) { create(:label, company: company, parent_label: parent, label_positions: 3) }

      it 'updates sublabel positions within parent' do
        new_order = [child3.id, child1.id, child2.id]
        patch reorder_labels_path, params: { order: new_order, parent_id: parent.id }, as: :json

        expect(response).to have_http_status(:ok)

        child1.reload
        child2.reload
        child3.reload

        expect(child3.label_positions).to eq(0)
        expect(child1.label_positions).to eq(1)
        expect(child2.label_positions).to eq(2)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for missing order array' do
        patch reorder_labels_path, params: { order: nil }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['success']).to be false
        expect(JSON.parse(response.body)['message']).to include('Invalid order array')
      end

      it 'returns error for non-array order' do
        patch reorder_labels_path, params: { order: 'not-an-array' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['success']).to be false
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
      get labels_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for show' do
      label = create(:label, company: company)
      get label_path(label.full_code)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post labels_path, params: { label: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      label = create(:label, company: company)
      patch label_path(label.full_code), params: { label: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      label = create(:label, company: company)
      delete label_path(label.full_code)
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for reorder' do
      patch reorder_labels_path, params: { order: [1, 2, 3] }, as: :json
      expect(response).to redirect_to(auth_login_path)
    end
  end

  describe 'integration scenarios' do
    context 'hierarchical structure' do
      it 'creates and maintains hierarchy' do
        # Create root label
        post labels_path, params: {
          label: {
            name: 'Electronics',
            code: 'electronics',
            label_type: 'category'
          }
        }

        root = Label.unscoped.last
        expect(root.full_code).to eq('electronics')

        # Create child label
        post labels_path, params: {
          label: {
            name: 'Phones',
            code: 'phones',
            label_type: 'category',
            parent_label_id: root.id
          }
        }

        child = Label.unscoped.last
        expect(child.full_code).to eq('electronics-phones')
        expect(child.full_name).to eq('Electronics > Phones')

        # Create grandchild label
        post labels_path, params: {
          label: {
            name: 'iPhone',
            code: 'iphone',
            label_type: 'category',
            parent_label_id: child.id
          }
        }

        grandchild = Label.unscoped.last
        expect(grandchild.full_code).to eq('electronics-phones-iphone')
        expect(grandchild.full_name).to eq('Electronics > Phones > iPhone')
      end
    end

    context 'complete workflow' do
      it 'creates label, adds products, reorders, and deletes' do
        # Create label
        post labels_path, params: {
          label: {
            name: 'Workflow Test',
            code: 'workflow_test',
            label_type: 'category'
          }
        }

        label = Label.unscoped.last
        expect(label.name).to eq('Workflow Test')

        # Create products and associate with label
        product1 = create(:product, company: company)
        product2 = create(:product, company: company)
        create(:product_label, label: label, product: product1)
        create(:product_label, label: label, product: product2)

        # View label with products
        get label_path(label.full_code)
        expect(response).to be_successful

        # Try to delete label (should fail with products)
        delete label_path(label.full_code)
        expect(response).to redirect_to(labels_path)
        expect(Label.exists?(label.id)).to be true

        # Remove products from label
        ProductLabel.where(label: label).destroy_all

        # Now delete should succeed
        delete label_path(label.full_code)
        expect(response).to redirect_to(labels_path)
        expect(Label.exists?(label.id)).to be false
      end
    end
  end
end
