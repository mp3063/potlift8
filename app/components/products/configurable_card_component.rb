# frozen_string_literal: true

module Products
  class ConfigurableCardComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    def render?
      product.product_type_configurable?
    end

    private

    def configuration_type_label
      product.configuration_type&.humanize || "Not set"
    end

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

    def configurations
      @configurations ||= product.configurations.includes(:configuration_values).order(:position)
    end

    def configurations_count
      configurations.size
    end

    def variants_count
      @variants_count ||= product.subproducts.count
    end

    def has_configurations?
      configurations_count > 0
    end

    def has_variants?
      variants_count > 0
    end

    def can_generate_variants?
      configurations.any? { |c| c.configuration_values.any? }
    end

    def possible_combinations
      return 0 unless has_configurations?

      configurations.map { |c| c.configuration_values.count }.reduce(1, :*)
    end
  end
end
