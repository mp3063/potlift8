# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::LabelsComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:label1) { create(:label, name: "Featured", company: company, info: { 'color' => '#ef4444' }) }
  let(:label2) { create(:label, name: "New Arrival", company: company, info: { 'color' => '#10b981' }) }
  let(:other_company_label) { create(:label, name: "Other Company", company: create(:company)) }

  it "renders labels header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Labels")
  end

  context "with no labels" do
    it "displays no labels selected message" do
      label1 # Create at least one available label
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No labels selected")
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

    it "displays labels with blue-100 background" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-blue-100.text-blue-800")
    end

    it "includes remove button for each label" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button[data-action='click->product-label-manager#removeLabel']", count: 2)
      expect(page).to have_css("span.sr-only", text: "Remove label Featured")
      expect(page).to have_css("span.sr-only", text: "Remove label New Arrival")
    end

    it "includes proper data attributes for removal" do
      render_inline(described_class.new(product: product))

      # Check that buttons have label IDs in data attributes
      expect(page).to have_css("button[data-label-id='#{label1.id}']")
      expect(page).to have_css("button[data-label-id='#{label2.id}']")
    end

    it "displays color dots for each label" do
      render_inline(described_class.new(product: product))

      # Check for color dots with inline styles
      expect(page).to have_css("span[style*='background-color: #ef4444']")
      expect(page).to have_css("span[style*='background-color: #10b981']")
    end
  end

  context "with available labels to add" do
    before do
      label1 # Create label
      label2 # Create label
    end

    it "displays clickable buttons for available labels" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button[data-action='click->product-label-manager#addLabel']", count: 2)
      expect(page).to have_css("button[data-label-name='Featured']")
      expect(page).to have_css("button[data-label-name='New Arrival']")
    end

    it "includes search input" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("input[placeholder='Search labels...']")
      expect(page).to have_css("input[data-product-label-manager-target='searchInput']")
    end

    it "includes proper data attributes for adding" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button[data-label-id='#{label1.id}']")
      expect(page).to have_css("button[data-label-id='#{label2.id}']")
    end

    it "displays color dots for available labels" do
      render_inline(described_class.new(product: product))

      # Check for color dots in available labels
      expect(page).to have_css("button[data-label-id='#{label1.id}'] span[style*='background-color: #ef4444']")
      expect(page).to have_css("button[data-label-id='#{label2.id}'] span[style*='background-color: #10b981']")
    end
  end

  context "with all labels assigned" do
    before do
      product.labels << label1
      product.labels << label2
    end

    it "displays no available labels" do
      render_inline(described_class.new(product: product))

      # Should not display clickable add buttons for assigned labels
      expect(page).not_to have_css("button[data-action='click->product-label-manager#addLabel']")
    end

    it "shows all labels as selected" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span[data-label-id='#{label1.id}']")
      expect(page).to have_css("span[data-label-id='#{label2.id}']")
    end
  end

  it "includes Stimulus controller data attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-controller='product-label-manager']")
    expect(page).to have_css("[data-product-label-manager-product-id-value='#{product.id}']")
  end

  it "includes label list target" do
    label1 # Ensure at least one label exists
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-product-label-manager-target='labelList']")
  end

  it "includes selected container target" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-product-label-manager-target='selectedContainer']")
  end

  it "includes empty state for no search results" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-product-label-manager-target='emptyState']")
    expect(page).to have_text("No labels found matching your search")
  end

  describe "multi-tenancy security" do
    it "only shows labels from the same company" do
      label1 # Create label for product's company
      other_company_label # Create label for different company

      render_inline(described_class.new(product: product))

      # Should show label from same company
      expect(page).to have_css("button[data-label-name='Featured']")

      # Should NOT show label from other company
      expect(page).not_to have_css("button[data-label-name='Other Company']")
    end

    it "scopes available labels to product's company" do
      label1
      other_company_label

      component = described_class.new(product: product)
      render_inline(component)

      # Access the private method for testing
      available = component.send(:available_labels)

      expect(available).to include(label1)
      expect(available).not_to include(other_company_label)
    end
  end

  describe "accessibility" do
    before do
      product.labels << label1
      label2 # Create available label
    end

    it "includes ARIA labels for buttons" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button[aria-label='Remove label Featured']")
      expect(page).to have_css("button[aria-label='Add label New Arrival']")
    end

    it "includes screen reader text for remove buttons" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.sr-only", text: "Remove label Featured")
    end

    it "includes aria-hidden on decorative elements" do
      render_inline(described_class.new(product: product))

      # Color dots should be aria-hidden
      expect(page).to have_css("span[aria-hidden='true'].rounded-full")
    end

    it "includes data-label-id for selected labels" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span[data-label-id='#{label1.id}']")
    end
  end
end
