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

      it 'displays active label filter chip' do
        get products_path, params: { label_id: label1.id }

        expect(response).to be_successful
        expect(response.body).to include('Active filters:')
        expect(response.body).to include('Electronics')
      end

      it 'preserves other filters when applying label filter' do
        get products_path, params: { label_id: label1.id, q: 'Alpha', product_type: '1' }

        expect(response).to be_successful
        expect(response.body).to include('Product Alpha')
        # Should not show other products even though they match label
      end

      context 'with hierarchical labels' do
        let!(:parent_label) { create(:label, company: company, code: 'electronics-parent', name: 'Electronics', parent_label_id: nil) }
        let!(:child_label) { create(:label, company: company, code: 'phones', name: 'Phones', parent_label: parent_label) }
        let!(:grandchild_label) { create(:label, company: company, code: 'smartphones', name: 'Smartphones', parent_label: child_label) }

        let!(:parent_product) { create(:product, company: company, sku: 'ELEC001', name: 'Electronic Device') }
        let!(:child_product) { create(:product, company: company, sku: 'PHONE001', name: 'Phone Device') }
        let!(:grandchild_product) { create(:product, company: company, sku: 'SMART001', name: 'Smartphone Device') }

        before do
          create(:product_label, product: parent_product, label: parent_label)
          create(:product_label, product: child_product, label: child_label)
          create(:product_label, product: grandchild_product, label: grandchild_label)
        end

        it 'filters by parent label includes products with child labels' do
          get products_path, params: { label_id: parent_label.id }

          expect(response).to be_successful
          # Should show products with parent label, child label, and grandchild label
          expect(response.body).to include('Electronic Device')
          expect(response.body).to include('Phone Device')
          expect(response.body).to include('Smartphone Device')
        end

        it 'filters by child label includes products with grandchild labels' do
          get products_path, params: { label_id: child_label.id }

          expect(response).to be_successful
          # Should show products with child label and grandchild label
          expect(response.body).to include('Phone Device')
          expect(response.body).to include('Smartphone Device')
          # Should NOT show parent label products
          expect(response.body).not_to include('Electronic Device')
        end

        it 'filters by grandchild label only shows that level' do
          get products_path, params: { label_id: grandchild_label.id }

          expect(response).to be_successful
          # Should only show products with grandchild label
          expect(response.body).to include('Smartphone Device')
          expect(response.body).not_to include('Electronic Device')
          expect(response.body).not_to include('Phone Device')
        end

        it 'displays full hierarchical label name in filter chip' do
          get products_path, params: { label_id: grandchild_label.id }

          expect(response).to be_successful
          expect(response.body).to include('Active filters:')
          # Should show full path: Electronics > Phones > Smartphones
          expect(response.body).to include('Electronics &gt; Phones &gt; Smartphones')
        end
      end

      it 'handles invalid label_id gracefully' do
        get products_path, params: { label_id: 999999 }

        expect(response).to be_successful
        # Should show all products (filter ignored)
        expect(response.body).to include('Product Alpha')
        expect(response.body).to include('Product Beta')
      end

      it 'prevents filtering by labels from other companies' do
        other_company_label = create(:label, company: other_company, code: 'other', name: 'Other Label')

        get products_path, params: { label_id: other_company_label.id }

        expect(response).to be_successful
        # Should show all products (filter ignored for security)
        expect(response.body).to include('Product Alpha')
        expect(response.body).to include('Product Beta')
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
        # With 31 total products and 25 per page, we should see 25 on page 1
        # Products are ordered by created_at DESC by default
        # So newest products (BULK027 down to BULK003) plus PROD003 should be on page 1
        # And older products (PROD001, PROD002, BULK002, BULK001, BULK000) on page 2

        # Check a recent product is on page 1
        expect(response.body).to include('BULK027') # Newest bulk product
        # Check the oldest products are NOT on page 1 (should be on page 2)
        expect(response.body).not_to include('PROD001') # One of the oldest
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
        # Check that other company product SKU and name are not in response
        # (Avoid checking raw ID as it can appear in counts, pagination, etc.)
        expect(response.body).not_to include('OTHER001')
        expect(response.body).not_to include('Other Product')
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
    let!(:product) do
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
      expect(response.body).to include('Labels added to 2 products successfully.')
    end
  end

  describe 'POST /products/:id/add_label' do
    let(:product) { create(:product, company: company) }
    let(:label) { create(:label, company: company, code: 'test', name: 'Test Label') }
    let(:other_company_label) { create(:label, company: other_company) }
    let(:other_company_product) { create(:product, company: other_company) }

    it 'adds a label to the product' do
      expect {
        post add_label_product_path(product), params: { label_id: label.id }
      }.to change { product.labels.count }.by(1)
    end

    it 'associates the correct label with the product' do
      post add_label_product_path(product), params: { label_id: label.id }

      product.reload
      expect(product.labels).to include(label)
    end

    it 'redirects to product show page with success message' do
      post add_label_product_path(product), params: { label_id: label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label &#39;Test Label&#39; added successfully.")
    end

    it 'does not add duplicate labels' do
      product.labels << label

      expect {
        post add_label_product_path(product), params: { label_id: label.id }
      }.not_to change { product.labels.count }
    end

    it 'shows error when adding duplicate label' do
      product.labels << label
      post add_label_product_path(product), params: { label_id: label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Label already assigned')
    end

    it 'shows error when label_id is missing' do
      post add_label_product_path(product)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Please select a label')
    end

    it 'prevents adding labels from other companies' do
      expect {
        post add_label_product_path(product), params: { label_id: other_company_label.id }
      }.not_to change { product.labels.count }
    end

    it 'prevents adding labels to other company products' do
      expect {
        post add_label_product_path(other_company_product), params: { label_id: label.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /products/:id/remove_label' do
    let(:product) { create(:product, company: company) }
    let(:label) { create(:label, company: company, code: 'test', name: 'Test Label') }
    let(:other_company_product) { create(:product, company: other_company) }

    before do
      product.labels << label
    end

    it 'removes a label from the product' do
      expect {
        delete remove_label_product_path(product), params: { label_id: label.id }
      }.to change { product.labels.count }.by(-1)
    end

    it 'removes the correct label from the product' do
      delete remove_label_product_path(product), params: { label_id: label.id }

      product.reload
      expect(product.labels).not_to include(label)
    end

    it 'redirects to product show page with success message' do
      delete remove_label_product_path(product), params: { label_id: label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label &#39;Test Label&#39; removed successfully.")
    end

    it 'shows error when label_id is missing' do
      delete remove_label_product_path(product)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Label ID is required')
    end

    it 'shows error when label not found on product' do
      different_label = create(:label, company: company)

      delete remove_label_product_path(product), params: { label_id: different_label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Label not found on this product')
    end

    it 'prevents removing labels from other company products' do
      expect {
        delete remove_label_product_path(other_company_product), params: { label_id: label.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'PATCH /products/:id/toggle_active' do
    let(:product) { create(:product, company: company, product_status: :draft) }
    let(:other_company_product) { create(:product, company: other_company) }

    it 'activates a draft product' do
      patch toggle_active_product_path(product)

      product.reload
      expect(product.product_status).to eq('active')
    end

    it 'deactivates an active product' do
      product.update(product_status: :active)

      patch toggle_active_product_path(product)

      product.reload
      expect(product.product_status).to eq('disabled')
    end

    it 'redirects to product show page with success message for activation' do
      patch toggle_active_product_path(product)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Product activated successfully')
    end

    it 'redirects to product show page with success message for deactivation' do
      product.update(product_status: :active)

      patch toggle_active_product_path(product)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Product deactivated successfully')
    end

    it 'prevents toggling other company products' do
      expect {
        patch toggle_active_product_path(other_company_product)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'DELETE /products/:id/remove_from_catalog' do
    let(:product) { create(:product, company: company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:other_catalog) { create(:catalog, company: company) }
    let(:other_company_product) { create(:product, company: other_company) }

    before do
      # Add product to catalog
      create(:catalog_item, product: product, catalog: catalog)
    end

    it 'removes the catalog_item association' do
      expect {
        delete remove_from_catalog_product_path(product), params: { catalog_id: catalog.id }
      }.to change { product.catalog_items.count }.by(-1)
    end

    it 'removes the correct catalog_item' do
      delete remove_from_catalog_product_path(product), params: { catalog_id: catalog.id }

      product.reload
      expect(product.catalog_items.where(catalog_id: catalog.id)).not_to exist
    end

    it 'does NOT delete the product itself (CRITICAL BUG FIX)' do
      product_id = product.id

      expect {
        delete remove_from_catalog_product_path(product), params: { catalog_id: catalog.id }
      }.not_to change { Product.count }

      # Verify product still exists
      expect(Product.find_by(id: product_id)).to be_present
      expect(Product.find_by(id: product_id).id).to eq(product_id)
    end

    it 'only removes the specified catalog, not all catalogs' do
      # Add product to second catalog
      create(:catalog_item, product: product, catalog: other_catalog)

      expect {
        delete remove_from_catalog_product_path(product), params: { catalog_id: catalog.id }
      }.to change { product.catalog_items.count }.from(2).to(1)

      # Verify the other catalog_item still exists
      product.reload
      expect(product.catalog_items.where(catalog_id: other_catalog.id)).to exist
    end

    it 'redirects to product show page with success message' do
      delete remove_from_catalog_product_path(product), params: { catalog_id: catalog.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Product removed from #{catalog.name} successfully")
    end

    it 'shows error when catalog_id is missing' do
      delete remove_from_catalog_product_path(product)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Catalog ID is required')
    end

    it 'shows error when product is not in the specified catalog' do
      different_catalog = create(:catalog, company: company)

      delete remove_from_catalog_product_path(product), params: { catalog_id: different_catalog.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include('Product is not in this catalog')
    end

    it 'prevents removing from other company products' do
      expect {
        delete remove_from_catalog_product_path(other_company_product), params: { catalog_id: catalog.id }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    context 'with Turbo Stream request' do
      it 'returns a turbo_stream response' do
        delete remove_from_catalog_product_path(product),
               params: { catalog_id: catalog.id },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.content_type).to include('turbo-stream')
      end

      it 'returns the correct turbo-frame target in response' do
        delete remove_from_catalog_product_path(product),
               params: { catalog_id: catalog.id },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }

        expect(response.body).to include("catalog-tabs-#{product.id}")
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
