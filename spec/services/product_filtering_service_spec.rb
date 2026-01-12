require "rails_helper"

RSpec.describe ProductFilteringService do
  let(:company) { create(:company) }
  let!(:product1) { create(:product, company: company, product_type: :sellable, product_status: :active) }
  let!(:product2) { create(:product, :configurable_variant, company: company, product_status: :draft) }
  let!(:product3) { create(:product, company: company, product_type: :bundle, product_status: :active) }
  let(:base_scope) { company.products }

  describe "#call" do
    context "with no filters" do
      it "returns all products" do
        service = described_class.new(base_scope, {})
        result = service.call

        expect(result.count).to eq(3)
      end
    end

    context "with type filter" do
      it "filters by product type" do
        service = described_class.new(base_scope, { type: "sellable" })
        result = service.call

        expect(result).to contain_exactly(product1)
      end
    end

    context "with status filter" do
      it "filters by product status" do
        service = described_class.new(base_scope, { status: "active" })
        result = service.call

        expect(result).to contain_exactly(product1, product3)
      end
    end

    context "with search query" do
      let!(:product4) { create(:product, company: company, name: "Special Widget", sku: "WIDGET-001") }

      it "searches by name" do
        service = described_class.new(base_scope, { q: "widget" })
        result = service.call

        expect(result).to contain_exactly(product4)
      end

      it "searches by SKU" do
        service = described_class.new(base_scope, { q: "WIDGET-001" })
        result = service.call

        expect(result).to contain_exactly(product4)
      end
    end

    context "with label filter" do
      let(:label) { create(:label, company: company) }
      let(:sublabel) { create(:label, company: company, parent_label: label) }

      before do
        product1.labels << label
        product2.labels << sublabel
      end

      it "filters by label including descendants" do
        service = described_class.new(base_scope, { label_id: label.id.to_s }, company)
        result = service.call

        expect(result).to contain_exactly(product1, product2)
      end

      it "exposes current_label" do
        service = described_class.new(base_scope, { label_id: label.id.to_s }, company)
        service.call

        expect(service.current_label).to eq(label)
      end
    end
  end

  describe "#sort_column" do
    it "returns allowed column when valid" do
      service = described_class.new(base_scope, { sort: "sku" })
      expect(service.sort_column).to eq("sku")
    end

    it "returns default when invalid" do
      service = described_class.new(base_scope, { sort: "invalid" })
      expect(service.sort_column).to eq("created_at")
    end
  end

  describe "#sort_direction" do
    it "returns allowed direction when valid" do
      service = described_class.new(base_scope, { direction: "asc" })
      expect(service.sort_direction).to eq("asc")
    end

    it "returns default when invalid" do
      service = described_class.new(base_scope, { direction: "invalid" })
      expect(service.sort_direction).to eq("desc")
    end
  end
end
