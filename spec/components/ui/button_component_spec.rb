require "rails_helper"

RSpec.describe Ui::ButtonComponent, type: :component do
  describe "variants" do
    it "renders primary variant with correct classes" do
      render_inline(described_class.new(variant: :primary)) { "Click me" }

      expect(page).to have_css("button.bg-primary-600.text-white.hover\\:bg-primary-700")
      expect(page).to have_text("Click me")
    end

    it "renders secondary variant with correct classes" do
      render_inline(described_class.new(variant: :secondary)) { "Cancel" }

      expect(page).to have_css("button.bg-white.text-gray-700.hover\\:bg-gray-50.border.border-gray-300")
      expect(page).to have_text("Cancel")
    end

    it "renders danger variant with correct classes" do
      render_inline(described_class.new(variant: :danger)) { "Delete" }

      expect(page).to have_css("button.bg-danger-600.text-white.hover\\:bg-danger-700")
      expect(page).to have_text("Delete")
    end

    it "renders ghost variant with correct classes" do
      render_inline(described_class.new(variant: :ghost)) { "View more" }

      expect(page).to have_css("button.bg-transparent.text-gray-700.hover\\:bg-gray-100")
      expect(page).to have_text("View more")
    end

    it "renders link variant with correct classes" do
      render_inline(described_class.new(variant: :link)) { "Learn more" }

      expect(page).to have_css("button.bg-transparent.text-primary-600.hover\\:underline")
      expect(page).to have_text("Learn more")
    end

    it "defaults to primary variant when variant not specified" do
      render_inline(described_class.new) { "Default" }

      expect(page).to have_css("button.bg-primary-600.text-white")
    end
  end

  describe "sizes" do
    it "renders small size with correct classes" do
      render_inline(described_class.new(size: :sm)) { "Small" }

      expect(page).to have_css("button.px-3.py-1\\.5.text-sm")
      expect(page).to have_text("Small")
    end

    it "renders medium size with correct classes" do
      render_inline(described_class.new(size: :md)) { "Medium" }

      expect(page).to have_css("button.px-4.py-2.text-sm")
      expect(page).to have_text("Medium")
    end

    it "renders large size with correct classes" do
      render_inline(described_class.new(size: :lg)) { "Large" }

      expect(page).to have_css("button.px-6.py-3.text-base")
      expect(page).to have_text("Large")
    end

    it "defaults to medium size when size not specified" do
      render_inline(described_class.new) { "Default Size" }

      expect(page).to have_css("button.px-4.py-2.text-sm")
    end
  end

  describe "states" do
    it "renders disabled state with correct attributes and classes" do
      render_inline(described_class.new(disabled: true)) { "Disabled" }

      expect(page).to have_css("button[disabled]")
      expect(page).to have_css("button.disabled\\:opacity-50.disabled\\:cursor-not-allowed")
      expect(page).to have_text("Disabled")
    end

    it "renders loading state with spinner and disabled attribute" do
      render_inline(described_class.new(loading: true)) { "Save" }

      expect(page).to have_css("svg.animate-spin")
      expect(page).to have_css("button[disabled]")
      expect(page).to have_text("Save")
    end

    it "renders loading state with spinner element" do
      render_inline(described_class.new(loading: true)) { "Processing" }

      expect(page).to have_css("svg.animate-spin.-ml-1.h-4.w-4")
    end

    it "shows content even when loading" do
      render_inline(described_class.new(loading: true)) { "Submitting..." }

      expect(page).to have_text("Submitting...")
      expect(page).to have_css("svg.animate-spin")
    end

    it "does not show icon when loading" do
      svg_icon = '<svg class="test-icon"><path d="M5 13l4 4L19 7"/></svg>'
      render_inline(described_class.new(loading: true, icon: svg_icon)) { "Save" }

      expect(page).to have_css("svg.animate-spin")
      expect(page).not_to have_css("svg.test-icon")
    end
  end

  describe "icons" do
    it "renders icon on the left by default" do
      svg_icon = '<svg class="icon-plus"><path d="M12 5v14m-7-7h14"/></svg>'
      render_inline(described_class.new(icon: svg_icon)) { "Add Item" }

      expect(page).to have_css("span.h-4.w-4")
      expect(page).to have_css("svg.icon-plus")
      expect(page).to have_text("Add Item")
    end

    it "renders icon on the right when specified" do
      svg_icon = '<svg class="icon-arrow"><path d="M5 12h14m-7-7l7 7-7 7"/></svg>'
      render_inline(described_class.new(icon: svg_icon, icon_position: :right)) { "Continue" }

      expect(page).to have_css("span.h-4.w-4")
      expect(page).to have_css("svg.icon-arrow")
      expect(page).to have_text("Continue")
    end

    it "renders icon wrapped in span with size classes" do
      svg_icon = '<svg class="icon-close"><path d="M6 18L18 6M6 6l12 12"/></svg>'
      render_inline(described_class.new(icon: svg_icon)) { "Close" }

      expect(page).to have_css("span.h-4.w-4 svg.icon-close")
    end

    it "does not render icon when not specified" do
      render_inline(described_class.new) { "No Icon" }

      expect(page).not_to have_css("span.h-4.w-4")
      expect(page).to have_text("No Icon")
    end
  end

  describe "type attribute" do
    it "defaults to button type" do
      render_inline(described_class.new) { "Click" }

      expect(page).to have_css('button[type="button"]')
    end

    it "renders submit type when specified" do
      render_inline(described_class.new(type: :submit)) { "Submit" }

      expect(page).to have_css('button[type="submit"]')
    end

    it "renders reset type when specified" do
      render_inline(described_class.new(type: :reset)) { "Reset" }

      expect(page).to have_css('button[type="reset"]')
    end
  end

  describe "base classes" do
    it "always includes base styling classes" do
      render_inline(described_class.new) { "Button" }

      expect(page).to have_css("button.rounded-lg")
      expect(page).to have_css("button.transition-colors")
      expect(page).to have_css("button.focus\\:outline-none")
      expect(page).to have_css("button.focus\\:ring-2")
      expect(page).to have_css("button.focus\\:ring-offset-2")
    end

    it "includes inline-flex and items-center for icon alignment" do
      render_inline(described_class.new) { "Button" }

      expect(page).to have_css("button.inline-flex.items-center.justify-center")
    end

    it "includes font-medium for text weight" do
      render_inline(described_class.new) { "Button" }

      expect(page).to have_css("button.font-medium")
    end
  end

  describe "accessibility" do
    it "includes aria-label when provided" do
      render_inline(described_class.new(aria_label: "Close modal")) { "×" }

      expect(page).to have_css('button[aria-label="Close modal"]')
    end

    it "supports aria_label for icon-only buttons" do
      svg_icon = '<svg><path d="M6 18L18 6M6 6l12 12"/></svg>'
      render_inline(described_class.new(icon: svg_icon, aria_label: "Close")) { "" }

      expect(page).to have_css('button[aria-label="Close"]')
    end

    it "does not include aria attributes when not specified" do
      render_inline(described_class.new) { "Button" }

      expect(page).to have_css("button")
      expect(page).not_to have_css("button[aria-label]")
    end

    it "supports custom aria attributes via options" do
      render_inline(described_class.new(aria: { expanded: true, controls: "menu" })) { "Menu" }

      expect(page).to have_css('button[aria-expanded="true"]')
      expect(page).to have_css('button[aria-controls="menu"]')
    end
  end

  describe "additional HTML attributes" do
    it "accepts custom CSS classes" do
      render_inline(described_class.new(class: "custom-class")) { "Custom" }

      expect(page).to have_css("button.custom-class")
      expect(page).to have_text("Custom")
    end

    it "accepts data attributes" do
      render_inline(described_class.new(data: { action: "click->modal#open" })) { "Open" }

      expect(page).to have_css('button[data-action="click->modal#open"]')
    end

    it "accepts id attribute" do
      render_inline(described_class.new(id: "submit-btn")) { "Submit" }

      expect(page).to have_css('button#submit-btn')
    end

    it "accepts name attribute" do
      render_inline(described_class.new(name: "commit")) { "Save" }

      expect(page).to have_css('button[name="commit"]')
    end

    it "accepts value attribute" do
      render_inline(described_class.new(value: "save")) { "Save" }

      expect(page).to have_css('button[value="save"]')
    end
  end

  describe "focus states" do
    it "includes focus ring color for primary variant" do
      render_inline(described_class.new(variant: :primary)) { "Primary" }

      expect(page).to have_css("button.focus\\:ring-primary-500")
    end

    it "includes focus ring color for secondary variant" do
      render_inline(described_class.new(variant: :secondary)) { "Secondary" }

      expect(page).to have_css("button.focus\\:ring-primary-500")
    end

    it "includes focus ring color for danger variant" do
      render_inline(described_class.new(variant: :danger)) { "Danger" }

      expect(page).to have_css("button.focus\\:ring-danger-500")
    end

    it "includes focus ring color for ghost variant" do
      render_inline(described_class.new(variant: :ghost)) { "Ghost" }

      expect(page).to have_css("button.focus\\:ring-gray-300")
    end

    it "includes focus ring color for link variant" do
      render_inline(described_class.new(variant: :link)) { "Link" }

      expect(page).to have_css("button.focus\\:ring-0")
    end
  end

  describe "combined scenarios" do
    it "renders small primary button with icon and loading state" do
      svg_icon = '<svg class="icon-save"><path d="M5 13l4 4L19 7"/></svg>'
      render_inline(described_class.new(variant: :primary, size: :sm, icon: svg_icon, loading: true)) { "Save" }

      expect(page).to have_css("button.bg-primary-600.px-3.py-1\\.5.text-sm")
      expect(page).to have_css("svg.animate-spin")
      expect(page).to have_css("button[disabled]")
      expect(page).to have_text("Save")
      expect(page).not_to have_css("svg.icon-save") # Icon hidden when loading
    end

    it "renders large danger button with right icon and disabled state" do
      svg_icon = '<svg class="icon-trash"><path d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>'
      render_inline(described_class.new(variant: :danger, size: :lg, icon: svg_icon, icon_position: :right, disabled: true)) { "Delete" }

      expect(page).to have_css("button.bg-danger-600.px-6.py-3.text-base")
      expect(page).to have_css("button[disabled].disabled\\:opacity-50")
      expect(page).to have_css("svg.icon-trash")
      expect(page).to have_text("Delete")
    end

    it "renders ghost button with custom classes and data attributes" do
      render_inline(described_class.new(
        variant: :ghost,
        class: "w-full",
        data: { turbo_frame: "modal" }
      )) { "View Details" }

      expect(page).to have_css("button.w-full")
      expect(page).to have_css('button[data-turbo-frame="modal"]')
      expect(page).to have_text("View Details")
    end
  end

  describe "content rendering" do
    it "renders text content" do
      render_inline(described_class.new) { "Click Me" }

      expect(page).to have_text("Click Me")
    end

    it "renders HTML content safely" do
      render_inline(described_class.new) { "<strong>Bold</strong>".html_safe }

      expect(page).to have_css("strong", text: "Bold")
    end

    it "handles empty content gracefully" do
      render_inline(described_class.new) { "" }

      expect(page).to have_css("button")
    end

    it "handles whitespace in content" do
      render_inline(described_class.new) { "  Padded Text  " }

      expect(page).to have_text("Padded Text")
    end
  end

  # Visual Regression Tests
  # Tagged with :visual to run separately from functional tests
  # Run with: bundle exec rspec --tag visual
  describe "visual regression", :visual do
    context "variants at desktop viewport" do
      it "matches baseline for primary variant" do
        render_inline(described_class.new(variant: :primary)) { "Primary Button" }

        expect(page).to match_screenshot("button_primary")
      end

      it "matches baseline for secondary variant" do
        render_inline(described_class.new(variant: :secondary)) { "Secondary Button" }

        expect(page).to match_screenshot("button_secondary")
      end

      it "matches baseline for danger variant" do
        render_inline(described_class.new(variant: :danger)) { "Danger Button" }

        expect(page).to match_screenshot("button_danger")
      end

      it "matches baseline for ghost variant" do
        render_inline(described_class.new(variant: :ghost)) { "Ghost Button" }

        expect(page).to match_screenshot("button_ghost")
      end

      it "matches baseline for link variant" do
        render_inline(described_class.new(variant: :link)) { "Link Button" }

        expect(page).to match_screenshot("button_link")
      end
    end

    context "sizes comparison" do
      it "matches baseline for small size" do
        render_inline(described_class.new(size: :sm, variant: :primary)) { "Small" }

        expect(page).to match_screenshot("button_size_sm")
      end

      it "matches baseline for medium size" do
        render_inline(described_class.new(size: :md, variant: :primary)) { "Medium" }

        expect(page).to match_screenshot("button_size_md")
      end

      it "matches baseline for large size" do
        render_inline(described_class.new(size: :lg, variant: :primary)) { "Large" }

        expect(page).to match_screenshot("button_size_lg")
      end
    end

    context "states" do
      it "matches baseline for disabled state" do
        render_inline(described_class.new(variant: :primary, disabled: true)) { "Disabled" }

        expect(page).to match_screenshot("button_state_disabled")
      end

      it "matches baseline for loading state" do
        render_inline(described_class.new(variant: :primary, loading: true)) { "Loading" }

        expect(page).to match_screenshot("button_state_loading")
      end

      it "matches baseline with left icon" do
        svg_icon = '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/></svg>'
        render_inline(described_class.new(variant: :primary, icon: svg_icon)) { "Add Item" }

        expect(page).to match_screenshot("button_icon_left")
      end

      it "matches baseline with right icon" do
        svg_icon = '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>'
        render_inline(described_class.new(variant: :primary, icon: svg_icon, icon_position: :right)) { "Continue" }

        expect(page).to match_screenshot("button_icon_right")
      end
    end
  end
end
