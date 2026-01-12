# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductDuplication do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: "ORIGINAL", name: "Original Product") }
  let(:attribute) { create(:product_attribute, company: company, code: "color") }
  let(:label) { create(:label, company: company) }

  before do
    product.product_attribute_values.create!(product_attribute: attribute, value: "blue")
    product.labels << label
  end

  describe "#duplicate!" do
    it "creates a new product" do
      expect { product.duplicate! }.to change(Product, :count).by(1)
    end

    it "generates unique SKU with _COPY suffix" do
      copy = product.duplicate!

      expect(copy.sku).to start_with("ORIGINAL_COPY_")
    end

    it "adds (Copy) suffix to name" do
      copy = product.duplicate!

      expect(copy.name).to eq("Original Product (Copy)")
    end

    it "duplicates attribute values" do
      copy = product.duplicate!

      expect(copy.product_attribute_values.count).to eq(1)
      expect(copy.read_attribute_value("color")).to eq("blue")
    end

    it "copies labels" do
      copy = product.duplicate!

      expect(copy.labels).to include(label)
    end
  end
end
