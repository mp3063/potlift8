# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/products/:product_id/attribute_values', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:product) { create(:product, company: company) }
  let(:other_company_product) { create(:product, company: other_company) }
  # 'price' is a seeded system attribute (name "Price"); reference rather than recreate.
  let(:product_attribute) { company.product_attributes.find_by(code: 'price') }
  let(:other_company_attribute) { create(:product_attribute, company: other_company) }

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
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe 'PATCH /products/:product_id/attribute_values/:attribute_id' do
    context 'with valid parameters' do
      it 'creates a new attribute value if not exists' do
        expect {
          patch product_attribute_value_path(product, product_attribute), params: { value: '19,99' }
        }.to change(ProductAttributeValue, :count).by(1)
      end

      it 'updates existing attribute value' do
        existing_value = create(:product_attribute_value,
                                product: product,
                                product_attribute: product_attribute,
                                value: '1500')

        expect {
          patch product_attribute_value_path(product, product_attribute), params: { value: '19,99' }
        }.not_to change(ProductAttributeValue, :count)

        existing_value.reload
        expect(existing_value.value).to eq('1999')
      end

      it 'sets the correct value' do
        patch product_attribute_value_path(product, product_attribute), params: { value: '19,99' }

        value = product.product_attribute_values.find_by(product_attribute: product_attribute)
        expect(value.value).to eq('1999')
      end

      it 'redirects to product show page with success message' do
        patch product_attribute_value_path(product, product_attribute), params: { value: '19,99' }

        expect(response).to redirect_to(product)
        follow_redirect!
        expect(response.body).to include('Price updated successfully')
      end
    end

    context 'with money attributes' do
      def stored_price
        product.product_attribute_values.find_by(product_attribute: product_attribute)&.value
      end

      it 'accepts a dot as the decimal separator' do
        patch product_attribute_value_path(product, product_attribute), params: { value: '40.5' }

        expect(stored_price).to eq('4050')
      end

      it 'accepts whole amounts' do
        patch product_attribute_value_path(product, product_attribute), params: { value: '40' }

        expect(stored_price).to eq('4000')
      end

      it 'rejects an invalid amount without saving (html)' do
        patch product_attribute_value_path(product, product_attribute), params: { value: 'abc' }

        expect(stored_price).to be_nil
        expect(response).to redirect_to(product)
        expect(flash[:alert]).to eq('Failed to update Price: abc is not a valid amount (use e.g. 40,00 or 40.00)')
      end

      it 'rejects an invalid amount without saving (turbo_stream)' do
        create(:product_attribute_value, product: product, product_attribute: product_attribute, value: '1500')

        patch product_attribute_value_path(product, product_attribute, format: :turbo_stream),
              params: { value: 'abc' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('abc is not a valid amount')
        expect(stored_price).to eq('1500')
      end

      it 're-renders the row with the formatted amount' do
        patch product_attribute_value_path(product, product_attribute, format: :turbo_stream),
              params: { value: '19,99' }

        expect(response.body).to include('19,99 €')
      end
    end

    context 'with a special price' do
      let(:special_price) { company.product_attributes.find_by!(code: 'special_price') }

      it 'stores plain cents when no date range exists' do
        patch product_attribute_value_path(product, special_price), params: { value: '35,00' }

        expect(product.product_attribute_values.find_by(product_attribute: special_price).value).to eq('3500')
      end

      it 'updates the amount of an existing date range' do
        pav = create(:product_attribute_value, product: product, product_attribute: special_price, value: '3000',
                     info: { 'special_price' => { 'amount' => '3000', 'from' => '2026-10-01', 'until' => '2026-10-31' } })

        patch product_attribute_value_path(product, special_price), params: { value: '35,00' }

        pav.reload
        expect(pav.read_attribute(:value)).to eq('3500')
        expect(pav.value).to eq('3500,2026-10-01,2026-10-31')
      end

      it 'drops the date range when the amount is cleared' do
        pav = create(:product_attribute_value, product: product, product_attribute: special_price, value: '3000',
                     info: { 'special_price' => { 'amount' => '3000', 'from' => '2026-10-01', 'until' => '2026-10-31' } })

        patch product_attribute_value_path(product, special_price), params: { value: '' }

        expect(pav.reload.value).to be_nil
      end
    end

    context 'with boolean attributes' do
      let(:boolean_attribute) do
        create(:product_attribute, :boolean_type,
               company: company,
               code: 'featured',
               name: 'Featured')
      end

      it 'handles checkbox values' do
        patch product_attribute_value_path(product, boolean_attribute), params: { value: '1' }

        value = product.product_attribute_values.find_by(product_attribute: boolean_attribute)
        expect(value.value).to eq('true')
      end

      it 'handles unchecked checkbox' do
        patch product_attribute_value_path(product, boolean_attribute), params: { value: '0' }

        value = product.product_attribute_values.find_by(product_attribute: boolean_attribute)
        expect(value.value).to eq('false')
      end
    end

    context 'with numeric attributes' do
      let(:number_attribute) do
        create(:product_attribute, :number_type,
               company: company,
               code: 'stock_level',
               name: 'Stock Level')
      end

      it 'handles numeric values' do
        patch product_attribute_value_path(product, number_attribute), params: { value: '150' }

        value = product.product_attribute_values.find_by(product_attribute: number_attribute)
        expect(value.value).to eq('150')
      end
    end

    context 'with select attributes' do
      let(:select_attribute) do
        create(:product_attribute, :select_type,
               company: company,
               code: 'size',
               name: 'Size')
      end

      it 'handles select values' do
        # Use one of the predefined options from the factory
        patch product_attribute_value_path(product, select_attribute), params: { value: 'Option 2' }

        value = product.product_attribute_values.find_by(product_attribute: select_attribute)
        expect(value.value).to eq('Option 2')
      end
    end

    context 'with unit fields (weight attributes)' do
      # 'weight' is a seeded system attribute (number/weight format); reference rather than recreate.
      let(:weight_attribute) { company.product_attributes.find_by(code: 'weight') }

      it 'stores unit in info field' do
        patch product_attribute_value_path(product, weight_attribute),
              params: { value: '2.5', unit: 'kg' }

        value = product.product_attribute_values.find_by(product_attribute: weight_attribute)
        expect(value.value).to eq('2.5')
        expect(value.info['unit']).to eq('kg')
      end
    end

    context 'multi-tenant security' do
      it 'prevents updating attributes for other company products' do
        expect {
          patch product_attribute_value_path(other_company_product, product_attribute),
                params: { value: '1999' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'prevents using attributes from other companies' do
        expect {
          patch product_attribute_value_path(product, other_company_attribute),
                params: { value: '1999' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'with blank value' do
      it 'stores nil for blank values' do
        patch product_attribute_value_path(product, product_attribute), params: { value: '' }

        value = product.product_attribute_values.find_by(product_attribute: product_attribute)
        expect(value.value).to be_nil
      end
    end

    context 'with turbo_stream format' do
      it 'returns turbo_stream response with flash message on success' do
        patch product_attribute_value_path(product, product_attribute, format: :turbo_stream),
              params: { value: '19,99' }

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('Price updated successfully')
      end

      it 'returns turbo_stream response with error flash on validation failure' do
        # Create a mock that will cause validation to fail
        allow_any_instance_of(ProductAttributeValue).to receive(:save).and_return(false)
        allow_any_instance_of(ProductAttributeValue).to receive(:errors).and_return(
          double(full_messages: [ 'Value is invalid' ])
        )

        patch product_attribute_value_path(product, product_attribute, format: :turbo_stream),
              params: { value: '19,99' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('Failed to update Price')
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

    it 'requires authentication for update' do
      patch product_attribute_value_path(product, product_attribute), params: { value: '1999' }
      expect(response).to redirect_to(auth_login_path)
    end
  end
end
