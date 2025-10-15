# frozen_string_literal: true

module Shared
  class EmptyStateComponent < ViewComponent::Base
    attr_reader :title, :description, :icon

    def initialize(title:, description: nil, icon: :inbox, **options)
      @title = title
      @description = description
      @icon = icon
      @options = options
    end

    def call
      content_tag(:div, class: "text-center py-12", **@options) do
        concat(render_icon)
        concat(content_tag(:h3, @title, class: "mt-4 text-lg font-semibold text-gray-900"))
        concat(content_tag(:p, @description, class: "mt-2 text-sm text-gray-600")) if @description
        concat(content_tag(:div, content, class: "mt-6")) if content.present?
      end
    end

    private

    def render_icon
      icon_svg = case @icon
      when :inbox
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>'
      when :package
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>'
      when :search
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>'
      else
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"/>'
      end

      content_tag(:div, class: "mx-auto h-16 w-16 text-gray-400") do
        raw(<<~SVG)
          <svg class="h-full w-full" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            #{icon_svg}
          </svg>
        SVG
      end
    end
  end
end
