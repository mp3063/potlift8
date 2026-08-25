# frozen_string_literal: true

module Shared
  class FormErrorsComponent < ViewComponent::Base
    attr_reader :errors

    def initialize(errors:)
      @errors = errors
    end

    def render?
      @errors.any?
    end

    def call
      content_tag(:div, class: "rounded-lg bg-red-50 border border-red-200 p-4", role: "alert") do
        content_tag(:div, class: "flex") do
          concat(render_icon)
          concat(render_content)
        end
      end
    end

    private

    def render_icon
      content_tag(:div, class: "flex-shrink-0") do
        raw(<<~SVG)
          <svg class="h-5 w-5 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
        SVG
      end
    end

    def render_content
      content_tag(:div, class: "ml-3 flex-1") do
        concat(render_heading)
        concat(render_error_list)
      end
    end

    def render_heading
      error_count = @errors.count
      error_word = error_count == 1 ? "error" : "errors"
      is_are = error_count == 1 ? "is" : "are"

      content_tag(
        :h3,
        "There #{is_are} #{error_count} #{error_word} with your submission",
        class: "text-sm font-medium text-red-800"
      )
    end

    def render_error_list
      content_tag(:ul, class: "mt-2 text-sm text-red-700 list-disc list-inside space-y-1") do
        @errors.full_messages.each do |message|
          concat(content_tag(:li, message))
        end
      end
    end
  end
end
