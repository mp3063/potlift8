# frozen_string_literal: true

module Shared
  class BreadcrumbComponent < ViewComponent::Base
    attr_reader :items

    def initialize(items: [])
      @items = items
    end

    def render?
      @items.any?
    end

    def call
      content_tag(:nav, class: "flex mb-6", aria: { label: "Breadcrumb" }) do
        content_tag(:ol, class: "inline-flex items-center space-x-1 md:space-x-3") do
          @items.each_with_index do |item, index|
            concat(render_item(item, index))
          end
        end
      end
    end

    private

    def render_item(item, index)
      is_last = index == @items.length - 1

      content_tag(:li, class: "inline-flex items-center") do
        if is_last
          concat(render_current_item(item))
        else
          concat(render_link_item(item, index))
          concat(render_separator) unless is_last
        end
      end
    end

    def render_link_item(item, index)
      link_to item[:url], class: breadcrumb_link_classes do
        concat(render_home_icon) if index == 0 && item[:icon] == :home
        concat(content_tag(:span, item[:label]))
      end
    end

    def render_current_item(item)
      content_tag(:span, class: "text-sm font-medium text-gray-700", aria: { current: "page" }) do
        item[:label]
      end
    end

    def render_separator
      content_tag(:svg, class: "w-6 h-6 text-gray-400", fill: "currentColor", viewBox: "0 0 20 20") do
        raw('<path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd"></path>')
      end
    end

    def render_home_icon
      raw(<<~SVG)
        <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path d="M10.707 2.293a1 1 0 00-1.414 0l-7 7a1 1 0 001.414 1.414L4 10.414V17a1 1 0 001 1h2a1 1 0 001-1v-2a1 1 0 011-1h2a1 1 0 011 1v2a1 1 0 001 1h2a1 1 0 001-1v-6.586l.293.293a1 1 0 001.414-1.414l-7-7z"></path>
        </svg>
      SVG
    end

    def breadcrumb_link_classes
      "inline-flex items-center text-sm font-medium text-gray-600 hover:text-blue-600 transition-colors"
    end
  end
end
