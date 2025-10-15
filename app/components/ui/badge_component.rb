# frozen_string_literal: true

module Ui
  # Reusable badge component for status indicators and labels
  #
  # Displays colored badges with consistent styling across variants.
  # Commonly used for product status, types, tags, and notification counts.
  #
  # @example Basic badge
  #   <%= render Ui::BadgeComponent.new do %>
  #     Active
  #   <% end %>
  #
  # @example Success badge
  #   <%= render Ui::BadgeComponent.new(variant: :success) do %>
  #     Published
  #   <% end %>
  #
  # @example Warning badge with dot indicator
  #   <%= render Ui::BadgeComponent.new(variant: :warning, dot: true) do %>
  #     Pending Review
  #   <% end %>
  #
  # @example Large primary badge
  #   <%= render Ui::BadgeComponent.new(variant: :primary, size: :lg) do %>
  #     Featured
  #   <% end %>
  #
  # @example Badge with custom attributes
  #   <%= render Ui::BadgeComponent.new(
  #     variant: :info,
  #     title: "Product is active",
  #     data: { testid: "status-badge" }
  #   ) do %>
  #     Active
  #   <% end %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  #
  class BadgeComponent < ViewComponent::Base
    # Badge color variants with Tailwind classes
    VARIANTS = {
      success: "bg-green-100 text-green-800 border-green-200",
      info: "bg-blue-100 text-blue-800 border-blue-200",
      warning: "bg-yellow-100 text-yellow-800 border-yellow-200",
      danger: "bg-red-100 text-red-800 border-red-200",
      gray: "bg-gray-100 text-gray-800 border-gray-200",
      primary: "bg-blue-600 text-white border-blue-600"
    }.freeze

    # Badge size variants
    SIZES = {
      sm: "px-2 py-0.5 text-xs",
      md: "px-2.5 py-1 text-sm",
      lg: "px-3 py-1.5 text-base"
    }.freeze

    # Base classes applied to all badges
    BASE_CLASSES = "inline-flex items-center font-medium rounded-full border"

    attr_reader :variant, :size, :dot

    # Initialize a new badge component
    #
    # @param variant [Symbol] Badge color variant (:success, :info, :warning, :danger, :gray, :primary)
    # @param size [Symbol] Badge size (:sm, :md, :lg)
    # @param dot [Boolean] Whether to show a colored dot indicator before the text
    # @param options [Hash] Additional HTML attributes (e.g., class, id, data, aria, title)
    #
    # @example
    #   BadgeComponent.new(variant: :success, size: :sm, dot: true)
    #
    # @return [BadgeComponent]
    def initialize(variant: :gray, size: :sm, dot: false, **options)
      @variant = variant
      @size = size
      @dot = dot
      @options = options
    end

    # Renders the badge component
    #
    # @return [String] HTML span element with badge styling
    def call
      content_tag(:span, class: badge_classes, **@options) do
        concat(render_dot) if @dot
        concat(content)
      end
    end

    private

    # Builds CSS classes for the badge
    #
    # @return [String] Combined CSS classes
    def badge_classes
      [BASE_CLASSES, VARIANTS[@variant], SIZES[@size]].join(" ")
    end

    # Renders a colored dot indicator
    #
    # Used to provide visual emphasis for badge status.
    #
    # @return [String] HTML span element with dot styling
    def render_dot
      content_tag(:span, nil, class: "inline-block h-1.5 w-1.5 rounded-full bg-current mr-1.5")
    end
  end
end
