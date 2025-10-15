# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::LabelsComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:label1) { create(:label, name: "Featured", company: company) }
  let(:label2) { create(:label, name: "New Arrival", company: company) }

  it "renders labels header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Labels")
  end

  context "with no labels" do
    it "displays no labels message" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No labels assigned")
    end
  end

  context "with labels assigned" do
    before do
      product.labels << label1
      product.labels << label2
    end

    it "displays all assigned labels" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Featured")
      expect(page).to have_text("New Arrival")
    end

    it "displays labels with blue-50 background" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-blue-50.text-blue-700")
    end

    it "includes remove button for each label" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button[type='submit']", count: 2)
      expect(page).to have_css("span.sr-only", text: "Remove Featured")
      expect(page).to have_css("span.sr-only", text: "Remove New Arrival")
    end

    it "includes proper form action for removal" do
      render_inline(described_class.new(product: product))

      # Check that remove button exists within a form with correct action
      expect(page).to have_css("form[action*='remove_label']")
    end
  end

  context "with available labels to add" do
    before do
      label1 # Create label
      label2 # Create label
    end

    it "displays select dropdown with available labels" do
      render_inline(described_class.new(product: product))

      expect(page).to have_select("label_id", with_options: ["Featured", "New Arrival"])
    end

    it "displays Add button" do
      render_inline(described_class.new(product: product))

      expect(page).to have_button("Add")
    end

    it "includes proper form action for adding" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("form[action*='add_label']")
    end

    it "includes prompt option in select" do
      render_inline(described_class.new(product: product))

      expect(page).to have_select("label_id", with_options: ["Select a label..."])
    end
  end

  context "with all labels assigned" do
    before do
      product.labels << label1
      product.labels << label2
      # Stub Label.where to return empty relation for available labels
      allow(Label).to receive_message_chain(:where, :not, :order).and_return(Label.none)
    end

    it "displays message that all labels are assigned" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("All available labels are assigned")
    end

    it "does not display Add button" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_button("Add")
    end
  end

  it "includes Stimulus controller data attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-controller='product-labels']")
    expect(page).to have_css("[data-product-labels-product-id-value='#{product.id}']")
  end

  it "includes label selector controller for form" do
    label1 # Ensure at least one label exists
    render_inline(described_class.new(product: product))

    expect(page).to have_css("form[data-controller='label-selector']")
    expect(page).to have_css("[data-label-selector-target='select']")
  end

  it "uses blue-600 color scheme for Add button" do
    label1 # Ensure at least one label exists
    render_inline(described_class.new(product: product))

    expect(page).to have_css("button.bg-blue-600.hover\\:bg-blue-700")
  end

  it "includes focus ring with blue-500" do
    label1 # Ensure at least one label exists
    render_inline(described_class.new(product: product))

    expect(page).to have_css("select.focus\\:border-blue-500.focus\\:ring-blue-500")
  end
end
