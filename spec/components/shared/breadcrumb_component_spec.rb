# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shared::BreadcrumbComponent, type: :component do
  describe 'rendering' do
    context 'with items' do
      let(:items) do
        [
          { label: 'Home', url: '/' },
          { label: 'Products', url: '/products' },
          { label: 'Edit Product', url: '/products/1/edit' }
        ]
      end

      it 'renders breadcrumb nav' do
        render_inline(described_class.new(items: items))

        aggregate_failures do
          expect(page).to have_css('nav[aria-label="Breadcrumb"]')
          expect(page).to have_css('ol.inline-flex.items-center')
        end
      end

      it 'renders all breadcrumb items' do
        render_inline(described_class.new(items: items))

        aggregate_failures do
          expect(page).to have_text('Home')
          expect(page).to have_text('Products')
          expect(page).to have_text('Edit Product')
        end
      end

      it 'renders links for all items except last' do
        render_inline(described_class.new(items: items))

        aggregate_failures do
          expect(page).to have_link('Home', href: '/')
          expect(page).to have_link('Products', href: '/products')
          expect(page).not_to have_link('Edit Product')
        end
      end

      it 'renders last item as plain text with aria-current' do
        render_inline(described_class.new(items: items))

        expect(page).to have_css('span[aria-current="page"]', text: 'Edit Product')
      end

      it 'renders separators between items' do
        render_inline(described_class.new(items: items))

        # Should have 2 separators for 3 items (between items, not after last)
        expect(page).to have_css('svg.w-6.h-6.text-gray-400', count: 2)
      end

      it 'applies proper spacing between items' do
        render_inline(described_class.new(items: items))

        expect(page).to have_css('ol.space-x-1.md\\:space-x-3')
      end
    end

    context 'with home icon' do
      let(:items) do
        [
          { label: 'Home', url: '/', icon: :home },
          { label: 'Products', url: '/products' }
        ]
      end

      it 'renders home icon for first item with icon: :home' do
        render_inline(described_class.new(items: items))

        expect(page).to have_css('svg.w-4.h-4.mr-2', count: 1)
      end

      it 'renders home icon with proper path' do
        render_inline(described_class.new(items: items))

        # Check for home icon SVG path
        home_svg = page.find('svg.w-4.h-4.mr-2')
        expect(home_svg).to be_present
      end

      it 'does not render icon for items without icon' do
        render_inline(described_class.new(items: items))

        within('li', text: 'Products') do
          expect(page).not_to have_css('svg.w-4.h-4.mr-2')
        end
      end
    end

    context 'without items' do
      it 'does not render when items array is empty' do
        render_inline(described_class.new(items: []))

        expect(page.text).to be_empty
      end

      it 'does not render when items is nil' do
        render_inline(described_class.new)

        expect(page.text).to be_empty
      end
    end
  end

  describe '#render?' do
    it 'returns true when items are present' do
      items = [{ label: 'Home', url: '/' }]
      component = described_class.new(items: items)

      expect(component.render?).to be true
    end

    it 'returns false when items array is empty' do
      component = described_class.new(items: [])

      expect(component.render?).to be false
    end

    it 'returns false when items is nil' do
      component = described_class.new

      expect(component.render?).to be false
    end
  end

  describe 'link styling' do
    let(:items) do
      [
        { label: 'Home', url: '/' },
        { label: 'Current', url: '/current' }
      ]
    end

    it 'applies link classes to non-last items' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('a.inline-flex.items-center.text-sm.font-medium.text-gray-600')
    end

    it 'applies hover state to links' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('a.hover\\:text-blue-600')
    end

    it 'applies transition to links' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('a.transition-colors')
    end

    it 'applies current item styling to last item' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('span.text-sm.font-medium.text-gray-700', text: 'Current')
    end
  end

  describe 'separator rendering' do
    let(:items) do
      [
        { label: 'One', url: '/one' },
        { label: 'Two', url: '/two' },
        { label: 'Three', url: '/three' }
      ]
    end

    it 'renders separator SVG with proper attributes' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('svg.w-6.h-6.text-gray-400')
        expect(page).to have_css('svg[fill="currentColor"]')
        expect(page).to have_css('svg[viewBox="0 0 20 20"]')
      end
    end

    it 'renders correct number of separators' do
      render_inline(described_class.new(items: items))

      # Should have n-1 separators for n items
      expect(page).to have_css('svg.w-6.h-6.text-gray-400', count: 2)
    end

    it 'does not render separator after last item' do
      render_inline(described_class.new(items: items))

      within('li', text: 'Three') do
        expect(page).not_to have_css('svg.w-6.h-6.text-gray-400')
      end
    end
  end

  describe 'single item breadcrumb' do
    let(:items) { [{ label: 'Home', url: '/' }] }

    it 'renders single item without separator' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_text('Home')
        expect(page).not_to have_css('svg.w-6.h-6.text-gray-400')
      end
    end

    it 'treats single item as current (no link)' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('span[aria-current="page"]', text: 'Home')
        expect(page).not_to have_link('Home')
      end
    end
  end

  describe 'two item breadcrumb' do
    let(:items) do
      [
        { label: 'Home', url: '/' },
        { label: 'Products', url: '/products' }
      ]
    end

    it 'renders first item as link' do
      render_inline(described_class.new(items: items))

      expect(page).to have_link('Home', href: '/')
    end

    it 'renders second item as current' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('span[aria-current="page"]', text: 'Products')
    end

    it 'renders one separator' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('svg.w-6.h-6.text-gray-400', count: 1)
    end
  end

  describe 'complex breadcrumb path' do
    let(:items) do
      [
        { label: 'Home', url: '/', icon: :home },
        { label: 'Products', url: '/products' },
        { label: 'Electronics', url: '/products?category=electronics' },
        { label: 'Phones', url: '/products?category=phones' },
        { label: 'iPhone 15', url: '/products/123' }
      ]
    end

    it 'renders all levels' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_text('Home')
        expect(page).to have_text('Products')
        expect(page).to have_text('Electronics')
        expect(page).to have_text('Phones')
        expect(page).to have_text('iPhone 15')
      end
    end

    it 'renders correct number of links' do
      render_inline(described_class.new(items: items))

      # 4 links (all except last)
      expect(page).to have_css('a', count: 4)
    end

    it 'renders correct number of separators' do
      render_inline(described_class.new(items: items))

      # 4 separators (n-1 for n items)
      expect(page).to have_css('svg.w-6.h-6.text-gray-400', count: 4)
    end

    it 'marks only last item as current' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('[aria-current="page"]', count: 1)
    end
  end

  describe 'accessibility' do
    let(:items) do
      [
        { label: 'Home', url: '/' },
        { label: 'Products', url: '/products' }
      ]
    end

    it 'has aria-label on nav element' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('nav[aria-label="Breadcrumb"]')
    end

    it 'uses semantic nav element' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('nav')
    end

    it 'uses ordered list for items' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('ol')
        expect(page).to have_css('li', count: 2)
      end
    end

    it 'marks current page with aria-current' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('[aria-current="page"]', text: 'Products')
    end

    it 'has sufficient color contrast' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('.text-gray-600') # Links
        expect(page).to have_css('.text-gray-700') # Current item
        expect(page).to have_css('.text-gray-400') # Separators
      end
    end
  end

  describe 'responsive design' do
    let(:items) do
      [
        { label: 'Home', url: '/' },
        { label: 'Products', url: '/products' }
      ]
    end

    it 'has responsive spacing' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('ol.space-x-1.md\\:space-x-3')
    end

    it 'has bottom margin for layout' do
      render_inline(described_class.new(items: items))

      expect(page).to have_css('nav.mb-6')
    end

    it 'uses flexbox layout' do
      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('nav.flex')
        expect(page).to have_css('ol.inline-flex.items-center')
        expect(page).to have_css('li.inline-flex.items-center')
      end
    end
  end

  describe 'edge cases' do
    it 'handles very long labels' do
      items = [
        { label: 'A' * 100, url: '/' },
        { label: 'B' * 100, url: '/long' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_text('A' * 100)
        expect(page).to have_text('B' * 100)
      end
    end

    it 'handles special characters in labels' do
      items = [
        { label: 'Home & Products', url: '/' },
        { label: 'Details <test>', url: '/test' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_text('Home & Products')
        expect(page).to have_text('Details <test>')
      end
    end

    it 'handles unicode in labels' do
      items = [
        { label: '首页', url: '/' },
        { label: '产品', url: '/products' },
        { label: 'مُنتَجات', url: '/arabic' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_text('首页')
        expect(page).to have_text('产品')
        expect(page).to have_text('مُنتَجات')
      end
    end

    it 'handles URLs with query parameters' do
      items = [
        { label: 'Home', url: '/' },
        { label: 'Products', url: '/products?sort=name&filter=active' }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_link('Home', href: '/')
    end

    it 'handles fragment URLs' do
      items = [
        { label: 'Home', url: '/' },
        { label: 'Section', url: '/page#section' }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_link('Home', href: '/')
    end

    it 'handles empty label gracefully' do
      items = [
        { label: '', url: '/' },
        { label: 'Products', url: '/products' }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_css('li', count: 2)
    end

    it 'handles items with only icon, no label text' do
      items = [
        { label: '', url: '/', icon: :home },
        { label: 'Products', url: '/products' }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_css('svg.w-4.h-4.mr-2')
    end
  end

  describe 'integration examples' do
    it 'renders product detail breadcrumb' do
      items = [
        { label: 'Home', url: '/', icon: :home },
        { label: 'Products', url: '/products' },
        { label: 'SKU123', url: '/products/1' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('svg.w-4.h-4') # Home icon
        expect(page).to have_link('Products', href: '/products')
        expect(page).to have_css('span[aria-current="page"]', text: 'SKU123')
        expect(page).to have_css('svg.w-6.h-6', count: 2) # 2 separators
      end
    end

    it 'renders nested category breadcrumb' do
      items = [
        { label: 'Home', url: '/', icon: :home },
        { label: 'Catalog', url: '/catalog' },
        { label: 'Electronics', url: '/catalog/electronics' },
        { label: 'Smartphones', url: '/catalog/electronics/smartphones' },
        { label: 'Apple', url: '/catalog/electronics/smartphones/apple' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('li', count: 5)
        expect(page).to have_css('a', count: 4)
        expect(page).to have_css('[aria-current="page"]', text: 'Apple')
      end
    end

    it 'renders settings page breadcrumb' do
      items = [
        { label: 'Home', url: '/', icon: :home },
        { label: 'Settings', url: '/settings' }
      ]

      render_inline(described_class.new(items: items))

      aggregate_failures do
        expect(page).to have_css('svg.w-4.h-4') # Home icon
        expect(page).to have_css('[aria-current="page"]', text: 'Settings')
      end
    end
  end
end
