# frozen_string_literal: true

module Products
  # Product form component with organized card sections
  #
  # Renders a comprehensive product creation/editing form organized into logical
  # card sections. The form includes client-side validation via Stimulus and
  # displays validation errors using the FormErrorsComponent.
  #
  # **Form Sections:**
  # - Basic Information: SKU, Name, Product Type
  # - Additional Details: Description, Active status checkbox
  #
  # **Features:**
  # - Card-based layout using Ui::CardComponent
  # - Form error summary at the top
  # - Client-side SKU validation via Stimulus (product-form controller)
  # - Product type select dropdown with 3 types
  # - Accessible form labels and ARIA attributes
  # - Error states with proper styling and accessibility
  # - Action buttons (Submit/Cancel) using Ui::ButtonComponent
  # - Rich text editor support for description (if ActionText configured)
  #
  # **Accessibility:**
  # - Proper label associations
  # - ARIA attributes for form controls
  # - Error messages linked to inputs
  # - Focus management
  # - Keyboard navigation
  #
  # **Stimulus Integration:**
  # - Controller: product-form
  # - Validates SKU format and uniqueness
  # - Handles product type changes
  #
  # **Product Types:**
  # - Sellable (1): Regular products sold directly
  # - Configurable (2): Products with variants or options
  # - Bundle (3): Products composed of multiple products
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
  # @example With validation errors
  #   <%= render Products::FormComponent.new(
  #     product: @product, # @product.errors present
  #     url: product_path(@product),
  #     method: :patch
  #   ) %>
  #
  # @see docs/DESIGN_SYSTEM.md Design System Documentation
  # @see app/javascript/controllers/product_form_controller.js Stimulus Controller
  # @see Ui::CardComponent Card layout component
  # @see Ui::ButtonComponent Action buttons
  #
  class FormComponent < ViewComponent::Base
    # Initialize a new product form component
    #
    # @param product [Product] The product model instance (new or existing)
    # @param url [String] The form submission URL (products_path or product_path)
    # @param method [Symbol] The HTTP method (:post for create, :patch/:put for update)
    #
    # @example Create form
    #   FormComponent.new(
    #     product: Product.new,
    #     url: products_path,
    #     method: :post
    #   )
    #
    # @example Edit form
    #   FormComponent.new(
    #     product: Product.find(123),
    #     url: product_path(123),
    #     method: :patch
    #   )
    #
    # @return [FormComponent]
    def initialize(product:, url:, method:)
      @product = product
      @url = url
      @method = method
      @company = product.company
    end

    private

    attr_reader :product, :url, :method, :company

    # Product type options for select dropdown
    #
    # Returns an array of [label, value] pairs for the product type select field.
    # Values are symbolic keys that correspond to the product_type enum in the Product model.
    #
    # @return [Array<Array<String, String>>] Array of [label, value] pairs
    #
    # @example
    #   product_type_options
    #   # => [['Sellable', 'sellable'], ['Configurable', 'configurable'], ['Bundle', 'bundle']]
    def product_type_options
      Product.product_types.map { |key, _value| [key.humanize, key] }
    end

    # Available labels for the current company
    #
    # Returns all labels ordered by hierarchy and position.
    # Returns empty array if company is not present.
    #
    # @return [ActiveRecord::Relation] Labels for the company
    #
    def available_labels
      return Label.none unless company.present?

      company.labels.order(:label_positions, :name)
    end

    # Selected label IDs for the product
    #
    # @return [Array<Integer>] Array of label IDs
    #
    def selected_label_ids
      product.label_ids
    end
  end
end
