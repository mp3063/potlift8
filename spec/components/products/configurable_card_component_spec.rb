# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ConfigurableCardComponent, type: :component do
  let(:company) { create(:company) }

  it "does not render for sellable products" do
    product = create(:product, company: company)
    render_inline(described_class.new(product: product))

    expect(page).not_to have_text("Variants")
  end

  context "with a configurable product" do
    let(:product) { create(:product, :configurable_variant, company: company) }

    def add_variants(count)
      count.times { create(:product_configuration, superproduct: product, subproduct: create(:product, company: company)) }
    end

    it "renders a Variants header with the variant count and configuration type" do
      add_variants(2)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("h3", text: "Variants")
      expect(page).to have_css("span.rounded-full", text: "2")
      expect(page).to have_css("span.rounded-full", text: "Variant")
    end

    it "renders one line per configuration with its value chips" do
      create(:configuration, :size, product: product, position: 1)
      create(:configuration, :color, product: product, position: 2)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("dt", text: "Size")
      expect(page).to have_css("dt", text: "Color")
      expect(page).to have_css("dd span", text: "Small")
      expect(page).to have_css("dd span", text: "Red")
      expect(page).to have_css("dt.w-20[title='Size']", text: "Size")
      expect(page).not_to have_css("dt[title='size']")
      expect(page).not_to have_css("div.bg-gray-50.rounded-lg.p-4")
    end

    it "shows the combinations hint when fewer variants exist than combinations" do
      create(:configuration, :size, product: product)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("Up to 3 combinations possible, 0 generated")
    end

    it "hides the hint when every combination exists" do
      create(:configuration, :size, product: product)
      add_variants(3)
      render_inline(described_class.new(product: product.reload))

      expect(page).not_to have_text("combinations possible")
    end

    it "links to manage variants and to configurations" do
      render_inline(described_class.new(product: product))

      expect(page).to have_link("Manage variants", href: "/products/#{product.id}/variants")
      expect(page).to have_link("Configurations", href: "/products/#{product.id}/configurations")
    end

    it "shows a one-line empty state without configurations" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No configurations yet")
      expect(page).not_to have_css("dl")
    end
  end
end
