# frozen_string_literal: true

module Shared
  class MobileSidebarComponent < ViewComponent::Base
    include Rails.application.routes.url_helpers

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

    def render_backdrop
      content_tag(:div, nil,
        class: "fixed inset-0 bg-gray-900 bg-opacity-50",
        data: { action: "click->mobile-sidebar#close" }
      )
    end

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
