# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Product Catalogs", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let!(:product) { create(:product, company: company) }
  let!(:catalog) { create(:catalog, company: company) }

  before do
    authenticate_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  describe "POST /products/:product_id/catalogs" do
    it "adds product to catalog" do
      post product_catalogs_path(product), params: { catalog_id: catalog.id }

      expect(product.catalogs.reload).to include(catalog)
    end

    it "redirects to product with success message" do
      post product_catalogs_path(product), params: { catalog_id: catalog.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("added to")
      expect(response.body).to include("successfully")
    end

    it "returns error for blank catalog_id" do
      post product_catalogs_path(product), params: { catalog_id: "" }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Please select a catalog")
    end

    it "returns error if product already in catalog" do
      product.catalog_items.create!(catalog: catalog)

      post product_catalogs_path(product), params: { catalog_id: catalog.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("already in")
    end

    it "returns error if catalog not found" do
      post product_catalogs_path(product), params: { catalog_id: 99999 }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Catalog not found")
    end

    context "with JSON format" do
      it "returns success response" do
        post product_catalogs_path(product, format: :json), params: { catalog_id: catalog.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for blank catalog_id" do
        post product_catalogs_path(product, format: :json), params: { catalog_id: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Please select a catalog")
      end
    end

    context "multi-tenant security" do
      let(:other_company) { create(:company) }
      let(:other_product) { create(:product, company: other_company) }

      it "prevents adding catalogs to other company products" do
        expect {
          post product_catalogs_path(other_product), params: { catalog_id: catalog.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "DELETE /products/:product_id/catalogs/:id" do
    before { product.catalog_items.create!(catalog: catalog) }

    it "removes product from catalog" do
      delete product_catalog_path(product, catalog)

      expect(product.catalogs.reload).not_to include(catalog)
    end

    it "redirects to product with success message" do
      delete product_catalog_path(product, catalog)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("removed from")
      expect(response.body).to include("successfully")
    end

    it "handles catalog not on product" do
      product.catalog_items.find_by(catalog: catalog).destroy

      delete product_catalog_path(product, catalog)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("not in this catalog")
    end

    context "with JSON format" do
      it "returns success response" do
        delete product_catalog_path(product, catalog, format: :json)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for catalog not on product" do
        product.catalog_items.find_by(catalog: catalog).destroy

        delete product_catalog_path(product, catalog, format: :json)

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("not in this catalog")
      end
    end

    context "multi-tenant security" do
      let(:other_company) { create(:company) }
      let(:other_product) { create(:product, company: other_company) }

      it "prevents removing catalogs from other company products" do
        expect {
          delete product_catalog_path(other_product, catalog)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "authentication requirements" do
    before do
      # Reset authentication mocks
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(nil)
      allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(nil)
    end

    it "requires authentication for create" do
      post product_catalogs_path(product), params: { catalog_id: catalog.id }
      expect(response).to redirect_to(auth_login_path)
    end

    it "requires authentication for destroy" do
      product.catalog_items.create!(catalog: catalog)

      delete product_catalog_path(product, catalog)
      expect(response).to redirect_to(auth_login_path)
    end
  end
end
