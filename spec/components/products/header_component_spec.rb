# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::HeaderComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: "TEST-001", name: "Test Product", product_status: :active) }

  it "renders the product name as the page heading" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("h1", text: "Test Product")
  end

  describe "status badge" do
    it "renders a success badge with a dot for active products" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-green-100.text-green-800", text: "Active")
      expect(page).to have_css("span.bg-current")
    end

    it "renders a warning badge for draft products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-yellow-100.text-yellow-800", text: "Draft")
    end

    it "renders a danger badge for discontinued products" do
      product.update!(product_status: :discontinued)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-red-100.text-red-800", text: "Discontinued")
    end

    it "renders a gray badge for disabled products" do
      product.update!(product_status: :disabled)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-gray-100.text-gray-800", text: "Disabled")
    end
  end

  describe "type badge" do
    it "shows the product type" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-blue-100", text: "Sellable")
    end

    it "appends the configuration type for configurables" do
      configurable = create(:product, :configurable_variant, company: company)
      render_inline(described_class.new(product: configurable))

      expect(page).to have_css("span.bg-blue-100", text: "Configurable · Variant")
    end
  end

  describe "facts strip" do
    it "shows the SKU in monospace" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd.font-mono", text: "TEST-001")
    end

    it "shows the EAN when present" do
      product.update!(ean: "1234567890123")
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd.font-mono", text: "1234567890123")
    end

    it "shows a dash when the EAN is blank" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd", text: "—")
    end

    it "shows the restock level from info" do
      product.update!(info: { "restock_level" => 25 })
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Restock level")
      expect(page).to have_css("dd", text: "25")
    end

    it "shows the last updated time" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("ago")
    end
  end

  describe "description" do
    it "is omitted when blank" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("p.line-clamp-2")
    end

    it "renders clamped to two lines when present" do
      product.update!(info: { "description" => "A long description" })
      render_inline(described_class.new(product: product))

      expect(page).to have_css("p.line-clamp-2", text: "A long description")
    end
  end

  describe "actions" do
    it "links to the edit page" do
      render_inline(described_class.new(product: product))

      expect(page).to have_link("Edit", href: "/products/#{product.id}/edit")
    end

    it "shows a gray Deactivate button for active products" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-gray-600", text: "Deactivate")
    end

    it "shows a green Activate button for inactive products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-green-600", text: "Activate")
    end

    it "puts Assets, Duplicate and Delete in the More menu" do
      render_inline(described_class.new(product: product))

      menu = "[data-controller='dropdown'] [role='menu']"
      expect(page).to have_css("#{menu} a[role='menuitem']", text: "Assets")
      expect(page).to have_css("#{menu} button[role='menuitem']", text: "Duplicate")
      expect(page).to have_css("#{menu} button[role='menuitem']", text: "Delete")
    end
  end

  describe "inactive variants notice" do
    let(:configurable) { create(:product, :configurable_variant, company: company, product_status: :draft) }

    before do
      active_variant = create(:product, company: company, product_status: :active)
      draft_variant = create(:product, company: company, product_status: :draft)
      create(:product_configuration, superproduct: configurable, subproduct: active_variant)
      create(:product_configuration, superproduct: configurable, subproduct: draft_variant)
    end

    it "shows the count and an activate-all button for an inactive configurable with inactive variants" do
      render_inline(described_class.new(product: configurable))

      expect(page).to have_text("1 of 2 variants not yet active")
      expect(page).to have_button("Activate all variants")
    end

    it "is hidden when the product is active" do
      configurable.update!(product_status: :active)
      render_inline(described_class.new(product: configurable))

      expect(page).not_to have_button("Activate all variants")
    end

    it "is hidden for sellable products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).not_to have_button("Activate all variants")
    end
  end
end
