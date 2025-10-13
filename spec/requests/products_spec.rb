# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/products', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    # Set up authenticated session using session helper
    # This works in request specs by making a request that sets up session
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
    let!(:product1) { create(:product, company: company, sku: 'PROD001', name: 'Product Alpha') }
    let!(:product2) { create(:product, company: company, sku: 'PROD002', name: 'Product Beta') }
    let!(:product3) { create(:product, company: company, sku: 'PROD003', name: 'Product Gamma', product_status: :draft) }
    let!(:other_product) { create(:product, company: other_company, sku: 'OTHER001', name: 'Other Product') }

    it 'returns successful response' do
      get products_path
      expect(response).to be_successful
    end

    it 'displays only current company products' do
      get products_path
      expect(response.body).to include('Product Alpha')
      expect(response.body).to include('Product Beta')
      expect(response.body).to include('Product Gamma')
      expect(response.body).not_to include('Other Product')
    end

    context 'with search query filter' do
      it 'filters products by name' do
        get products_path, params: { q: 'Alpha' }

        expect(response).to be_successful
        expect(response.body).to include('Product Alpha')
        expect(response.body).not_to include('Product Beta')
      end

      it 'filters products by SKU' do
        get products_path, params: { q: 'PROD002' }

        expect(response).to be_successful
        expect(response.body).to include('Product Beta')
        expect(response.body).not_to include('Product Alpha')
      end

      it 'search is case insensitive' do
        get products_path, params: { q: 'alpha' }

        expect(response).to be_successful
        expect(response.body).to include('Product Alpha')
      end
    end

    context 'with status filter' do
      it 'filters products by status' do
        get products_path, params: { status: 'active' }

        expect(response).to be_successful
        expect(response.body).to include('Product Alpha')
        expect(response.body).not_to include('Product Gamma') # draft
      end
    end

    context 'with label filter' do
      let(:label1) { create(:label, company: company, code: 'electronics', name: 'Electronics') }
      let(:label2) { create(:label, company: company, code: 'clothing', name: 'Clothing') }

      before do
        create(:product_label, product: product1, label: label1)
        create(:product_label, product: product2, label: label2)
      end

      it 'filters products by label' do
        get products_path, params: { label_id: label1.id }

        expect(response).to be_successful
        expect(response.body).to include('Product Alpha')
        expect(response.body).not_to include('Product Beta')
      end
    end

    context 'with sorting' do
      it 'sorts by SKU ascending' do
        get products_path, params: { sort: 'sku', direction: 'asc' }
        expect(response).to be_successful
        # Check that PROD001 appears before PROD002 in the response
        expect(response.body.index('PROD001')).to be < response.body.index('PROD002')
      end

      it 'sorts by name descending' do
        get products_path, params: { sort: 'name', direction: 'desc' }
        expect(response).to be_successful
        # Gamma should come before Alpha when descending
        expect(response.body.index('Gamma')).to be < response.body.index('Alpha')
      end

      it 'defaults to created_at desc when no sort specified' do
        get products_path
        expect(response).to be_successful
        # Most recently created (product3) should appear first
        expect(response.body.index('PROD003')).to be < response.body.index('PROD001')
      end
    end

    context 'with pagination' do
      before do
        # Create 30 products for pagination testing
        28.times do |i|
          create(:product, company: company, sku: "BULK#{i.to_s.rjust(3, '0')}", name: "Bulk Product #{i}")
        end
      end

      it 'paginates results with default per_page (25)' do
        get products_path

        expect(response).to be_successful
        expect(response.body).to include('Showing')
        expect(response.body).to include('of 31') # 3 original + 28 bulk
      end

      it 'respects per_page parameter' do
        get products_path, params: { per_page: 10 }

        expect(response).to be_successful
        expect(response.body).to include('1') # page indicator
        expect(response.body).to include('to')
        expect(response.body).to include('10') # showing 10 per page
      end

      it 'navigates to second page' do
        get products_path, params: { page: 2, per_page: 10 }

        expect(response).to be_successful
        expect(response.body).to include('11') # starting from 11th item
      end
    end

    context 'CSV export' do
      it 'exports products as CSV' do
        get products_path(format: :csv)

        expect(response).to be_successful
        expect(response.content_type).to eq('text/csv')
        expect(response.headers['Content-Disposition']).to match(/attachment/)
        expect(response.headers['Content-Disposition']).to match(/products_\d{8}_\d{6}\.csv/)
      end

      it 'includes correct CSV headers' do
        get products_path(format: :csv)

        csv_content = response.body
        headers = csv_content.lines.first.strip

        expect(headers).to include('SKU')
        expect(headers).to include('Name')
        expect(headers).to include('Product Type')
        expect(headers).to include('Active')
      end

      it 'exports filtered results' do
        get products_path(format: :csv), params: { q: 'Alpha' }

        csv_content = response.body
        expect(csv_content).to include('Product Alpha')
        expect(csv_content).not_to include('Product Beta')
      end
    end

    context 'multi-tenant security' do
      it 'does not show other company products' do
        get products_path

        expect(response).to be_successful
        # Parse product IDs from response to ensure other_product is not included
        expect(response.body).not_to include(other_product.id.to_s)
        expect(response.body).not_to include('OTHER001')
      end
    end
  end

  describe 'GET /show' do
    let(:product) { create(:product, company: company, sku: 'SHOW001', name: 'Show Product') }
    let(:other_company_product) { create(:product, company: other_company) }

    it 'returns successful response for own company product' do
      get product_path(product)
      expect(response).to be_successful
    end

    it 'displays product details' do
      get product_path(product)

      expect(response.body).to include('SHOW001')
      expect(response.body).to include('Show Product')
    end

    it 'prevents access to other company products' do
      expect {
        get product_path(other_company_product)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with attributes' do
      let(:product_attribute) { create(:product_attribute, company: company, code: 'price', name: 'Price') }
      let!(:attribute_value) do
        create(:product_attribute_value,
               product: product,
               product_attribute: product_attribute,
               value: '1999')
      end

      it 'displays product attribute values' do
        get product_path(product)

        expect(response).to be_successful
        expect(response.body).to include('Price')
        expect(response.body).to include('1999')
      end
    end
  end

  describe 'GET /new' do
    it 'returns successful response' do
      get new_product_path
      expect(response).to be_successful
    end

    it 'displays product form' do
      get new_product_path

      expect(response.body).to include('SKU')
      expect(response.body).to include('Name')
      expect(response.body).to include('Product Type')
    end
  end

  describe 'GET /edit' do
    let(:product) { create(:product, company: company) }
    let(:other_company_product) { create(:product, company: other_company) }

    it 'returns successful response for own company product' do
      get edit_product_path(product)
      expect(response).to be_successful
    end

    it 'displays product edit form with values' do
      get edit_product_path(product)

      expect(response.body).to include(product.sku)
      expect(response.body).to include(product.name)
    end

    it 'prevents editing other company products' do
      expect {
        get edit_product_path(other_company_product)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'POST /create' do
    let(:valid_attributes) do
      {
        sku: 'NEW001',
        name: 'New Product',
        product_type: :sellable,
        product_status: :active
      }
    end

    let(:invalid_attributes) do
      {
        sku: '',
        name: ''
      }
    end

    context 'with valid parameters' do
      it 'creates a new product' do
        expect {
          post products_path, params: { product: valid_attributes }
        }.to change(Product, :count).by(1)
      end

      it 'assigns product to current company' do
        post products_path, params: { product: valid_attributes }

        product = Product.last
        expect(product.company_id).to eq(company.id)
      end

      it 'redirects to products list' do
        post products_path, params: { product: valid_attributes }

        expect(response).to redirect_to(products_path)
        follow_redirect!
        expect(response.body).to include('Product created successfully')
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new product' do
        expect {
          post products_path, params: { product: invalid_attributes }
        }.not_to change(Product, :count)
      end

      it 'renders new template with errors' do
        post products_path, params: { product: invalid_attributes }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('error')
      end
    end

    context 'with auto-generated SKU' do
      it 'generates SKU when not provided' do
        attributes = valid_attributes.except(:sku)
        post products_path, params: { product: attributes }

        product = Product.last
        expect(product.sku).to be_present
        expect(product.sku).to match(/^[A-Z0-9_]+$/)
      end
    end

    context 'with duplicate SKU' do
      let!(:existing_product) { create(:product, company: company, sku: 'DUP001') }

      it 'does not create product with duplicate SKU' do
        expect {
          post products_path, params: { product: valid_attributes.merge(sku: 'DUP001') }
        }.not_to change(Product, :count)
      end

      it 'shows validation error' do
        post products_path, params: { product: valid_attributes.merge(sku: 'DUP001') }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('has already been taken')
      end
    end

    context 'with labels' do
      let(:label1) { create(:label, company: company) }
      let(:label2) { create(:label, company: company) }

      it 'assigns labels to product' do
        post products_path, params: {
          product: valid_attributes.merge(label_ids: [label1.id, label2.id])
        }

        product = Product.last
        expect(product.labels).to include(label1, label2)
      end
    end
  end

  describe 'PATCH /update' do
    let(:product) { create(:product, company: company, sku: 'OLD001', name: 'Old Name') }
    let(:other_company_product) { create(:product, company: other_company) }

    let(:new_attributes) do
      {
        name: 'Updated Name',
        product_status: :discontinuing
      }
    end

    context 'with valid parameters' do
      it 'updates the product' do
        patch product_path(product), params: { product: new_attributes }

        product.reload
        expect(product.name).to eq('Updated Name')
        expect(product.product_status).to eq('discontinuing')
      end

      it 'redirects to products list' do
        patch product_path(product), params: { product: new_attributes }

        expect(response).to redirect_to(products_path)
        follow_redirect!
        expect(response.body).to include('Product updated successfully')
      end
    end

    context 'with invalid parameters' do
      it 'renders edit template with errors' do
        patch product_path(product), params: { product: { name: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('error')
      end

      it 'does not update the product' do
        patch product_path(product), params: { product: { name: '' } }

        product.reload
        expect(product.name).to eq('Old Name')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating other company products' do
        expect {
          patch product_path(other_company_product), params: { product: new_attributes }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe 'DELETE /destroy' do
    let!(:product) { create(:product, company: company) }
    let(:other_company_product) { create(:product, company: other_company) }

    it 'destroys the product' do
      expect {
        delete product_path(product)
      }.to change(Product, :count).by(-1)
    end

    it 'redirects to products list' do
      delete product_path(product)

      expect(response).to redirect_to(products_path)
      follow_redirect!
      expect(response.body).to include('Product deleted successfully')
    end

    it 'prevents deleting other company products' do
      expect {
        delete product_path(other_company_product)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with associated records' do
      let(:label) { create(:label, company: company) }

      before do
        create(:product_label, product: product, label: label)
      end

      it 'destroys associated product_labels' do
        expect {
          delete product_path(product)
        }.to change(ProductLabel, :count).by(-1)
      end
    end
  end

  describe 'POST /duplicate' do
    let(:product) do
      create(:product,
             company: company,
             sku: 'ORIG001',
             name: 'Original Product',
             product_type: :sellable,
             product_status: :active)
    end
    let(:other_company_product) { create(:product, company: other_company) }

    it 'creates a duplicate product' do
      expect {
        post duplicate_product_path(product)
      }.to change(Product, :count).by(1)
    end

    it 'duplicates product with modified SKU and name' do
      post duplicate_product_path(product)

      new_product = Product.last
      expect(new_product.sku).to match(/ORIG001_COPY_[A-Z0-9]+/)
      expect(new_product.name).to eq('Original Product (Copy)')
    end

    it 'assigns duplicate to same company' do
      post duplicate_product_path(product)

      new_product = Product.last
      expect(new_product.company_id).to eq(company.id)
    end

    it 'redirects to edit page for new product' do
      post duplicate_product_path(product)

      new_product = Product.last
      expect(response).to redirect_to(edit_product_path(new_product))
      follow_redirect!
      expect(response.body).to include("Product duplicated as #{new_product.sku}")
    end

    it 'prevents duplicating other company products' do
      expect {
        post duplicate_product_path(other_company_product)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with attribute values' do
      let(:product_attribute) { create(:product_attribute, company: company, code: 'price', name: 'Price') }

      before do
        create(:product_attribute_value,
               product: product,
               product_attribute: product_attribute,
               value: '1999')
      end

      it 'duplicates attribute values' do
        post duplicate_product_path(product)

        new_product = Product.last
        expect(new_product.product_attribute_values.count).to eq(1)
        expect(new_product.read_attribute_value('price')).to eq('1999')
      end
    end

    context 'with labels' do
      let(:label1) { create(:label, company: company) }
      let(:label2) { create(:label, company: company) }

      before do
        create(:product_label, product: product, label: label1)
        create(:product_label, product: product, label: label2)
      end

      it 'duplicates product labels' do
        post duplicate_product_path(product)

        new_product = Product.last
        expect(new_product.labels.count).to eq(2)
        expect(new_product.labels).to include(label1, label2)
      end
    end
  end

  describe 'POST /bulk_destroy' do
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }
    let!(:product3) { create(:product, company: company) }
    let!(:other_company_product) { create(:product, company: other_company) }

    it 'destroys multiple products from current company' do
      expect {
        post bulk_destroy_products_path, params: { product_ids: [product1.id, product2.id] }
      }.to change(Product, :count).by(-2)
    end

    it 'does not destroy products from other companies' do
      initial_count = Product.count

      post bulk_destroy_products_path, params: {
        product_ids: [product1.id, other_company_product.id]
      }

      # Only product1 should be destroyed
      expect(Product.count).to eq(initial_count - 1)
      expect(Product.exists?(other_company_product.id)).to be true
      expect(Product.exists?(product1.id)).to be false
    end

    it 'redirects to products list with success message' do
      post bulk_destroy_products_path, params: { product_ids: [product1.id, product2.id] }

      expect(response).to redirect_to(products_path)
      follow_redirect!
      expect(response.body).to include('2 products deleted')
    end
  end

  describe 'POST /bulk_update_labels' do
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }
    let!(:other_company_product) { create(:product, company: other_company) }

    let(:label1) { create(:label, company: company) }
    let(:label2) { create(:label, company: company) }

    it 'updates labels for multiple products' do
      post bulk_update_labels_products_path, params: {
        product_ids: [product1.id, product2.id],
        label_ids: [label1.id, label2.id]
      }

      product1.reload
      product2.reload

      expect(product1.labels).to include(label1, label2)
      expect(product2.labels).to include(label1, label2)
    end

    it 'does not update labels for other company products' do
      post bulk_update_labels_products_path, params: {
        product_ids: [product1.id, other_company_product.id],
        label_ids: [label1.id]
      }

      product1.reload
      other_company_product.reload

      expect(product1.labels).to include(label1)
      expect(other_company_product.labels).to be_empty
    end

    it 'redirects to products list with success message' do
      post bulk_update_labels_products_path, params: {
        product_ids: [product1.id, product2.id],
        label_ids: [label1.id]
      }

      expect(response).to redirect_to(products_path)
      follow_redirect!
      expect(response.body).to include('Labels updated for 2 products')
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
      get products_path
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for create' do
      post products_path, params: { product: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for update' do
      product = create(:product, company: company)
      patch product_path(product), params: { product: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
    end

    it 'requires authentication for destroy' do
      product = create(:product, company: company)
      delete product_path(product)
      expect(response).to redirect_to(auth_login_path)
    end
  end
end
