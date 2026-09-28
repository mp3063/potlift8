# frozen_string_literal: true

require "rails_helper"

RSpec.describe MoneyHelper, type: :helper do
  let(:company) { create(:company) }
  let(:price) { company.product_attributes.find_by!(code: "price") }
  let(:special_price) { company.product_attributes.find_by!(code: "special_price") }
  let(:weight) { company.product_attributes.find_by!(code: "weight") }

  describe "#attribute_display_value" do
    it "formats money cents in euros by default" do
      expect(helper.attribute_display_value(price, "4000")).to eq("40,00 €")
    end

    it "formats money cents in the given currency" do
      expect(helper.attribute_display_value(price, "4000", currency: "sek")).to eq("40,00 SEK")
    end

    it "leaves non-money values alone" do
      expect(helper.attribute_display_value(weight, "2500")).to eq("2500")
    end

    it "returns blank values unchanged" do
      expect(helper.attribute_display_value(price, nil)).to be_nil
    end

    it "appends the date range of a special price" do
      expect(helper.attribute_display_value(special_price, "3500,2026-10-01,2026-10-31"))
        .to eq("35,00 € (2026-10-01 – 2026-10-31)")
    end

    it "formats a plain special price amount" do
      expect(helper.attribute_display_value(special_price, "3500")).to eq("35,00 €")
    end
  end

  describe "#attribute_input_value" do
    it "turns money cents into an editable amount" do
      expect(helper.attribute_input_value(price, "4050")).to eq("40,50")
    end

    it "keeps only the amount of a special price" do
      expect(helper.attribute_input_value(special_price, "3500,2026-10-01,2026-10-31")).to eq("35,00")
    end

    it "leaves non-money values alone" do
      expect(helper.attribute_input_value(weight, "2500")).to eq("2500")
    end
  end
end
