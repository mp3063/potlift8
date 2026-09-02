# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::CatalogTabsComponent, type: :component do
  include ActionView::RecordIdentifier

  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:price_attribute) { company.product_attributes.find_by!(code: "price") }
  let(:brand_attribute) { company.product_attributes.find_by!(code: "brand") }

  def attribute_values_for(product)
    product.product_attribute_values.reload.index_by(&:product_attribute)
  end

  def render_component(product, available_catalogs: [])
    render_inline(described_class.new(
      product: product,
      catalog_items: product.catalog_items,
      attribute_values: attribute_values_for(product),
      available_catalogs: available_catalogs
    ))
  end

  describe "Product tab" do
    it "renders one row per attribute, rooted at the value row id" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product)

      expect(page).to have_css("##{dom_id(brand_attribute, :value)} dd", text: "Acme")
    end

    it "keeps attributes with values out of the unset group" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product)

      expect(page).not_to have_css("details ##{dom_id(brand_attribute, :value)}", visible: :all)
    end

    it "groups non-mandatory unset attributes inside a details block with a count" do
      render_component(product)

      unset_count = company.product_attributes.where(mandatory: false).count
      expect(page).to have_css("details summary", text: "Show #{unset_count} unset attributes")
      expect(page).to have_css("details ##{dom_id(brand_attribute, :value)} dd", text: "Not set", visible: :all)
    end

    it "keeps mandatory unset attributes visible with a Required badge" do
      render_component(product)

      row = "##{dom_id(price_attribute, :value)}"
      expect(page).not_to have_css("details #{row}", visible: :all)
      expect(page).to have_css("#{row} span.bg-yellow-100", text: "Required")
      expect(page).to have_css("#{row} dd.text-amber-700", text: "Not set")
    end

    it "wires each row to the inline editor with a hidden editor block" do
      render_component(product)

      row = "##{dom_id(price_attribute, :value)}"
      expect(page).to have_css("#{row}[data-controller='inline-editor']")
      expect(page).to have_css("#{row} [data-inline-editor-target='display']")
      expect(page).to have_css("#{row} [data-inline-editor-target='editor'].hidden")
      expect(page).to have_css("#{row} button[aria-label='Edit #{price_attribute.name}']")
    end

    it "puts the attribute description on the name as a tooltip instead of a third line" do
      brand_attribute.update!(description: "Manufacturer brand")
      render_component(product)

      expect(page).to have_css("##{dom_id(brand_attribute, :value)} dt[title='Manufacturer brand']", visible: :all)
      expect(page).not_to have_css("##{dom_id(brand_attribute, :value)} dd", text: "Manufacturer brand", visible: :all)
    end
  end
end
