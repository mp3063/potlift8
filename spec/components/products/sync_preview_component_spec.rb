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
      labels: [ { name: "New Arrival" }, { name: "Sale" } ],
      inventory: { total_saldo: 100, warehouses: [ { name: "Main", quantity: 100 } ] }
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
          "sku" => "TEST-SKU-001", "name" => "Test Product", "status" => "active",
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
          "sku" => "TEST-SKU-001", "name" => "Old Product Name", "status" => "active",
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

  describe "Basic Product Info diff" do
    let(:payload) do
      { product: { id: product.id, sku: "TEST-SKU-001", name: "Test Product", product_status: "active" } }
    end

    def basic_info_summary
      page.find("summary", text: "Basic Product Info")
    end

    # The sent load as the client returns it: flat, symbol keys, no id
    def shopify_data_with(load)
      { last_synced_at: 1.hour.ago.iso8601, last_payload: load, sync_task_id: 1, sync_status: "executed" }
    end

    context "when the sent fields match" do
      let(:shopify_data) { shopify_data_with(sku: "TEST-SKU-001", name: "Test Product", product_status: "active") }

      it "shows In sync" do
        subject
        expect(basic_info_summary).to have_text("In sync")
      end
    end

    context "when a sent field differs" do
      let(:shopify_data) { shopify_data_with(sku: "TEST-SKU-001", name: "Old Name", product_status: "active") }

      it "counts only that field" do
        subject
        expect(basic_info_summary).to have_text("1 difference")
        expect(page).to have_text("Old Name")
      end
    end
  end

  describe "Variants / Bundle Items diff" do
    let(:product) { create(:product, :configurable_variant, company: company, sku: "TEST-SKU-001") }
    let(:payload) do
      {
        subproducts: [ {
          quantity: 1, configuration_position: 1, variant_config: { "size" => "S" }, configuration_details: nil,
          product: { id: 99, sku: "TEST-SKU-001-S", ean: nil, name: "Small", product_type: "sellable", product_status: "active" },
          attributes: { "color" => { value: "Red" } }, inventory: { total_saldo: 3 }, translations: {}
        } ]
      }
    end
    let(:sent_variant) do
      { sku: "TEST-SKU-001-S", name: "Small", product_type: "sellable", product_status: "active", quantity: 1,
        configuration_position: 1, variant_config: { size: "S" }, attributes: { color: { value: "Red" } },
        inventory: { total_saldo: 3 }, translations: {} }
    end
    let(:shopify_data) do
      { last_synced_at: 1.hour.ago.iso8601, last_payload: { sku: "TEST-SKU-001", subproducts: [ sent_variant ] },
        sync_task_id: 1, sync_status: "executed" }
    end

    def variants_summary
      page.find("summary", text: "Variants / Bundle Items")
    end

    it "shows In sync when the stored load is what would be sent" do
      subject
      expect(variants_summary).to have_text("In sync")
    end

    it "compares dates the way they are stored" do
      payload[:subproducts].first[:inventory][:eta] = Date.new(2026, 3, 23)
      sent_variant[:inventory][:eta] = "2026-03-23"
      subject
      expect(variants_summary).to have_text("In sync")
    end

    it "flags a variant that changed since" do
      sent_variant[:name] = "Old Small"
      subject
      expect(variants_summary).not_to have_text("In sync")
    end
  end

  describe "showing which values differ" do
    let(:payload) do
      {
        product: { id: product.id, sku: "TEST-SKU-001", name: "New Name", product_status: "active" },
        attributes: { "weight" => { value: "500", shopify_field: "weight" }, "color" => { value: "Red" } },
        labels: [ { code: "new", name: "New Arrival" }, { code: "sale", name: "Sale" } ]
      }
    end
    let(:stored) do
      { sku: "TEST-SKU-001", name: "Old Name", product_status: "active",
        attributes: { weight: { value: "400", shopify_field: "weight" }, color: { value: "Red" } },
        labels: [ { code: "new", name: "Fresh" } ] }
    end
    let(:shopify_data) { { last_synced_at: 1.hour.ago.iso8601, last_payload: stored, sync_task_id: 1, sync_status: "executed" } }

    def section(title)
      page.find("summary", text: title).ancestor("details")
    end

    def changed_rows(title)
      section(title).all("[data-diff='changed']")
    end

    it "shows both values of a changed field, and only on that row" do
      subject
      rows = changed_rows("Basic Product Info")
      expect(rows.size).to eq(1)
      expect(rows.first).to have_text(/Potlift:\s+New Name/).and have_text(/Shopify:\s+Old Name/)
    end

    it "renders the compared fields, not the payload's" do
      subject
      expect(section("Basic Product Info")).not_to have_css("td", exact_text: "id")
    end

    it "shows a nested change by its dotted path and leaf values" do
      subject
      row = changed_rows("Attributes").sole
      expect(row).to have_text("weight.value").and have_text(/Potlift:\s+500/).and have_text(/Shopify:\s+400/)
      expect(row).not_to have_text("shopify_field")
    end

    it "highlights a changed field inside an array item" do
      subject
      item = section("Labels").all("[data-diff-item]").first
      expect(item["data-diff-item"]).to eq("changed")
      expect(item).to have_text(/Potlift:\s+New Arrival/).and have_text(/Shopify:\s+Fresh/)
    end

    it "marks an item that is only on the Potlift side" do
      subject
      item = section("Labels").all("[data-diff-item]").last
      expect(item).to have_text("Not in Shopify yet").and have_text("Sale")
    end

    it "marks an item that is only on the stored side, with its stored fields" do
      stored[:labels] << { code: "old", name: "Clearance" }
      payload[:labels].pop
      subject
      item = section("Labels").all("[data-diff-item]").last
      expect(item).to have_text("Only in Shopify").and have_text("Clearance")
    end

    it "keeps a section whose items were all removed, marking the stored ones" do
      payload[:labels] = []
      subject
      expect(section("Labels")).to have_css("summary", text: "1 difference")
      expect(section("Labels").find("[data-diff-item]")).to have_text("Only in Shopify").and have_text("Fresh")
    end

    it "marks every item when the section was last sent empty" do
      stored[:labels] = []
      subject
      expect(section("Labels")).to have_css("summary", text: "2 differences")
      expect(section("Labels").all("[data-diff-item]").map(&:text)).to all(include("Not in Shopify yet"))
    end

    it "counts changed fields plus added and removed items" do
      subject
      expect(section("Labels")).to have_css("summary", text: "2 differences")
      expect(section("Attributes")).to have_css("summary", text: "1 difference")
    end

    it "opens sections with differences" do
      payload[:inventory] = { total_saldo: 1 }
      payload[:translations] = { "sv" => { "name" => "Ny" } }
      stored[:translations] = { sv: { name: "Gammal" } }
      subject
      expect(section("Translations")[:open]).not_to be_nil
    end
  end

  describe "without comparison data" do
    let(:payload) { { product: { id: 7, sku: "TEST-SKU-001", status: "active" } } }

    it "renders the payload as it is" do
      subject
      expect(page).to have_css("td", exact_text: "id").and have_css("td", exact_text: "status")
      expect(page).not_to have_css("[data-diff='changed']")
    end
  end

  describe "changed since sync badge" do
    it "shows when the catalog item is out of date" do
      catalog_item.update!(sync_status: :synced, last_synced_at: 2.hours.ago, content_changed_at: 1.hour.ago)
      subject
      expect(page).to have_text("Changed since sync")
    end

    it "is absent when the catalog item is up to date" do
      catalog_item.update!(sync_status: :synced, last_synced_at: 1.hour.ago, content_changed_at: 2.hours.ago)
      subject
      expect(page).not_to have_text("Changed since sync")
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
      result = component.format_value([ 1, 2, 3 ])
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
