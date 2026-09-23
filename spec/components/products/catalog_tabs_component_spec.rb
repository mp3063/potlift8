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

      # The tooltip leads with the full name so a truncated name stays readable
      expect(page).to have_css("##{dom_id(brand_attribute, :value)} dt[title='#{brand_attribute.name} — Manufacturer brand']", visible: :all)
      expect(page).not_to have_css("##{dom_id(brand_attribute, :value)} dd", text: "Manufacturer brand", visible: :all)
    end
  end

  describe "catalog tab" do
    let(:catalog) { create(:catalog, company: company, name: "European Webshop") }
    let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
    let(:short_description) { company.product_attributes.find_by!(code: "short_description") }
    let(:panel) { "#panel-#{catalog.code}" }

    it "renders a one-line catalog header with view and remove actions" do
      render_component(product.reload)

      expect(page).to have_css("#{panel} h4", text: "European Webshop")
      expect(page).to have_css("#{panel} a", text: "View catalog")
      expect(page).to have_css("#{panel} button", text: "Remove")
      expect(page).not_to have_css("#{panel} button", text: "Remove from Catalog")
    end

    it "marks inherited product values with an inherited tag and no editor" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product.reload)

      expect(page).to have_css("#{panel} dd", text: "Acme")
      expect(page).to have_css("#{panel} span.text-gray-400", text: "inherited")
      expect(page).not_to have_text("Inherited from product")
    end

    it "renders overrides with the Override badge and edit/remove controls" do
      override = create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: short_description, value: "EU copy")
      render_component(product.reload)

      row = "##{dom_id(override, :value)}"
      expect(page).to have_css("#{row} dd", text: "EU copy")
      expect(page).to have_css("#{row} span.bg-blue-100", text: "Override")
      expect(page).to have_css("#{row}[data-controller='inline-editor']")
      expect(page).to have_css("#{row} button[aria-label='Edit #{short_description.name}']")
      expect(page).to have_css("#{row} button[aria-label='Remove override for #{short_description.name}']")
    end

    it "omits attributes with neither an override nor a product value" do
      render_component(product.reload)

      expect(page).not_to have_css("#{panel} dt", text: brand_attribute.name)
    end

    it "still offers the Add Attribute Override action" do
      render_component(product.reload)

      expect(page).to have_css("#{panel} button", text: "Add Attribute Override")
    end
  end
end
