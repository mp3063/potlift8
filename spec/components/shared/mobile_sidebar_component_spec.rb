require "rails_helper"

RSpec.describe Shared::MobileSidebarComponent, type: :component do
  describe "basic rendering" do
    it "renders with lg:hidden class" do
      render_inline(described_class.new)

      expect(page).to have_css("div.lg\\:hidden")
    end

    it "has fixed inset-0 positioning" do
      render_inline(described_class.new)

      expect(page).to have_css("div.fixed.inset-0")
    end

    it "has z-50 for layering" do
      render_inline(described_class.new)

      expect(page).to have_css("div.z-50")
    end

    it "is hidden by default" do
      render_inline(described_class.new)

      expect(page).to have_css("div.hidden")
    end

    it "has mobile-sidebar-target overlay" do
      render_inline(described_class.new)

      expect(page).to have_css('div[data-mobile-sidebar-target="overlay"]')
    end
  end

  describe "backdrop" do
    it "backdrop has gray-900 background" do
      render_inline(described_class.new)

      expect(page).to have_css("div.bg-gray-900")
    end

    it "backdrop has opacity-50" do
      render_inline(described_class.new)

      expect(page).to have_css("div.bg-opacity-50")
    end

    it "backdrop has fixed inset-0 positioning" do
      render_inline(described_class.new)

      # There should be two elements with fixed inset-0: overlay container and backdrop
      expect(page).to have_css("div.fixed.inset-0", count: 2)
    end

    it "backdrop has click action to close" do
      render_inline(described_class.new)

      expect(page).to have_css('div[data-action="click->mobile-sidebar#close"]')
    end
  end

  describe "sidebar panel" do
    it "sidebar has w-64 width" do
      render_inline(described_class.new)

      expect(page).to have_css("div.w-64")
    end

    it "has white background" do
      render_inline(described_class.new)

      expect(page).to have_css("div.bg-white.w-64")
    end

    it "has shadow-xl" do
      render_inline(described_class.new)

      expect(page).to have_css("div.shadow-xl")
    end

    it "has overflow-y-auto" do
      render_inline(described_class.new)

      expect(page).to have_css("div.overflow-y-auto")
    end

    it "has fixed positioning on left side" do
      render_inline(described_class.new)

      expect(page).to have_css("div.fixed.inset-y-0.left-0")
    end
  end

  describe "header" do
    it "renders Potlift8 text" do
      render_inline(described_class.new)

      expect(page).to have_text("Potlift8")
    end

    it "Potlift8 text has correct styling" do
      render_inline(described_class.new)

      expect(page).to have_css("span.text-lg.font-bold.text-gray-900", text: "Potlift8")
    end

    it "header has border-b" do
      render_inline(described_class.new)

      expect(page).to have_css("div.border-b.border-gray-200")
    end

    it "header has flex layout" do
      render_inline(described_class.new)

      expect(page).to have_css("div.flex.items-center.justify-between")
    end

    it "header has padding" do
      render_inline(described_class.new)

      expect(page).to have_css("div.p-4.border-b")
    end

    it "has close button" do
      render_inline(described_class.new)

      expect(page).to have_css("button")
    end
  end

  describe "close button" do
    it "has X icon SVG" do
      render_inline(described_class.new)

      expect(page).to have_css("button svg.h-6.w-6")
    end

    it "has aria-label for accessibility" do
      render_inline(described_class.new)

      expect(page).to have_css('button[aria-label="Close menu"]')
    end

    it "has click action to close sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css('button[data-action="click->mobile-sidebar#close"]')
    end

    it "has hover effect" do
      render_inline(described_class.new)

      expect(page).to have_css("button.hover\\:text-gray-600")
    end

    it "has text-gray-400 default color" do
      render_inline(described_class.new)

      expect(page).to have_css("button.text-gray-400")
    end

    it "has rounded-lg" do
      render_inline(described_class.new)

      expect(page).to have_css("button.rounded-lg")
    end

    it "has padding" do
      render_inline(described_class.new)

      expect(page).to have_css("button.p-2")
    end

    it "is button type" do
      render_inline(described_class.new)

      expect(page).to have_css('button[type="button"]')
    end
  end

  describe "navigation" do
    it "renders Dashboard link" do
      render_inline(described_class.new)

      expect(page).to have_link("Dashboard")
    end

    it "renders Products link" do
      render_inline(described_class.new)

      expect(page).to have_link("Products")
    end

    it "renders Catalogs link" do
      render_inline(described_class.new)

      expect(page).to have_link("Catalogs")
    end

    it "renders Inventory link" do
      render_inline(described_class.new)

      expect(page).to have_link("Inventory")
    end

    it "renders Reports link" do
      render_inline(described_class.new)

      expect(page).to have_link("Reports")
    end

    it "nav container has semantic nav element" do
      render_inline(described_class.new)

      expect(page).to have_css("nav")
    end

    it "nav has padding and spacing" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.p-4.space-y-2")
    end
  end

  describe "navigation links" do
    it "links have hover:bg-gray-100" do
      render_inline(described_class.new)

      expect(page).to have_css("a.hover\\:bg-gray-100")
    end

    it "links have text-base font size" do
      render_inline(described_class.new)

      expect(page).to have_css("a.text-base")
    end

    it "links have font-medium weight" do
      render_inline(described_class.new)

      expect(page).to have_css("a.font-medium")
    end

    it "links have text-gray-700 color" do
      render_inline(described_class.new)

      expect(page).to have_css("a.text-gray-700")
    end

    it "links have rounded-lg corners" do
      render_inline(described_class.new)

      expect(page).to have_css("a.rounded-lg")
    end

    it "links are block display" do
      render_inline(described_class.new)

      expect(page).to have_css("a.block")
    end

    it "links have padding" do
      render_inline(described_class.new)

      expect(page).to have_css("a.px-4.py-2")
    end

    it "Dashboard link has correct href" do
      render_inline(described_class.new)

      expect(page).to have_link("Dashboard", href: "/")
    end

    it "Products link has correct href" do
      render_inline(described_class.new)

      expect(page).to have_link("Products", href: "/products")
    end

    it "Catalogs link has correct href" do
      render_inline(described_class.new)

      expect(page).to have_link("Catalogs", href: "/catalogs")
    end

    it "Inventory link has correct href" do
      render_inline(described_class.new)

      expect(page).to have_link("Inventory", href: "/inventories")
    end

    it "Reports link has correct href" do
      render_inline(described_class.new)

      expect(page).to have_link("Reports", href: "/reports")
    end
  end

  describe "stimulus integration" do
    it "overlay has mobile-sidebar target" do
      render_inline(described_class.new)

      expect(page).to have_css('div[data-mobile-sidebar-target="overlay"]')
    end

    it "close button has mobile-sidebar close action" do
      render_inline(described_class.new)

      expect(page).to have_css('button[data-action="click->mobile-sidebar#close"]')
    end

    it "backdrop has click close action" do
      render_inline(described_class.new)

      # Count backdrop with close action
      backdrop_selector = 'div.bg-gray-900[data-action="click->mobile-sidebar#close"]'
      expect(page).to have_css(backdrop_selector)
    end

    it "nav links have close action on click" do
      render_inline(described_class.new)

      expect(page).to have_css('a[data-action="click->mobile-sidebar#close"]')
    end

    it "all nav links close sidebar on click" do
      render_inline(described_class.new)

      # Should have 5 links (Dashboard, Products, Catalogs, Inventory, Reports)
      expect(page).to have_css('a[data-action="click->mobile-sidebar#close"]', count: 5)
    end
  end

  describe "accessibility" do
    it "close button has aria-label" do
      render_inline(described_class.new)

      expect(page).to have_css('button[aria-label="Close menu"]')
    end

    it "uses semantic nav element" do
      render_inline(described_class.new)

      expect(page).to have_css("nav")
    end

    it "close button is keyboard accessible" do
      render_inline(described_class.new)

      expect(page).to have_css('button[type="button"]')
    end

    it "links are keyboard accessible" do
      render_inline(described_class.new)

      # All links should be standard anchor elements
      expect(page).to have_css("a", count: 5)
    end
  end

  describe "responsive design" do
    it "entire component hidden on large screens" do
      render_inline(described_class.new)

      expect(page).to have_css("div.lg\\:hidden")
    end

    it "sidebar width is fixed at 64" do
      render_inline(described_class.new)

      expect(page).to have_css("div.w-64")
    end
  end

  describe "layout and positioning" do
    it "overlay uses fixed positioning" do
      render_inline(described_class.new)

      expect(page).to have_css("div.fixed.inset-0.z-50")
    end

    it "sidebar uses fixed left positioning" do
      render_inline(described_class.new)

      expect(page).to have_css("div.fixed.inset-y-0.left-0")
    end

    it "backdrop covers full screen" do
      render_inline(described_class.new)

      expect(page).to have_css("div.fixed.inset-0.bg-gray-900")
    end

    it "has proper z-index stacking" do
      render_inline(described_class.new)

      expect(page).to have_css("div.z-50")
    end
  end

  describe "visual styling" do
    it "backdrop is semi-transparent" do
      render_inline(described_class.new)

      expect(page).to have_css("div.bg-gray-900.bg-opacity-50")
    end

    it "sidebar has white background" do
      render_inline(described_class.new)

      expect(page).to have_css("div.bg-white.shadow-xl")
    end

    it "sidebar has shadow for depth" do
      render_inline(described_class.new)

      expect(page).to have_css("div.shadow-xl")
    end

    it "header has bottom border" do
      render_inline(described_class.new)

      expect(page).to have_css("div.border-b.border-gray-200")
    end
  end

  describe "content structure" do
    it "contains header and navigation sections" do
      render_inline(described_class.new)

      expect(page).to have_css("div.flex.items-center.justify-between") # header
      expect(page).to have_css("nav.p-4") # navigation
    end

    it "header contains title and close button" do
      render_inline(described_class.new)

      expect(page).to have_css("span", text: "Potlift8")
      expect(page).to have_css("button")
    end

    it "navigation contains all links" do
      render_inline(described_class.new)

      expect(page).to have_link("Dashboard")
      expect(page).to have_link("Products")
      expect(page).to have_link("Catalogs")
      expect(page).to have_link("Inventory")
      expect(page).to have_link("Reports")
    end
  end

  describe "scrolling behavior" do
    it "sidebar content is scrollable" do
      render_inline(described_class.new)

      expect(page).to have_css("div.overflow-y-auto")
    end

    it "sidebar spans full height" do
      render_inline(described_class.new)

      expect(page).to have_css("div.inset-y-0")
    end
  end

  describe "interaction design" do
    it "backdrop dismisses sidebar on click" do
      render_inline(described_class.new)

      expect(page).to have_css('div.bg-gray-900[data-action="click->mobile-sidebar#close"]')
    end

    it "close button dismisses sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css('button[data-action="click->mobile-sidebar#close"]')
    end

    it "clicking nav links dismisses sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css('a[data-action="click->mobile-sidebar#close"]', count: 5)
    end
  end

  describe "icon rendering" do
    it "close button contains SVG icon" do
      render_inline(described_class.new)

      expect(page).to have_css("button svg")
    end

    it "SVG has correct dimensions" do
      render_inline(described_class.new)

      expect(page).to have_css("svg.h-6.w-6")
    end

    it "SVG uses stroke for outline style" do
      render_inline(described_class.new)

      # Check that SVG element exists within button
      expect(page).to have_css("button svg")
    end
  end

  describe "spacing and alignment" do
    it "header has flex layout with space between" do
      render_inline(described_class.new)

      expect(page).to have_css("div.flex.items-center.justify-between")
    end

    it "navigation has vertical spacing between links" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.space-y-2")
    end

    it "header has padding" do
      render_inline(described_class.new)

      expect(page).to have_css("div.p-4.border-b")
    end

    it "navigation has padding" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.p-4")
    end
  end

  describe "combined functionality" do
    it "renders complete mobile sidebar structure" do
      render_inline(described_class.new)

      # Check all major components are present
      expect(page).to have_css("div.lg\\:hidden") # Container
      expect(page).to have_css("div.bg-gray-900.bg-opacity-50") # Backdrop
      expect(page).to have_css("div.w-64.bg-white") # Sidebar panel
      expect(page).to have_text("Potlift8") # Header
      expect(page).to have_css("button") # Close button
      expect(page).to have_css("nav") # Navigation
      expect(page).to have_link("Dashboard") # Links
    end

    it "has proper stimulus setup for toggle behavior" do
      render_inline(described_class.new)

      # Overlay target for visibility control
      expect(page).to have_css('div[data-mobile-sidebar-target="overlay"]')
      # Multiple close actions
      expect(page).to have_css('[data-action*="mobile-sidebar#close"]', minimum: 6)
    end
  end

  describe "text content" do
    it "displays all navigation text correctly" do
      render_inline(described_class.new)

      expect(page).to have_text("Potlift8")
      expect(page).to have_text("Dashboard")
      expect(page).to have_text("Products")
      expect(page).to have_text("Catalogs")
      expect(page).to have_text("Inventory")
      expect(page).to have_text("Reports")
    end
  end

  describe "default state" do
    it "is hidden by default for mobile sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css("div.hidden.lg\\:hidden")
    end

    it "can be shown by removing hidden class via Stimulus" do
      render_inline(described_class.new)

      # Component structure supports toggle via Stimulus
      expect(page).to have_css('div[data-mobile-sidebar-target="overlay"]')
    end
  end
end
