require "rails_helper"

RSpec.describe Shared::NavbarComponent, type: :component do
  let(:user) { { id: 1, email: "user@example.com", name: "John Doe" } }
  let(:company) { double("Company", id: 1, name: "Test Company", code: "TEST") }

  describe "basic rendering" do
    it "renders navbar with fixed positioning" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.fixed.top-0.z-40")
    end

    it "has white background and border-b" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.bg-white.border-b.border-gray-200")
    end

    it "has shadow-sm for subtle shadow" do
      render_inline(described_class.new)

      expect(page).to have_css("nav.shadow-sm")
    end

    it "contains max-w-7xl container" do
      render_inline(described_class.new)

      expect(page).to have_css("div.max-w-7xl")
    end

    it "has correct height class" do
      render_inline(described_class.new)

      expect(page).to have_css("div.h-16")
    end

    it "has controllers for dropdown and mobile-sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css('nav[data-controller="dropdown mobile-sidebar"]')
    end
  end

  describe "logo section" do
    it "renders Potlift8 text" do
      render_inline(described_class.new)

      expect(page).to have_text("Potlift8")
    end

    it "logo links to root_path" do
      render_inline(described_class.new)

      expect(page).to have_link("Potlift8", href: "/")
    end

    it "contains SVG logo with blue-600 color" do
      render_inline(described_class.new)

      expect(page).to have_css("svg.text-blue-600")
      expect(page).to have_css("svg.h-8.w-8")
    end

    it "logo text has correct styling" do
      render_inline(described_class.new)

      expect(page).to have_css("span.text-xl.font-bold.text-gray-900", text: "Potlift8")
    end

    it "logo section has flex layout with gap" do
      render_inline(described_class.new)

      expect(page).to have_css("a.flex.items-center.gap-3")
    end
  end

  describe "mobile menu button" do
    it "is hidden on desktop" do
      render_inline(described_class.new)

      expect(page).to have_css("button.lg\\:hidden")
    end

    it "has aria-label for accessibility" do
      render_inline(described_class.new)

      expect(page).to have_css('button[aria-label="Open menu"]')
    end

    it "has Stimulus action to toggle mobile sidebar" do
      render_inline(described_class.new)

      expect(page).to have_css('button[data-action="click->mobile-sidebar#toggle"]')
    end

    it "contains hamburger menu SVG" do
      render_inline(described_class.new)

      expect(page).to have_css("button.lg\\:hidden svg.h-6.w-6")
    end

    it "has hover and focus states" do
      render_inline(described_class.new)

      expect(page).to have_css("button.hover\\:bg-gray-100.focus\\:ring-2.focus\\:ring-blue-500")
    end
  end

  describe "navigation links" do
    context "when user is present" do
      it "renders navigation with hidden md:flex" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.hidden.md\\:flex.md\\:items-center")
      end

      it "has link to Dashboard" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Dashboard")
      end

      it "has link to Products" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Products")
      end

      it "has link to Labels" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Labels")
      end

      it "has link to Storages" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Storages")
      end

      it "has link to Catalogs" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Catalogs")
      end

      it "has link to Attributes" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_link("Attributes")
      end

      # TODO: Uncomment when Reports feature is implemented
      # it "has link to Reports" do
      #   render_inline(described_class.new(current_user: user))
      #
      #   expect(page).to have_link("Reports")
      # end

      it "navigation has gap between links" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.md\\:gap-6")
      end

      it "links have text-sm and font-medium" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("a.text-sm.font-medium")
      end

      it "links have transition-colors for smooth hover" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("a.transition-colors")
      end
    end

    context "when user is not present" do
      it "does not render navigation" do
        render_inline(described_class.new)

        expect(page).not_to have_link("Dashboard")
        expect(page).not_to have_link("Products")
        expect(page).not_to have_link("Labels")
        expect(page).not_to have_link("Storages")
        expect(page).not_to have_link("Catalogs")
        expect(page).not_to have_link("Attributes")
      end
    end
  end

  describe "company switcher" do
    context "when company is present" do
      it "renders company name" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_text("Test Company")
      end

      it "has blue-50 background" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.bg-blue-50")
      end

      it "has blue-200 border" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.border.border-blue-200")
      end

      it "has rounded-lg corners" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.rounded-lg.border.border-blue-200")
      end

      it "hidden on mobile" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.hidden.lg\\:block")
      end

      it "contains company icon SVG" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("svg.h-5.w-5.text-blue-600")
      end

      it "company name has correct text styling" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("span.text-sm.font-medium.text-blue-900", text: "Test Company")
      end

      it "has flex layout with gap" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.flex.items-center.gap-2")
      end

      it "has proper padding" do
        render_inline(described_class.new(current_user: user, current_company: company))

        expect(page).to have_css("div.px-3.py-2.bg-blue-50")
      end
    end

    context "when company is not present" do
      it "does not render company switcher" do
        render_inline(described_class.new(current_user: user))

        expect(page).not_to have_css("div.bg-blue-50.border-blue-200")
        expect(page).not_to have_text("Test Company")
      end
    end
  end

  describe "user dropdown" do
    context "when user is present" do
      it "renders user avatar with initials" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.h-8.w-8.rounded-full.bg-blue-600")
        expect(page).to have_css("span.text-sm.font-medium.text-white", text: "JD")
      end

      it "avatar has blue-600 background" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.bg-blue-600.rounded-full")
      end

      it "dropdown button has data-controller" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('div[data-controller="dropdown"]')
      end

      it "dropdown button has click action" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('button[data-action="click->dropdown#toggle"]')
      end

      it "dropdown menu has data target" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('div[data-dropdown-target="menu"]')
      end

      it "dropdown button has aria-expanded" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('button[aria-expanded="false"]')
      end

      it "dropdown button has aria-haspopup" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('button[aria-haspopup="true"]')
      end

      it "menu contains user name" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("p.text-sm.font-medium.text-gray-900", text: "John Doe")
      end

      it "menu contains user email" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("p.text-xs.text-gray-500", text: "user@example.com")
      end

      # TODO: Uncomment when Profile and Settings features are implemented
      # it "has Profile link" do
      #   render_inline(described_class.new(current_user: user))
      #
      #   expect(page).to have_link("Profile")
      # end
      #
      # it "has Settings link" do
      #   render_inline(described_class.new(current_user: user))
      #
      #   expect(page).to have_link("Settings")
      # end

      it "has Sign out button" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_button("Sign out")
      end

      it "Sign out button has red-700 text" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("button.text-red-700", text: "Sign out")
      end

      it "dropdown menu is hidden by default" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('div.hidden[data-dropdown-target="menu"]')
      end

      it "dropdown menu has shadow-lg" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.shadow-lg.rounded-lg")
      end

      it "dropdown menu has ring styling" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.ring-1.ring-black.ring-opacity-5")
      end

      it "dropdown menu has role menu" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('div[role="menu"]')
      end

      it "dropdown menu has aria-orientation" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('div[aria-orientation="vertical"]')
      end

      it "dropdown items have role menuitem" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css('[role="menuitem"]')
      end

      it "contains chevron icon" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("svg.h-4.w-4.text-gray-500")
      end

      it "dropdown items have hover effect" do
        render_inline(described_class.new(current_user: user))

        # Check for hover class on dropdown menu items (button or link)
        expect(page).to have_css(".hover\\:bg-gray-100")
      end

      it "dropdown items have transition-colors" do
        render_inline(described_class.new(current_user: user))

        # Check for transition class on dropdown menu items (button or link)
        expect(page).to have_css(".transition-colors")
      end

      it "renders dividers between sections" do
        render_inline(described_class.new(current_user: user))

        expect(page).to have_css("div.border-t.border-gray-200")
      end
    end

    context "when user is not present" do
      it "does not render user dropdown" do
        render_inline(described_class.new)

        expect(page).not_to have_css('div[data-controller="dropdown"]')
        expect(page).not_to have_css("div.h-8.w-8.rounded-full")
      end

      it "does not render user section" do
        render_inline(described_class.new)

        # expect(page).not_to have_link("Profile")  # TODO: Uncomment when Profile implemented
        # expect(page).not_to have_link("Settings") # TODO: Uncomment when Settings implemented
        expect(page).not_to have_button("Sign out")
      end
    end
  end

  describe "user avatar initials" do
    it "uses first letters of name" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_text("JD")
    end

    it "handles single name" do
      single_name_user = { id: 1, email: "test@example.com", name: "Alice" }
      render_inline(described_class.new(current_user: single_name_user))

      expect(page).to have_text("A")
    end

    it "handles three-word name" do
      long_name_user = { id: 1, email: "test@example.com", name: "John Jacob Smith" }
      render_inline(described_class.new(current_user: long_name_user))

      expect(page).to have_text("JJS")
    end

    it "handles missing name with default" do
      no_name_user = { id: 1, email: "test@example.com", name: nil }
      render_inline(described_class.new(current_user: no_name_user))

      expect(page).to have_text("U")
    end

    it "initials are uppercase" do
      lowercase_user = { id: 1, email: "test@example.com", name: "jane doe" }
      render_inline(described_class.new(current_user: lowercase_user))

      expect(page).to have_text("JD")
      expect(page).not_to have_text("jd")
    end
  end

  describe "stimulus integration" do
    it "has dropdown controller on user dropdown" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('div[data-controller="dropdown"]')
    end

    it "has mobile-sidebar controller on navbar" do
      render_inline(described_class.new)

      expect(page).to have_css('nav[data-controller*="mobile-sidebar"]')
    end

    it "dropdown toggle button has target" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('button[data-dropdown-target="button"]')
    end

    it "mobile menu button triggers toggle action" do
      render_inline(described_class.new)

      expect(page).to have_css('button[data-action="click->mobile-sidebar#toggle"]')
    end
  end

  describe "responsive design" do
    it "navigation hidden on mobile" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css("div.hidden.md\\:flex")
    end

    it "company switcher hidden on mobile" do
      render_inline(described_class.new(current_user: user, current_company: company))

      expect(page).to have_css("div.hidden.lg\\:block")
    end

    it "mobile menu button shown only on mobile" do
      render_inline(described_class.new)

      expect(page).to have_css("button.lg\\:hidden")
    end

    it "has responsive padding classes" do
      render_inline(described_class.new)

      expect(page).to have_css("div.px-4.sm\\:px-6.lg\\:px-8")
    end
  end

  describe "accessibility" do
    it "navbar is semantic nav element" do
      render_inline(described_class.new)

      expect(page).to have_css("nav")
    end

    it "mobile menu button has aria-label" do
      render_inline(described_class.new)

      expect(page).to have_css('button[aria-label="Open menu"]')
    end

    it "dropdown has proper ARIA attributes" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('button[aria-expanded]')
      expect(page).to have_css('button[aria-haspopup]')
    end

    it "dropdown menu has role menu" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('div[role="menu"]')
    end

    it "dropdown items have role menuitem" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('[role="menuitem"]')
    end

    it "buttons have focus states" do
      render_inline(described_class.new)

      expect(page).to have_css("button.focus\\:ring-2")
    end
  end

  describe "combined scenarios" do
    it "renders full navbar with user and company" do
      render_inline(described_class.new(current_user: user, current_company: company))

      expect(page).to have_text("Potlift8")
      expect(page).to have_link("Dashboard")
      expect(page).to have_text("Test Company")
      expect(page).to have_text("JD")
      expect(page).to have_button("Sign out")
    end

    it "renders minimal navbar without authentication" do
      render_inline(described_class.new)

      expect(page).to have_text("Potlift8")
      expect(page).not_to have_link("Dashboard")
      expect(page).not_to have_text("JD")
    end

    it "renders with user but no company" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_link("Dashboard")
      expect(page).to have_text("JD")
      expect(page).not_to have_css("div.bg-blue-50")
    end
  end

  describe "focus and hover states" do
    it "dropdown button has focus ring" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css("button.focus\\:ring-2.focus\\:ring-blue-500")
    end

    it "dropdown button has focus ring offset" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css("button.focus\\:ring-offset-2")
    end

    it "mobile menu button has focus ring" do
      render_inline(described_class.new)

      expect(page).to have_css("button.focus\\:ring-2.focus\\:ring-blue-500")
    end

    it "mobile menu button has hover background" do
      render_inline(described_class.new)

      expect(page).to have_css("button.hover\\:bg-gray-100")
    end

    it "dropdown button has hover background" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css("button.hover\\:bg-gray-100")
    end
  end

  describe "logout button" do
    it "Sign out button uses POST method" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('form[data-turbo="false"]')
      expect(page).to have_button("Sign out")
    end

    it "Sign out button has proper focus ring styles" do
      render_inline(described_class.new(current_user: user))

      expect(page).to have_css('button.focus\:ring-2.focus\:ring-blue-500', text: "Sign out")
      expect(page).to have_css('button.focus\:ring-offset-2', text: "Sign out")
    end

    it "Sign out button does not have inline important styles" do
      render_inline(described_class.new(current_user: user))

      sign_out_button = page.find('button', text: "Sign out")
      style_attr = sign_out_button[:style]

      # Should not have !important styles that disable focus
      expect(style_attr).to be_nil.or be_empty
    end

    # TODO: Uncomment when Profile and Settings features are implemented
    # it "other links use default GET method" do
    #   render_inline(described_class.new(current_user: user))
    #
    #   # Profile and Settings should use GET method (either nil or "get")
    #   profile_link = page.find('a', text: "Profile")
    #   expect(profile_link[:"data-turbo-method"]).to be_in([nil, "get"])
    #
    #   settings_link = page.find('a', text: "Settings")
    #   expect(settings_link[:"data-turbo-method"]).to be_in([nil, "get"])
    # end
  end

  describe "icons" do
    # TODO: Uncomment when Profile and Settings features are implemented
    # it "renders user icon for Profile" do
    #   render_inline(described_class.new(current_user: user))
    #
    #   # Check that SVG is present in dropdown
    #   expect(page).to have_css('svg.h-5.w-5')
    # end
    #
    # it "renders cog icon for Settings" do
    #   render_inline(described_class.new(current_user: user))
    #
    #   # Multiple icons should be present for menu items
    #   expect(page).to have_css('svg.h-5.w-5', count: 3) # user, cog, logout
    # end

    it "renders logout icon for Sign out" do
      render_inline(described_class.new(current_user: user))

      # At minimum, the logout icon should be present
      expect(page).to have_css('svg.h-5.w-5', minimum: 1)
    end

    it "logo section has SVG icon" do
      render_inline(described_class.new)

      expect(page).to have_css("svg.h-8.w-8.text-blue-600")
    end

    it "company switcher has building icon" do
      render_inline(described_class.new(current_user: user, current_company: company))

      expect(page).to have_css("svg.h-5.w-5.text-blue-600")
    end
  end
end
