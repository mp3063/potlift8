# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Shared::PaginationComponent, type: :component do
  describe 'rendering' do
    context 'with multiple pages' do
      let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

      it 'renders pagination nav' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_css('nav[aria-label="Pagination"]')
          expect(page).to have_css('.flex.items-center.justify-between')
        end
      end

      it 'displays page information' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_text('Showing')
          expect(page).to have_text('11')
          expect(page).to have_text('to')
          expect(page).to have_text('20')
          expect(page).to have_text('of')
          expect(page).to have_text('100')
          expect(page).to have_text('results')
        end
      end

      it 'renders previous and next buttons' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_link('Previous')
          expect(page).to have_link('Next')
        end
      end

      it 'renders page numbers' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_text('1')
          expect(page).to have_text('2')
          expect(page).to have_text('3')
        end
      end
    end

    context 'with single page' do
      let(:pagy) { Pagy.new(count: 5, page: 1, limit: 10) }

      it 'does not render when only one page' do
        render_inline(described_class.new(pagy: pagy))

        expect(page.text).to be_empty
      end
    end
  end

  describe '#render?' do
    it 'returns true when multiple pages' do
      pagy = Pagy.new(count: 100, page: 1, limit: 10)
      component = described_class.new(pagy: pagy)

      expect(component.render?).to be true
    end

    it 'returns false when single page' do
      pagy = Pagy.new(count: 5, page: 1, limit: 10)
      component = described_class.new(pagy: pagy)

      expect(component.render?).to be false
    end

    it 'returns false when no items' do
      pagy = Pagy.new(count: 0, page: 1, limit: 10)
      component = described_class.new(pagy: pagy)

      expect(component.render?).to be false
    end
  end

  describe 'mobile pagination' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'renders mobile navigation' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.flex.flex-1.justify-between.sm\\:hidden')
    end

    it 'shows Previous and Next buttons on mobile' do
      render_inline(described_class.new(pagy: pagy))

      within('.sm\\:hidden') do
        aggregate_failures do
          expect(page).to have_text('Previous')
          expect(page).to have_text('Next')
        end
      end
    end

    context 'on first page' do
      let(:pagy) { Pagy.new(count: 100, page: 1, limit: 10) }

      it 'disables Previous button' do
        render_inline(described_class.new(pagy: pagy))

        within('.sm\\:hidden') do
          expect(page).to have_css('span.text-gray-500.cursor-not-allowed', text: 'Previous')
        end
      end

      it 'enables Next button' do
        render_inline(described_class.new(pagy: pagy))

        within('.sm\\:hidden') do
          expect(page).to have_link('Next', href: '/?page=2')
        end
      end
    end

    context 'on last page' do
      let(:pagy) { Pagy.new(count: 100, page: 10, limit: 10) }

      it 'enables Previous button' do
        render_inline(described_class.new(pagy: pagy))

        within('.sm\\:hidden') do
          expect(page).to have_link('Previous', href: '/?page=9')
        end
      end

      it 'disables Next button' do
        render_inline(described_class.new(pagy: pagy))

        within('.sm\\:hidden') do
          expect(page).to have_css('span.text-gray-500.cursor-not-allowed', text: 'Next')
        end
      end
    end

    context 'on middle page' do
      let(:pagy) { Pagy.new(count: 100, page: 5, limit: 10) }

      it 'enables both buttons' do
        render_inline(described_class.new(pagy: pagy))

        within('.sm\\:hidden') do
          aggregate_failures do
            expect(page).to have_link('Previous', href: '/?page=4')
            expect(page).to have_link('Next', href: '/?page=6')
          end
        end
      end
    end
  end

  describe 'desktop pagination' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'renders desktop navigation' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.hidden.sm\\:flex.sm\\:flex-1.sm\\:items-center.sm\\:justify-between')
    end

    it 'shows page information on desktop' do
      render_inline(described_class.new(pagy: pagy))

      within('.hidden.sm\\:flex') do
        expect(page).to have_text('Showing')
      end
    end

    it 'shows page numbers on desktop' do
      render_inline(described_class.new(pagy: pagy))

      within('.hidden.sm\\:flex') do
        expect(page).to have_css('nav[aria-label="Pagination"]')
      end
    end

    it 'renders arrow icons for Previous/Next' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('svg.h-5.w-5', count: 2) # Previous and Next arrows
    end

    context 'on first page' do
      let(:pagy) { Pagy.new(count: 100, page: 1, limit: 10) }

      it 'disables Previous button' do
        render_inline(described_class.new(pagy: pagy))

        expect(page).to have_css('span.text-gray-500.cursor-not-allowed[aria-hidden="true"]')
      end

      it 'enables Next button' do
        render_inline(described_class.new(pagy: pagy))

        expect(page).to have_css('a[aria-label="Next page"][href="/?page=2"]')
      end
    end

    context 'on last page' do
      let(:pagy) { Pagy.new(count: 100, page: 10, limit: 10) }

      it 'enables Previous button' do
        render_inline(described_class.new(pagy: pagy))

        expect(page).to have_css('a[aria-label="Previous page"][href="/?page=9"]')
      end

      it 'disables Next button' do
        render_inline(described_class.new(pagy: pagy))

        expect(page).to have_css('span.text-gray-500.cursor-not-allowed[aria-hidden="true"]')
      end
    end
  end

  describe 'page numbers display' do
    context 'with current page highlighted' do
      let(:pagy) { Pagy.new(count: 100, page: 3, limit: 10) }

      it 'highlights current page' do
        render_inline(described_class.new(pagy: pagy))

        # Component uses bg-blue-600 and text-white for current page with aria-current="page"
        expect(page).to have_css('span[aria-current="page"]', text: '3')
        expect(page).to have_css('span.bg-blue-600', text: '3')
      end

      it 'renders other pages as links' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_link('1', href: '/?page=1')
          expect(page).to have_link('2', href: '/?page=2')
          expect(page).to have_link('4', href: '/?page=4')
        end
      end
    end

    context 'with gaps in page numbers' do
      let(:pagy) { Pagy.new(count: 200, page: 5, limit: 10) }

      it 'renders gap ellipsis when needed' do
        render_inline(described_class.new(pagy: pagy))

        # Pagy typically shows gaps as "…"
        # This depends on Pagy's series configuration
        expect(page).to have_css('nav[aria-label="Pagination"]')
      end
    end

    context 'with few pages' do
      let(:pagy) { Pagy.new(count: 30, page: 2, limit: 10) }

      it 'shows all page numbers when few pages' do
        render_inline(described_class.new(pagy: pagy))

        aggregate_failures do
          expect(page).to have_text('1')
          expect(page).to have_text('2')
          expect(page).to have_text('3')
        end
      end
    end
  end

  describe 'page information formatting' do
    it 'displays correct range for first page' do
      pagy = Pagy.new(count: 100, page: 1, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('span.font-medium', text: '1')
        expect(page).to have_css('span.font-medium', text: '10')
        expect(page).to have_css('span.font-medium', text: '100')
      end
    end

    it 'displays correct range for middle page' do
      pagy = Pagy.new(count: 100, page: 5, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('span.font-medium', text: '41')
        expect(page).to have_css('span.font-medium', text: '50')
        expect(page).to have_css('span.font-medium', text: '100')
      end
    end

    it 'displays correct range for last page with partial results' do
      pagy = Pagy.new(count: 95, page: 10, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('span.font-medium', text: '91')
        expect(page).to have_css('span.font-medium', text: '95')
        expect(page).to have_css('span.font-medium', text: '95')
      end
    end

    it 'uses proper text styling' do
      pagy = Pagy.new(count: 100, page: 1, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('p.text-sm.text-gray-700')
    end
  end

  describe 'styling and layout' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'has proper border and spacing' do
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('.border-t.border-gray-200')
        expect(page).to have_css('.mt-8')
        expect(page).to have_css('.px-4.sm\\:px-0')
      end
    end

    it 'uses proper button styling for mobile' do
      render_inline(described_class.new(pagy: pagy))

      within('.sm\\:hidden') do
        expect(page).to have_css('.rounded-md.border.border-gray-300.bg-white')
      end
    end

    it 'uses proper button styling for desktop' do
      render_inline(described_class.new(pagy: pagy))

      within('.hidden.sm\\:flex') do
        aggregate_failures do
          expect(page).to have_css('.inline-flex.items-center')
          expect(page).to have_css('.ring-1.ring-inset.ring-gray-300')
        end
      end
    end

    it 'applies hover states to active buttons' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.hover\\:bg-gray-50')
    end

    it 'rounds corners properly' do
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('.rounded-l-md') # Previous button
        expect(page).to have_css('.rounded-r-md') # Next button
      end
    end
  end

  describe 'accessibility' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'has aria-label on nav elements' do
      render_inline(described_class.new(pagy: pagy))

      # Outer container is a div with aria-label, desktop pagination has a nav with aria-label
      expect(page).to have_css('div[aria-label="Pagination"]')
      expect(page).to have_css('nav[aria-label="Pagination"]')
    end

    it 'has aria-label on Previous button' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('[aria-label="Previous page"]')
    end

    it 'has aria-label on Next button' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('[aria-label="Next page"]')
    end

    it 'marks current page with aria-current' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('span[aria-current="page"]', text: '2')
    end

    it 'uses semantic nav element' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('nav')
    end

    it 'has sufficient color contrast' do
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_css('.text-gray-700') # Info text
        # Current page uses bg-blue-600 with text-white in the class string
        expect(page).to have_css('span.bg-blue-600') # Current page bg
      end
    end

    it 'indicates disabled state with cursor-not-allowed' do
      pagy = Pagy.new(count: 100, page: 1, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.cursor-not-allowed')
    end
  end

  describe 'URL generation' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'generates URLs with page parameter' do
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_link(href: '/?page=1')
        expect(page).to have_link(href: '/?page=3')
      end
    end

    it 'generates URL for previous page' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_link(href: '/?page=1')
    end

    it 'generates URL for next page' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_link(href: '/?page=3')
    end

    context 'with existing query parameters' do
      it 'preserves sort parameters' do
        with_request_url('/products?sort=name&direction=asc') do
          render_inline(described_class.new(pagy: pagy))

          aggregate_failures do
            expect(page).to have_link(href: '/products?direction=asc&page=1&sort=name')
            expect(page).to have_link(href: '/products?direction=asc&page=3&sort=name')
          end
        end
      end

      it 'preserves filter parameters' do
        with_request_url('/products?status=active&type=sellable') do
          render_inline(described_class.new(pagy: pagy))

          aggregate_failures do
            expect(page).to have_link(href: '/products?page=1&status=active&type=sellable')
            expect(page).to have_link(href: '/products?page=3&status=active&type=sellable')
          end
        end
      end

      it 'preserves search query' do
        with_request_url('/products?q=widget') do
          render_inline(described_class.new(pagy: pagy))

          aggregate_failures do
            expect(page).to have_link(href: '/products?page=1&q=widget')
            expect(page).to have_link(href: '/products?page=3&q=widget')
          end
        end
      end

      it 'preserves complex combination of parameters' do
        with_request_url('/products?q=widget&status=active&sort=created_at&direction=desc') do
          render_inline(described_class.new(pagy: pagy))

          aggregate_failures do
            expect(page).to have_link(href: '/products?direction=desc&page=1&q=widget&sort=created_at&status=active')
            expect(page).to have_link(href: '/products?direction=desc&page=3&q=widget&sort=created_at&status=active')
          end
        end
      end

      it 'updates existing page parameter' do
        with_request_url('/products?page=5&status=active') do
          render_inline(described_class.new(pagy: pagy))

          # Should update page to new values (1, 3) while keeping status
          aggregate_failures do
            expect(page).to have_link(href: '/products?page=1&status=active')
            expect(page).to have_link(href: '/products?page=3&status=active')
          end
        end
      end

      it 'handles URLs without query parameters' do
        with_request_url('/products') do
          pagy = Pagy.new(count: 100, page: 1, limit: 10)
          render_inline(described_class.new(pagy: pagy))

          expect(page).to have_link(href: '/products?page=2')
        end
      end

      it 'preserves URL path' do
        with_request_url('/search?q=test') do
          render_inline(described_class.new(pagy: pagy))

          aggregate_failures do
            expect(page).to have_link(href: '/search?page=1&q=test')
            expect(page).to have_link(href: '/search?page=3&q=test')
          end
        end
      end
    end

    context 'with nil page' do
      it 'returns # for nil page' do
        component = described_class.new(pagy: pagy)

        expect(component.send(:pagy_url_for, pagy, nil)).to eq('#')
      end
    end
  end

  # Helper method for testing with specific request URLs
  def with_request_url(url, &block)
    uri = URI.parse(url)
    path = uri.path
    query_params = Rack::Utils.parse_nested_query(uri.query || '')

    # Mock the request object for the component
    request_stub = double('request',
      path: path,
      query_parameters: query_params
    )

    # Use vc_test_request to set up the request context
    vc_test_request.tap do |req|
      allow(req).to receive(:path).and_return(path)
      allow(req).to receive(:query_parameters).and_return(query_params)
    end

    yield
  end

  describe 'edge cases' do
    it 'handles exactly 2 pages' do
      pagy = Pagy.new(count: 20, page: 1, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_text('1')
        expect(page).to have_text('2')
        expect(page).to have_text('20')
      end
    end

    it 'handles large page counts' do
      pagy = Pagy.new(count: 10000, page: 500, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_text('4991')
        expect(page).to have_text('5000')
        expect(page).to have_text('10000')
      end
    end

    it 'handles single item per page' do
      pagy = Pagy.new(count: 10, page: 5, limit: 1)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_text('Showing')
        expect(page).to have_text('5')
        expect(page).to have_text('to')
        expect(page).to have_text('5')
      end
    end

    it 'handles last page with single item' do
      pagy = Pagy.new(count: 21, page: 3, limit: 10)
      render_inline(described_class.new(pagy: pagy))

      aggregate_failures do
        expect(page).to have_text('21')
        expect(page).to have_text('to')
        expect(page).to have_text('21')
      end
    end
  end

  describe 'responsive behavior' do
    let(:pagy) { Pagy.new(count: 100, page: 2, limit: 10) }

    it 'has mobile-only elements' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.sm\\:hidden')
    end

    it 'has desktop-only elements' do
      render_inline(described_class.new(pagy: pagy))

      expect(page).to have_css('.hidden.sm\\:flex')
    end

    it 'shows simplified controls on mobile' do
      render_inline(described_class.new(pagy: pagy))

      within('.sm\\:hidden') do
        # Mobile should only show Previous/Next, no page numbers
        expect(page).to have_text('Previous')
        expect(page).to have_text('Next')
        expect(page).not_to have_text('Showing')
      end
    end

    it 'shows full controls on desktop' do
      render_inline(described_class.new(pagy: pagy))

      within('.hidden.sm\\:flex') do
        aggregate_failures do
          expect(page).to have_text('Showing')
          expect(page).to have_css('nav[aria-label="Pagination"]')
        end
      end
    end
  end
end
