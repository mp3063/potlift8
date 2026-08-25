# frozen_string_literal: true

module Products
  class LabelsComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    # Returns available labels (not already assigned)
    # Scoped to product's company for multi-tenancy security
    def available_labels
      @available_labels ||= product.company.labels
                                   .where.not(id: product.label_ids)
                                   .order(:name)
    end

    def has_labels?
      product.labels.any?
    end
  end
end
