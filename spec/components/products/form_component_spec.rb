# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::FormComponent, type: :component do
  let(:company) { create(:company) }

  describe 'rendering new product form' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'renders the form' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('form')
      expect(page).to have_css("form[action='#{url}']")
    end

    it 'includes SKU field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('SKU', type: 'text')
      expect(page).to have_text('Leave blank to auto-generate a unique SKU')
    end

    it 'includes product type select' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_select('Product Type', with_options: ['Sellable', 'Configurable', 'Bundle'])
    end

    it 'includes name field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Name', type: 'text')
    end

    it 'includes description field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Description', type: 'textarea')
    end

    it 'includes active checkbox' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Active', type: 'checkbox')
      expect(page).to have_text('Product is active and available for use')
    end

    it 'includes submit button' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_button(type: 'submit')
    end

    it 'includes cancel link' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_link('Cancel', href: '/products')
    end

    it 'sets Stimulus controller' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('form[data-controller="product-form"]')
    end

    it 'sets Turbo data attribute' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('form[data-turbo="true"]')
    end
  end

  describe 'rendering edit product form' do
    let(:product) do
      create(:product,
             company: company,
             sku: 'EDIT001',
             name: 'Existing Product',
             product_type: :sellable,
             product_status: :active,
             info: { 'description' => 'Product description' })
    end
    let(:url) { "/products/#{product.id}" }
    let(:method) { :patch }

    it 'pre-fills SKU field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('SKU', with: 'EDIT001')
    end

    it 'pre-fills name field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Name', with: 'Existing Product')
    end

    it 'pre-selects product type' do
      render_inline(described_class.new(product: product, url: url, method: method))

      # The select field should have product_type value
      within('select#product_product_type') do
        # Check that Sellable option exists with value="1"
        expect(page).to have_css('option[value="1"]', text: 'Sellable')
      end
    end

    it 'checks active checkbox for active products' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_checked_field('Active')
    end

    it 'unchecks active checkbox for inactive products' do
      product.product_status = :draft
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_unchecked_field('Active')
    end
  end

  describe 'validation error display' do
    let(:product) do
      product = Product.new(company: company)
      product.errors.add(:sku, 'has already been taken')
      product.errors.add(:name, "can't be blank")
      product
    end
    let(:url) { '/products' }
    let(:method) { :post }

    it 'displays error summary' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('.bg-red-50')
      expect(page).to have_text('There were 2 errors with your submission')
    end

    it 'displays error icon' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('svg.text-red-400')
    end

    it 'lists all error messages' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_text('Sku has already been taken', normalize_ws: true)
      expect(page).to have_text("Name can't be blank")
    end

    it 'adds error styling to SKU field' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input#product_sku.ring-red-300')
    end

    it 'displays inline error message for SKU' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('.text-red-600', text: 'has already been taken')
    end

    it 'handles single error correctly' do
      product = Product.new(company: company)
      product.errors.add(:name, "can't be blank")

      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_text('There was 1 error with your submission')
    end
  end

  describe 'Stimulus data attributes' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'sets SKU field target' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input[data-product-form-target="sku"]')
    end

    it 'sets SKU validation action' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input[data-action="blur->product-form#validateSku"]')
    end

    it 'sets product type target' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('select[data-product-form-target="productType"]')
    end

    it 'sets product type change action' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('select[data-action="change->product-form#handleTypeChange"]')
    end
  end

  describe 'field placeholders and hints' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'shows SKU placeholder' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('SKU', placeholder: 'Auto-generated if left blank')
    end

    it 'shows name placeholder' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Name', placeholder: 'Enter product name')
    end

    it 'shows description placeholder' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_field('Description', placeholder: 'Enter product description')
    end

    it 'shows active checkbox help text' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_text('Product is active and available for use')
    end
  end

  describe 'responsive grid layout' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'uses grid layout for form fields' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('.grid.grid-cols-1.gap-x-6.gap-y-8')
    end

    it 'makes SKU and Type fields half-width on larger screens' do
      render_inline(described_class.new(product: product, url: url, method: method))

      # SKU should be in a column span 3 (half of 6)
      expect(page).to have_css('.sm\\:col-span-3', count: 2) # SKU and Type
    end

    it 'makes Name and Description full-width' do
      render_inline(described_class.new(product: product, url: url, method: method))

      # Name and Description should span all 6 columns
      expect(page).to have_css('.sm\\:col-span-6', count: 3) # Name, Description, Active
    end
  end

  describe 'accessibility' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'has proper label associations' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('label[for="product_sku"]')
      expect(page).to have_css('label[for="product_name"]')
      expect(page).to have_css('label[for="product_product_type"]')
      expect(page).to have_css('label[for="product_description"]')
      expect(page).to have_css('label[for="product_active"]')
    end

    it 'uses semantic HTML structure' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('form')
      expect(page).to have_css('label')
      expect(page).to have_css('input')
      expect(page).to have_css('select')
      expect(page).to have_css('textarea')
    end

    it 'includes aria-hidden on error icon' do
      product = Product.new(company: company)
      product.errors.add(:name, "can't be blank")

      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('svg[aria-hidden="true"]')
    end

    it 'provides descriptive field labels' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_text('SKU')
      expect(page).to have_text('Product Type')
      expect(page).to have_text('Name')
      expect(page).to have_text('Description')
      expect(page).to have_text('Active')
    end
  end

  describe 'form styling' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'applies Tailwind form styles' do
      render_inline(described_class.new(product: product, url: url, method: method))

      # Check for Tailwind form classes
      expect(page).to have_css('input.rounded-md')
      expect(page).to have_css('input.shadow-sm')
      expect(page).to have_css('select.rounded-md')
      expect(page).to have_css('textarea.rounded-md')
    end

    it 'applies focus styles' do
      render_inline(described_class.new(product: product, url: url, method: method))

      # Check for focus ring classes
      expect(page).to have_css('input.focus\\:ring-2')
      expect(page).to have_css('select.focus\\:ring-2')
      expect(page).to have_css('textarea.focus\\:ring-2')
    end

    it 'applies error styles when field has errors' do
      product = Product.new(company: company)
      product.errors.add(:sku, 'has already been taken')

      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input#product_sku.ring-red-300.focus\\:ring-red-600')
    end

    it 'styles submit button' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input[type="submit"].bg-indigo-600')
      expect(page).to have_css('input[type="submit"].hover\\:bg-indigo-500')
    end

    it 'styles cancel link' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('a.text-gray-900', text: 'Cancel')
    end
  end

  describe 'product type options' do
    let(:product) { Product.new(company: company) }
    let(:url) { '/products' }
    let(:method) { :post }

    it 'includes all product types' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_select('Product Type', with_options: ['Sellable', 'Configurable', 'Bundle'])
    end

    it 'includes prompt option' do
      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_select('Product Type', with_options: ['Select a product type'])
    end

    it 'maps product types to correct enum values' do
      render_inline(described_class.new(product: product, url: url, method: method))

      within('select#product_product_type') do
        expect(page).to have_css('option[value="1"]', text: 'Sellable')
        expect(page).to have_css('option[value="2"]', text: 'Configurable')
        expect(page).to have_css('option[value="3"]', text: 'Bundle')
      end
    end
  end

  describe 'helper methods' do
    let(:component) do
      described_class.new(
        product: Product.new(company: company),
        url: '/products',
        method: :post
      )
    end

    describe '#product_type_options' do
      it 'returns array of label-value pairs' do
        options = component.send(:product_type_options)

        expect(options).to eq([
          ['Sellable', 1],
          ['Configurable', 2],
          ['Bundle', 3]
        ])
      end
    end

    describe '#x_circle_icon' do
      it 'returns SVG markup' do
        icon = component.send(:x_circle_icon)

        expect(icon).to include('svg')
        expect(icon).to include('h-5 w-5')
        expect(icon).to include('text-red-400')
      end

      it 'returns HTML safe string' do
        icon = component.send(:x_circle_icon)

        expect(icon).to be_html_safe
      end
    end
  end

  describe 'different product types' do
    let(:url) { '/products' }
    let(:method) { :post }

    it 'renders form for sellable product' do
      product = create(:product, company: company, product_type: :sellable)

      render_inline(described_class.new(product: product, url: url, method: method))

      # Check that product form renders with sellable type option
      within('select#product_product_type') do
        expect(page).to have_css('option[value="1"]', text: 'Sellable')
      end
    end

    it 'renders form for configurable product' do
      product = create(:product, company: company, product_type: :configurable, configuration_type: :variant)

      render_inline(described_class.new(product: product, url: url, method: method))

      # Check that product form renders with configurable type option
      within('select#product_product_type') do
        expect(page).to have_css('option[value="2"]', text: 'Configurable')
      end
    end

    it 'renders form for bundle product' do
      product = create(:product, company: company, product_type: :bundle)

      render_inline(described_class.new(product: product, url: url, method: method))

      # Check that product form renders with bundle type option
      within('select#product_product_type') do
        expect(page).to have_css('option[value="3"]', text: 'Bundle')
      end
    end
  end

  describe 'error state variations' do
    let(:url) { '/products' }
    let(:method) { :post }

    it 'handles multiple errors on same field' do
      product = Product.new(company: company)
      product.errors.add(:name, "can't be blank")
      product.errors.add(:name, 'is too short')

      render_inline(described_class.new(product: product, url: url, method: method))

      # Should show first error message
      expect(page).to have_css('.text-red-600', text: "can't be blank")
    end

    it 'handles errors on multiple fields' do
      product = Product.new(company: company)
      product.errors.add(:sku, 'has already been taken')
      product.errors.add(:name, "can't be blank")
      product.errors.add(:product_type, 'must be selected')

      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).to have_css('input#product_sku.ring-red-300')
      expect(page).to have_css('input#product_name.ring-red-300')
      expect(page).to have_css('select#product_product_type.ring-red-300')
    end

    it 'displays no errors when product is valid' do
      product = Product.new(company: company)

      render_inline(described_class.new(product: product, url: url, method: method))

      expect(page).not_to have_css('.bg-red-50')
      expect(page).not_to have_text('error')
    end
  end
end
