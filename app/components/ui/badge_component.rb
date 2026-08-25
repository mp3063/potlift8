# frozen_string_literal: true

module Ui
  class BadgeComponent < ViewComponent::Base
    VARIANTS = {
      success: "bg-green-100 text-green-800 border-green-200",
      info: "bg-blue-100 text-blue-800 border-blue-200",
      warning: "bg-yellow-100 text-yellow-800 border-yellow-200",
      danger: "bg-red-100 text-red-800 border-red-200",
      gray: "bg-gray-100 text-gray-800 border-gray-200",
      primary: "bg-blue-600 text-white border-blue-600"
    }.freeze

    SIZES = {
      sm: "px-2 py-0.5 text-xs",
      md: "px-2.5 py-1 text-sm",
      lg: "px-3 py-1.5 text-base"
    }.freeze

    BASE_CLASSES = "inline-flex items-center font-medium rounded-full border"

    attr_reader :variant, :size, :dot

    def initialize(variant: :gray, size: :sm, dot: false, **options)
      @variant = variant
      @size = size
      @dot = dot
      @options = options
    end

    def call
      content_tag(:span, class: badge_classes, **@options) do
        concat(render_dot) if @dot
        concat(content)
      end
    end

    private

    def badge_classes
      custom_class = @options.delete(:class)
      classes = [ BASE_CLASSES, VARIANTS[@variant], SIZES[@size] ]
      classes << custom_class if custom_class.present?
      classes.join(" ")
    end

    def render_dot
      content_tag(:span, nil, class: "inline-block h-1.5 w-1.5 rounded-full bg-current mr-1.5")
    end
  end
end
