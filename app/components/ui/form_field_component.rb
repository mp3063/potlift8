# frozen_string_literal: true

module Ui
  # Form field component with label, input, and inline error display
  #
  # Provides consistent form field styling with accessibility features
  # and inline validation feedback.
  #
  # @example Text input
  #   <%= render Ui::FormFieldComponent.new(
  #     form: f,
  #     attribute: :sku,
  #     label: "SKU",
  #     required: true
  #   ) %>
  #
  # @example Select input
  #   <%= render Ui::FormFieldComponent.new(
  #     form: f,
  #     attribute: :product_type,
  #     label: "Product Type",
  #     type: :select,
  #     options: [['Sellable', 1], ['Configurable', 2]]
  #   ) %>
  #
  # @example Textarea
  #   <%= render Ui::FormFieldComponent.new(
  #     form: f,
  #     attribute: :description,
  #     label: "Description",
  #     type: :text_area,
  #     rows: 4
  #   ) %>
  #
  class FormFieldComponent < ViewComponent::Base
    attr_reader :form, :attribute, :label, :type, :required

    def initialize(form:, attribute:, label:, type: :text_field, required: false, **options)
      @form = form
      @attribute = attribute
      @label = label
      @type = type
      @required = required
      @options = options
    end

    def call
      content_tag(:div, class: "space-y-1") do
        concat(render_label)
        concat(render_input)
        concat(render_error) if has_error?
      end
    end

    private

    def render_label
      @form.label @attribute, class: "block text-sm font-medium text-gray-700" do
        concat(@label)
        concat(required_indicator) if @required
      end
    end

    def required_indicator
      content_tag(:span, class: "text-red-600 ml-1", aria: { hidden: true }) do
        "*"
      end
    end

    def render_input
      input_classes = [
        "mt-1 block w-full rounded-md shadow-sm sm:text-sm",
        error_classes
      ].join(" ")

      case @type
      when :text_field
        @form.text_field @attribute, {
          required: @required,
          class: input_classes,
          aria: aria_attributes
        }.merge(@options)
      when :text_area
        @form.text_area @attribute, {
          required: @required,
          class: input_classes,
          aria: aria_attributes,
          rows: @options[:rows] || 3
        }.merge(@options.except(:rows))
      when :select
        @form.select @attribute, @options[:options], {}, {
          required: @required,
          class: input_classes,
          aria: aria_attributes
        }.merge(@options.except(:options))
      when :email_field
        @form.email_field @attribute, {
          required: @required,
          class: input_classes,
          aria: aria_attributes
        }.merge(@options)
      when :number_field
        @form.number_field @attribute, {
          required: @required,
          class: input_classes,
          aria: aria_attributes
        }.merge(@options)
      end
    end

    def render_error
      return unless has_error?

      content_tag(:p, class: "mt-2 text-sm text-red-600", id: error_id, role: "alert") do
        errors.first
      end
    end

    def has_error?
      errors.any?
    end

    def errors
      @form.object.errors[@attribute]
    end

    def error_classes
      if has_error?
        "border-red-300 text-red-900 placeholder-red-300 focus:border-red-500 focus:ring-red-500"
      else
        "border-gray-300 focus:border-blue-500 focus:ring-blue-500"
      end
    end

    def aria_attributes
      attrs = { required: @required }
      attrs[:invalid] = true if has_error?
      attrs[:describedby] = error_id if has_error?
      attrs
    end

    def error_id
      "#{@attribute}-error"
    end
  end
end
