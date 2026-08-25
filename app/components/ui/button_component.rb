# frozen_string_literal: true

module Ui
  class ButtonComponent < ViewComponent::Base
    VARIANTS = {
      primary: "bg-blue-600 hover:bg-blue-700 focus:ring-blue-500 text-white",
      secondary: "bg-white hover:bg-gray-50 focus:ring-blue-500 text-gray-700 border border-gray-300",
      danger: "bg-red-600 hover:bg-red-700 focus:ring-red-500 text-white",
      ghost: "bg-transparent hover:bg-gray-100 focus:ring-gray-300 text-gray-700",
      link: "bg-transparent hover:underline text-blue-600 focus:ring-0"
    }.freeze

    SIZES = {
      sm: "px-3 py-1.5 text-sm",
      md: "px-4 py-2 text-sm",
      lg: "px-6 py-3 text-base"
    }.freeze

    BASE_CLASSES = "inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-150 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"

    attr_reader :variant, :size, :disabled, :type, :loading, :icon, :icon_position, :aria_label, :href

    def initialize(
      variant: :primary,
      size: :md,
      disabled: false,
      type: "button",
      loading: false,
      icon: nil,
      icon_position: :left,
      aria_label: nil,
      href: nil,
      **options
    )
      @variant = variant
      @size = size
      @disabled = disabled || loading
      @type = type
      @loading = loading
      @icon = icon
      @icon_position = icon_position
      @aria_label = aria_label
      @href = href
      @options = options
    end

    def call
      if @href.present?
        link_to(@href, **html_options) { button_content }
      else
        content_tag(:button, button_content, **html_options)
      end
    end

    private

    def button_content
      if @loading || @icon.present?
        content_tag(:span, class: "flex items-center gap-2") do
          concat(loading_spinner) if @loading
          concat(icon_element) if @icon && @icon_position == :left && !@loading
          concat(content)
          concat(icon_element) if @icon && @icon_position == :right && !@loading
        end
      else
        content
      end
    end

    def loading_spinner
      content_tag(:svg, class: "animate-spin -ml-1 h-4 w-4", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24") do
        concat(content_tag(:circle, nil, class: "opacity-25", cx: "12", cy: "12", r: "10", stroke: "currentColor", "stroke-width": "4"))
        concat(content_tag(:path, nil, class: "opacity-75", fill: "currentColor", d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"))
      end
    end

    def icon_element
      return nil unless @icon

      content_tag(:span, class: "h-4 w-4") do
        raw(@icon) if @icon.is_a?(String) && @icon.include?("svg")
      end
    end

    def html_options
      options = {
        class: button_classes,
        **@options
      }

      aria_attrs = {}

      if @href.present?
        options[:class] += " pointer-events-none" if @disabled
        aria_attrs[:disabled] = "true" if @disabled
      else
        options[:type] = @type
        options[:disabled] = @disabled
      end

      aria_attrs[:label] = @aria_label if @aria_label.present?
      options[:aria] = aria_attrs unless aria_attrs.empty?

      options
    end

    def button_classes
      [ BASE_CLASSES, VARIANTS[@variant], SIZES[@size] ].join(" ")
    end
  end
end
