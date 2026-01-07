# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SidebarComponent, type: :component do
  let(:company) { create(:company, name: 'Test Company') }
  let(:items) do
    [
      { name: 'Products', path: '/products', icon_path: '<path d="M1 1"/>' },
      { name: 'Storages', path: '/storages', icon_path: '<path d="M2 2"/>' },
      { name: 'Catalogs', path: '/catalogs', icon_path: '<path d="M3 3"/>' }
    ]
  end

  describe 'rendering' do
    it 'renders component' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      expect(page).to have_text('Potlift8')
    end

    it 'renders all navigation items' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      expect(page).to have_link('Products', href: '/products')
      expect(page).to have_link('Storages', href: '/storages')
      expect(page).to have_link('Catalogs', href: '/catalogs')
    end

    it 'renders company name' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      expect(page).to have_text('Test Company')
      expect(page).to have_text('Current workspace')
    end
  end

  describe 'active state' do
    it 'highlights active item with bg-gray-800 class' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      # Scope to desktop sidebar to avoid ambiguous match (both desktop and mobile render same links)
      products_link = page.find('.lg\\:fixed a', text: 'Products', match: :first)
      expect(products_link[:class]).to include('bg-gray-800')
      expect(products_link[:class]).to include('text-white')
    end

    it 'does not highlight inactive items' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      # Scope to desktop sidebar to avoid ambiguous match
      storages_link = page.find('.lg\\:fixed a', text: 'Storages', match: :first)
      # Inactive items have hover:bg-gray-800 but not bg-gray-800 as standalone class
      expect(storages_link[:class]).not_to match(/(?<!\S)bg-gray-800(?!\S)/)
      expect(storages_link[:class]).to include('text-gray-400')
    end

    context 'with nested paths' do
      it 'highlights parent item for nested path' do
        render_inline(described_class.new(items: items, active_path: '/products/123/edit', company: company))

        # Scope to desktop sidebar to avoid ambiguous match
        products_link = page.find('.lg\\:fixed a', text: 'Products', match: :first)
        expect(products_link[:class]).to include('bg-gray-800')
      end
    end
  end

  describe 'icon rendering' do
    it 'renders SVG icons for each item' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      # Check that SVGs are present (ViewComponent renders raw HTML)
      # 3 items in desktop + 3 in mobile + 1 close button SVG = 7
      expect(page).to have_css('svg', count: 7)
    end

    it 'applies icon color classes based on active state' do
      component = described_class.new(items: items, active_path: '/products', company: company)

      # Test active icon classes
      active_icon_classes = component.send(:icon_classes, items[0])
      expect(active_icon_classes).to include('text-white')

      # Test inactive icon classes
      inactive_icon_classes = component.send(:icon_classes, items[1])
      expect(inactive_icon_classes).to include('text-gray-400')
    end
  end

  describe 'responsive behavior' do
    it 'renders both desktop and mobile sidebars' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      # Desktop sidebar (hidden lg:flex)
      expect(page).to have_css('.lg\\:fixed')

      # Mobile sidebar (lg:hidden)
      expect(page).to have_css('[data-controller="mobile-sidebar"]')
    end

    it 'includes mobile sidebar controller' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      expect(page).to have_css('[data-controller="mobile-sidebar"]')
      expect(page).to have_css('[data-mobile-sidebar-target="overlay"]')
    end
  end

  describe 'helper methods' do
    let(:component) { described_class.new(items: items, active_path: '/products', company: company) }

    describe '#item_active?' do
      it 'returns true for active item' do
        expect(component.send(:item_active?, items[0])).to be true
      end

      it 'returns false for inactive item' do
        expect(component.send(:item_active?, items[1])).to be false
      end

      it 'returns true for nested active paths' do
        component = described_class.new(items: items, active_path: '/products/123', company: company)
        expect(component.send(:item_active?, items[0])).to be true
      end
    end

    describe '#item_classes' do
      it 'returns active classes for active item' do
        classes = component.send(:item_classes, items[0])

        expect(classes).to include('bg-gray-800')
        expect(classes).to include('text-white')
        expect(classes).to include('group flex gap-x-3')
      end

      it 'returns inactive classes for inactive item' do
        classes = component.send(:item_classes, items[1])

        expect(classes).to include('text-gray-400')
        expect(classes).to include('hover:text-white')
        # Should have hover:bg-gray-800 but not bg-gray-800 as standalone class
        expect(classes).to include('hover:bg-gray-800')
        expect(classes).not_to match(/(?<!\S)bg-gray-800(?!\S)/)
      end
    end

    describe '#icon_classes' do
      it 'returns active icon classes for active item' do
        classes = component.send(:icon_classes, items[0])

        expect(classes).to include('text-white')
        expect(classes).to include('h-6 w-6')
      end

      it 'returns inactive icon classes for inactive item' do
        classes = component.send(:icon_classes, items[1])

        expect(classes).to include('text-gray-400')
        expect(classes).to include('group-hover:text-white')
      end
    end
  end

  describe 'accessibility' do
    it 'has proper semantic HTML structure' do
      render_inline(described_class.new(items: items, active_path: '/products', company: company))

      expect(page).to have_css('nav')
      expect(page).to have_css('ul[role="list"]')
    end
  end
end
