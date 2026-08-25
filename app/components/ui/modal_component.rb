# frozen_string_literal: true

module Ui
  # **Stimulus Integration:**
  # - Controller: modal
  # - Targets: backdrop, container
  # - Actions: open, close, preventClose
  # - Values: closable
  class ModalComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_one :trigger

    attr_reader :size, :closable, :modal_id

    SIZE_CLASSES = {
      sm: "max-w-md",
      md: "max-w-lg",
      lg: "max-w-2xl",
      xl: "max-w-4xl",
      full: "max-w-full mx-4"
    }.freeze

    def initialize(size: :md, closable: true, modal_id: nil, **options)
      @size = size
      @closable = closable
      @modal_id = modal_id || "modal_#{SecureRandom.hex(4)}"
      @options = options
    end

    def call
      content_tag(:div, **stimulus_attributes) do
        concat(render_trigger) if trigger?
        concat(render_modal_backdrop)
      end
    end

    private

    def stimulus_attributes
      {
        data: {
          controller: "modal",
          modal_closable_value: @closable
        }
      }
    end

    def render_trigger
      content_tag(:div, trigger, data: { action: "click->modal#open" })
    end

    def render_modal_backdrop
      content_tag(:div,
        class: "fixed inset-0 z-50 overflow-y-auto hidden transition-opacity duration-300 starting:opacity-0",
        data: { modal_target: "backdrop" },
        role: "dialog",
        aria: { labelledby: "#{@modal_id}-title", modal: "true" }
      ) do
        concat(render_overlay)
        concat(render_modal_container)
      end
    end

    def render_overlay
      content_tag(:div, nil,
        class: "fixed inset-0 bg-gray-900 opacity-50 transition-opacity",
        data: { action: "click->modal#close" }
      )
    end

    # Contains the actual modal box with header, content, and footer.
    # preventClose action prevents clicks inside modal from closing it.
    def render_modal_container
      content_tag(:div, class: "relative z-10 flex min-h-full items-center justify-center p-4") do
        content_tag(:div, class: modal_classes, data: { modal_target: "container", action: "click->modal#preventClose" }) do
          concat(render_close_button) if @closable
          concat(render_header) if header?
          concat(content_tag(:div, content, class: "px-6 py-4"))
          concat(render_footer) if footer?
        end
      end
    end

    def render_close_button
      content_tag(:button,
        type: "button",
        class: "absolute top-4 right-4 text-gray-600 hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-blue-500 rounded-lg p-1",
        data: { action: "click->modal#close" },
        aria: { label: "Close" }
      ) do
        raw('<svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>')
      end
    end

    def render_header
      content_tag(:div, class: "px-6 py-4 border-b border-gray-200") do
        content_tag(:h3, header, class: "text-lg font-semibold text-gray-900", id: "#{@modal_id}-title")
      end
    end

    def render_footer
      content_tag(:div, footer, class: "px-6 py-4 bg-gray-50 border-t border-gray-200 flex justify-end gap-2")
    end

    def modal_classes
      [
        "relative bg-white rounded-lg shadow-xl transform transition-all w-full",
        "starting:opacity-0 starting:scale-95",
        SIZE_CLASSES[@size]
      ].join(" ")
    end
  end
end
