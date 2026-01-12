# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProductTranslations do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, name: "English Name") }

  describe "#translated_name" do
    it "returns translation for locale" do
      product.set_translated_name(:es, "Nombre Espanol")

      expect(product.translated_name(:es)).to eq("Nombre Espanol")
    end

    it "falls back to original name if no translation" do
      expect(product.translated_name(:fr)).to eq("English Name")
    end
  end

  describe "#translated_description" do
    before { product.description = "English description" }

    it "returns translation for locale" do
      product.set_translated_description(:es, "Descripcion espanola")

      expect(product.translated_description(:es)).to eq("Descripcion espanola")
    end

    it "falls back to original description if no translation" do
      expect(product.translated_description(:fr)).to eq("English description")
    end
  end

  describe "#set_translated_name" do
    it "creates translation record" do
      expect {
        product.set_translated_name(:de, "Deutscher Name")
      }.to change { product.translations.count }.by(1)
    end

    it "updates existing translation" do
      product.set_translated_name(:de, "Original")
      product.set_translated_name(:de, "Updated")

      expect(product.translated_name(:de)).to eq("Updated")
    end
  end

  describe "#set_translated_description" do
    it "creates translation record" do
      expect {
        product.set_translated_description(:de, "Deutsche Beschreibung")
      }.to change { product.translations.count }.by(1)
    end
  end
end
