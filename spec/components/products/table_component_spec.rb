# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Products::TableComponent, type: :component do
  let(:company) { create(:company) }

  describe 'rendering' do
    context 'with products' do
      let!(:product1) do
        create(:product,
               company: company,
               sku: 'PROD001',
               name: 'Product Alpha',
               product_type: :sellable,
               product_status: :active,
               created_at: 2.days.ago)
      end

      let!(:product2) do
        create(:product,
               company: company,
               sku: 'PROD002',
               name: 'Product Beta',
               product_type: :configurable,
               configuration_type: :variant,
               product_status: :draft,
               created_at: 1.day.ago)
      end

      let!(:product3) do
        create(:product,
               company: company,
               sku: 'PROD003',
               name: 'Product Gamma',
               product_type: :bundle,
               product_status: :active,
               created_at: Time.current)
      end

      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 3, page: 1, limit: 25) }

      it 'renders the products table' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_css('table')
        expect(page).to have_css('thead')
        expect(page).to have_css('tbody')
      end

      it 'displays all products' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_text('PROD001')
        expect(page).to have_text('Product Alpha')

        expect(page).to have_text('PROD002')
        expect(page).to have_text('Product Beta')

        expect(page).to have_text('PROD003')
        expect(page).to have_text('Product Gamma')
      end

      it 'displays product SKU as links' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_link('PROD001', href: /\/products\/#{product1.id}/)
        expect(page).to have_link('PROD002', href: /\/products\/#{product2.id}/)
      end

      it 'displays product types with badges' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_text('Sellable')
        expect(page).to have_text('Configurable')
        expect(page).to have_text('Bundle')
      end

      it 'displays product status badges' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Active products
        within("tr[data-product-id='#{product1.id}']") do
          expect(page).to have_css('span.bg-green-50', text: 'Active')
        end

        # Draft products
        within("tr[data-product-id='#{product2.id}']") do
          expect(page).to have_css('span.bg-gray-50', text: 'Inactive')
        end
      end

      it 'renders action buttons' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Edit links
        expect(page).to have_css("a[href*='/products/#{product1.id}/edit']")

        # Duplicate links
        expect(page).to have_css("a[href*='/products/#{product1.id}/duplicate']")

        # Delete buttons
        expect(page).to have_css("form[action='/products/#{product1.id}']")
      end

      it 'renders bulk action checkboxes' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Header checkbox for select all
        expect(page).to have_css('thead input[type="checkbox"][data-action="change->bulk-actions#toggleAll"]')

        # Individual checkboxes for each product
        expect(page).to have_css("input[type='checkbox'][value='#{product1.id}']")
        expect(page).to have_css("input[type='checkbox'][value='#{product2.id}']")
        expect(page).to have_css("input[type='checkbox'][value='#{product3.id}']")
      end
    end

    context 'with labels' do
      let(:label1) { create(:label, company: company, name: 'Electronics') }
      let(:label2) { create(:label, company: company, name: 'Featured') }
      let(:label3) { create(:label, company: company, name: 'New') }
      let(:label4) { create(:label, company: company, name: 'Sale') }

      let!(:product_with_labels) do
        product = create(:product, company: company, sku: 'LABELED')
        create(:product_label, product: product, label: label1)
        create(:product_label, product: product, label: label2)
        create(:product_label, product: product, label: label3)
        create(:product_label, product: product, label: label4)
        product
      end

      let!(:product_without_labels) do
        create(:product, company: company, sku: 'UNLABELED')
      end

      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 2, page: 1, limit: 25) }

      it 'displays labels for products' do
        render_inline(described_class.new(products: products, pagy: pagy))

        within("tr[data-product-id='#{product_with_labels.id}']") do
          expect(page).to have_text('Electronics')
          expect(page).to have_text('Featured')
          expect(page).to have_text('New')
        end
      end

      it 'shows +N indicator when more than 3 labels' do
        render_inline(described_class.new(products: products, pagy: pagy))

        within("tr[data-product-id='#{product_with_labels.id}']") do
          # Should show first 3 labels plus +1 indicator
          expect(page).to have_text('+1')
        end
      end

      it 'handles products without labels' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Should not crash, just show empty labels cell
        expect(page).to have_css("tr[data-product-id='#{product_without_labels.id}']")
      end
    end

    context 'with inventory' do
      let(:storage1) { create(:storage, company: company) }
      let(:storage2) { create(:storage, company: company) }

      let!(:product_with_stock) do
        product = create(:product, company: company, sku: 'INSTOCK')
        create(:inventory, product: product, storage: storage1, value: 50)
        create(:inventory, product: product, storage: storage2, value: 30)
        product
      end

      let!(:product_no_stock) do
        create(:product, company: company, sku: 'OUTOFSTOCK')
      end

      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 2, page: 1, limit: 25) }

      it 'displays total inventory' do
        render_inline(described_class.new(products: products, pagy: pagy))

        within("tr[data-product-id='#{product_with_stock.id}']") do
          expect(page).to have_text('80') # 50 + 30
        end
      end

      it 'displays zero inventory for products without stock' do
        render_inline(described_class.new(products: products, pagy: pagy))

        within("tr[data-product-id='#{product_no_stock.id}']") do
          expect(page).to have_text('0')
        end
      end
    end

    context 'with sorting' do
      let(:product1) { create(:product, company: company, sku: 'AAA', name: 'Alpha') }
      let(:product2) { create(:product, company: company, sku: 'BBB', name: 'Beta') }
      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 2, page: 1, limit: 25) }

      it 'renders sort links in headers' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_link('SKU')
        expect(page).to have_link('Name')
        expect(page).to have_link('Created')
      end

      it 'highlights current sort column' do
        render_inline(described_class.new(
          products: products,
          pagy: pagy,
          current_sort: 'sku',
          current_direction: 'asc'
        ))

        # Should have active styling on SKU column
        expect(page).to have_css('a.text-indigo-600', text: 'SKU')
      end

      it 'displays sort direction indicator' do
        render_inline(described_class.new(
          products: products,
          pagy: pagy,
          current_sort: 'sku',
          current_direction: 'asc'
        ))

        # Should show chevron up icon for ascending
        within('thead') do
          expect(page).to have_css('svg.h-4.w-4')
        end
      end

      it 'toggles sort direction in links' do
        render_inline(described_class.new(
          products: products,
          pagy: pagy,
          current_sort: 'sku',
          current_direction: 'asc'
        ))

        # Next click on SKU should sort desc (params can be in any order)
        expect(page).to have_link('SKU', href: /[?&]sort=sku/)
        expect(page).to have_link('SKU', href: /[?&]direction=desc/)
      end

      it 'defaults to ascending for new column' do
        render_inline(described_class.new(
          products: products,
          pagy: pagy,
          current_sort: 'sku',
          current_direction: 'asc'
        ))

        # Clicking Name (not currently sorted) should sort asc (params can be in any order)
        expect(page).to have_link('Name', href: /[?&]sort=name/)
        expect(page).to have_link('Name', href: /[?&]direction=asc/)
      end
    end

    context 'with pagination' do
      let(:products) { Product.where(company: company) }

      before do
        30.times { |i| create(:product, company: company, sku: "BULK#{i.to_s.rjust(3, '0')}") }
      end

      it 'displays pagination controls' do
        pagy = Pagy.new(count: 30, page: 1, limit: 10)
        render_inline(described_class.new(products: products.limit(10), pagy: pagy))

        expect(page).to have_text('Showing')
        expect(page).to have_text('1')
        expect(page).to have_text('to')
        expect(page).to have_text('10')
        expect(page).to have_text('of')
        expect(page).to have_text('30')
      end

      it 'displays page navigation links' do
        pagy = Pagy.new(count: 30, page: 2, limit: 10)
        render_inline(described_class.new(products: products.limit(10).offset(10), pagy: pagy))

        expect(page).to have_link('Previous')
        expect(page).to have_link('Next')
      end

      it 'disables previous link on first page' do
        pagy = Pagy.new(count: 30, page: 1, limit: 10)
        render_inline(described_class.new(products: products.limit(10), pagy: pagy))

        # Previous button should be disabled
        expect(page).to have_css('a.pointer-events-none.opacity-50')
      end
    end

    context 'empty state' do
      let(:products) { Product.none }
      let(:pagy) { Pagy.new(count: 0, page: 1, limit: 25) }

      it 'displays empty state when no products' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_text('No products')
        expect(page).to have_text('Get started by creating a new product')
      end

      it 'displays empty state icon' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Package icon
        expect(page).to have_css('svg.h-12.w-12.text-gray-400')
      end

      it 'shows new product button in empty state' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_link('New Product', href: /\/products\/new/)
      end

      it 'does not show table headers in empty state' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Table should still exist with empty state row
        expect(page).to have_css('table')
        expect(page).to have_css('tbody tr', count: 1) # One row for empty state
        expect(page).to have_text('No products')
      end
    end

    context 'turbo frame' do
      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 0, page: 1, limit: 25) }

      it 'wraps content in turbo frame' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_css('turbo-frame#products_table')
      end

      it 'sets turbo frame on sort links' do
        create(:product, company: company)
        pagy = Pagy.new(count: 1, page: 1, limit: 25)

        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_css('a[data-turbo-frame="products_table"]')
      end
    end

    context 'accessibility' do
      let(:products) { Product.where(company: company) }
      let(:pagy) { Pagy.new(count: 1, page: 1, limit: 25) }

      before do
        create(:product, company: company, sku: 'TEST001', name: 'Test Product')
      end

      it 'includes screen reader text for action buttons' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_css('span.sr-only', text: 'Edit')
        expect(page).to have_css('span.sr-only', text: 'Duplicate')
        expect(page).to have_css('span.sr-only', text: 'Delete')
      end

      it 'uses semantic table markup' do
        render_inline(described_class.new(products: products, pagy: pagy))

        expect(page).to have_css('table')
        expect(page).to have_css('thead')
        expect(page).to have_css('tbody')
        expect(page).to have_css('th[scope="col"]')
      end

      it 'includes aria-hidden on decorative SVG icons' do
        render_inline(described_class.new(products: products, pagy: pagy))

        # Check SVG icons have aria-hidden
        expect(page).to have_css('svg[aria-hidden="true"]')
      end
    end
  end

  describe 'helper methods' do
    let(:component) do
      products = Product.none
      pagy = Pagy.new(count: 0, page: 1, limit: 25)
      described_class.new(products: products, pagy: pagy)
    end

    describe '#status_badge' do
      it 'returns active badge for active products' do
        product = create(:product, company: company, product_status: :active)
        badge = component.send(:status_badge, product)

        expect(badge).to include('Active')
        expect(badge).to include('bg-green-50')
        expect(badge).to include('text-green-700')
      end

      it 'returns inactive badge for non-active products' do
        product = create(:product, company: company, product_status: :draft)
        badge = component.send(:status_badge, product)

        expect(badge).to include('Inactive')
        expect(badge).to include('bg-gray-50')
        expect(badge).to include('text-gray-600')
      end
    end

    describe '#type_badge' do
      it 'returns blue badge for sellable products' do
        product = create(:product, company: company, product_type: :sellable)
        badge = component.send(:type_badge, product)

        expect(badge).to include('Sellable')
        expect(badge).to include('bg-blue-50')
        expect(badge).to include('text-blue-700')
      end

      it 'returns purple badge for configurable products' do
        product = create(:product, company: company, product_type: :configurable, configuration_type: :variant)
        badge = component.send(:type_badge, product)

        expect(badge).to include('Configurable')
        expect(badge).to include('bg-purple-50')
        expect(badge).to include('text-purple-700')
      end

      it 'returns orange badge for bundle products' do
        product = create(:product, company: company, product_type: :bundle)
        badge = component.send(:type_badge, product)

        expect(badge).to include('Bundle')
        expect(badge).to include('bg-orange-50')
        expect(badge).to include('text-orange-700')
      end
    end

    describe '#sort_icon' do
      it 'returns nil when column is not sorted' do
        component = described_class.new(
          products: Product.none,
          pagy: Pagy.new(count: 0, page: 1, limit: 25),
          current_sort: 'name',
          current_direction: 'asc'
        )

        expect(component.send(:sort_icon, 'sku')).to be_nil
      end

      it 'returns up chevron for ascending sort' do
        component = described_class.new(
          products: Product.none,
          pagy: Pagy.new(count: 0, page: 1, limit: 25),
          current_sort: 'sku',
          current_direction: 'asc'
        )

        icon = component.send(:sort_icon, 'sku')
        expect(icon).to include('svg')
        expect(icon).to include('h-4 w-4')
      end

      it 'returns down chevron for descending sort' do
        component = described_class.new(
          products: Product.none,
          pagy: Pagy.new(count: 0, page: 1, limit: 25),
          current_sort: 'sku',
          current_direction: 'desc'
        )

        icon = component.send(:sort_icon, 'sku')
        expect(icon).to include('svg')
        expect(icon).to include('h-4 w-4')
      end
    end
  end
end
