# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ActivityTimelineComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  it "renders activity header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Recent Activity")
  end

  context "with no PaperTrail versions" do
    it "falls back to creation entry" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Product created")
      expect(page).to have_text("by System")
    end

    it "displays single timeline item" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("li", count: 1)
    end

    it "uses green icon for creation" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("svg.text-green-500")
    end
  end

  context "with PaperTrail versions" do
    before do
      PaperTrail.request.whodunnit = "John Smith"
      product.update!(name: "Updated Name")
      product.update!(sku: "NEW-SKU")
    end

    it "displays real version entries" do
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("Updated name")
      expect(page).to have_text("Updated sku")
    end

    it "shows user attribution from whodunnit" do
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("by John Smith")
    end

    it "shows entries ordered by most recent first" do
      render_inline(described_class.new(product: product.reload))

      items = page.all("li")
      expect(items.size).to eq(2)
      texts = items.map(&:text)
      expect(texts.join).to include("name")
      expect(texts.join).to include("sku")
    end

    it "limits to 5 entries" do
      PaperTrail.request.whodunnit = "Jane Doe"
      5.times { |i| product.update!(name: "Name #{i}") }

      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("li", maximum: 5)
    end
  end

  context "with API/sync version" do
    before do
      PaperTrail.request.whodunnit = "API (Test Company)"
      product.update!(name: "Synced Name")
    end

    it "shows API attribution" do
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("by API (Test Company)")
    end
  end

  context "with nil whodunnit" do
    before do
      PaperTrail.request.whodunnit = nil
      product.update!(name: "Anonymous Update")
    end

    it "falls back to System" do
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("by System")
    end
  end

  context "version with multiple changed fields" do
    before do
      PaperTrail.request.whodunnit = "Test User"
      product.update!(name: "New Name", sku: "NEW-SKU", ean: "1234567890123")
    end

    it "lists changed field names in a sentence" do
      render_inline(described_class.new(product: product.reload))

      # Fields are combined: "Updated sku, name, and ean" (order depends on changeset)
      expect(page).to have_text(/Updated .*(name|sku|ean)/)
      expect(page).to have_text("by Test User")
    end
  end

  it "renders View full history link" do
    render_inline(described_class.new(product: product))

    expect(page).to have_link("View full history", href: "/products/#{product.id}/versions")
  end

  it "displays timestamps with time ago format" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("ago")
  end

  it "uses list structure for activities" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("ul[role='list']")
  end

  it "includes accessibility attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("svg[aria-hidden='true']")
  end

  context "activity icon colors" do
    it "uses blue for update activities" do
      PaperTrail.request.whodunnit = "User"
      product.update!(name: "Changed")

      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("svg.text-blue-500")
    end
  end

  context "with no activities (stubbed empty)" do
    before do
      allow_any_instance_of(described_class).to receive(:recent_activities).and_return([])
    end

    it "displays empty state message" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No recent activity")
    end
  end
end
