# frozen_string_literal: true

module Ui
  # Reusable modal dialog with Stimulus controller for interactions
  #
  # Provides an accessible modal dialog overlay with support for headers, footers,
  # and custom content. Modals are controlled via Stimulus for smooth open/close
  # animations and proper focus management.
  #
  # **Features:**
  # - Accessible with ARIA attributes (role, labelledby, modal)
  # - Keyboard navigation support (ESC to close when closable)
  # - Backdrop click to close (when closable)
  # - Focus trapping within modal
  # - Smooth fade animations
  # - Multiple size options
  # - Optional close button
  #
  # **Accessibility:**
  # - Proper ARIA role and attributes
  # - Focus management (returns to trigger on close)
  # - Keyboard ESC support
  # - Screen reader announcements
  # - Close button with aria-label
  #
  # **Stimulus Integration:**
  # - Controller: modal
  # - Targets: backdrop, container
  # - Actions: open, close, preventClose
  # - Values: closable
  #
  # **Slots:**
  # - trigger: Button or element that opens the modal
  # - header: Modal title/heading
  # - footer: Footer content (typically action buttons)
  #
  # @example Modal with trigger button
  #   <%= render Ui::ModalComponent.new(size: :lg) do |modal| %>
  #     <% modal.with_trigger do %>
  #       <%= render Ui::ButtonComponent.new { "Open Modal" } %>
  #     <% end %>
  #
  #     <% modal.with_header do %>
  #       Confirm Deletion
  #     <% end %>
  #
  #     <p class="text-gray-600">
  #       Are you sure you want to delete this product? This action cannot be undone.
  #     </p>
  #
  #     <% modal.with_footer do %>
  #       <%= render Ui::ButtonComponent.new(variant: :secondary, data: { action: "click->modal#close" }) { "Cancel" } %>
  #       <%= render Ui::ButtonComponent.new(variant: :danger) { "Delete Product" } %>
  #     <% end %>
  #   <% end %>
  #
  # @example Form modal (extra large)
  #   <%= render Ui::ModalComponent.new(size: :xl) do |modal| %>
  #     <% modal.with_trigger do %>
  #       <%= render Ui::ButtonComponent.new { "Create New Product" } %>
  #     <% end %>
  #
  #     <% modal.with_header do %>
  #       Create New Product
  #     <% end %>
  #
  #     <%= form_with model: @product, data: { turbo: false } do |f| %>
  #       <div class="space-y-4">
  #         <%= f.text_field :sku, class: "..." %>
  #         <%= f.text_field :name, class: "..." %>
  #       </div>
  #     <% end %>
  #
  #     <% modal.with_footer do %>
  #       <%= render Ui::ButtonComponent.new(variant: :secondary, data: { action: "click->modal#close" }) { "Cancel" } %>
  #       <%= render Ui::ButtonComponent.new(type: "submit") { "Create Product" } %>
  #     <% end %>
  #   <% end %>
  #
  # @example Non-closable modal (requires explicit action)
  #   <%= render Ui::ModalComponent.new(closable: false) do |modal| %>
  #     <% modal.with_trigger do %>
  #       <%= render Ui::ButtonComponent.new { "Agree to Terms" } %>
  #     <% end %>
  #
  #     <% modal.with_header do %>
  #       Terms and Conditions
  #     <% end %>
  #
  #     <p>You must agree to continue...</p>
  #
  #     <% modal.with_footer do %>
  #       <%= render Ui::ButtonComponent.new { "I Agree" } %>
  #     <% end %>
  #   <% end %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  # @see app/javascript/controllers/modal_controller.js Stimulus Controller
  #
  class ModalComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_one :trigger

    attr_reader :size, :closable, :modal_id

    # Modal size options with Tailwind max-width classes
    SIZE_CLASSES = {
      sm: "max-w-md",
      md: "max-w-lg",
      lg: "max-w-2xl",
      xl: "max-w-4xl",
      full: "max-w-full mx-4"
    }.freeze

    # Initialize a new modal component
    #
    # @param size [Symbol] Modal width size (:sm, :md, :lg, :xl, :full)
    # @param closable [Boolean] Whether the modal can be closed via close button, ESC key, or backdrop click
    # @param modal_id [String] Unique ID for the modal (auto-generated if not provided for ARIA labelledby)
    # @param options [Hash] Additional HTML attributes for the container
    #
    # @note When closable is false, the modal can only be closed programmatically or via an action in the modal content.
    #       This is useful for critical confirmations or required user actions.
    #
    # @example Basic initialization
    #   ModalComponent.new(size: :md, closable: true)
    #
    # @example Required confirmation modal
    #   ModalComponent.new(size: :sm, closable: false, modal_id: "terms_modal")
    #
    # @return [ModalComponent]
    def initialize(size: :md, closable: true, modal_id: nil, **options)
      @size = size
      @closable = closable
      @modal_id = modal_id || "modal_#{SecureRandom.hex(4)}"
      @options = options
    end

    # Renders the modal component
    #
    # @return [String] HTML structure with Stimulus controllers and ARIA attributes
    def call
      content_tag(:div, **stimulus_attributes) do
        concat(render_trigger) if trigger?
        concat(render_modal_backdrop)
      end
    end

    private

    # Builds Stimulus data attributes for modal controller
    #
    # @return [Hash] Data attributes for Stimulus controller binding
    def stimulus_attributes
      {
        data: {
          controller: "modal",
          modal_closable_value: @closable
        }
      }
    end

    # Renders the modal trigger element
    #
    # Wraps the trigger content with click handler to open modal.
    #
    # @return [String] HTML div with modal open action
    def render_trigger
      content_tag(:div, trigger, data: { action: "click->modal#open" })
    end

    # Renders the modal backdrop and container
    #
    # Creates the full-screen overlay with modal content.
    #
    # @return [String] HTML structure for modal backdrop
    def render_modal_backdrop
      content_tag(:div,
        class: "fixed inset-0 z-50 overflow-y-auto hidden transition-opacity duration-300 starting:opacity-0",
        data: { modal_target: "backdrop" },
        aria: { labelledby: "#{@modal_id}-title", role: "dialog", modal: "true" }
      ) do
        concat(render_overlay)
        concat(render_modal_container)
      end
    end

    # Renders the semi-transparent backdrop overlay
    #
    # Clicking the overlay closes the modal if closable is true.
    #
    # @return [String] HTML div for backdrop overlay
    def render_overlay
      content_tag(:div, nil,
        class: "fixed inset-0 bg-gray-900 opacity-50 transition-opacity",
        data: { action: "click->modal#close" }
      )
    end

    # Renders the modal content container
    #
    # Contains the actual modal box with header, content, and footer.
    # preventClose action prevents clicks inside modal from closing it.
    #
    # @return [String] HTML structure for modal container
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

    # Renders the close button (X) in top-right corner
    #
    # Only rendered when modal is closable.
    #
    # @return [String] HTML button with close icon
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

    # Renders the modal header section
    #
    # Header content is wrapped in an H3 with the modal ID for ARIA labelledby.
    #
    # @return [String] HTML div with header content
    def render_header
      content_tag(:div, class: "px-6 py-4 border-b border-gray-200") do
        content_tag(:h3, header, class: "text-lg font-semibold text-gray-900", id: "#{@modal_id}-title")
      end
    end

    # Renders the modal footer section
    #
    # Footer typically contains action buttons aligned to the right.
    #
    # @return [String] HTML div with footer content
    def render_footer
      content_tag(:div, footer, class: "px-6 py-4 bg-gray-50 border-t border-gray-200 flex justify-end gap-2")
    end

    # Builds CSS classes for the modal container
    #
    # @return [String] Combined CSS classes for modal sizing and styling
    def modal_classes
      [
        "relative bg-white rounded-lg shadow-xl transform transition-all w-full",
        "starting:opacity-0 starting:scale-95",
        SIZE_CLASSES[@size]
      ].join(" ")
    end
  end
end
