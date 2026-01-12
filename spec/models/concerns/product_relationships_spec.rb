# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductRelationships do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, product_type: :configurable, configuration_type: :variant) }
  let(:variant) { create(:product, company: company, product_type: :sellable) }
  let(:cross_sell_product) { create(:product, company: company) }
  let(:upsell_product) { create(:product, company: company) }

  before do
    # Create configuration for variants
    ProductConfiguration.create!(superproduct: product, subproduct: variant)

    # Create related products
    RelatedProduct.create!(product: product, related_to: cross_sell_product, relation_type: :cross_sell)
    RelatedProduct.create!(product: product, related_to: upsell_product, relation_type: :upsell)
  end

  describe "#has_variants?" do
    it "returns true for configurable product with subproducts" do
      expect(product.has_variants?).to be true
    end

    it "returns false for sellable product" do
      expect(variant.has_variants?).to be false
    end
  end

  describe "#is_variant?" do
    it "returns true for product that is a subproduct" do
      expect(variant.is_variant?).to be true
    end

    it "returns false for parent product" do
      expect(product.is_variant?).to be false
    end
  end

  describe "#variants" do
    it "returns subproducts" do
      expect(product.variants).to include(variant)
    end
  end

  describe "#cross_sell_products" do
    it "returns cross-sell related products" do
      expect(product.cross_sell_products).to include(cross_sell_product)
    end
  end

  describe "#upsell_products" do
    it "returns upsell related products" do
      expect(product.upsell_products).to include(upsell_product)
    end
  end

  describe "#alternative_products" do
    let(:alternative_product) { create(:product, company: company) }

    before do
      RelatedProduct.create!(product: product, related_to: alternative_product, relation_type: :alternative)
    end

    it "returns alternative related products" do
      expect(product.alternative_products).to include(alternative_product)
    end
  end

  describe "#accessory_products" do
    let(:accessory_product) { create(:product, company: company) }

    before do
      RelatedProduct.create!(product: product, related_to: accessory_product, relation_type: :accessory)
    end

    it "returns accessory related products" do
      expect(product.accessory_products).to include(accessory_product)
    end
  end

  describe "#similar_products" do
    let(:similar_product) { create(:product, company: company) }

    before do
      RelatedProduct.create!(product: product, related_to: similar_product, relation_type: :similar)
    end

    it "returns similar related products" do
      expect(product.similar_products).to include(similar_product)
    end
  end
end
