# frozen_string_literal: true

module Products
  # Product form component
  #
  # Displays a product form with:
  # - SKU field with auto-generation hint and validation
  # - Product Type selector
  # - Name and Description fields
  # - Active status checkbox
  # - Inline error messages
  #
  # Features:
  # - Client-side SKU validation via Stimulus
  # - Product type change handling
  # - Accessible form labels and ARIA attributes
  # - Responsive grid layout
  #
  # @example New product form
  #   <%= render Products::FormComponent.new(
  #     product: Product.new,
  #     url: products_path,
  #     method: :post
  #   ) %>
  #
  # @example Edit product form
  #   <%= render Products::FormComponent.new(
  #     product: @product,
  #     url: product_path(@product),
  #     method: :patch
  #   ) %>
  #
  class FormComponent < ViewComponent::Base
    def initialize(product:, url:, method:)
      @product = product
      @url = url
      @method = method
    end

    private

    attr_reader :product, :url, :method

    # X-circle icon SVG for error display
    def x_circle_icon
      '<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.28 7.22a.75.75 0 00-1.06 1.06L8.94 10l-1.72 1.72a.75.75 0 101.06 1.06L10 11.06l1.72 1.72a.75.75 0 101.06-1.06L11.06 10l1.72-1.72a.75.75 0 00-1.06-1.06L10 8.94 8.28 7.22z" clip-rule="evenodd" />
      </svg>'.html_safe
    end

    # Product type options for select dropdown
    #
    # @return [Array<Array<String, Integer>>] Array of [label, value] pairs
    def product_type_options
      [
        ['Sellable', 1],
        ['Configurable', 2],
        ['Bundle', 3]
      ]
    end
  end
end
