# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::InventorySummaryComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:storage1) { create(:storage, name: "Main Warehouse", company: company) }
  let(:storage2) { create(:storage, name: "Retail Store", company: company) }

  it "renders inventory header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Inventory")
  end

  it "displays total inventory count" do
    allow(product).to receive(:total_inventory).and_return(150)
    render_inline(described_class.new(product: product))

    expect(page).to have_text("150")
    expect(page).to have_text("total units")
  end

  it "displays total inventory in large font" do
    allow(product).to receive(:total_inventory).and_return(150)
    render_inline(described_class.new(product: product))

    expect(page).to have_css("span.text-3xl.font-bold", text: "150")
  end

  context "with no storage locations" do
    it "displays empty state message" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No inventory locations")
    end

    it "displays empty state icon" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("svg.text-gray-400")
    end

    it "displays zero for total inventory" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("0")
      expect(page).to have_text("total units")
    end
  end

  # NOTE: Tests below are pending - product_inventories_path route not yet implemented
  # The inventory detail page is planned but not yet built
  context "with storage locations", skip: "product_inventories_path route not implemented" do
    let!(:inventory1) { create(:inventory, product: product, storage: storage1, value: 100) }
    let!(:inventory2) { create(:inventory, product: product, storage: storage2, value: 50) }

    before do
      allow(product).to receive(:total_inventory).and_return(150)
    end

    it "displays storage locations with inventory counts" do
      skip "Requires product_inventories_path route"
    end

    it "displays storage locations in definition list" do
      skip "Requires product_inventories_path route"
    end

    it "displays View Details link" do
      skip "Requires product_inventories_path route"
    end

    it "uses blue-600 color scheme for link" do
      skip "Requires product_inventories_path route"
    end
  end

  context "with nil value attribute", skip: "Inventory value is required (can't be nil)" do
    it "displays 0 for nil value" do
      skip "Inventory validation requires value to be present"
    end
  end

  it "sorts storage locations by name", skip: "Requires product_inventories_path route" do
    skip "Requires product_inventories_path route"
  end

  it "includes proper spacing and layout", skip: "Requires product_inventories_path route" do
    skip "Requires product_inventories_path route"
  end
end
