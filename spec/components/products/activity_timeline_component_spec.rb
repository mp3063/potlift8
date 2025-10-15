# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ActivityTimelineComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  it "renders activity header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Recent Activity")
  end

  it "displays placeholder activities" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Product updated")
    expect(page).to have_text("Product created")
  end

  it "displays activities in timeline format with connecting lines" do
    render_inline(described_class.new(product: product))

    # First item should have connecting line, last item should not
    expect(page).to have_css("span.w-0\\.5.bg-gray-200") # connecting line
  end

  it "displays activity icons" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("svg.text-blue-500") # update icon
    expect(page).to have_css("svg.text-green-500") # create icon
  end

  it "displays timestamps with time ago format" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("ago")
  end

  it "includes title attribute with full timestamp" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("div[title*='#{product.updated_at.year}']")
  end

  it "displays user information" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("by System")
  end

  it "uses list structure for activities" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("ul[role='list']")
    expect(page).to have_css("li", count: 2)
  end

  it "includes icon with rounded background" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("span.rounded-full.bg-gray-50")
  end

  context "activity icon colors" do
    it "uses green for create activities" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("svg.text-green-500")
    end

    it "uses blue for update activities" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("svg.text-blue-500")
    end
  end

  context "with no activities (future implementation)" do
    before do
      # When actual audit log is implemented, we can test empty state
      allow_any_instance_of(described_class).to receive(:recent_activities).and_return([])
    end

    it "displays empty state message" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No recent activity")
    end

    it "displays empty state icon" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("svg.text-gray-400")
    end
  end

  it "includes proper spacing between timeline items" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("ul.-mb-8")
    expect(page).to have_css("div.pb-8")
  end

  it "includes accessibility attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("svg[aria-hidden='true']")
    expect(page).to have_css("span[aria-hidden='true']") # connecting line
  end

  it "positions icon and content correctly" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("div.flex.space-x-3")
    expect(page).to have_css("div.min-w-0.flex-1")
  end
end
