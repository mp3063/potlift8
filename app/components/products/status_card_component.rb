# frozen_string_literal: true

module Products
  # Product status card component for sidebar
  #
  # Displays active status with icon, product type, and last updated timestamp.
  # Includes toggle button for activating/deactivating product with appropriate
  # color styling (green for activate, gray for deactivate).
  #
  # @example Render status card
  #   <%= render Products::StatusCardComponent.new(product: @product) %>
  #
  class StatusCardComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new status card component
    #
    # @param product [Product] Product instance
    # @return [StatusCardComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns icon name for status display
    #
    # @return [String] Icon identifier (check-circle or x-circle)
    def status_icon
      product.active? ? "check-circle" : "x-circle"
    end

    # Returns color class for status icon
    #
    # @return [String] Tailwind color class
    def status_color
      product.active? ? "text-green-500" : "text-gray-400"
    end

    # Returns status text label
    #
    # @return [String] Status label
    def status_text
      product.active? ? "Active" : "Inactive"
    end

    # Returns status text color class
    #
    # @return [String] Tailwind text color class
    def status_text_color
      product.active? ? "text-green-700" : "text-gray-700"
    end

    # Returns toggle button text
    #
    # @return [String] Button label
    def toggle_button_text
      product.active? ? "Deactivate" : "Activate"
    end

    # Returns toggle button color classes
    #
    # @return [String] Tailwind button color classes
    def toggle_button_classes
      if product.active?
        "w-full rounded-md bg-gray-600 hover:bg-gray-500 focus:ring-gray-500 px-3 py-2 text-sm font-semibold text-white shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"
      else
        "w-full rounded-md bg-green-600 hover:bg-green-500 focus:ring-green-500 px-3 py-2 text-sm font-semibold text-white shadow-sm focus:outline-none focus:ring-2 focus:ring-offset-2"
      end
    end

    # Returns formatted product type
    #
    # @return [String] Product type label
    def product_type_label
      product.product_type.humanize
    end
  end
end
