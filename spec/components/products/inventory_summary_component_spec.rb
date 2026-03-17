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

  context "with storage locations" do
    let!(:inventory1) { create(:inventory, product: product, storage: storage1, value: 100) }
    let!(:inventory2) { create(:inventory, product: product, storage: storage2, value: 50) }

    before do
      allow(product).to receive(:total_inventory).and_return(150)
    end

    it "displays storage locations with inventory counts" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Main Warehouse")
      expect(page).to have_text("100")
      expect(page).to have_text("Retail Store")
      expect(page).to have_text("50")
    end

    it "displays storage locations in definition list" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dl.space-y-2")
      expect(page).to have_css("dt.text-gray-500", count: 2)
      expect(page).to have_css("dd.font-medium", count: 2)
    end

    it "displays Manage Inventory link" do
      render_inline(described_class.new(product: product))

      expect(page).to have_link("Manage Inventory", href: product_inventories_path(product))
    end

    it "uses blue-600 color scheme for link" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("a.text-blue-600", text: "Manage Inventory")
    end
  end

  context "with zero value inventory" do
    let!(:inventory) { create(:inventory, product: product, storage: storage1, value: 0) }

    it "displays 0 for zero value" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd.font-medium", text: "0")
    end
  end

  it "sorts storage locations by name" do
    create(:inventory, product: product, storage: storage2, value: 50)  # Retail Store
    create(:inventory, product: product, storage: storage1, value: 100) # Main Warehouse
    allow(product).to receive(:total_inventory).and_return(150)

    render_inline(described_class.new(product: product))

    storage_names = page.all("dt.text-gray-500").map(&:text)
    expect(storage_names).to eq([ "Main Warehouse", "Retail Store" ])
  end

  it "includes proper spacing and layout" do
    create(:inventory, product: product, storage: storage1, value: 100)
    allow(product).to receive(:total_inventory).and_return(100)

    render_inline(described_class.new(product: product))

    expect(page).to have_css("div.mb-4")        # Total inventory spacing
    expect(page).to have_css("dl.space-y-2")    # Storage locations spacing
    expect(page).to have_css("div.mt-4")        # Manage Inventory link spacing
  end
end
