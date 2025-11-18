# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ui::FormFieldComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { build(:product, company: company) }
  let(:form_builder) do
    ActionView::Helpers::FormBuilder.new(:product, product, vc_test_controller.view_context, {})
  end

  describe "text field" do
    it "renders label and input" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :name,
        label: "Product Name"
      ))

      expect(page).to have_content('Product Name')
      expect(page).to have_field('product_name')
    end

    it "shows required indicator when required" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :name,
        label: "Product Name",
        required: true
      ))

      expect(page).to have_css('span.text-red-600', text: '*')
      expect(page).to have_field('product_name')
    end

    it "displays validation errors" do
      product.errors.add(:sku, "can't be blank")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('p.text-red-600', text: "can't be blank")
      expect(page).to have_css('input.border-red-300')
    end

    it "adds aria attributes for errors" do
      product.errors.add(:sku, "can't be blank")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('input[aria-invalid="true"]')
      expect(page).to have_css('input[aria-describedby="sku-error"]')
      expect(page).to have_css('p#sku-error[role="alert"]')
    end

    it "applies correct CSS classes for valid input" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('input.border-gray-300')
      expect(page).to have_css('input.focus\:border-blue-500')
    end

    it "passes through additional HTML options" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU",
        placeholder: "Enter SKU",
        maxlength: 20
      ))

      expect(page).to have_field('product_sku', placeholder: 'Enter SKU')
      expect(page).to have_css('input[maxlength="20"]')
    end
  end

  describe "text area" do
    it "renders textarea with default rows" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :description,
        label: "Description",
        type: :text_area
      ))

      expect(page).to have_css('textarea[rows="3"]')
      expect(page).to have_content('Description')
    end

    it "renders textarea with custom rows" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :description,
        label: "Description",
        type: :text_area,
        rows: 5
      ))

      expect(page).to have_css('textarea[rows="5"]')
    end

    it "displays validation errors on textarea" do
      product.errors.add(:description, "is too short")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :description,
        label: "Description",
        type: :text_area
      ))

      expect(page).to have_css('p.text-red-600', text: "is too short")
      expect(page).to have_css('textarea.border-red-300')
    end
  end

  describe "select field" do
    it "renders select with options" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :product_type,
        label: "Product Type",
        type: :select,
        options: [['Sellable', 1], ['Configurable', 2]]
      ))

      expect(page).to have_select('product_product_type', options: ['Sellable', 'Configurable'])
      expect(page).to have_content('Product Type')
    end

    it "displays validation errors on select" do
      product.errors.add(:product_type, "must be selected")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :product_type,
        label: "Product Type",
        type: :select,
        options: [['Sellable', 1], ['Configurable', 2]]
      ))

      expect(page).to have_css('p.text-red-600', text: "must be selected")
      expect(page).to have_css('select.border-red-300')
    end

    it "marks select as required when specified" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :product_type,
        label: "Product Type",
        type: :select,
        required: true,
        options: [['Sellable', 1], ['Configurable', 2]]
      ))

      expect(page).to have_css('select[required]')
      expect(page).to have_css('span.text-red-600', text: '*')
    end
  end

  describe "email field" do
    let(:contact) { Struct.new(:email, keyword_init: true).new(email: nil) }
    let(:contact_form_builder) do
      ActionView::Helpers::FormBuilder.new(:contact, contact, vc_test_controller.view_context, {})
    end

    before do
      # Allow contact to respond to errors
      def contact.errors
        @errors ||= ActiveModel::Errors.new(self)
      end
    end

    it "renders email input" do
      render_inline(described_class.new(
        form: contact_form_builder,
        attribute: :email,
        label: "Email",
        type: :email_field
      ))

      expect(page).to have_css('input[type="email"]')
      expect(page).to have_content('Email')
    end

    it "displays validation errors on email field" do
      contact.errors.add(:email, "is invalid")

      render_inline(described_class.new(
        form: contact_form_builder,
        attribute: :email,
        label: "Email",
        type: :email_field
      ))

      expect(page).to have_css('p.text-red-600', text: "is invalid")
    end
  end

  describe "number field" do
    let(:inventory) { Struct.new(:quantity, keyword_init: true).new(quantity: nil) }
    let(:inventory_form_builder) do
      ActionView::Helpers::FormBuilder.new(:inventory, inventory, vc_test_controller.view_context, {})
    end

    before do
      # Allow inventory to respond to errors
      def inventory.errors
        @errors ||= ActiveModel::Errors.new(self)
      end
    end

    it "renders number input" do
      render_inline(described_class.new(
        form: inventory_form_builder,
        attribute: :quantity,
        label: "Quantity",
        type: :number_field
      ))

      expect(page).to have_css('input[type="number"]')
      expect(page).to have_content('Quantity')
    end

    it "passes through min and max attributes" do
      render_inline(described_class.new(
        form: inventory_form_builder,
        attribute: :quantity,
        label: "Quantity",
        type: :number_field,
        min: 0,
        max: 100
      ))

      expect(page).to have_css('input[min="0"]')
      expect(page).to have_css('input[max="100"]')
    end
  end

  describe "accessibility" do
    it "associates label with input using for attribute" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      label = page.find('label')
      input = page.find('input')
      expect(label[:for]).to eq(input[:id])
    end

    it "uses aria-required for required fields" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU",
        required: true
      ))

      expect(page).to have_css('input[aria-required="true"]')
    end

    it "hides asterisk from screen readers" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU",
        required: true
      ))

      expect(page).to have_css('span[aria-hidden="true"]', text: '*')
    end

    it "uses role=alert for error messages" do
      product.errors.add(:sku, "can't be blank")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('p[role="alert"]', text: "can't be blank")
    end
  end

  describe "error handling" do
    it "displays only the first error when multiple errors exist" do
      product.errors.add(:sku, "can't be blank")
      product.errors.add(:sku, "must be unique")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('p.text-red-600', text: "can't be blank")
      expect(page).not_to have_css('p.text-red-600', text: "must be unique")
    end

    it "does not render error paragraph when no errors" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).not_to have_css('p.text-red-600')
      expect(page).not_to have_css('p[role="alert"]')
    end
  end

  describe "layout structure" do
    it "wraps field in div with space-y-1 class" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      expect(page).to have_css('div.space-y-1', count: 1)
    end

    it "renders label before input" do
      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      html = rendered_content
      label_index = html.index('<label')
      input_index = html.index('<input')

      expect(label_index).to be < input_index
    end

    it "renders error message after input" do
      product.errors.add(:sku, "can't be blank")

      render_inline(described_class.new(
        form: form_builder,
        attribute: :sku,
        label: "SKU"
      ))

      html = rendered_content
      input_index = html.index('<input')
      error_index = html.index('role="alert"')

      expect(input_index).to be < error_index
    end
  end
end
