# frozen_string_literal: true

module Ui
  # Reusable card container with optional header, footer, and actions
  #
  # Provides a flexible container component for organizing content with consistent
  # styling. Cards support header sections with action buttons, main content area
  # with configurable padding, and footer sections for additional controls.
  #
  # **Features:**
  # - Customizable padding levels (none, sm, md, lg)
  # - Optional header and footer sections
  # - Action buttons in header
  # - Hover effects for interactive cards
  # - Consistent shadow and border styling
  # - Responsive design
  #
  # **Slots:**
  # - header: Optional header content (renders with gray background)
  # - footer: Optional footer content (renders with gray background)
  # - actions: Multiple action buttons rendered in header (requires header slot)
  #
  # @example Simple card
  #   <%= render Ui::CardComponent.new do %>
  #     <p>Card content here</p>
  #   <% end %>
  #
  # @example Card with header
  #   <%= render Ui::CardComponent.new do |card| %>
  #     <% card.with_header do %>
  #       <h3 class="text-lg font-semibold text-gray-900">Product Details</h3>
  #     <% end %>
  #
  #     <div class="space-y-4">
  #       <p><strong>SKU:</strong> ABC-123</p>
  #       <p><strong>Status:</strong> Active</p>
  #     </div>
  #   <% end %>
  #
  # @example Card with header and actions
  #   <%= render Ui::CardComponent.new do |card| %>
  #     <% card.with_header do %>
  #       <h3 class="text-lg font-semibold text-gray-900">Product Details</h3>
  #     <% end %>
  #
  #     <% card.with_action do %>
  #       <%= render Ui::ButtonComponent.new(variant: :secondary, size: :sm) { "Edit" } %>
  #     <% end %>
  #
  #     <% card.with_action do %>
  #       <%= render Ui::ButtonComponent.new(variant: :danger, size: :sm) { "Delete" } %>
  #     <% end %>
  #
  #     <div class="space-y-4">
  #       <p>Content here</p>
  #     </div>
  #   <% end %>
  #
  # @example Card with footer
  #   <%= render Ui::CardComponent.new do |card| %>
  #     <% card.with_header do %>
  #       <h3>Confirm Action</h3>
  #     <% end %>
  #
  #     <p>Are you sure you want to proceed?</p>
  #
  #     <% card.with_footer do %>
  #       <div class="flex justify-end gap-2">
  #         <%= render Ui::ButtonComponent.new(variant: :secondary) { "Cancel" } %>
  #         <%= render Ui::ButtonComponent.new(variant: :primary) { "Confirm" } %>
  #       </div>
  #     <% end %>
  #   <% end %>
  #
  # @example Hover effect card (for clickable cards)
  #   <%= render Ui::CardComponent.new(hover: true, padding: :lg) do %>
  #     <div class="text-center">
  #       <h4 class="text-2xl font-bold text-gray-900">1,234</h4>
  #       <p class="text-sm text-gray-600">Total Products</p>
  #     </div>
  #   <% end %>
  #
  # @example Card without padding (for custom layouts)
  #   <%= render Ui::CardComponent.new(padding: :none) do %>
  #     <div class="p-4 bg-blue-50">Custom header</div>
  #     <div class="p-6">Custom content</div>
  #   <% end %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  #
  class CardComponent < ViewComponent::Base
    renders_one :header
    renders_one :footer
    renders_many :actions

    attr_reader :padding, :hover, :border

    # Padding size options with Tailwind classes
    PADDING_CLASSES = {
      none: "",
      sm: "p-4",
      md: "p-6",
      lg: "p-8"
    }.freeze

    # Initialize a new card component
    #
    # @param padding [Symbol] Padding size for the card body (:none, :sm, :md, :lg)
    # @param hover [Boolean] Whether to show hover effect with shadow transition (for interactive cards)
    # @param border [Boolean] Whether to show border around the card
    # @param options [Hash] Additional HTML attributes (e.g., class, id, data)
    #
    # @example Basic initialization
    #   CardComponent.new(padding: :md, hover: false, border: true)
    #
    # @example Interactive card with hover effect
    #   CardComponent.new(hover: true, padding: :lg)
    #
    # @return [CardComponent]
    def initialize(padding: :md, hover: false, border: true, **options)
      @padding = padding
      @hover = hover
      @border = border
      @options = options
    end

    # Renders the card component
    #
    # @return [String] HTML div element with card structure
    def call
      content_tag(:div, class: card_classes, **@options) do
        concat(render_header) if header?
        concat(content_tag(:div, content, class: body_classes))
        concat(render_footer) if footer?
      end
    end

    private

    # Builds CSS classes for the card container
    #
    # @return [String] Combined CSS classes for card styling
    def card_classes
      classes = [ "bg-white rounded-lg shadow-sm" ]
      classes << "border border-gray-200" if @border
      classes << "hover:shadow-md transition-shadow duration-200" if @hover
      classes.join(" ")
    end

    # Returns CSS classes for card body based on padding setting
    #
    # @return [String] Padding CSS classes
    def body_classes
      PADDING_CLASSES[@padding]
    end

    # Renders the card header section
    #
    # Header has gray background and contains header content on the left
    # and action buttons on the right.
    #
    # @return [String] HTML div element with header content
    def render_header
      content_tag(:div, class: "px-6 py-4 border-b border-gray-200 bg-gray-50") do
        content_tag(:div, class: "flex items-center justify-between") do
          concat(header)
          concat(render_actions) if actions?
        end
      end
    end

    # Renders action buttons in the header
    #
    # Actions are displayed as a horizontal row with gap spacing.
    #
    # @return [String] HTML div element containing action buttons
    def render_actions
      content_tag(:div, class: "flex items-center gap-2") do
        actions.each { |action| concat(action) }
      end
    end

    # Renders the card footer section
    #
    # Footer has gray background with top border.
    #
    # @return [String] HTML div element with footer content
    def render_footer
      content_tag(:div, footer, class: "px-6 py-4 bg-gray-50 border-t border-gray-200 rounded-b-lg")
    end
  end
end
