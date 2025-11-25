# frozen_string_literal: true

module Products
  # Configurable product management card component
  #
  # Displays configuration dimensions, variants summary, and action buttons
  # for managing configurable products (variant or option types).
  # Only renders content for configurable products.
  #
  # @example Render configurable card
  #   <%= render Products::ConfigurableCardComponent.new(product: @product) %>
  #
  class ConfigurableCardComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new configurable card component
    #
    # @param product [Product] Product instance to display
    # @return [ConfigurableCardComponent]
    def initialize(product:)
      @product = product
    end

    # Only render for configurable products
    #
    # @return [Boolean]
    def render?
      product.product_type_configurable?
    end

    private

    # Returns the configuration type label
    #
    # @return [String] "Variant" or "Option"
    def configuration_type_label
      product.configuration_type&.humanize || "Not set"
    end

    # Returns badge variant for configuration type
    #
    # @return [Symbol] Badge variant
    def configuration_type_badge_variant
      case product.configuration_type
      when "variant"
        :info
      when "option"
        :warning
      else
        :gray
      end
    end

    # Returns configurations for the product
    #
    # @return [ActiveRecord::Relation]
    def configurations
      @configurations ||= product.configurations.includes(:configuration_values).order(:position)
    end

    # Returns the count of configurations
    #
    # @return [Integer]
    def configurations_count
      configurations.size
    end

    # Returns the count of variants (subproducts)
    #
    # @return [Integer]
    def variants_count
      @variants_count ||= product.subproducts.count
    end

    # Check if product has any configurations
    #
    # @return [Boolean]
    def has_configurations?
      configurations_count > 0
    end

    # Check if product has any variants
    #
    # @return [Boolean]
    def has_variants?
      variants_count > 0
    end

    # Check if product can generate variants
    # Requires at least one configuration with values
    #
    # @return [Boolean]
    def can_generate_variants?
      configurations.any? { |c| c.configuration_values.any? }
    end

    # Returns total possible variant combinations
    #
    # @return [Integer]
    def possible_combinations
      return 0 unless has_configurations?

      configurations.map { |c| c.configuration_values.count }.reduce(1, :*)
    end
  end
end
