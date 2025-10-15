# frozen_string_literal: true

module Ui
  # Reusable button component with consistent styling across all variants
  #
  # Provides a unified button interface with support for different visual styles,
  # sizes, loading states, and accessibility features. All buttons follow WCAG 2.1 AA
  # guidelines with proper focus indicators and keyboard navigation.
  #
  # **Accessibility Features:**
  # - Focus ring with keyboard navigation support
  # - Disabled state with cursor and opacity changes
  # - Loading state automatically disables button interaction
  # - Requires aria-label for icon-only buttons
  # - Proper HTML button semantics
  #
  # **Variants:**
  # - primary: Primary action (blue background)
  # - secondary: Secondary action (white background, gray border)
  # - danger: Destructive action (red background)
  # - ghost: Subtle action (transparent background)
  # - link: Link-style button (no background, underline on hover)
  #
  # @example Primary button
  #   <%= render Ui::ButtonComponent.new do %>
  #     Save Product
  #   <% end %>
  #
  # @example Secondary button
  #   <%= render Ui::ButtonComponent.new(variant: :secondary) do %>
  #     Cancel
  #   <% end %>
  #
  # @example Danger button (small)
  #   <%= render Ui::ButtonComponent.new(variant: :danger, size: :sm) do %>
  #     Delete
  #   <% end %>
  #
  # @example Loading state with spinner
  #   <%= render Ui::ButtonComponent.new(loading: true) do %>
  #     Submitting...
  #   <% end %>
  #
  # @example Icon-only button (requires aria-label for accessibility)
  #   <%= render Ui::ButtonComponent.new(aria_label: "Close dialog") do %>
  #     <svg>...</svg>
  #   <% end %>
  #
  # @example Button with left icon
  #   <%= render Ui::ButtonComponent.new(
  #     icon: '<svg>...</svg>',
  #     icon_position: :left
  #   ) do %>
  #     Add Product
  #   <% end %>
  #
  # @example Submit button with Turbo data attributes
  #   <%= render Ui::ButtonComponent.new(
  #     type: "submit",
  #     variant: :primary,
  #     data: { turbo_frame: "products_form" }
  #   ) do %>
  #     Save Changes
  #   <% end %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  #
  class ButtonComponent < ViewComponent::Base
    # Button variants with Tailwind classes
    VARIANTS = {
      primary: "bg-blue-600 hover:bg-blue-700 focus:ring-blue-500 text-white",
      secondary: "bg-white hover:bg-gray-50 focus:ring-blue-500 text-gray-700 border border-gray-300",
      danger: "bg-red-600 hover:bg-red-700 focus:ring-red-500 text-white",
      ghost: "bg-transparent hover:bg-gray-100 focus:ring-gray-300 text-gray-700",
      link: "bg-transparent hover:underline text-blue-600 focus:ring-0"
    }.freeze

    # Button sizes
    SIZES = {
      sm: "px-3 py-1.5 text-sm",
      md: "px-4 py-2 text-sm",
      lg: "px-6 py-3 text-base"
    }.freeze

    # Base classes applied to all buttons
    BASE_CLASSES = "inline-flex items-center justify-center font-medium rounded-lg transition-colors duration-150 focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"

    attr_reader :variant, :size, :disabled, :type, :loading, :icon, :icon_position, :aria_label, :href

    # Initialize a new button component
    #
    # @param variant [Symbol] Button style variant (:primary, :secondary, :danger, :ghost, :link)
    # @param size [Symbol] Button size (:sm, :md, :lg)
    # @param disabled [Boolean] Whether the button is disabled (prevents interaction)
    # @param type [String] HTML button type attribute ("button", "submit", or "reset")
    # @param loading [Boolean] Whether the button is in loading state (shows spinner, disables button)
    # @param icon [String] SVG icon markup to display alongside text (optional)
    # @param icon_position [Symbol] Position of icon (:left or :right, defaults to :left)
    # @param aria_label [String] Aria label for accessibility (required for icon-only buttons without text)
    # @param href [String] URL for link buttons (renders <a> instead of <button>)
    # @param options [Hash] Additional HTML attributes (e.g., class, id, data, title)
    #
    # @example Basic initialization
    #   ButtonComponent.new(variant: :primary, size: :md)
    #
    # @example With data attributes for Stimulus
    #   ButtonComponent.new(
    #     variant: :secondary,
    #     data: { action: "click->modal#close" }
    #   )
    #
    # @example As a link
    #   ButtonComponent.new(
    #     variant: :secondary,
    #     href: "/products/123/edit"
    #   )
    #
    # @return [ButtonComponent]
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

    # Renders the button component
    #
    # @return [String] HTML button or link element with all styling and content
    def call
      if @href.present?
        link_to(@href, **html_options) { button_content }
      else
        content_tag(:button, button_content, **html_options)
      end
    end

    private

    # Constructs the button's inner content structure
    #
    # Handles icon positioning, loading spinner, and text content.
    #
    # @return [String] HTML content for button interior
    def button_content
      # If we have component-managed icons/loading, wrap in flex container
      if @loading || @icon.present?
        content_tag(:span, class: "flex items-center gap-2") do
          concat(loading_spinner) if @loading
          concat(icon_element) if @icon && @icon_position == :left && !@loading
          concat(content)
          concat(icon_element) if @icon && @icon_position == :right && !@loading
        end
      else
        # No wrapper needed if content manages its own layout
        content
      end
    end

    # Renders an animated loading spinner
    #
    # Displayed when loading state is active. Uses SVG animation for smooth rotation.
    #
    # @return [String] HTML SVG element with spinner graphic
    def loading_spinner
      content_tag(:svg, class: "animate-spin -ml-1 h-4 w-4", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24") do
        concat(content_tag(:circle, nil, class: "opacity-25", cx: "12", cy: "12", r: "10", stroke: "currentColor", "stroke-width": "4"))
        concat(content_tag(:path, nil, class: "opacity-75", fill: "currentColor", d: "M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"))
      end
    end

    # Renders the icon element if provided
    #
    # @return [String, nil] HTML span with icon or nil if no icon
    def icon_element
      return nil unless @icon

      content_tag(:span, class: "h-4 w-4") do
        raw(@icon) if @icon.is_a?(String) && @icon.include?("svg")
      end
    end

    # Builds HTML attributes hash for the button element
    #
    # Merges button-specific attributes with custom options.
    # Handles links and buttons differently.
    #
    # @return [Hash] HTML attributes including type, disabled, class, aria
    def html_options
      options = {
        class: button_classes,
        **@options
      }

      # Build aria attributes hash
      aria_attrs = {}

      if @href.present?
        # For links, add pointer-events-none and opacity if disabled
        options[:class] += " pointer-events-none" if @disabled
        aria_attrs[:disabled] = "true" if @disabled
      else
        # For buttons, use standard type and disabled attributes
        options[:type] = @type
        options[:disabled] = @disabled
      end

      aria_attrs[:label] = @aria_label if @aria_label.present?
      options[:aria] = aria_attrs unless aria_attrs.empty?

      options
    end

    # Builds CSS classes for the button
    #
    # @return [String] Combined CSS classes for variant, size, and base styles
    def button_classes
      [BASE_CLASSES, VARIANTS[@variant], SIZES[@size]].join(" ")
    end
  end
end
