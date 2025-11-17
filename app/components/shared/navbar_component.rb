# frozen_string_literal: true

module Shared
  # Primary navigation bar component
  #
  # Renders the main navigation header with logo, navigation links, company switcher,
  # and user menu. The navbar is fixed to the top of the viewport and includes
  # responsive behavior for mobile devices.
  #
  # **Features:**
  # - Fixed position navigation bar
  # - Logo and branding
  # - Primary navigation links (Desktop only)
  # - Company switcher display
  # - User dropdown menu with profile/settings/logout
  # - Mobile menu trigger button
  # - Responsive design (stacks on mobile)
  # - Active link highlighting
  #
  # **Accessibility:**
  # - Semantic nav element
  # - Proper ARIA labels for icon buttons
  # - Keyboard navigation support
  # - Focus indicators
  # - Screen reader friendly
  #
  # **Stimulus Integration:**
  # - Controller: dropdown (for user menu)
  # - Controller: mobile-sidebar (for mobile menu)
  #
  # @example Basic usage in layout
  #   <%= render Shared::NavbarComponent.new(
  #     current_user: current_user,
  #     current_company: current_company
  #   ) %>
  #
  # @example Without user (guest state)
  #   <%= render Shared::NavbarComponent.new %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  # @see app/javascript/controllers/dropdown_controller.js Dropdown Controller
  # @see app/javascript/controllers/mobile_sidebar_controller.js Mobile Sidebar Controller
  #
  class NavbarComponent < ViewComponent::Base
    include Rails.application.routes.url_helpers

    attr_reader :current_user, :current_company

    # Initialize a new navbar component
    #
    # @param current_user [User, nil] Current user model instance
    # @param current_company [Company, nil] Current company model instance
    #
    # @example With authenticated user
    #   NavbarComponent.new(
    #     current_user: User.find(1),
    #     current_company: Company.find(1)
    #   )
    #
    # @example Guest user
    #   NavbarComponent.new(current_user: nil, current_company: nil)
    #
    # @return [NavbarComponent]
    def initialize(current_user: nil, current_company: nil)
      @current_user = current_user
      @current_company = current_company
    end

    # Renders the navbar component
    #
    # @return [String] HTML nav element with navigation structure
    def call
      content_tag(:nav, class: navbar_classes, data: { controller: "dropdown mobile-sidebar" }) do
        content_tag(:div, class: "mx-auto max-w-7xl px-4 sm:px-6 lg:px-8") do
          content_tag(:div, class: "flex h-16 items-center justify-between") do
            concat(render_logo_section)
            concat(render_navigation)
            concat(render_user_section)
          end
        end
      end
    end

    private

    # CSS classes for the navbar container
    #
    # @return [String] CSS classes for fixed navbar with border and shadow
    def navbar_classes
      "fixed top-0 left-0 right-0 z-40 bg-white border-b border-gray-200 shadow-sm"
    end

    # Renders the logo section with mobile menu button
    #
    # @return [String] HTML div with logo and mobile menu button
    def render_logo_section
      content_tag(:div, class: "flex items-center gap-4") do
        concat(render_mobile_menu_button)
        concat(helpers.link_to(helpers.root_path, class: "flex items-center gap-3") do
          concat(logo_svg)
          concat(content_tag(:span, "Potlift8", class: "text-xl font-bold text-gray-900"))
        end)
      end
    end

    # Renders the mobile menu hamburger button
    #
    # Only visible on mobile/tablet devices (hidden on lg+ screens).
    #
    # @return [String] HTML button with hamburger icon
    def render_mobile_menu_button
      button_tag(
        type: "button",
        class: "lg:hidden p-2 text-gray-700 hover:bg-gray-100 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500",
        data: { action: "click->mobile-sidebar#toggle" },
        aria: { label: "Open menu" }
      ) do
        raw(<<~SVG)
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        SVG
      end
    end

    def logo_svg
      raw(<<~SVG)
        <svg class="h-8 w-8 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 2C12 2 8 6 8 10C8 12 10 14 12 14C14 14 16 12 16 10C16 6 12 2 12 2Z"/>
          <path d="M12 14C12 14 8 16 8 18C8 20 10 22 12 22C14 22 16 20 16 18C16 16 12 14 12 14Z"/>
        </svg>
      SVG
    end

    def render_navigation
      return unless @current_user

      content_tag(:div, class: "hidden md:flex md:items-center md:gap-6") do
        concat(nav_link("Dashboard", helpers.root_path))
        concat(nav_link("Products", helpers.products_path))
        concat(nav_link("Labels", helpers.labels_path))
        concat(nav_link("Storages", helpers.storages_path))
        concat(nav_link("Catalogs", helpers.catalogs_path))
        concat(nav_link("Attributes", helpers.product_attributes_path))
        # TODO: Uncomment when Reports feature is implemented
        # concat(nav_link("Reports", helpers.reports_path))
      end
    end

    def nav_link(text, path)
      active = helpers.current_page?(path)
      classes = [
        "text-sm font-medium transition-colors",
        active ? "text-blue-600 border-b-2 border-blue-600 pb-1" : "text-gray-700 hover:text-blue-600"
      ].join(" ")

      helpers.link_to text, path, class: classes
    end

    def render_user_section
      return unless @current_user

      content_tag(:div, class: "flex items-center gap-4") do
        concat(render_search_button)
        concat(render_company_switcher) if @current_company
        concat(render_user_dropdown)
      end
    end

    # Renders the search button trigger
    #
    # Opens the global search modal when clicked.
    #
    # @return [String] HTML button element
    def render_search_button
      button_tag(
        type: "button",
        class: "p-2 text-gray-700 hover:bg-gray-100 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors",
        data: { action: "click->global-search#open" },
        aria: { label: "Open search (Cmd+K)" }
      ) do
        concat(search_icon_svg)
        concat(content_tag(:span, class: "sr-only") { "Search (⌘K)" })
      end
    end

    def search_icon_svg
      raw(<<~SVG)
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      SVG
    end

    def render_company_switcher
      content_tag(:div, class: "hidden lg:block") do
        content_tag(:div, class: "flex items-center gap-2 px-3 py-2 bg-blue-50 rounded-lg border border-blue-200") do
          concat(company_icon)
          concat(content_tag(:span, @current_company.name, class: "text-sm font-medium text-blue-900"))
        end
      end
    end

    def company_icon
      raw(<<~SVG)
        <svg class="h-5 w-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/>
        </svg>
      SVG
    end

    def render_user_dropdown
      content_tag(:div, class: "relative", data: { controller: "dropdown" }) do
        concat(render_user_button)
        concat(render_dropdown_menu)
      end
    end

    def render_user_button
      button_tag(
        type: "button",
        class: "flex items-center gap-2 rounded-full bg-white p-1 text-gray-700 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
        data: { action: "click->dropdown#toggle", dropdown_target: "button" },
        aria: { expanded: "false", haspopup: "true" }
      ) do
        concat(user_avatar)
        concat(chevron_icon)
      end
    end

    def user_avatar
      initials = @current_user&.name&.split&.map(&:first)&.join&.upcase || "U"
      content_tag(:div, class: "h-8 w-8 rounded-full bg-blue-600 flex items-center justify-center") do
        content_tag(:span, initials, class: "text-sm font-medium text-white")
      end
    end

    def chevron_icon
      raw(<<~SVG)
        <svg class="h-4 w-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
        </svg>
      SVG
    end

    def render_dropdown_menu
      content_tag(:div,
        class: "hidden absolute right-0 mt-2 w-48 origin-top-right rounded-lg bg-white shadow-lg ring-1 ring-black ring-opacity-5 focus:outline-none",
        data: { dropdown_target: "menu" },
        role: "menu",
        aria: { orientation: "vertical" }
      ) do
        content_tag(:div, class: "py-1", role: "none") do
          concat(dropdown_header)
          # TODO: Uncomment when Profile and Settings features are implemented
          # concat(content_tag(:div, nil, class: "border-t border-gray-200 my-1"))
          # concat(dropdown_item("Profile", helpers.profile_path, icon: "user"))
          # concat(dropdown_item("Settings", helpers.settings_path, icon: "cog"))
          concat(content_tag(:div, nil, class: "border-t border-gray-200 my-1"))
          concat(dropdown_item("Sign out", helpers.auth_logout_path, icon: "logout", method: :post, class: "text-red-700"))
        end
      end
    end

    def dropdown_header
      content_tag(:div, class: "px-4 py-2") do
        concat(content_tag(:p, @current_user&.name, class: "text-sm font-medium text-gray-900 truncate"))
        concat(content_tag(:p, @current_user&.email, class: "text-xs text-gray-500 truncate"))
      end
    end

    def dropdown_item(text, path, icon: nil, method: :get, **options)
      # Dropdown item styling with subtle focus state
      item_classes = [
        "block px-4 py-2 text-sm hover:bg-gray-100 transition-colors rounded-md",
        "focus:outline-none focus:bg-gray-100",
        "cursor-pointer",
        options[:class] || "text-gray-700"
      ].join(" ")

      if method == :post
        # Use button_to for POST requests (logout)
        # Note: button_to creates a form wrapper, so we style both form and button
        # IMPORTANT: Turbo disabled because logout redirects to external Authlift8 (CORS)
        # Using inline styles with !important to override all browser default focus styles
        helpers.button_to path,
          method: :post,
          class: "#{item_classes} w-full text-left",
          role: "menuitem",
          style: "outline: none !important; box-shadow: none !important; border: none !important;",
          form: {
            class: "w-full",
            style: "outline: none !important; box-shadow: none !important; border: none !important;",
            data: { turbo: false }
          } do
          content_tag(:div, class: "flex items-center gap-2") do
            concat(dropdown_icon(icon)) if icon
            concat(content_tag(:span, text))
          end
        end
      else
        # Use link_to for GET requests
        helpers.link_to path, class: item_classes, role: "menuitem" do
          content_tag(:div, class: "flex items-center gap-2") do
            concat(dropdown_icon(icon)) if icon
            concat(content_tag(:span, text))
          end
        end
      end
    end

    def dropdown_icon(name)
      icons = {
        "user" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>',
        "cog" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>',
        "logout" => '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"/>'
      }

      raw(<<~SVG)
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          #{icons[name]}
        </svg>
      SVG
    end
  end
end
