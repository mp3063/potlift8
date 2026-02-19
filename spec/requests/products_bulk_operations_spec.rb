# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Products Bulk Operations', type: :request do
  let(:user) { create(:user) }
  let(:company) { create(:company, code: 'TEST') }
  let(:other_company) { create(:company, code: 'OTHER') }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(
      { 'id' => company.id, 'code' => company.code, 'name' => company.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  describe 'POST /products/bulk_destroy' do
    let!(:product1) { create(:product, company: company, sku: 'BULK-1', name: 'Product 1') }
    let!(:product2) { create(:product, company: company, sku: 'BULK-2', name: 'Product 2') }
    let!(:product3) { create(:product, company: company, sku: 'BULK-3', name: 'Product 3') }
    let!(:other_company_product) { create(:product, company: other_company, sku: 'OTHER-1') }

    context 'with valid product IDs' do
      it 'deletes multiple products successfully' do
        expect {
          post products_bulk_destroy_path, params: { product_ids: [ product1.id, product2.id ] }
        }.to change(Product, :count).by(-2)

        expect(Product.exists?(product1.id)).to be false
        expect(Product.exists?(product2.id)).to be false
        expect(Product.exists?(product3.id)).to be true
      end

      it 'redirects with success message' do
        post products_bulk_destroy_path, params: { product_ids: [ product1.id, product2.id ] }

        expect(response).to redirect_to(products_path)
        follow_redirect!
        expect(response.body).to include('2 products deleted')
      end

      it 'only deletes products from current company' do
        initial_count = Product.count

        post products_bulk_destroy_path, params: {
          product_ids: [ product1.id, other_company_product.id ]
        }

        # Only product1 from current company should be deleted
        expect(Product.count).to eq(initial_count - 1)
        expect(Product.exists?(product1.id)).to be false
        expect(Product.exists?(other_company_product.id)).to be true
      end
    end

    context 'with empty product_ids' do
      it 'does not delete any products and handles gracefully' do
        post products_bulk_destroy_path, params: { product_ids: [] }

        expect(response).to redirect_to(products_path)
        # The controller may handle this silently or with a message
      end

      it 'does not delete any products' do
        expect {
          post products_bulk_destroy_path, params: { product_ids: [] }
        }.not_to change(Product, :count)
      end
    end

    context 'with invalid product IDs' do
      it 'ignores non-existent product IDs' do
        expect {
          post products_bulk_destroy_path, params: { product_ids: [ 9999, product1.id ] }
        }.to change(Product, :count).by(-1)

        expect(Product.exists?(product1.id)).to be false
      end
    end
  end

  describe 'POST /products/bulk_update_labels' do
    let!(:product1) { create(:product, company: company, sku: 'BULK-1') }
    let!(:product2) { create(:product, company: company, sku: 'BULK-2') }
    let!(:product3) { create(:product, company: company, sku: 'BULK-3') }
    let!(:other_company_product) { create(:product, company: other_company) }

    let!(:label1) { create(:label, company: company, code: 'LABEL-1', name: 'Label 1', label_type: 'category') }
    let!(:label2) { create(:label, company: company, code: 'LABEL-2', name: 'Label 2', label_type: 'tag') }
    let!(:label3) { create(:label, company: company, code: 'LABEL-3', name: 'Label 3', label_type: 'brand') }

    describe 'adding labels (action_type: add)' do
      context 'to products without existing labels' do
        it 'adds labels to multiple products' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label1.id, label2.id ],
            action_type: 'add'
          }

          product1.reload
          product2.reload

          expect(product1.labels).to include(label1, label2)
          expect(product2.labels).to include(label1, label2)
          expect(product3.labels).to be_empty
        end

        it 'redirects with success message' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label1.id ],
            action_type: 'add'
          }

          expect(response).to redirect_to(products_path)
          follow_redirect!
          expect(response.body).to include('Labels added to 2 products successfully')
        end
      end

      context 'to products with existing labels' do
        before do
          product1.labels << label1
          product2.labels << label2
        end

        it 'adds new labels without removing existing ones' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label3.id ],
            action_type: 'add'
          }

          product1.reload
          product2.reload

          expect(product1.labels).to include(label1, label3)
          expect(product2.labels).to include(label2, label3)
        end

        it 'does not duplicate labels if already present' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id ],
            label_ids: [ label1.id, label2.id ],
            action_type: 'add'
          }

          product1.reload

          expect(product1.labels.where(id: label1.id).count).to eq(1)
          expect(product1.labels).to include(label1, label2)
        end
      end

      context 'with other company products' do
        it 'only adds labels to current company products' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, other_company_product.id ],
            label_ids: [ label1.id ],
            action_type: 'add'
          }

          product1.reload
          other_company_product.reload

          expect(product1.labels).to include(label1)
          expect(other_company_product.labels).to be_empty
        end
      end
    end

    describe 'removing labels (action_type: remove)' do
      before do
        product1.labels << [ label1, label2, label3 ]
        product2.labels << [ label1, label2 ]
        product3.labels << label1
      end

      context 'from products with multiple labels' do
        it 'removes specified labels from multiple products' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label1.id, label2.id ],
            action_type: 'remove'
          }

          product1.reload
          product2.reload
          product3.reload

          expect(product1.label_ids).to contain_exactly(label3.id)
          expect(product2.labels).to be_empty
          expect(product3.labels).to include(label1) # Not affected
        end

        it 'redirects with success message' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label1.id ],
            action_type: 'remove'
          }

          expect(response).to redirect_to(products_path)
          follow_redirect!
          expect(response.body).to match(/Labels removed from 2 product/i)
        end
      end

      context 'when removing non-existent labels' do
        it 'does not raise an error' do
          expect {
            post products_bulk_update_labels_path, params: {
              product_ids: [ product3.id ],
              label_ids: [ label2.id, label3.id ], # product3 only has label1
              action_type: 'remove'
            }
          }.not_to raise_error

          product3.reload
          expect(product3.labels).to include(label1)
        end
      end

      context 'when removing all labels' do
        it 'leaves product with no labels' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product2.id ],
            label_ids: [ label1.id, label2.id ],
            action_type: 'remove'
          }

          product2.reload
          expect(product2.labels).to be_empty
        end
      end
    end

    describe 'edge cases' do
      context 'with empty product_ids' do
        it 'handles empty product_ids appropriately' do
          post products_bulk_update_labels_path, params: {
            product_ids: [],
            label_ids: [ label1.id ],
            action_type: 'add'
          }

          expect(response).to redirect_to(products_path)
          # Controller handles this with appropriate message
        end
      end

      context 'with empty label_ids' do
        it 'handles empty label_ids appropriately' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id ],
            label_ids: [],
            action_type: 'add'
          }

          expect(response).to redirect_to(products_path)
          # Controller handles this with appropriate message
        end
      end

      context 'with nil action_type (defaults to add)' do
        it 'defaults to adding labels' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id ],
            label_ids: [ label1.id ]
          }

          product1.reload
          expect(product1.labels).to include(label1)
        end
      end

      context 'with invalid action_type' do
        it 'treats as add action' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id ],
            label_ids: [ label1.id ],
            action_type: 'invalid'
          }

          product1.reload
          expect(product1.labels).to include(label1)
        end
      end

      context 'with string product_ids' do
        it 'handles string IDs correctly' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id.to_s, product2.id.to_s ],
            label_ids: [ label1.id.to_s ],
            action_type: 'add'
          }

          product1.reload
          product2.reload

          expect(product1.labels).to include(label1)
          expect(product2.labels).to include(label1)
        end
      end
    end

    describe 'error handling' do
      context 'when a product fails to save' do
        before do
          # Make product1 invalid by stubbing validation
          allow_any_instance_of(Product).to receive(:valid?).and_return(false)
          allow_any_instance_of(Product).to receive(:save).and_return(false)
          allow_any_instance_of(Product).to receive_message_chain(:errors, :full_messages).and_return([ 'Invalid product' ])
        end

        it 'rolls back all changes' do
          initial_label_count_p1 = product1.labels.count
          initial_label_count_p2 = product2.labels.count

          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id, product2.id ],
            label_ids: [ label1.id ],
            action_type: 'add'
          }

          product1.reload
          product2.reload

          # Changes should be rolled back
          expect(product1.labels.count).to eq(initial_label_count_p1)
          expect(product2.labels.count).to eq(initial_label_count_p2)
        end

        it 'redirects with error message' do
          post products_bulk_update_labels_path, params: {
            product_ids: [ product1.id ],
            label_ids: [ label1.id ],
            action_type: 'add'
          }

          expect(response).to redirect_to(products_path)
          follow_redirect!
          expect(response.body).to include('Failed to update labels')
        end
      end
    end

    describe 'performance' do
      it 'handles bulk operations efficiently with many products' do
        # Create 20 products
        products = create_list(:product, 20, company: company)
        product_ids = products.map(&:id)

        expect {
          post products_bulk_update_labels_path, params: {
            product_ids: product_ids,
            label_ids: [ label1.id, label2.id ],
            action_type: 'add'
          }
        }.to change { ProductLabel.count }.by(40) # 20 products * 2 labels

        products.each do |product|
          product.reload
          expect(product.labels).to include(label1, label2)
        end
      end
    end
  end

  describe 'GET /products/bulk/labels_for_products' do
    let!(:product1) { create(:product, company: company, sku: 'LFP-1') }
    let!(:product2) { create(:product, company: company, sku: 'LFP-2') }
    let!(:product3) { create(:product, company: company, sku: 'LFP-3') }

    let!(:label1) { create(:label, company: company, code: 'LFP-LABEL-1', name: 'Label 1') }
    let!(:label2) { create(:label, company: company, code: 'LFP-LABEL-2', name: 'Label 2') }
    let!(:label3) { create(:label, company: company, code: 'LFP-LABEL-3', name: 'Label 3') }

    before do
      product1.labels << label1
      product1.labels << label2
      product2.labels << label2
      # product3 has no labels
    end

    context 'with valid product IDs' do
      it 'returns assigned_to_any with labels on any selected product' do
        get products_bulk_labels_for_products_path, params: { product_ids: [ product1.id, product2.id ] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['assigned_to_any']).to contain_exactly(label1.id, label2.id)
      end

      it 'returns assigned_to_all with labels on all selected products' do
        get products_bulk_labels_for_products_path, params: { product_ids: [ product1.id, product2.id ] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Only label2 is on both products
        expect(json['assigned_to_all']).to contain_exactly(label2.id)
      end

      it 'returns only labels for single product' do
        get products_bulk_labels_for_products_path, params: { product_ids: [ product2.id ] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['assigned_to_any']).to contain_exactly(label2.id)
        expect(json['assigned_to_all']).to contain_exactly(label2.id)
      end

      it 'returns empty arrays for product with no labels' do
        get products_bulk_labels_for_products_path, params: { product_ids: [ product3.id ] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['assigned_to_any']).to be_empty
        expect(json['assigned_to_all']).to be_empty
      end
    end

    context 'with empty product_ids' do
      it 'returns empty arrays' do
        get products_bulk_labels_for_products_path, params: { product_ids: [] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['assigned_to_any']).to be_empty
        expect(json['assigned_to_all']).to be_empty
      end
    end

    context 'with products from another company' do
      it 'ignores products from other companies' do
        other_product = create(:product, company: other_company)
        other_label = create(:label, company: other_company)
        other_product.labels << other_label

        get products_bulk_labels_for_products_path, params: { product_ids: [ product1.id, other_product.id ] }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        # Should only include labels from product1, not other_product
        expect(json['assigned_to_any']).to contain_exactly(label1.id, label2.id)
        expect(json['assigned_to_all']).to contain_exactly(label1.id, label2.id)
      end
    end
  end
end
