# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::StatusCardComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, product_status: :active) }

  it "renders status header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Status")
  end

  it "displays active status label" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Active Status")
  end

  it "displays product type label" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Product Type")
    expect(page).to have_text(product.product_type.humanize)
  end

  it "displays last updated timestamp" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Last Updated")
    expect(page).to have_text("ago")
  end

  context "with active product" do
    before { product.update!(product_status: :active) }

    it "displays active status with check-circle icon" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Active")
      expect(page).to have_css("svg.text-green-500")
    end

    it "displays Deactivate button" do
      render_inline(described_class.new(product: product))

      expect(page).to have_button("Deactivate")
    end

    it "displays gray button for deactivate action" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-gray-600.hover\\:bg-gray-500")
    end
  end

  context "with inactive product" do
    before { product.update!(product_status: :draft) }

    it "displays inactive status with x-circle icon" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Inactive")
      expect(page).to have_css("svg.text-gray-400")
    end

    it "displays Activate button" do
      render_inline(described_class.new(product: product))

      expect(page).to have_button("Activate")
    end

    it "displays green button for activate action" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-green-600.hover\\:bg-green-500")
    end
  end

  it "includes proper form action for toggle" do
    render_inline(described_class.new(product: product))

    # Check that toggle button exists within a form with correct action
    expect(page).to have_css("form[action*='toggle_active']")
  end

  it "uses PATCH method for toggle form" do
    render_inline(described_class.new(product: product))

    # button_to with method: :patch creates a form with hidden _method field
    expect(page).to have_css("form input[name='_method'][value='patch']", visible: false)
  end

  it "includes title attribute with full timestamp" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("dd[title*='#{product.updated_at.year}']")
  end

  it "displays status information in definition list" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("dl")
    expect(page).to have_css("dt", text: "Active Status")
    expect(page).to have_css("dt", text: "Product Type")
    expect(page).to have_css("dt", text: "Last Updated")
  end

  it "uses full width button" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("button.w-full")
  end

  it "includes focus ring styles" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("button.focus\\:outline-none.focus\\:ring-2.focus\\:ring-offset-2")
  end
end
