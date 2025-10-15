# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::BasicInfoComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: "TEST-001", name: "Test Product", ean: "1234567890123", description: "Test description") }

  it "renders basic product information" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Basic Information")
    expect(page).to have_text("TEST-001")
    expect(page).to have_text("Test Product")
    expect(page).to have_text("1234567890123")
    expect(page).to have_text("Test description")
  end

  it "displays SKU in monospace font" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("dd.font-mono", text: "TEST-001")
  end

  it "displays EAN when present" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("EAN")
    expect(page).to have_text("1234567890123")
  end

  it "displays dash when EAN is not present" do
    product.update!(ean: nil)
    render_inline(described_class.new(product: product))

    expect(page).to have_text("EAN")
    expect(page).to have_text("—")
  end

  it "displays product type badge" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("span.rounded-full", text: product.product_type.humanize)
  end

  it "displays status badge with dot indicator" do
    product.update!(product_status: :active)
    render_inline(described_class.new(product: product))

    expect(page).to have_css("span.rounded-full", text: "Active")
    expect(page).to have_css("span.bg-current") # dot indicator
  end

  context "with active status" do
    before { product.update!(product_status: :active) }

    it "displays success badge variant" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-green-100.text-green-800", text: "Active")
    end
  end

  context "with draft status" do
    before { product.update!(product_status: :draft) }

    it "displays warning badge variant" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-yellow-100.text-yellow-800", text: "Draft")
    end
  end

  context "with discontinued status" do
    before { product.update!(product_status: :discontinued) }

    it "displays danger badge variant" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-red-100.text-red-800", text: "Discontinued")
    end
  end

  context "without description" do
    before { product.update!(description: nil) }

    it "does not display description section" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_text("Description")
    end
  end

  context "with description" do
    before { product.update!(description: "Test description\nSecond line") }

    it "displays description with preserved whitespace" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Description")
      expect(page).to have_css("dd.whitespace-pre-wrap")
    end
  end
end
