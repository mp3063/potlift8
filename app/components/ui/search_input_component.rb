# frozen_string_literal: true

module Ui
  # Reusable search input with icon and consistent styling
  #
  # @example Basic search
  #   <%= render Ui::SearchInputComponent.new(
  #     name: :q,
  #     placeholder: "Search products..."
  #   ) %>
  #
  # @example With form builder
  #   <%= form_with url: products_path, method: :get do |f| %>
  #     <%= render Ui::SearchInputComponent.new(
  #       name: :q,
  #       value: params[:q],
  #       placeholder: "Search products by name or SKU..."
  #     ) %>
  #   <% end %>
  #
  class SearchInputComponent < ViewComponent::Base
    attr_reader :name, :value, :placeholder, :label

    def initialize(name:, placeholder:, value: nil, label: nil, **options)
      @name = name
      @value = value
      @placeholder = placeholder
      @label = label || placeholder
      @options = options
    end

    def call
      content_tag(:div, class: "flex-1") do
        concat(render_label)
        concat(render_input_wrapper)
      end
    end

    private

    def render_label
      content_tag(:label, @label, for: input_id, class: "sr-only")
    end

    def render_input_wrapper
      content_tag(:div, class: "relative") do
        concat(render_search_icon)
        concat(render_input)
      end
    end

    def render_search_icon
      content_tag(:div, class: "pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3") do
        raw(<<~SVG)
          <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clip-rule="evenodd" />
          </svg>
        SVG
      end
    end

    def render_input
      text_field_tag @name, @value,
        placeholder: @placeholder,
        id: input_id,
        class: "block w-full rounded-md border-0 py-1.5 pl-10 text-gray-900 ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-blue-600 sm:text-sm sm:leading-6",
        aria: { label: @label },
        **@options
    end

    def input_id
      "search_#{@name}"
    end
  end
end
