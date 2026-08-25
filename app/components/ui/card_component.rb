# frozen_string_literal: true

module Ui
  class CardComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_many :actions

    attr_reader :padding, :hover, :border

    PADDING_CLASSES = {
      none: "",
      sm: "p-4",
      md: "p-6",
      lg: "p-8"
    }.freeze

    def initialize(padding: :md, hover: false, border: true, **options)
      @padding = padding
      @hover = hover
      @border = border
      @options = options
    end

    def call
      content_tag(:div, class: card_classes, **@options) do
        concat(render_header) if header?
        concat(content_tag(:div, content, class: body_classes))
        concat(render_footer) if footer?
      end
    end

    private

    def card_classes
      classes = [ "bg-white rounded-lg shadow-sm" ]
      classes << "border border-gray-200" if @border
      classes << "hover:shadow-md transition-shadow duration-200" if @hover
      classes.join(" ")
    end

    def body_classes
      PADDING_CLASSES[@padding]
    end

    def render_header
      content_tag(:div, class: "px-6 py-4 border-b border-gray-200 bg-gray-50") do
        content_tag(:div, class: "flex items-center justify-between") do
          concat(header)
          concat(render_actions) if actions?
        end
      end
    end

    def render_actions
      content_tag(:div, class: "flex items-center gap-2") do
        actions.each { |action| concat(action) }
      end
    end

    def render_footer
      content_tag(:div, footer, class: "px-6 py-4 bg-gray-50 border-t border-gray-200 rounded-b-lg")
    end
  end
end
