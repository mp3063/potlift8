require "rails_helper"

RSpec.describe LabelProductCountService do
  let(:company) { create(:company) }
  let!(:parent_label) { create(:label, company: company) }
  let!(:child_label) { create(:label, company: company, parent_label: parent_label) }
  let!(:grandchild_label) { create(:label, company: company, parent_label: child_label) }
  let!(:unrelated_label) { create(:label, company: company) }

  let!(:product1) { create(:product, company: company) }
  let!(:product2) { create(:product, company: company) }
  let!(:product3) { create(:product, company: company) }

  before do
    product1.labels << parent_label
    product2.labels << child_label
    product3.labels << grandchild_label
  end

  describe "#call" do
    it "returns hash of label_id => count" do
      service = described_class.new(company)
      result = service.call

      expect(result).to be_a(Hash)
    end

    it "counts products including descendants for parent label" do
      service = described_class.new(company)
      result = service.call

      expect(result[parent_label.id]).to eq(3)
    end

    it "counts products including descendants for child label" do
      service = described_class.new(company)
      result = service.call

      expect(result[child_label.id]).to eq(2)
    end

    it "counts only direct products for grandchild label" do
      service = described_class.new(company)
      result = service.call

      expect(result[grandchild_label.id]).to eq(1)
    end

    it "returns zero for labels with no products" do
      service = described_class.new(company)
      result = service.call

      expect(result[unrelated_label.id]).to eq(0)
    end
  end
end
