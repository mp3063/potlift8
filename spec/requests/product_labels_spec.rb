# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Product Labels", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let!(:product) { create(:product, company: company) }
  let!(:label) { create(:label, company: company) }

  before do
    authenticate_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe "POST /products/:product_id/labels" do
    it "adds a label to the product" do
      post product_labels_path(product), params: { label_id: label.id }

      expect(product.reload.labels).to include(label)
    end

    it "redirects to product with success message" do
      post product_labels_path(product), params: { label_id: label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label")
      expect(response.body).to include("added successfully")
    end

    it "returns error for blank label_id" do
      post product_labels_path(product), params: { label_id: "" }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Please select a label")
    end

    it "returns error if label already assigned" do
      product.labels << label

      post product_labels_path(product), params: { label_id: label.id }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label already assigned")
    end

    it "returns error if label not found" do
      post product_labels_path(product), params: { label_id: 99999 }

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label not found")
    end

    context "with JSON format" do
      it "returns success response" do
        post product_labels_path(product, format: :json), params: { label_id: label.id }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for blank label_id" do
        post product_labels_path(product, format: :json), params: { label_id: "" }

        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Please select a label")
      end
    end

    context "multi-tenant security" do
      let(:other_company) { create(:company) }
      let(:other_product) { create(:product, company: other_company) }

      it "prevents adding labels to other company products" do
        expect {
          post product_labels_path(other_product), params: { label_id: label.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "DELETE /products/:product_id/labels/:id" do
    before { product.labels << label }

    it "removes a label from the product" do
      delete product_label_path(product, label.id)

      expect(product.reload.labels).not_to include(label)
    end

    it "redirects to product with success message" do
      delete product_label_path(product, label.id)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label")
      expect(response.body).to include("removed successfully")
    end

    it "handles label not on product" do
      product.labels.delete(label)

      delete product_label_path(product, label.id)

      expect(response).to redirect_to(product)
      follow_redirect!
      expect(response.body).to include("Label not found on this product")
    end

    context "with JSON format" do
      it "returns success response" do
        delete product_label_path(product, label.id, format: :json)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "returns error for label not on product" do
        product.labels.delete(label)

        delete product_label_path(product, label.id, format: :json)

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to include("Label not found on this product")
      end
    end

    context "multi-tenant security" do
      let(:other_company) { create(:company) }
      let(:other_product) { create(:product, company: other_company) }

      it "prevents removing labels from other company products" do
        expect {
          delete product_label_path(other_product, label.id)
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
      post product_labels_path(product), params: { label_id: label.id }
      expect(response).to redirect_to(auth_login_path)
    end

    it "requires authentication for destroy" do
      product.labels << label

      delete product_label_path(product, label.id)
      expect(response).to redirect_to(auth_login_path)
    end
  end
end
