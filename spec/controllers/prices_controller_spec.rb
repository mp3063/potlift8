require 'rails_helper'

RSpec.describe PricesController, type: :request do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:user) { create(:user, company: company, name: 'Test User', email: 'test@example.com') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe 'GET /products/:product_id/prices' do
    it 'renders successfully with no prices' do
      get product_prices_path(product)
      expect(response).to be_successful
    end

    it 'renders successfully with base, special, and group prices' do
      create(:price, :base, product: product)
      create(:price, :special, product: product)
      customer_group = create(:customer_group, company: company)
      create(:price, :group, product: product, customer_group: customer_group)

      get product_prices_path(product)
      expect(response).to be_successful
    end

    it 'displays customer group name for group prices' do
      customer_group = create(:customer_group, :vip, company: company)
      create(:price, :group, product: product, customer_group: customer_group)

      get product_prices_path(product)
      expect(response.body).to include('VIP Customers')
    end

    it 'displays discount percentage from customer group' do
      customer_group = create(:customer_group, company: company, discount_percent: 25)
      create(:price, :group, product: product, customer_group: customer_group)

      get product_prices_path(product)
      expect(response.body).to include('25%')
    end
  end

  describe 'GET /products/:product_id/prices/new' do
    it 'renders base price form by default' do
      get new_product_price_path(product)
      expect(response).to be_successful
    end

    it 'renders special price form with date fields' do
      get new_product_price_path(product, price_type: 'special')
      expect(response).to be_successful
      expect(response.body).to include('Valid From')
    end

    it 'renders group price form with customer group dropdown' do
      create(:customer_group, company: company)
      get new_product_price_path(product, price_type: 'group')
      expect(response).to be_successful
      expect(response.body).to include('Customer Group')
    end
  end

  describe 'POST /products/:product_id/prices' do
    it 'creates a base price' do
      expect {
        post product_prices_path(product), params: {
          price: { value: 29.99, currency: 'eur', price_type: 'base' }
        }
      }.to change(Price, :count).by(1)

      expect(response).to redirect_to(product_prices_path(product))
      expect(Price.last.price_type).to eq('base')
    end

    it 'creates a special price with date range' do
      expect {
        post product_prices_path(product), params: {
          price: {
            value: 19.99,
            currency: 'eur',
            price_type: 'special',
            valid_from: 1.day.from_now,
            valid_to: 1.week.from_now
          }
        }
      }.to change(Price, :count).by(1)

      expect(Price.last.price_type).to eq('special')
    end

    it 'creates a group price with customer_group_id' do
      customer_group = create(:customer_group, company: company)

      expect {
        post product_prices_path(product), params: {
          price: {
            value: 24.99,
            currency: 'eur',
            price_type: 'group',
            customer_group_id: customer_group.id
          }
        }
      }.to change(Price, :count).by(1)

      price = Price.last
      expect(price.price_type).to eq('group')
      expect(price.customer_group).to eq(customer_group)
    end

    it 'rejects invalid price_type' do
      expect {
        post product_prices_path(product), params: {
          price: { value: 10, currency: 'eur', price_type: 'customer_group' }
        }
      }.not_to change(Price, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects missing value' do
      expect {
        post product_prices_path(product), params: {
          price: { currency: 'eur', price_type: 'base' }
        }
      }.not_to change(Price, :count)
    end

    it 'rejects customer_group_id from another company' do
      other_company = create(:company)
      other_group = create(:customer_group, company: other_company)

      expect {
        post product_prices_path(product), params: {
          price: {
            value: 24.99,
            currency: 'eur',
            price_type: 'group',
            customer_group_id: other_group.id
          }
        }
      }.not_to change(Price, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /products/:product_id/prices/:id' do
    let(:price) { create(:price, :base, product: product) }

    it 'updates price value' do
      patch product_price_path(product, price), params: {
        price: { value: 39.99 }
      }

      expect(response).to redirect_to(product_prices_path(product))
      expect(price.reload.value).to eq(39.99)
    end

    it 'updates customer_group_id on group price' do
      group_price = create(:price, :group, product: product, customer_group: create(:customer_group, company: company))
      new_group = create(:customer_group, company: company)

      patch product_price_path(product, group_price), params: {
        price: { customer_group_id: new_group.id }
      }

      expect(group_price.reload.customer_group).to eq(new_group)
    end
  end

  describe 'DELETE /products/:product_id/prices/:id' do
    it 'deletes the price and redirects' do
      price = create(:price, :base, product: product)

      expect {
        delete product_price_path(product, price)
      }.to change(Price, :count).by(-1)

      expect(response).to redirect_to(product_prices_path(product))
    end
  end
end
