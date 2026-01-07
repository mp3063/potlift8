# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shared::FormErrorsComponent, type: :component do
  let(:company) { create(:company) }

  # Helper to create a product with errors (bypasses before_validation callbacks)
  def product_with_errors(*error_messages)
    product = build(:product, company: company)
    error_messages.each do |msg|
      product.errors.add(:base, msg)
    end
    product
  end

  # Helper to create a product with attribute-specific errors
  def product_with_attribute_errors(attribute_errors)
    product = build(:product, company: company)
    attribute_errors.each do |attr, msg|
      product.errors.add(attr, msg)
    end
    product
  end

  describe 'rendering' do
    context 'with errors' do
      let(:product) do
        product_with_errors('First error', 'Second error')
      end

      it 'renders error container' do
        render_inline(described_class.new(errors: product.errors))

        aggregate_failures do
          expect(page).to have_css('.rounded-lg.bg-red-50')
          expect(page).to have_css('.border.border-red-200')
          expect(page).to have_css('.p-4')
        end
      end

      it 'renders error icon' do
        render_inline(described_class.new(errors: product.errors))

        aggregate_failures do
          expect(page).to have_css('svg.h-5.w-5.text-red-500')
          expect(page).to have_css('svg[aria-hidden="true"]')
        end
      end

      it 'renders error heading with singular form' do
        product = product_with_errors('Single error')

        render_inline(described_class.new(errors: product.errors))

        expect(page).to have_css('h3.text-sm.font-medium.text-red-800', text: /There is 1 error with your submission/)
      end

      it 'renders error heading with plural form' do
        product = product_with_errors('First error', 'Second error')

        render_inline(described_class.new(errors: product.errors))

        expect(page).to have_css('h3.text-sm.font-medium.text-red-800', text: /There are \d+ errors with your submission/)
      end

      it 'displays all error messages' do
        product = product_with_attribute_errors(
          sku: "can't be blank",
          name: "can't be blank",
          product_type: "can't be blank"
        )

        render_inline(described_class.new(errors: product.errors))

        aggregate_failures do
          expect(page).to have_css('ul.list-disc.list-inside')
          expect(page).to have_text("Sku can't be blank")
          expect(page).to have_text("Name can't be blank")
          expect(page).to have_text("Product type can't be blank")
        end
      end

      it 'displays error count correctly' do
        product = product_with_errors('First error', 'Second error')

        render_inline(described_class.new(errors: product.errors))

        expect(page).to have_text('2 errors')
      end

      it 'renders error list with proper styling' do
        product = product_with_errors('Single error')

        render_inline(described_class.new(errors: product.errors))

        aggregate_failures do
          expect(page).to have_css('ul.mt-2.text-sm.text-red-700')
          expect(page).to have_css('ul.space-y-1')
          expect(page).to have_css('li')
        end
      end
    end

    context 'without errors' do
      let(:product) { create(:product, company: company) }

      it 'does not render when no errors' do
        render_inline(described_class.new(errors: product.errors))

        expect(page.text).to be_empty
      end

      it 'does not render with empty errors' do
        errors = ActiveModel::Errors.new(product)

        render_inline(described_class.new(errors: errors))

        expect(page.text).to be_empty
      end
    end
  end

  describe '#render?' do
    it 'returns true when errors are present' do
      product = product_with_errors('Single error')
      component = described_class.new(errors: product.errors)

      expect(component.render?).to be true
    end

    it 'returns false when no errors' do
      product = create(:product, company: company)
      component = described_class.new(errors: product.errors)

      expect(component.render?).to be false
    end
  end

  describe 'error count display' do
    it 'shows "1 error" for single error' do
      product = product_with_errors('Single error')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('1 error')
    end

    it 'shows "2 errors" for two errors' do
      product = product_with_errors('First error', 'Second error')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('2 errors')
    end

    it 'shows correct count for multiple errors' do
      product = product_with_errors('First error', 'Second error', 'Third error')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('3 errors')
    end
  end

  describe 'error message formatting' do
    it 'displays full error messages with attribute names' do
      product = product_with_attribute_errors(sku: "can't be blank")

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text("Sku can't be blank")
    end

    it 'handles validation errors with custom messages' do
      product = product_with_attribute_errors(sku: 'is already taken')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('Sku is already taken')
    end

    it 'handles base errors without attribute name' do
      product = product_with_errors('Something went wrong')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('Something went wrong')
    end

    it 'handles multiple errors for same attribute' do
      product = build(:product, company: company)
      product.errors.add(:sku, 'is invalid')
      product.errors.add(:sku, 'is too short')

      render_inline(described_class.new(errors: product.errors))

      aggregate_failures do
        expect(page).to have_text('Sku is invalid')
        expect(page).to have_text('Sku is too short')
      end
    end
  end

  describe 'accessibility' do
    let(:product) { product_with_errors('Test error') }

    it 'has role="alert" for screen readers' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('[role="alert"]')
    end

    it 'has aria-hidden on decorative icon' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('svg[aria-hidden="true"]')
    end

    it 'uses semantic heading element' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('h3')
    end

    it 'uses semantic list elements' do
      render_inline(described_class.new(errors: product.errors))

      aggregate_failures do
        expect(page).to have_css('ul')
        expect(page).to have_css('li')
      end
    end

    it 'has sufficient color contrast with red scheme' do
      render_inline(described_class.new(errors: product.errors))

      aggregate_failures do
        expect(page).to have_css('.bg-red-50')
        expect(page).to have_css('.text-red-800')
        expect(page).to have_css('.border-red-200')
      end
    end
  end

  describe 'layout and styling' do
    let(:product) { product_with_errors('Test error') }

    it 'uses flexbox for icon and content layout' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('.flex')
    end

    it 'icon container has flex-shrink-0 to prevent squashing' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('.flex-shrink-0')
    end

    it 'content has flex-1 to fill available space' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('.flex-1')
    end

    it 'content has left margin for spacing from icon' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('.ml-3')
    end

    it 'error list has top margin for spacing from heading' do
      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('ul.mt-2')
    end

    it 'error list items have vertical spacing' do
      product = product_with_errors('First error', 'Second error')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_css('ul.space-y-1')
    end
  end

  describe 'edge cases' do
    it 'handles very long error messages' do
      product = build(:product, company: company)
      product.errors.add(:sku, 'A' * 200)

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('A' * 200)
    end

    it 'handles error messages with HTML characters' do
      product = build(:product, company: company)
      product.errors.add(:sku, 'contains <script> tags')

      render_inline(described_class.new(errors: product.errors))

      # Should escape HTML
      expect(page).to have_text('contains <script> tags')
    end

    it 'handles error messages with quotes' do
      product = build(:product, company: company)
      product.errors.add(:sku, 'cannot contain "quotes"')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('cannot contain "quotes"')
    end

    it 'handles unicode in error messages' do
      product = build(:product, company: company)
      product.errors.add(:sku, '不能为空')

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text('不能为空')
    end

    it 'handles errors with newlines' do
      product = build(:product, company: company)
      product.errors.add(:sku, "has multiple\nlines")

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text("has multiple\nlines")
    end
  end

  describe 'integration with ActiveModel::Errors' do
    it 'works with standard ActiveModel validations' do
      # Test with name validation (no callback that auto-generates)
      product = build(:product, company: company, name: nil)
      product.valid?

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text("Name can't be blank")
    end

    it 'works with custom validations' do
      product = build(:product, company: company, product_type: :configurable, configuration_type: nil)
      product.valid?

      render_inline(described_class.new(errors: product.errors))

      expect(page).to have_text("Configuration type can't be blank")
    end

    it 'works with uniqueness validations' do
      create(:product, company: company, sku: 'TEST123')
      duplicate = build(:product, company: company, sku: 'TEST123')
      duplicate.valid?

      render_inline(described_class.new(errors: duplicate.errors))

      expect(page).to have_text('Sku has already been taken')
    end
  end
end
