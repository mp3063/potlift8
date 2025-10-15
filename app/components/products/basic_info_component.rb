# frozen_string_literal: true

module Products
  # Basic information display component for product detail page
  #
  # Displays core product information including SKU, name, description, EAN,
  # product type, and status. Uses CardComponent wrapper with BadgeComponent
  # for status indicators.
  #
  # @example Render basic info
  #   <%= render Products::BasicInfoComponent.new(product: @product) %>
  #
  class BasicInfoComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new basic info component
    #
    # @param product [Product] Product instance to display
    # @return [BasicInfoComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns badge variant for product status
    #
    # @return [Symbol] Badge variant (:success, :warning, :danger, :gray)
    def status_badge_variant
      case product.product_status
      when "active"
        :success
      when "draft", "incoming"
        :warning
      when "discontinued", "deleted"
        :danger
      else
        :gray
      end
    end

    # Returns badge variant for product type
    #
    # @return [Symbol] Badge variant (always :info for type)
    def type_badge_variant
      :info
    end

    # Returns formatted product type display name
    #
    # @return [String] Product type label
    def product_type_label
      product.product_type.humanize
    end

    # Returns formatted product status display name
    #
    # @return [String] Product status label
    def product_status_label
      product.product_status.humanize
    end
  end
end
