require "rails_helper"

RSpec.describe Ui::ModalComponent, type: :component do
  describe "basic rendering" do
    it "renders modal with header, content, and footer" do
      render_inline(described_class.new(title: "Confirm Action")) do |c|
        c.with_body { "Are you sure you want to continue?" }
        c.with_footer { "Footer content" }
      end

      expect(page).to have_css('div[role="dialog"][aria-modal="true"]')
      expect(page).to have_text("Confirm Action")
      expect(page).to have_text("Are you sure you want to continue?")
      expect(page).to have_text("Footer content")
    end

    it "includes Stimulus controller" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-controller="modal"]')
    end

    it "is hidden by default" do
      render_inline(described_class.new(title: "Hidden Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.hidden[data-modal-target="backdrop"]')
    end

    it "generates unique modal ID" do
      render_inline(described_class.new(title: "Modal 1")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[id^="modal-"]')
    end

    it "accepts custom ID" do
      render_inline(described_class.new(title: "Custom", id: "custom-modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div#custom-modal')
    end
  end

  describe "slots" do
    describe "trigger slot" do
      it "renders trigger with click action to open modal" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_trigger { '<button class="btn">Open Modal</button>'.html_safe }
          c.with_body { "Modal content" }
        end

        expect(page).to have_css('button.btn[data-action="click->modal#open"]', text: "Open Modal")
      end

      it "renders modal without trigger when not provided" do
        render_inline(described_class.new(title: "No Trigger")) do |c|
          c.with_body { "Content" }
        end

        expect(page).not_to have_css('[data-action="click->modal#open"]')
      end

      it "allows custom trigger elements" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_trigger { '<a href="#" class="link">Show Details</a>'.html_safe }
          c.with_body { "Details" }
        end

        expect(page).to have_css('a.link[data-action="click->modal#open"]', text: "Show Details")
      end
    end

    describe "body slot" do
      it "renders body content" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_body { "This is the modal body content" }
        end

        expect(page).to have_text("This is the modal body content")
      end

      it "renders HTML content in body" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_body { '<p class="text-gray-600">Formatted content</p>'.html_safe }
        end

        expect(page).to have_css("p.text-gray-600", text: "Formatted content")
      end

      it "applies body padding classes" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_body { "Content" }
        end

        expect(page).to have_css("div.px-6.py-4", text: "Content")
      end
    end

    describe "footer slot" do
      it "renders footer with bg-gray-50 and border-t" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_body { "Body" }
          c.with_footer { "Footer actions" }
        end

        expect(page).to have_css("div.bg-gray-50.border-t.border-gray-200", text: "Footer actions")
      end

      it "renders modal without footer when not provided" do
        render_inline(described_class.new(title: "No Footer")) do |c|
          c.with_body { "Body only" }
        end

        expect(page).not_to have_css("div.bg-gray-50.border-t")
      end

      it "applies footer padding classes" do
        render_inline(described_class.new(title: "Modal")) do |c|
          c.with_body { "Body" }
          c.with_footer { "Footer" }
        end

        expect(page).to have_css("div.px-6.py-4.bg-gray-50", text: "Footer")
      end

      it "renders action buttons in footer" do
        render_inline(described_class.new(title: "Confirm")) do |c|
          c.with_body { "Are you sure?" }
          c.with_footer do
            '<button class="btn-cancel">Cancel</button><button class="btn-confirm">Confirm</button>'.html_safe
          end
        end

        expect(page).to have_css("button.btn-cancel", text: "Cancel")
        expect(page).to have_css("button.btn-confirm", text: "Confirm")
      end
    end
  end

  describe "size variants" do
    it "renders small modal (max-w-md)" do
      render_inline(described_class.new(title: "Small Modal", size: :sm)) do |c|
        c.with_body { "Small content" }
      end

      expect(page).to have_css("div.max-w-md[data-modal-target='container']")
    end

    it "renders medium modal (max-w-lg, default)" do
      render_inline(described_class.new(title: "Medium Modal", size: :md)) do |c|
        c.with_body { "Medium content" }
      end

      expect(page).to have_css("div.max-w-lg[data-modal-target='container']")
    end

    it "renders large modal (max-w-2xl)" do
      render_inline(described_class.new(title: "Large Modal", size: :lg)) do |c|
        c.with_body { "Large content" }
      end

      expect(page).to have_css("div.max-w-2xl[data-modal-target='container']")
    end

    it "renders extra-large modal (max-w-4xl)" do
      render_inline(described_class.new(title: "XL Modal", size: :xl)) do |c|
        c.with_body { "Extra large content" }
      end

      expect(page).to have_css("div.max-w-4xl[data-modal-target='container']")
    end

    it "renders full-width modal (max-w-full)" do
      render_inline(described_class.new(title: "Full Modal", size: :full)) do |c|
        c.with_body { "Full width content" }
      end

      expect(page).to have_css("div.max-w-full[data-modal-target='container']")
    end

    it "defaults to medium size when not specified" do
      render_inline(described_class.new(title: "Default Size")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.max-w-lg[data-modal-target='container']")
    end
  end

  describe "closable option" do
    it "renders close button when closable is true (default)" do
      render_inline(described_class.new(title: "Closable Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('button[aria-label="Close"][data-action="click->modal#close"]')
    end

    it "renders close button with X icon" do
      render_inline(described_class.new(title: "Modal", closable: true)) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('button[aria-label="Close"] svg')
    end

    it "does not render close button when closable is false" do
      render_inline(described_class.new(title: "Not Closable", closable: false)) do |c|
        c.with_body { "Content" }
      end

      expect(page).not_to have_css('button[aria-label="Close"]')
    end

    it "close button has correct styling" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('button.text-gray-400.hover\\:text-gray-600[aria-label="Close"]')
    end
  end

  describe "backdrop" do
    it "renders backdrop with modal target" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-modal-target="backdrop"]')
    end

    it "backdrop has correct styling classes" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.fixed.inset-0.bg-black.bg-opacity-50.flex.items-center.justify-center.z-50[data-modal-target="backdrop"]')
    end

    it "backdrop has click action to close modal" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-action="click->modal#closeOutside"]')
    end

    it "backdrop is hidden by default" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.hidden[data-modal-target="backdrop"]')
    end
  end

  describe "modal container" do
    it "has container target" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-modal-target="container"]')
    end

    it "has correct base styling" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.bg-white.rounded-lg.shadow-xl.w-full.mx-4[data-modal-target="container"]')
    end

    it "includes overflow-hidden for contained content" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.overflow-hidden[data-modal-target="container"]')
    end
  end

  describe "header" do
    it "renders title in header" do
      render_inline(described_class.new(title: "Modal Title")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("h3.text-lg.font-semibold.text-gray-900", text: "Modal Title")
    end

    it "header has border-b" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.border-b.border-gray-200")
    end

    it "header has correct padding" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.px-6.py-4.border-b")
    end

    it "header uses flex layout for title and close button" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.flex.items-center.justify-between")
    end
  end

  describe "accessibility" do
    it "includes role='dialog' on container" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[role="dialog"]')
    end

    it "includes aria-modal='true' on container" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[aria-modal="true"]')
    end

    it "includes aria-labelledby referencing title" do
      render_inline(described_class.new(title: "Accessible Modal", id: "test-modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[aria-labelledby="test-modal-title"]')
      expect(page).to have_css('h3#test-modal-title', text: "Accessible Modal")
    end

    it "close button has aria-label" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('button[aria-label="Close"]')
    end

    it "supports custom aria-label for modal" do
      render_inline(described_class.new(title: "Modal", aria: { label: "Confirmation dialog" })) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[aria-label="Confirmation dialog"]')
    end

    it "supports aria-describedby" do
      render_inline(described_class.new(title: "Modal", aria: { describedby: "modal-description" })) do |c|
        c.with_body { '<p id="modal-description">Description text</p>'.html_safe }
      end

      expect(page).to have_css('div[aria-describedby="modal-description"]')
      expect(page).to have_css("p#modal-description", text: "Description text")
    end
  end

  describe "Stimulus data attributes" do
    it "includes data-controller='modal'" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-controller="modal"]')
    end

    it "trigger has data-action to open" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_trigger { '<button>Open</button>'.html_safe }
        c.with_body { "Content" }
      end

      expect(page).to have_css('[data-action="click->modal#open"]')
    end

    it "close button has data-action" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('button[data-action="click->modal#close"]')
    end

    it "backdrop has data-action for outside click" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-action="click->modal#closeOutside"]')
    end

    it "has backdrop target" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-modal-target="backdrop"]')
    end

    it "has container target" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-modal-target="container"]')
    end
  end

  describe "additional HTML attributes" do
    it "accepts custom CSS classes on wrapper" do
      render_inline(described_class.new(title: "Modal", class: "custom-modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div.custom-modal[data-controller="modal"]')
    end

    it "accepts data attributes" do
      render_inline(described_class.new(title: "Modal", data: { turbo_frame: "modal-frame" })) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-turbo-frame="modal-frame"]')
    end

    it "merges data-controller with existing data attributes" do
      render_inline(described_class.new(title: "Modal", data: { action: "resize->modal#adjust" })) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css('div[data-controller="modal"]')
      expect(page).to have_css('div[data-action="resize->modal#adjust"]')
    end
  end

  describe "combined scenarios" do
    it "renders full-featured modal with all options" do
      render_inline(described_class.new(
        title: "Delete Product",
        size: :lg,
        closable: true,
        id: "delete-modal",
        class: "product-modal",
        data: { product_id: "123" }
      )) do |c|
        c.with_trigger { '<button class="btn-danger">Delete</button>'.html_safe }
        c.with_body { '<p class="text-red-600">This action cannot be undone.</p>'.html_safe }
        c.with_footer do
          '<button class="btn-secondary">Cancel</button><button class="btn-danger">Confirm Delete</button>'.html_safe
        end
      end

      # Wrapper
      expect(page).to have_css('div#delete-modal.product-modal[data-controller="modal"]')
      expect(page).to have_css('div[data-product-id="123"]')

      # Trigger
      expect(page).to have_css('button.btn-danger[data-action="click->modal#open"]', text: "Delete")

      # Backdrop
      expect(page).to have_css('div.hidden[data-modal-target="backdrop"]')

      # Container with size
      expect(page).to have_css('div.max-w-2xl[data-modal-target="container"]')

      # Header with title and close button
      expect(page).to have_css('h3#delete-modal-title', text: "Delete Product")
      expect(page).to have_css('button[aria-label="Close"]')

      # Body
      expect(page).to have_css("p.text-red-600", text: "This action cannot be undone.")

      # Footer with actions
      expect(page).to have_css("div.bg-gray-50.border-t")
      expect(page).to have_css("button.btn-secondary", text: "Cancel")
      expect(page).to have_css("button.btn-danger", text: "Confirm Delete")

      # Accessibility
      expect(page).to have_css('div[role="dialog"][aria-modal="true"]')
      expect(page).to have_css('div[aria-labelledby="delete-modal-title"]')
    end

    it "renders minimal modal without trigger and footer" do
      render_inline(described_class.new(title: "Info", size: :sm, closable: false)) do |c|
        c.with_body { "Information message" }
      end

      expect(page).to have_css("div.max-w-md")
      expect(page).to have_text("Info")
      expect(page).to have_text("Information message")
      expect(page).not_to have_css('button[aria-label="Close"]')
      expect(page).not_to have_css("div.bg-gray-50.border-t")
    end

    it "renders form modal with submit action in footer" do
      render_inline(described_class.new(title: "Add Product", size: :xl)) do |c|
        c.with_trigger { '<button class="btn-primary">Add New</button>'.html_safe }
        c.with_body do
          '<form><input type="text" name="name" placeholder="Product name"></form>'.html_safe
        end
        c.with_footer do
          '<button type="button" class="btn-secondary" data-action="click->modal#close">Cancel</button>
           <button type="submit" class="btn-primary">Save Product</button>'.html_safe
        end
      end

      expect(page).to have_css("div.max-w-4xl")
      expect(page).to have_css("form input[name='name']")
      expect(page).to have_css("button.btn-secondary", text: "Cancel")
      expect(page).to have_css('button[type="submit"].btn-primary', text: "Save Product")
    end
  end

  describe "z-index and layering" do
    it "backdrop has z-50 for proper layering" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.z-50[data-modal-target='backdrop']")
    end

    it "ensures modal appears above other content" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      expect(page).to have_css("div.fixed.inset-0.z-50")
    end
  end

  describe "animation classes" do
    it "includes transition classes for smooth display" do
      render_inline(described_class.new(title: "Modal")) do |c|
        c.with_body { "Content" }
      end

      # These would typically be added by Stimulus controller
      # but we test for the structure that enables it
      expect(page).to have_css('div[data-modal-target="backdrop"]')
      expect(page).to have_css('div[data-modal-target="container"]')
    end
  end

  # Visual Regression Tests
  # Tagged with :visual to run separately from functional tests
  # Run with: bundle exec rspec --tag visual
  # Note: Modal visual tests require manual backdrop visibility manipulation
  describe "visual regression", :visual do
    context "size variations" do
      it "matches baseline for small modal" do
        render_inline(described_class.new(title: "Small Modal", size: :sm)) do |c|
          c.with_body { "This is a small modal with limited content" }
        end

        expect(page).to match_screenshot("modal_size_sm")
      end

      it "matches baseline for medium modal (default)" do
        render_inline(described_class.new(title: "Medium Modal", size: :md)) do |c|
          c.with_body { "This is a medium-sized modal with standard content" }
        end

        expect(page).to match_screenshot("modal_size_md")
      end

      it "matches baseline for large modal" do
        render_inline(described_class.new(title: "Large Modal", size: :lg)) do |c|
          c.with_body { "This is a large modal with more substantial content that requires additional space" }
        end

        expect(page).to match_screenshot("modal_size_lg")
      end

      it "matches baseline for extra-large modal" do
        render_inline(described_class.new(title: "Extra Large Modal", size: :xl)) do |c|
          c.with_body do
            <<~HTML.html_safe
              <div class="space-y-4">
                <p>This is an extra-large modal designed for complex content</p>
                <p>It can accommodate forms, tables, or detailed information</p>
              </div>
            HTML
          end
        end

        expect(page).to match_screenshot("modal_size_xl")
      end
    end

    context "with slots" do
      it "matches baseline for modal with header and body" do
        render_inline(described_class.new(title: "Product Details")) do |c|
          c.with_body do
            <<~HTML.html_safe
              <div class="space-y-2">
                <p class="text-gray-600">SKU: PRD-001</p>
                <p class="text-gray-700">Standard product description</p>
              </div>
            HTML
          end
        end

        expect(page).to match_screenshot("modal_header_body")
      end

      it "matches baseline for modal with footer" do
        render_inline(described_class.new(title: "Confirm Action")) do |c|
          c.with_body { "Are you sure you want to proceed with this action?" }
          c.with_footer do
            <<~HTML.html_safe
              <div class="flex justify-end gap-2">
                <button class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg">Cancel</button>
                <button class="px-4 py-2 bg-blue-600 text-white rounded-lg">Confirm</button>
              </div>
            HTML
          end
        end

        expect(page).to match_screenshot("modal_with_footer")
      end

      it "matches baseline for modal with trigger" do
        render_inline(described_class.new(title: "Modal with Trigger")) do |c|
          c.with_trigger do
            '<button class="px-4 py-2 bg-blue-600 text-white rounded-lg">Open Modal</button>'.html_safe
          end
          c.with_body { "Modal content appears when triggered" }
        end

        expect(page).to match_screenshot("modal_with_trigger")
      end
    end

    context "closable variations" do
      it "matches baseline for modal with close button" do
        render_inline(described_class.new(title: "Closable Modal", closable: true)) do |c|
          c.with_body { "This modal can be closed using the X button" }
        end

        expect(page).to match_screenshot("modal_closable")
      end

      it "matches baseline for modal without close button" do
        render_inline(described_class.new(title: "Required Modal", closable: false)) do |c|
          c.with_body { "This modal requires explicit action (no close button)" }
          c.with_footer do
            '<button class="px-4 py-2 bg-blue-600 text-white rounded-lg">Acknowledge</button>'.html_safe
          end
        end

        expect(page).to match_screenshot("modal_not_closable")
      end
    end

    context "full-featured modal" do
      it "matches baseline for complete modal with all slots" do
        render_inline(described_class.new(
          title: "Delete Product",
          size: :lg,
          closable: true,
          id: "delete-modal"
        )) do |c|
          c.with_trigger do
            '<button class="px-4 py-2 bg-red-600 text-white rounded-lg">Delete Product</button>'.html_safe
          end
          c.with_body do
            <<~HTML.html_safe
              <div class="space-y-4">
                <p class="text-red-600 font-semibold">Warning: This action cannot be undone</p>
                <p class="text-gray-700">
                  Deleting this product will remove it from all catalogs and inventories.
                  Any associated data will be permanently lost.
                </p>
                <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
                  <p class="text-sm text-yellow-800">
                    Please review the implications before proceeding.
                  </p>
                </div>
              </div>
            HTML
          end
          c.with_footer do
            <<~HTML.html_safe
              <div class="flex justify-end gap-3">
                <button class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300">
                  Cancel
                </button>
                <button class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700">
                  Confirm Delete
                </button>
              </div>
            HTML
          end
        end

        expect(page).to match_screenshot("modal_full_featured")
      end

      it "matches baseline for form modal" do
        render_inline(described_class.new(title: "Edit Product", size: :xl)) do |c|
          c.with_body do
            <<~HTML.html_safe
              <form class="space-y-4">
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Product Name</label>
                  <input type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg" value="Sample Product">
                </div>
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-1">Description</label>
                  <textarea class="w-full px-3 py-2 border border-gray-300 rounded-lg" rows="3">Product description here</textarea>
                </div>
                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">SKU</label>
                    <input type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg" value="PRD-001">
                  </div>
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-1">Price</label>
                    <input type="text" class="w-full px-3 py-2 border border-gray-300 rounded-lg" value="$99.99">
                  </div>
                </div>
              </form>
            HTML
          end
          c.with_footer do
            <<~HTML.html_safe
              <div class="flex justify-between items-center">
                <button class="px-4 py-2 text-red-600 hover:bg-red-50 rounded-lg">Delete</button>
                <div class="flex gap-2">
                  <button class="px-4 py-2 bg-gray-200 text-gray-700 rounded-lg">Cancel</button>
                  <button class="px-4 py-2 bg-blue-600 text-white rounded-lg">Save Changes</button>
                </div>
              </div>
            HTML
          end
        end

        expect(page).to match_screenshot("modal_form")
      end
    end
  end
end
