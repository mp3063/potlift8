# frozen_string_literal: true

module Shared
  class PaginationComponent < ViewComponent::Base
    attr_reader :pagy, :variant

    def initialize(pagy:, variant: :default)
      @pagy = pagy
      @variant = variant
    end

    def render?
      @pagy.pages > 1
    end

    def call
      content_tag(:div, class: container_classes, aria: { label: "Pagination" }) do
        concat(render_mobile_pagination)
        concat(render_desktop_pagination)
      end
    end

    private

    # Container classes based on variant
    def container_classes
      if @variant == :table
        "flex items-center justify-between border-t border-gray-200 bg-gray-50 px-6 py-3"
      else
        "flex items-center justify-between border-t border-gray-200 px-4 sm:px-0 mt-8"
      end
    end

    def render_mobile_pagination
      content_tag(:div, class: "flex flex-1 justify-between sm:hidden") do
        concat(prev_button_mobile)
        concat(next_button_mobile)
      end
    end

    def prev_button_mobile
      if @pagy.prev
        link_to "Previous", pagy_url_for(@pagy, @pagy.prev),
          class: "relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
      else
        content_tag(:span, "Previous",
          class: "relative inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-500 cursor-not-allowed")
      end
    end

    def next_button_mobile
      if @pagy.next
        link_to "Next", pagy_url_for(@pagy, @pagy.next),
          class: "relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"
      else
        content_tag(:span, "Next",
          class: "relative ml-3 inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-500 cursor-not-allowed")
      end
    end

    def render_desktop_pagination
      content_tag(:div, class: "hidden sm:flex sm:flex-1 sm:items-center sm:justify-between") do
        concat(render_info)
        concat(render_page_numbers)
      end
    end

    def render_info
      content_tag(:div) do
        content_tag(:p, class: "text-sm text-gray-700") do
          "Showing #{content_tag(:span, @pagy.from, class: 'font-medium')} to #{content_tag(:span, @pagy.to, class: 'font-medium')} of #{content_tag(:span, @pagy.count, class: 'font-medium')} results".html_safe
        end
      end
    end

    def render_page_numbers
      content_tag(:div) do
        content_tag(:nav, class: "isolate inline-flex -space-x-px rounded-md shadow-sm", aria: { label: "Pagination" }) do
          concat(prev_button_desktop)
          @pagy.series.each do |item|
            concat(page_item(item))
          end
          concat(next_button_desktop)
        end
      end
    end

    def prev_button_desktop
      if @pagy.prev
        link_to pagy_url_for(@pagy, @pagy.prev),
          class: "relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-600 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20",
          aria: { label: "Previous page" } do
          raw('<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>')
        end
      else
        content_tag(:span,
          class: "relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-500 ring-1 ring-inset ring-gray-300 cursor-not-allowed",
          aria: { label: "Previous page" }) do
          raw('<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" /></svg>')
        end
      end
    end

    def next_button_desktop
      if @pagy.next
        link_to pagy_url_for(@pagy, @pagy.next),
          class: "relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-600 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20",
          aria: { label: "Next page" } do
          raw('<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" /></svg>')
        end
      else
        content_tag(:span,
          class: "relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-500 ring-1 ring-inset ring-gray-300 cursor-not-allowed",
          aria: { label: "Next page" }) do
          raw('<svg class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" /></svg>')
        end
      end
    end

    def page_item(item)
      case item
      when Integer
        if item == @pagy.page
          content_tag(:span, item,
            class: "relative z-10 inline-flex items-center bg-blue-600 px-4 py-2 text-sm font-semibold text-white focus:z-20",
            aria: { current: "page" })
        else
          link_to item, pagy_url_for(@pagy, item),
            class: "relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-20"
        end
      when :gap
        content_tag(:span, "…",
          class: "relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-700 ring-1 ring-inset ring-gray-300")
      end
    end

    def pagy_url_for(pagy, page)
      return '#' if page.nil?

      # Get current request parameters and preserve them all
      current_params = helpers.request.query_parameters.dup

      # Update the page parameter
      current_params['page'] = page.to_s

      # Build URL with preserved params
      path = helpers.request.path
      query_string = current_params.to_query

      query_string.present? ? "#{path}?#{query_string}" : path
    rescue StandardError => e
      # Fallback to simple page param if something goes wrong
      Rails.logger.warn("Pagination URL generation failed: #{e.message}")
      "?page=#{page}"
    end
  end
end
