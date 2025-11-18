require 'rails_helper'

RSpec.describe Ui::SearchInputComponent, type: :component do
  it "renders search input with icon" do
    render_inline(described_class.new(
      name: :q,
      placeholder: "Search..."
    ))

    expect(page).to have_css('input[type="text"][name="q"]')
    expect(page).to have_css('svg.text-gray-400')
    expect(page).to have_css('label.sr-only', text: "Search...")
  end

  it "includes provided value" do
    render_inline(described_class.new(
      name: :q,
      value: "test query",
      placeholder: "Search..."
    ))

    expect(page).to have_field('search_q', with: 'test query')
  end

  it "uses custom label for screen readers" do
    render_inline(described_class.new(
      name: :q,
      placeholder: "Search...",
      label: "Search products by name or SKU"
    ))

    expect(page).to have_css('label.sr-only', text: "Search products by name or SKU")
  end

  it "applies custom options to input" do
    render_inline(described_class.new(
      name: :q,
      placeholder: "Search...",
      autofocus: true,
      data: { controller: "search" }
    ))

    expect(page).to have_css('input[autofocus]')
    expect(page).to have_css('input[data-controller="search"]')
  end

  it "generates unique input id based on name" do
    render_inline(described_class.new(
      name: :product_search,
      placeholder: "Search..."
    ))

    expect(page).to have_css('input#search_product_search')
    expect(page).to have_css('label[for="search_product_search"]')
  end

  it "applies correct styling classes" do
    render_inline(described_class.new(
      name: :q,
      placeholder: "Search..."
    ))

    expect(page).to have_css('input.rounded-md')
    expect(page).to have_css('input.pl-10') # Left padding for icon
    expect(page).to have_css('input.focus\:ring-blue-600')
  end
end
