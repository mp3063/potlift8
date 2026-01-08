# frozen_string_literal: true

module Shared
  # Mobile sidebar navigation component
  #
  # Provides a slide-out navigation menu for mobile and tablet devices.
  # The sidebar is controlled via Stimulus and overlays the main content
  # when opened. It includes a backdrop overlay and is hidden by default.
  #
  # **Features:**
  # - Slide-out animation from left side
  # - Semi-transparent backdrop overlay
  # - Navigation links with auto-close on click
  # - Close button in header
  # - Backdrop click to close
  # - Hidden on large screens (lg:hidden)
  # - Scrollable content area
  #
  # **Accessibility:**
  # - Proper ARIA labels for close button
  # - Keyboard navigation support
  # - Focus management
  # - Screen reader friendly
  #
  # **Stimulus Integration:**
  # - Target: overlay (the entire sidebar container)
  # - Actions: close (closes sidebar)
  # - Controlled by mobile-sidebar controller in NavbarComponent
  #
  # @example Usage in layout (typically rendered once)
  #   <%= render Shared::MobileSidebarComponent.new %>
  #
  # @note This component relies on the mobile-sidebar Stimulus controller
  #       being initialized in the parent NavbarComponent.
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  # @see app/javascript/controllers/mobile_sidebar_controller.js Mobile Sidebar Controller
  # @see Shared::NavbarComponent Parent component with controller
  #
  class MobileSidebarComponent < ViewComponent::Base
    include Rails.application.routes.url_helpers

    # Renders the mobile sidebar component
    #
    # @return [String] HTML structure with backdrop and sidebar panel
    def call
      content_tag(:div,
        id: "mobile-sidebar",
        class: "lg:hidden fixed inset-0 z-50 hidden",
        data: { mobile_sidebar_target: "overlay" },
        role: "dialog",
        aria: { modal: "true", label: "Mobile navigation menu" }
      ) do
        concat(render_backdrop)
        concat(render_sidebar)
      end
    end

    private

    # Renders the semi-transparent backdrop overlay
    #
    # Clicking the backdrop closes the sidebar.
    #
    # @return [String] HTML div for backdrop overlay
    def render_backdrop
      content_tag(:div, nil,
        class: "fixed inset-0 bg-gray-900 bg-opacity-50",
        data: { action: "click->mobile-sidebar#close" }
      )
    end

    # Renders the sidebar panel
    #
    # Contains the header with close button and navigation links.
    #
    # @return [String] HTML div with sidebar content
    def render_sidebar
      content_tag(:div, class: "fixed inset-y-0 left-0 w-64 bg-white shadow-xl overflow-y-auto") do
        concat(render_header)
        concat(render_navigation)
      end
    end

    def render_header
      content_tag(:div, class: "flex items-center justify-between p-4 border-b border-gray-200") do
        concat(content_tag(:span, "Potlift8", class: "text-lg font-bold text-gray-900"))
        concat(close_button)
      end
    end

    def close_button
      button_tag(
        type: "button",
        class: "p-2 text-gray-600 hover:text-gray-900 rounded-lg",
        data: { action: "click->mobile-sidebar#close" },
        aria: { label: "Close menu" }
      ) do
        raw('<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>')
      end
    end

    def render_navigation
      content_tag(:nav, class: "p-4 space-y-2") do
        concat(mobile_nav_link("Dashboard", helpers.root_path))
        concat(mobile_nav_link("Products", helpers.products_path))
        concat(mobile_nav_link("Imports", helpers.imports_path))
        concat(mobile_nav_link("Labels", helpers.labels_path))
        concat(mobile_nav_link("Storages", helpers.storages_path))
        concat(mobile_nav_link("Catalogs", helpers.catalogs_path))
        concat(mobile_nav_link("Attributes", helpers.product_attributes_path))
        # TODO: Uncomment when Reports feature is implemented
        # concat(mobile_nav_link("Reports", helpers.reports_path))
      end
    end

    def mobile_nav_link(text, path)
      helpers.link_to text, path,
        class: "block px-4 py-2 text-base font-medium text-gray-700 hover:bg-gray-100 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2",
        data: { action: "click->mobile-sidebar#close" }
    end
  end
end
