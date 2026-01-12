# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Product Bulk Operations", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user) }

  before do
    # Mock authentication (same pattern as other request specs)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(
      { "id" => company.id, "code" => company.code, "name" => company.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
  end

  describe "POST /products/bulk/destroy" do
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }

    it "deletes multiple products" do
      expect {
        post products_bulk_destroy_path, params: { product_ids: [ product1.id, product2.id ] }
      }.to change(Product, :count).by(-2)

      expect(response).to redirect_to(products_path)
    end

    it "handles empty selection" do
      expect {
        post products_bulk_destroy_path, params: { product_ids: [] }
      }.not_to change(Product, :count)

      expect(response).to redirect_to(products_path)
    end
  end

  describe "POST /products/bulk/update_labels" do
    let!(:product1) { create(:product, company: company) }
    let!(:product2) { create(:product, company: company) }
    let!(:label) { create(:label, company: company) }

    it "adds labels to multiple products" do
      post products_bulk_update_labels_path, params: {
        product_ids: [ product1.id, product2.id ],
        label_ids: [ label.id ],
        action_type: "add"
      }

      expect(product1.reload.labels).to include(label)
      expect(product2.reload.labels).to include(label)
    end

    it "removes labels from multiple products" do
      product1.labels << label
      product2.labels << label

      post products_bulk_update_labels_path, params: {
        product_ids: [ product1.id, product2.id ],
        label_ids: [ label.id ],
        action_type: "remove"
      }

      expect(product1.reload.labels).not_to include(label)
      expect(product2.reload.labels).not_to include(label)
    end
  end
end
