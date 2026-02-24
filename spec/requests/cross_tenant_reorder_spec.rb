# frozen_string_literal: true

RSpec.describe "Cross-tenant reorder isolation", type: :request do
  let(:company_a) { create(:company) }
  let(:company_b) { create(:company) }
  let(:user_a) { create(:user, company: company_a) }

  let(:product_a) { create(:product, :configurable_variant, company: company_a) }
  let(:product_b) { create(:product, :configurable_variant, company: company_b) }

  before { authenticate_user(user_a, role: "admin") }

  describe "PATCH /products/:product_id/variants/reorder" do
    let!(:config_b) { create(:product_configuration, superproduct: product_b, subproduct: create(:product, company: company_b), configuration_position: 5) }

    it "rejects reorder with foreign ProductConfiguration IDs" do
      expect {
        patch reorder_product_variants_path(product_a), params: { order: [config_b.id] }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(config_b.reload.configuration_position).to eq(5)
    end

    it "allows reorder with own ProductConfiguration IDs" do
      own_config = create(:product_configuration, superproduct: product_a, subproduct: create(:product, company: company_a), configuration_position: 1)
      patch reorder_product_variants_path(product_a), params: { order: [own_config.id] }
      expect(response).to have_http_status(:ok)
      expect(own_config.reload.configuration_position).to eq(1)
    end
  end

  describe "PATCH /products/:product_id/bundle_products/reorder" do
    let(:bundle_a) { create(:product, :bundle, company: company_a) }
    let(:bundle_b) { create(:product, :bundle, company: company_b) }
    let!(:config_b) { create(:product_configuration, :bundle_item, superproduct: bundle_b, subproduct: create(:product, company: company_b), configuration_position: 5) }

    it "rejects reorder with foreign ProductConfiguration IDs" do
      expect {
        patch reorder_product_bundle_products_path(bundle_a), params: { order: [config_b.id] }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(config_b.reload.configuration_position).to eq(5)
    end

    it "allows reorder with own ProductConfiguration IDs" do
      own_config = create(:product_configuration, :bundle_item, superproduct: bundle_a, subproduct: create(:product, company: company_a), configuration_position: 1)
      patch reorder_product_bundle_products_path(bundle_a), params: { order: [own_config.id] }
      expect(response).to have_http_status(:ok)
      expect(own_config.reload.configuration_position).to eq(1)
    end
  end

  describe "PATCH /products/:product_id/related_products/reorder" do
    let!(:related_b) { create(:related_product, product: product_b, position: 5) }

    it "rejects reorder with foreign RelatedProduct IDs" do
      expect {
        patch reorder_product_related_products_path(product_a), params: { order: [related_b.id] }
      }.to raise_error(ActiveRecord::RecordNotFound)
      expect(related_b.reload.position).to eq(5)
    end

    it "allows reorder with own RelatedProduct IDs" do
      own_related = create(:related_product, product: product_a, related_to: create(:product, company: company_a), position: 1)
      patch reorder_product_related_products_path(product_a), params: { order: [own_related.id] }
      expect(response).to have_http_status(:ok)
      expect(own_related.reload.position).to eq(1)
    end
  end
end
