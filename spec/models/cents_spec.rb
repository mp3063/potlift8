# frozen_string_literal: true

require "rails_helper"

RSpec.describe Cents do
  describe ".format" do
    it "shows euros with a comma and the symbol" do
      expect(described_class.format("4000")).to eq("40,00 €")
    end

    it "groups thousands with a space" do
      expect(described_class.format(123_450)).to eq("1 234,50 €")
    end

    it "uses the currency code for other currencies" do
      expect(described_class.format("4000", currency: "sek")).to eq("40,00 SEK")
    end

    it "returns nil for blank values" do
      expect(described_class.format(nil)).to be_nil
      expect(described_class.format("")).to be_nil
    end

    it "leaves values that are not whole cents untouched" do
      expect(described_class.format("19.99")).to eq("19.99")
    end
  end

  describe ".to_input" do
    it "renders cents as an editable amount" do
      expect(described_class.to_input("4050")).to eq("40,50")
    end

    it "returns an empty string for blank values" do
      expect(described_class.to_input(nil)).to eq("")
    end
  end

  describe ".to_decimal" do
    it "renders cents with a dot for CSV" do
      expect(described_class.to_decimal("123450")).to eq("1234.50")
    end

    it "returns nil for blank values" do
      expect(described_class.to_decimal(nil)).to be_nil
    end
  end

  describe ".parse" do
    {
      "40" => 4000,
      "40,00" => 4000,
      "40.00" => 4000,
      "40,5" => 4050,
      "0,99" => 99,
      " 1 234,50 " => 123_450,
      "1234.5" => 123_450
    }.each do |input, cents|
      it "reads #{input.inspect} as #{cents}" do
        expect(described_class.parse(input)).to eq(cents)
      end
    end

    it "returns nil for blank input" do
      expect(described_class.parse("")).to be_nil
      expect(described_class.parse(nil)).to be_nil
    end

    [ "abc", "40,001", "-5", "1.234,50", "4 0,0 0,1" ].each do |input|
      it "rejects #{input.inspect}" do
        expect { described_class.parse(input) }.to raise_error(Cents::InvalidAmount)
      end
    end
  end
end
