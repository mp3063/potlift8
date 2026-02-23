# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::SyncPreviewComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: "TEST-SKU-001", name: "Test Product") }
  let(:catalog) { create(:catalog, company: company, name: "Web EU", shop_id: 42) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

  let(:payload) do
    {
      product: { sku: "TEST-SKU-001", name: "Test Product", status: "active" },
      attributes: { color: "Red", size: "Large", weight: "500g" },
      labels: [{ name: "New Arrival" }, { name: "Sale" }],
      inventory: { total_saldo: 100, warehouses: [{ name: "Main", quantity: 100 }] }
    }
  end

  let(:shopify_data) { nil }

  subject do
    render_inline(described_class.new(
      product: product,
      catalog: catalog,
      catalog_item: catalog_item,
      payload: payload,
      shopify_data: shopify_data
    ))
  end

  it "renders the drawer with dialog role" do
    subject
    expect(page).to have_css("[role='dialog'][aria-modal='true']")
  end

  it "displays product SKU and catalog name in header" do
    subject
    expect(page).to have_text("TEST-SKU-001")
    expect(page).to have_text("Web EU")
  end

  it "renders payload sections for present data keys" do
    subject
    expect(page).to have_text("Basic Product Info")
    expect(page).to have_text("Attributes")
    expect(page).to have_text("Labels")
    expect(page).to have_text("Inventory")
  end

  it "hides sections for missing data keys" do
    subject
    expect(page).not_to have_text("Translations")
    expect(page).not_to have_text("Configurations")
    expect(page).not_to have_text("Assets & Images")
    expect(page).not_to have_text("Variants / Bundle Items")
  end

  it "opens first 3 sections by default" do
    subject
    open_details = page.all("details[open]")
    expect(open_details.size).to eq(3)
  end

  it "renders hash data as key-value pairs" do
    subject
    expect(page).to have_text("sku")
    expect(page).to have_text("TEST-SKU-001")
    expect(page).to have_text("color")
    expect(page).to have_text("Red")
  end

  it "renders array data with item count" do
    subject
    expect(page).to have_text("2 items")
  end

  it "includes raw JSON toggle in footer" do
    subject
    expect(page).to have_text("Show raw JSON payload")
    expect(page).to have_css("pre", visible: :all, text: /TEST-SKU-001/)
  end

  context "without Shopify comparison data" do
    let(:shopify_data) { nil }

    it "shows 'Never synced' message for connected catalog" do
      subject
      expect(page).to have_text("Never synced to Shopify")
    end

    it "does not show sync status badges" do
      subject
      expect(page).not_to have_text("In sync")
      expect(page).not_to have_text("difference")
    end
  end

  context "with matching Shopify data" do
    let(:shopify_data) do
      {
        last_synced_at: 2.hours.ago.iso8601,
        last_payload: {
          "product" => { "sku" => "TEST-SKU-001", "name" => "Test Product", "status" => "active" },
          "attributes" => { "color" => "Red", "size" => "Large", "weight" => "500g" }
        },
        sync_task_id: 1,
        sync_status: "executed"
      }
    end

    it "shows last synced timestamp" do
      subject
      expect(page).to have_text("Last synced")
      expect(page).to have_text("ago")
    end

    it "shows 'In sync' badge for matching sections" do
      subject
      expect(page).to have_text("In sync")
    end
  end

  context "with differing Shopify data" do
    let(:shopify_data) do
      {
        last_synced_at: 1.hour.ago.iso8601,
        last_payload: {
          "product" => { "sku" => "TEST-SKU-001", "name" => "Old Product Name", "status" => "active" },
          "attributes" => { "color" => "Blue", "size" => "Large", "weight" => "500g" }
        },
        sync_task_id: 1,
        sync_status: "executed"
      }
    end

    it "shows difference count badge" do
      subject
      expect(page).to have_text(/\d+ difference/)
    end

    it "highlights differing fields with both values" do
      subject
      expect(page).to have_text("Potlift:")
      expect(page).to have_text("Shopify:")
    end
  end

  describe "#format_value" do
    let(:component) do
      described_class.new(
        product: product,
        catalog: catalog,
        catalog_item: catalog_item,
        payload: payload,
        shopify_data: shopify_data
      )
    end

    it "formats nil as italic 'null'" do
      result = component.format_value(nil)
      expect(result.to_s).to include("null")
    end

    it "formats booleans with color" do
      result = component.format_value(true)
      expect(result.to_s).to include("true")
      expect(result.to_s).to include("text-green-600")
    end

    it "formats false with red color" do
      result = component.format_value(false)
      expect(result.to_s).to include("false")
      expect(result.to_s).to include("text-red-600")
    end

    it "formats hashes as truncated JSON" do
      result = component.format_value({ key: "value" })
      expect(result.to_s).to include("key")
    end

    it "formats arrays with item count" do
      result = component.format_value([1, 2, 3])
      expect(result.to_s).to include("3 items")
    end

    it "truncates long strings" do
      long_string = "a" * 300
      result = component.format_value(long_string)
      expect(result.length).to be <= 203 # 200 chars + "..."
    end

    it "converts numbers to string" do
      result = component.format_value(42)
      expect(result).to eq("42")
    end
  end
end
