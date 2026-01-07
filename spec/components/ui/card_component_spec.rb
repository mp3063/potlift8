require "rails_helper"

RSpec.describe Ui::CardComponent, type: :component do
  describe "basic rendering" do
    it "renders a card with content" do
      render_inline(described_class.new) { "Card content" }

      expect(page).to have_css("div.bg-white.rounded-lg.shadow-sm")
      expect(page).to have_text("Card content")
    end

    it "renders with border by default" do
      render_inline(described_class.new) { "Content" }

      expect(page).to have_css("div.border.border-gray-200")
    end

    it "renders without border when disabled" do
      render_inline(described_class.new(border: false)) { "Content" }

      expect(page).not_to have_css("div.border")
    end

    it "renders with shadow" do
      render_inline(described_class.new) { "Content" }

      expect(page).to have_css("div.shadow-sm")
    end

    it "renders with rounded corners" do
      render_inline(described_class.new) { "Content" }

      expect(page).to have_css("div.rounded-lg")
    end
  end

  describe "slots" do
    describe "header slot" do
      it "renders header slot with border-b" do
        render_inline(described_class.new) do |c|
          c.with_header { "Card Header" }
          "Card body content"
        end

        expect(page).to have_css("div.border-b.border-gray-200", text: "Card Header")
        expect(page).to have_text("Card body content")
      end

      it "renders header with correct padding" do
        render_inline(described_class.new) do |c|
          c.with_header { "Header" }
          "Body"
        end

        expect(page).to have_css("div.px-6.py-4", text: "Header")
      end

      it "renders card without header when not provided" do
        render_inline(described_class.new) { "Just body content" }

        expect(page).not_to have_css("div.border-b")
        expect(page).to have_text("Just body content")
      end

      it "renders header with custom classes" do
        render_inline(described_class.new) do |c|
          c.with_header(class: "bg-gray-50") { "Custom Header" }
          "Body"
        end

        expect(page).to have_css("div.bg-gray-50.border-b", text: "Custom Header")
      end
    end

    describe "footer slot" do
      it "renders footer slot with bg-gray-50 and border-t" do
        render_inline(described_class.new) do |c|
          c.with_footer { "Card Footer" }
          "Card body content"
        end

        expect(page).to have_css("div.bg-gray-50.border-t.border-gray-200", text: "Card Footer")
        expect(page).to have_text("Card body content")
      end

      it "renders footer with correct padding" do
        render_inline(described_class.new) do |c|
          c.with_footer { "Footer" }
          "Body"
        end

        expect(page).to have_css("div.px-6.py-4", text: "Footer")
      end

      it "renders card without footer when not provided" do
        render_inline(described_class.new) { "Just body content" }

        expect(page).not_to have_css("div.bg-gray-50.border-t")
        expect(page).to have_text("Just body content")
      end

      it "renders footer with rounded bottom corners" do
        render_inline(described_class.new) do |c|
          c.with_footer { "Footer with rounded corners" }
          "Body"
        end

        expect(page).to have_css("div.rounded-b-lg", text: "Footer with rounded corners")
      end
    end

    describe "actions slot" do
      it "renders actions in header area" do
        render_inline(described_class.new) do |c|
          c.with_header { "Title" }
          c.with_action do
            '<button class="btn">Action</button>'.html_safe
          end
          "Body"
        end

        expect(page).to have_css("div.border-b")
        expect(page).to have_css("button.btn", text: "Action")
      end

      it "renders multiple actions with flex layout" do
        render_inline(described_class.new) do |c|
          c.with_header { "Title" }
          c.with_action do
            '<button class="btn-1">Edit</button>'.html_safe
          end
          c.with_action do
            '<button class="btn-2">Delete</button>'.html_safe
          end
          "Body"
        end

        expect(page).to have_css("div.flex.items-center.gap-2")
        expect(page).to have_css("button.btn-1", text: "Edit")
        expect(page).to have_css("button.btn-2", text: "Delete")
      end

      it "does not render actions without header" do
        render_inline(described_class.new) do |c|
          c.with_action { '<button>Action</button>'.html_safe }
          "Body"
        end

        # Actions only render when there's a header
        expect(page).not_to have_css("button")
        expect(page).to have_text("Body")
      end
    end

    describe "combined slots" do
      it "renders header, body, and footer together" do
        render_inline(described_class.new) do |c|
          c.with_header { "Header Text" }
          c.with_footer { "Footer Text" }
          "Body Content"
        end

        expect(page).to have_css("div.border-b", text: "Header Text")
        expect(page).to have_text("Body Content")
        expect(page).to have_css("div.bg-gray-50.border-t", text: "Footer Text")
      end

      it "renders header with actions and footer" do
        render_inline(described_class.new) do |c|
          c.with_header { "Title" }
          c.with_action { '<button>Save</button>'.html_safe }
          c.with_footer { "Last updated: Today" }
          "Card content"
        end

        expect(page).to have_css("div.border-b", text: "Title")
        expect(page).to have_css("button", text: "Save")
        expect(page).to have_text("Card content")
        expect(page).to have_css("div.bg-gray-50.border-t", text: "Last updated: Today")
      end
    end
  end

  describe "padding variants" do
    it "renders with no padding" do
      render_inline(described_class.new(padding: :none)) { "Content" }

      expect(page).to have_css("div.bg-white.rounded-lg")
      expect(page).not_to have_css("div.p-4")
      expect(page).not_to have_css("div.p-6")
      expect(page).to have_text("Content")
    end

    it "renders with small padding" do
      render_inline(described_class.new(padding: :sm)) { "Content" }

      expect(page).to have_css("div > div.p-4", text: "Content")
    end

    it "renders with medium padding (default)" do
      render_inline(described_class.new(padding: :md)) { "Content" }

      expect(page).to have_css("div > div.p-6", text: "Content")
    end

    it "renders with large padding" do
      render_inline(described_class.new(padding: :lg)) { "Content" }

      expect(page).to have_css("div > div.p-8", text: "Content")
    end

    it "defaults to medium padding when not specified" do
      render_inline(described_class.new) { "Default Padding" }

      expect(page).to have_css("div > div.p-6")
    end

    it "applies padding to body content only, not header or footer" do
      render_inline(described_class.new(padding: :lg)) do |c|
        c.with_header { "Header" }
        c.with_footer { "Footer" }
        "Body"
      end

      # Header and footer have their own padding (px-6 py-4)
      expect(page).to have_css("div.px-6.py-4", text: "Header")
      expect(page).to have_css("div.px-6.py-4", text: "Footer")
      # Body has large padding
      expect(page).to have_css("div.p-8", text: "Body")
    end
  end

  describe "hover effect" do
    it "includes hover shadow when hover enabled" do
      render_inline(described_class.new(hover: true)) { "Hoverable card" }

      expect(page).to have_css("div.hover\\:shadow-md.transition-shadow")
      expect(page).to have_text("Hoverable card")
    end

    it "does not include hover shadow by default" do
      render_inline(described_class.new) { "Normal card" }

      expect(page).not_to have_css("div.hover\\:shadow-md")
      expect(page).to have_text("Normal card")
    end

    it "includes transition-shadow when hover enabled" do
      render_inline(described_class.new(hover: true)) { "Content" }

      expect(page).to have_css("div.transition-shadow")
    end

    it "works with border disabled" do
      render_inline(described_class.new(hover: true, border: false)) { "Hover no border" }

      expect(page).to have_css("div.hover\\:shadow-md")
      expect(page).not_to have_css("div.border")
    end
  end

  describe "additional HTML attributes" do
    it "accepts custom CSS classes" do
      render_inline(described_class.new(class: "mb-4 mx-auto")) { "Custom classes" }

      expect(page).to have_css("div.mb-4.mx-auto")
      expect(page).to have_text("Custom classes")
    end

    it "accepts id attribute" do
      render_inline(described_class.new(id: "product-card")) { "Content" }

      expect(page).to have_css("div#product-card")
    end

    it "accepts data attributes" do
      render_inline(described_class.new(data: { controller: "card", card_id: "123" })) { "Content" }

      expect(page).to have_css('div[data-controller="card"]')
      expect(page).to have_css('div[data-card-id="123"]')
    end

    it "accepts aria attributes" do
      render_inline(described_class.new(aria: { label: "Product information" })) { "Content" }

      expect(page).to have_css('div[aria-label="Product information"]')
    end

    it "accepts role attribute" do
      render_inline(described_class.new(role: "article")) { "Article content" }

      expect(page).to have_css('div[role="article"]')
    end
  end

  describe "content rendering" do
    it "renders text content" do
      render_inline(described_class.new) { "Plain text content" }

      expect(page).to have_text("Plain text content")
    end

    it "renders HTML content safely" do
      render_inline(described_class.new) do
        '<div class="content"><p>Paragraph</p></div>'.html_safe
      end

      expect(page).to have_css("div.content p", text: "Paragraph")
    end

    it "handles empty content gracefully" do
      render_inline(described_class.new) { "" }

      expect(page).to have_css("div.bg-white.rounded-lg")
    end

    it "renders complex nested content" do
      render_inline(described_class.new) do
        '<h3 class="text-lg font-semibold">Title</h3><p class="text-gray-600">Description</p>'.html_safe
      end

      expect(page).to have_css("h3.text-lg.font-semibold", text: "Title")
      expect(page).to have_css("p.text-gray-600", text: "Description")
    end
  end

  describe "combined scenarios" do
    it "renders full-featured card with all options" do
      render_inline(described_class.new(
        padding: :lg,
        hover: true,
        border: true,
        class: "mb-6",
        data: { turbo_frame: "product" }
      )) do |c|
        c.with_header { "Product Details" }
        c.with_action { '<button class="btn">Edit</button>'.html_safe }
        c.with_footer { "Updated: 2 hours ago" }
        "Product description and specifications"
      end

      # Custom class
      expect(page).to have_css("div.mb-6")
      # Data attribute
      expect(page).to have_css('div[data-turbo-frame="product"]')
      # Header with action
      expect(page).to have_css("div.border-b", text: "Product Details")
      expect(page).to have_css("button.btn", text: "Edit")
      # Body with large padding
      expect(page).to have_css("div.p-8", text: "Product description and specifications")
      # Footer
      expect(page).to have_css("div.bg-gray-50.border-t", text: "Updated: 2 hours ago")
    end

    it "renders minimal card with no padding and no border" do
      render_inline(described_class.new(padding: :none, border: false)) { "Minimal content" }

      expect(page).to have_css("div.bg-white.rounded-lg.shadow-sm")
      expect(page).not_to have_css("div.border")
      expect(page).to have_text("Minimal content")
    end

    it "renders clickable card with hover effect and data action" do
      render_inline(described_class.new(
        hover: true,
        class: "cursor-pointer",
        data: { action: "click->navigation#showDetails" }
      )) { "Click to view details" }

      expect(page).to have_css("div.cursor-pointer")
      expect(page).to have_css('div[data-action="click->navigation#showDetails"]')
      expect(page).to have_text("Click to view details")
    end
  end

  describe "accessibility" do
    it "supports ARIA landmarks with role" do
      render_inline(described_class.new(role: "region", aria: { label: "Product information" })) { "Content" }

      expect(page).to have_css('div[role="region"]')
      expect(page).to have_css('div[aria-label="Product information"]')
    end

    it "supports aria-describedby" do
      render_inline(described_class.new(aria: { describedby: "card-description" })) { "Content" }

      expect(page).to have_css('div[aria-describedby="card-description"]')
    end

    it "supports aria-labelledby for header reference" do
      render_inline(described_class.new(aria: { labelledby: "card-header" })) do |c|
        c.with_header { '<h2 id="card-header">Title</h2>'.html_safe }
        "Content"
      end

      expect(page).to have_css('div[aria-labelledby="card-header"]')
      expect(page).to have_css("h2#card-header", text: "Title")
    end
  end

  describe "responsive design" do
    it "works with responsive padding classes" do
      render_inline(described_class.new(class: "p-4 md:p-6 lg:p-8")) { "Responsive padding" }

      expect(page).to have_css("div.p-4.md\\:p-6.lg\\:p-8")
    end

    it "works with responsive width classes" do
      render_inline(described_class.new(class: "w-full md:w-2/3 lg:w-1/2")) { "Responsive width" }

      expect(page).to have_css("div.w-full.md\\:w-2\\/3.lg\\:w-1\\/2")
    end
  end

  # Visual Regression Tests
  # Tagged with :visual to run separately from functional tests
  # Run with: bundle exec rspec --tag visual
  # NOTE: These tests require a visual testing setup with screenshot comparison
  describe "visual regression", :visual, :skip do
    context "basic card variations" do
      it "matches baseline for default card" do
        render_inline(described_class.new) { "This is a default card with standard styling" }

        expect(page).to match_screenshot("card_default")
      end

      it "matches baseline for card without border" do
        render_inline(described_class.new(border: false)) { "Card without border" }

        expect(page).to match_screenshot("card_no_border")
      end

      it "matches baseline for hoverable card" do
        render_inline(described_class.new(hover: true)) { "Card with hover effect" }

        expect(page).to match_screenshot("card_hover")
      end
    end

    context "padding variations" do
      it "matches baseline for no padding" do
        render_inline(described_class.new(padding: :none)) { "No padding content" }

        expect(page).to match_screenshot("card_padding_none")
      end

      it "matches baseline for small padding" do
        render_inline(described_class.new(padding: :sm)) { "Small padding content" }

        expect(page).to match_screenshot("card_padding_sm")
      end

      it "matches baseline for medium padding" do
        render_inline(described_class.new(padding: :md)) { "Medium padding content" }

        expect(page).to match_screenshot("card_padding_md")
      end

      it "matches baseline for large padding" do
        render_inline(described_class.new(padding: :lg)) { "Large padding content" }

        expect(page).to match_screenshot("card_padding_lg")
      end
    end

    context "with slots" do
      it "matches baseline for card with header" do
        render_inline(described_class.new) do |c|
          c.with_header { "Card Header" }
          "Card body content goes here"
        end

        expect(page).to match_screenshot("card_with_header")
      end

      it "matches baseline for card with footer" do
        render_inline(described_class.new) do |c|
          c.with_footer { "Card Footer" }
          "Card body content goes here"
        end

        expect(page).to match_screenshot("card_with_footer")
      end

      it "matches baseline for card with header and footer" do
        render_inline(described_class.new) do |c|
          c.with_header { "Product Details" }
          c.with_footer { "Last updated: 2 hours ago" }
          "This is the main content of the card"
        end

        expect(page).to match_screenshot("card_header_footer")
      end

      it "matches baseline for card with header and actions" do
        render_inline(described_class.new) do |c|
          c.with_header { "Product Card" }
          c.with_action do
            '<button class="px-3 py-1 text-sm bg-blue-600 text-white rounded">Edit</button>'.html_safe
          end
          c.with_action do
            '<button class="px-3 py-1 text-sm bg-red-600 text-white rounded">Delete</button>'.html_safe
          end
          "Product information and details"
        end

        expect(page).to match_screenshot("card_with_actions")
      end
    end

    context "complex content" do
      it "matches baseline for card with rich content" do
        render_inline(described_class.new) do |c|
          c.with_header { '<h2 class="text-lg font-semibold">Product Name</h2>'.html_safe }
          <<~HTML.html_safe
            <div class="space-y-2">
              <p class="text-gray-600">SKU: PRD-001</p>
              <p class="text-gray-700">A detailed description of the product with multiple lines of text</p>
              <div class="flex gap-2">
                <span class="px-2 py-1 bg-green-100 text-green-800 rounded text-sm">Active</span>
                <span class="px-2 py-1 bg-blue-100 text-blue-800 rounded text-sm">In Stock</span>
              </div>
            </div>
          HTML
        end

        expect(page).to match_screenshot("card_rich_content")
      end
    end
  end
end
