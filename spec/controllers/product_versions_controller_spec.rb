require 'rails_helper'

RSpec.describe ProductVersionsController, type: :request do
  let(:company) { create(:company) }
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

  describe 'GET /products/:product_id/versions' do
    it 'renders the version history index' do
      product = create(:product, company: company)
      # Create a version by updating the product
      product.update!(name: "Updated Name")

      get product_versions_path(product)
      expect(response).to be_successful
    end
  end

  describe 'GET /products/:product_id/versions/:id' do
    it 'renders show page with diff values' do
      product = create(:product, company: company, name: "Original")
      product.update!(name: "Updated")

      version = product.versions.last

      get product_version_path(product, version)
      expect(response).to be_successful
    end

    it 'displays changed attributes correctly' do
      product = create(:product, company: company, name: "Original Name")
      product.update!(name: "New Name")

      version = product.versions.last

      get product_version_path(product, version)
      expect(response).to be_successful
      expect(response.body).to include('Name')
    end
  end

  describe 'GET /products/:product_id/versions/compare' do
    it 'renders compare page with version selectors' do
      product = create(:product, company: company, name: "V1")
      product.update!(name: "V2")
      product.update!(name: "V3")

      versions = product.versions.order(created_at: :desc)

      get compare_product_versions_path(product,
        version1_id: versions.second.id,
        version2_id: versions.first.id
      )
      expect(response).to be_successful
    end
  end

  describe 'GET /products/:product_id/versions/:id - diff format' do
    it 'does not render nested arrays in DiffViewComponent' do
      product = create(:product, company: company, name: "Original")
      product.update!(name: "Changed")

      version = product.versions.last

      get product_version_path(product, version)
      expect(response).to be_successful
      # Verify the response does not contain array-like rendering artifacts
      # (which would appear if hash destructuring produced [:old, value] pairs)
      expect(response.body).not_to include('[:old,')
      expect(response.body).not_to include('[:new,')
    end
  end
end
