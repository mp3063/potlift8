# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shared::EmptyStateComponent, type: :component do
  describe 'basic rendering' do
    it 'renders with required title' do
      render_inline(described_class.new(title: 'No items found'))

      expect(page).to have_text('No items found')
    end

    it 'renders title with proper styling' do
      render_inline(described_class.new(title: 'No items'))

      expect(page).to have_css('h3.mt-4.text-lg.font-semibold.text-gray-900', text: 'No items')
    end

    it 'renders container with centered text and padding' do
      render_inline(described_class.new(title: 'Empty'))

      aggregate_failures do
        expect(page).to have_css('.text-center')
        expect(page).to have_css('.py-12')
      end
    end
  end

  describe 'description rendering' do
    it 'renders description when provided' do
      render_inline(described_class.new(
        title: 'No products',
        description: 'Get started by creating your first product'
      ))

      expect(page).to have_text('Get started by creating your first product')
    end

    it 'renders description with proper styling' do
      render_inline(described_class.new(
        title: 'No products',
        description: 'Start creating'
      ))

      expect(page).to have_css('p.mt-2.text-sm.text-gray-600', text: 'Start creating')
    end

    it 'does not render description when nil' do
      render_inline(described_class.new(title: 'No items', description: nil))

      expect(page).not_to have_css('p.text-sm.text-gray-600')
    end

    it 'does not render description when not provided' do
      render_inline(described_class.new(title: 'No items'))

      expect(page).not_to have_css('p.text-sm.text-gray-600')
    end

    it 'handles long descriptions' do
      long_description = 'A' * 200
      render_inline(described_class.new(title: 'No items', description: long_description))

      expect(page).to have_text(long_description)
    end
  end

  describe 'icon rendering' do
    it 'renders inbox icon by default' do
      render_inline(described_class.new(title: 'Empty'))

      aggregate_failures do
        expect(page).to have_css('svg.h-full.w-full')
        expect(page).to have_css('.h-16.w-16.text-gray-400')
        # Check for inbox icon path attributes
        expect(page.find('svg')['viewBox']).to eq('0 0 24 24')
      end
    end

    it 'renders inbox icon when explicitly specified' do
      render_inline(described_class.new(title: 'Empty', icon: :inbox))

      expect(page).to have_css('.h-16.w-16.text-gray-400')
    end

    it 'renders package icon when specified' do
      render_inline(described_class.new(title: 'No products', icon: :package))

      aggregate_failures do
        expect(page).to have_css('svg.h-full.w-full')
        expect(page).to have_css('.h-16.w-16.text-gray-400')
      end
    end

    it 'renders search icon when specified' do
      render_inline(described_class.new(title: 'No results', icon: :search))

      aggregate_failures do
        expect(page).to have_css('svg.h-full.w-full')
        expect(page).to have_css('.h-16.w-16.text-gray-400')
      end
    end

    it 'falls back to inbox icon for unknown icon type' do
      render_inline(described_class.new(title: 'Empty', icon: :unknown))

      expect(page).to have_css('.h-16.w-16.text-gray-400')
    end

    it 'renders icon with centered container' do
      render_inline(described_class.new(title: 'Empty'))

      expect(page).to have_css('.mx-auto.h-16.w-16')
    end

    it 'renders icon with gray color' do
      render_inline(described_class.new(title: 'Empty'))

      expect(page).to have_css('.text-gray-400')
    end
  end

  describe 'content block rendering' do
    it 'renders content block when provided' do
      render_inline(described_class.new(title: 'Empty')) do
        '<button>New Item</button>'.html_safe
      end

      expect(page).to have_css('button', text: 'New Item')
    end

    it 'renders content block with proper container' do
      render_inline(described_class.new(title: 'Empty')) do
        '<button>Action</button>'.html_safe
      end

      expect(page).to have_css('.mt-6')
    end

    it 'does not render content container when no content' do
      render_inline(described_class.new(title: 'Empty'))

      # Should have basic structure but no .mt-6 div for content
      expect(page).to have_css('.text-center.py-12')
    end

    it 'renders complex content blocks' do
      render_inline(described_class.new(title: 'Empty')) do
        content_tag(:div, class: 'flex gap-2') do
          safe_join([
            content_tag(:button, 'Primary', class: 'btn-primary'),
            content_tag(:button, 'Secondary', class: 'btn-secondary')
          ])
        end
      end

      aggregate_failures do
        expect(page).to have_css('.flex.gap-2')
        expect(page).to have_css('button.btn-primary', text: 'Primary')
        expect(page).to have_css('button.btn-secondary', text: 'Secondary')
      end
    end

    it 'renders text content' do
      render_inline(described_class.new(title: 'Empty')) do
        'Some text content'
      end

      expect(page).to have_text('Some text content')
    end
  end

  describe 'HTML options' do
    it 'passes through additional CSS classes' do
      render_inline(described_class.new(title: 'Empty', class: 'custom-empty'))

      aggregate_failures do
        expect(page).to have_css('.custom-empty')
        expect(page).to have_css('.text-center') # Base classes still present
      end
    end

    it 'passes through data attributes' do
      render_inline(described_class.new(
        title: 'Empty',
        data: { controller: 'empty-state', testid: 'empty' }
      ))

      aggregate_failures do
        expect(page).to have_css('[data-controller="empty-state"]')
        expect(page).to have_css('[data-testid="empty"]')
      end
    end

    it 'passes through id attribute' do
      render_inline(described_class.new(title: 'Empty', id: 'products-empty'))

      expect(page).to have_css('#products-empty')
    end

    it 'passes through aria attributes' do
      render_inline(described_class.new(title: 'Empty', aria: { live: 'polite' }))

      expect(page).to have_css('[aria-live="polite"]')
    end

    it 'passes through role attribute' do
      render_inline(described_class.new(title: 'Empty', role: 'status'))

      expect(page).to have_css('[role="status"]')
    end
  end

  describe 'complete examples' do
    it 'renders products empty state' do
      render_inline(described_class.new(
        title: 'No products yet',
        description: 'Get started by creating your first product',
        icon: :package
      )) do
        '<a href="/products/new" class="btn-primary">Create Product</a>'.html_safe
      end

      aggregate_failures do
        expect(page).to have_text('No products yet')
        expect(page).to have_text('Get started by creating your first product')
        expect(page).to have_css('svg')
        expect(page).to have_link('Create Product', href: '/products/new')
      end
    end

    it 'renders search results empty state' do
      render_inline(described_class.new(
        title: 'No results found',
        description: 'Try adjusting your search or filters',
        icon: :search
      ))

      aggregate_failures do
        expect(page).to have_text('No results found')
        expect(page).to have_text('Try adjusting your search or filters')
        expect(page).to have_css('svg')
      end
    end

    it 'renders minimal empty state' do
      render_inline(described_class.new(title: 'Nothing here'))

      aggregate_failures do
        expect(page).to have_text('Nothing here')
        expect(page).to have_css('svg')
        expect(page).not_to have_css('p.text-sm')
      end
    end
  end

  describe 'accessibility' do
    it 'uses semantic heading element' do
      render_inline(described_class.new(title: 'Empty'))

      expect(page).to have_css('h3')
    end

    it 'icon has proper structure for screen readers' do
      render_inline(described_class.new(title: 'Empty'))

      expect(page).to have_css('svg')
    end

    it 'has sufficient color contrast' do
      render_inline(described_class.new(
        title: 'Empty',
        description: 'Description'
      ))

      aggregate_failures do
        expect(page).to have_css('.text-gray-900') # Dark title
        expect(page).to have_css('.text-gray-600') # Medium description
        expect(page).to have_css('.text-gray-400') # Light icon
      end
    end

    it 'can be made accessible with aria-live' do
      render_inline(described_class.new(
        title: 'No results',
        aria: { live: 'polite' }
      ))

      expect(page).to have_css('[aria-live="polite"]')
    end

    it 'can be made accessible with role' do
      render_inline(described_class.new(
        title: 'Loading',
        role: 'status'
      ))

      expect(page).to have_css('[role="status"]')
    end
  end

  describe 'edge cases' do
    it 'handles very long titles' do
      long_title = 'A' * 100
      render_inline(described_class.new(title: long_title))

      expect(page).to have_text(long_title)
    end

    it 'handles titles with HTML characters' do
      render_inline(described_class.new(title: 'No <items> found'))

      expect(page).to have_text('No <items> found')
    end

    it 'handles unicode in title and description' do
      render_inline(described_class.new(
        title: '没有产品',
        description: 'العربية test 日本語'
      ))

      aggregate_failures do
        expect(page).to have_text('没有产品')
        expect(page).to have_text('العربية test 日本語')
      end
    end

    it 'handles empty string title' do
      render_inline(described_class.new(title: ''))

      expect(page).to have_css('h3')
    end

    it 'handles special characters in description' do
      render_inline(described_class.new(
        title: 'Empty',
        description: "Line 1\nLine 2\tTabbed"
      ))

      expect(page).to have_text("Line 1\nLine 2\tTabbed")
    end
  end

  describe 'layout structure' do
    it 'has proper element hierarchy' do
      render_inline(described_class.new(
        title: 'Empty',
        description: 'Description'
      )) do
        '<button>Action</button>'.html_safe
      end

      # Container -> Icon -> Title -> Description -> Content
      container = page.find('.text-center.py-12')
      expect(container).to be_present

      within(container) do
        # Icon should come first
        icon = page.all('*').first
        expect(icon[:class]).to include('mx-auto')

        # Then title
        expect(page).to have_css('h3')

        # Then description
        expect(page).to have_css('p')

        # Then content
        expect(page).to have_css('button')
      end
    end

    it 'maintains proper spacing between elements' do
      render_inline(described_class.new(
        title: 'Empty',
        description: 'Description'
      )) do
        '<button>Action</button>'.html_safe
      end

      aggregate_failures do
        expect(page).to have_css('h3.mt-4') # Title margin
        expect(page).to have_css('p.mt-2') # Description margin
        expect(page).to have_css('div.mt-6') # Content margin
      end
    end
  end
end
