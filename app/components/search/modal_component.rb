# frozen_string_literal: true

module Search
  class ModalComponent < ViewComponent::Base
    def initialize
    end

    def call
      render_modal_backdrop
    end

    private

    def render_modal_backdrop
      content_tag(:div,
        class: "fixed top-20 left-0 right-0 z-50 flex justify-center px-4 hidden",
        data: {
          global_search_target: "modal"
        },
        role: "dialog",
        aria: {
          modal: "true",
          labelledby: "search-modal-title"
        }
      ) do
        content_tag(:div,
          class: "w-full max-w-2xl rounded-lg bg-white shadow-xl border border-gray-200",
          data: { action: "click->global-search#preventClose" }
        ) do
          concat(render_search_header)
          concat(render_results_area)
          concat(render_footer_hint)
        end
      end
    end

    def render_search_header
      content_tag(:div, class: "flex items-center border-b border-gray-200 px-4") do
        concat(search_icon)
        concat(render_search_input)
        concat(render_close_button)
      end
    end

    def search_icon
      raw(<<~SVG)
        <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      SVG
    end

    def render_search_input
      text_field_tag(
        "search",
        nil,
        placeholder: "Search products, storage, attributes, labels, catalogs...",
        autocomplete: "off",
        class: "flex-1 border-0 bg-transparent py-4 pl-3 pr-3 text-gray-900 placeholder-gray-500 focus:outline-none focus:ring-0 sm:text-sm",
        data: {
          global_search_target: "input",
          action: "input->global-search#handleInput"
        },
        aria: {
          label: "Search",
          autocomplete: "list"
        }
      )
    end

    def render_close_button
      button_tag(
        type: "button",
        class: "rounded-lg p-2 text-gray-400 hover:bg-gray-100 hover:text-gray-600 focus:outline-none focus:bg-gray-100",
        data: { action: "click->global-search#close" },
        aria: { label: "Close search" }
      ) do
        raw(<<~SVG)
          <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        SVG
      end
    end

    def render_results_area
      content_tag(:div,
        class: "max-h-96 overflow-y-auto border-b border-gray-200",
        data: { global_search_target: "results" },
        role: "listbox"
      ) do
        content_tag(:div, class: "px-4 py-8 text-center text-gray-500") do
          concat(content_tag(:p, "Type at least 2 characters to search", class: "text-sm"))
          concat(content_tag(:p, "Or press CMD/CTRL+K anytime to open search", class: "mt-1 text-xs text-gray-400"))
        end
      end
    end

    def render_footer_hint
      content_tag(:div, class: "flex items-center justify-between bg-gray-50 px-4 py-3 text-xs text-gray-500") do
        concat(content_tag(:div, class: "flex items-center gap-4") do
          concat(keyboard_hint("↑↓", "Navigate"))
          concat(keyboard_hint("Enter", "Select"))
          concat(keyboard_hint("Esc", "Close"))
        end)
        concat(content_tag(:div, "Press ⌘K to open anytime", class: "hidden sm:block"))
      end
    end

    def keyboard_hint(key, label)
      content_tag(:div, class: "flex items-center gap-1") do
        concat(content_tag(:kbd, key, class: "rounded border border-gray-300 bg-white px-1.5 py-0.5 font-mono text-xs font-semibold text-gray-700"))
        concat(content_tag(:span, label))
      end
    end
  end
end
