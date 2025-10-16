# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Global Search', type: :system do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Mock authentication
  before do
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(
      { id: user.id, email: user.email, name: user.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return(
      { id: company.id, code: company.code, name: company.name }
    )
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe "opening search modal" do
    before do
      visit root_path
    end

    it "opens search modal with keyboard shortcut", js: true do
      # Modal should be hidden initially
      expect(page).to have_css('[data-global-search-target="modal"].hidden')

      # Press CMD+K (use 'k' with metaKey modifier)
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Modal should be visible
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)')

      # Input should be focused
      expect(page).to have_css('input[data-global-search-target="input"]:focus')
    end

    it "locks body scroll when modal is open", js: true do
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Body should have overflow hidden
      overflow = page.evaluate_script("document.body.style.overflow")
      expect(overflow).to eq('hidden')
    end

    it "shows initial instructions in modal", js: true do
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Type at least 2 characters to search')
      end
    end
  end

  describe "closing search modal" do
    before do
      visit root_path
    end

    it "closes modal with Escape key", js: true do
      # Open modal
      page.execute_script("
        const openEvent = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(openEvent);
      ")

      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)')

      # Press Escape
      page.execute_script("
        const escEvent = new KeyboardEvent('keydown', {
          key: 'Escape',
          bubbles: true
        });
        document.dispatchEvent(escEvent);
      ")

      # Modal should be hidden
      expect(page).to have_css('[data-global-search-target="modal"].hidden')
    end

    it "closes modal with close button click", js: true do
      # Open modal
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Click close button
      within('[data-global-search-target="modal"]') do
        find('button[aria-label="Close search"]').click
      end

      # Modal should be hidden
      expect(page).to have_css('[data-global-search-target="modal"].hidden')
    end

    it "restores body scroll when closed", js: true do
      # Open modal
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Close modal
      page.execute_script("
        const escEvent = new KeyboardEvent('keydown', {
          key: 'Escape',
          bubbles: true
        });
        document.dispatchEvent(escEvent);
      ")

      # Body overflow should be restored
      overflow = page.evaluate_script("document.body.style.overflow")
      expect(overflow).to eq('')
    end

    it "clears input when closed", js: true do
      # Open modal and type
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      fill_in 'search', with: 'test query'

      # Close modal
      find('button[aria-label="Close search"]').click

      # Reopen modal
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Input should be empty
      expect(find('input[data-global-search-target="input"]').value).to eq('')
    end
  end

  describe "searching across all scopes" do
    let!(:product) { create(:product, company: company, name: 'iPhone 15 Pro', sku: 'IP-15-PRO') }
    let!(:storage) { create(:storage, company: company, name: 'Main Warehouse', code: 'WH-MAIN') }
    let!(:label) { create(:label, company: company, name: 'Electronics', code: 'electronics') }
    let!(:product_attribute) { create(:product_attribute, company: company, name: 'Price', code: 'price') }
    let!(:catalog) { create(:catalog, company: company, name: 'Webshop EU', code: 'web-eu') }

    before do
      visit root_path
      # Open search modal
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "searches across all scopes and displays results", js: true do
      # Type search query
      fill_in 'search', with: 'test'

      # Wait for debounce and API call (300ms + request time)
      sleep 0.5

      # Should show results grouped by category
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3', text: 'Products')
        expect(page).to have_link(href: /\/products\/#{product.id}/)
        expect(page).to have_text(product.name)
      end
    end

    it "shows loading state during search", js: true do
      fill_in 'search', with: 'test'

      # Should show loading immediately
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('svg.animate-spin')
        expect(page).to have_text('Searching...')
      end
    end

    it "displays product results with correct format", js: true do
      fill_in 'search', with: 'iPhone'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        # Should show product name, SKU, and badge
        expect(page).to have_text('iPhone 15 Pro')
        expect(page).to have_text('IP-15-PRO')
        expect(page).to have_css('.bg-blue-100') # Product type badge
      end
    end

    it "displays storage results correctly", js: true do
      fill_in 'search', with: 'Warehouse'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3', text: 'Storage Locations')
        expect(page).to have_text('Main Warehouse')
        expect(page).to have_text('WH-MAIN')
      end
    end

    it "shows empty state when no results found", js: true do
      fill_in 'search', with: 'nonexistent search query xyz'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        expect(page).to have_css('svg') # Sad face icon
        expect(page).to have_text('No results found')
        expect(page).to have_text('Try searching with different keywords')
      end
    end
  end

  describe "recent searches" do
    before do
      visit root_path
      # Perform a search to store it in recent searches
      visit search_path(q: 'iPhone', scope: 'all')

      # Return to home and open modal
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "loads recent searches when modal opens", js: true do
      sleep 0.3 # Wait for async load

      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3', text: 'Recent Searches')
        expect(page).to have_text('iPhone')
      end
    end

    it "fills input when clicking recent search", js: true do
      sleep 0.3

      within('[data-global-search-target="results"]') do
        find('button[data-action*="fillSearch"]', text: 'iPhone').click
      end

      sleep 0.5 # Wait for search

      # Should perform search and show results
      expect(find('input[data-global-search-target="input"]').value).to eq('iPhone')
    end
  end

  describe "navigation to results" do
    let!(:product) { create(:product, company: company, name: 'Test Product', sku: 'TEST-1') }

    before do
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "navigates to product page when clicking result", js: true do
      fill_in 'search', with: 'Test Product'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        click_link href: /\/products\/#{product.id}/
      end

      expect(page).to have_current_path(product_path(product))
    end
  end

  describe "multi-tenancy isolation" do
    let(:other_company) { create(:company) }
    let!(:own_product) { create(:product, company: company, name: 'Our Product', sku: 'OUR-1') }
    let!(:other_product) { create(:product, company: other_company, name: 'Their Product', sku: 'THEIR-1') }

    before do
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "only shows results from current company", js: true do
      fill_in 'search', with: 'Product'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Our Product')
        expect(page).not_to have_text('Their Product')
      end
    end
  end

  describe "debouncing" do
    before do
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "debounces search input to avoid excessive API calls", js: true do
      # Type multiple characters quickly
      input = find('input[data-global-search-target="input"]')
      input.send_keys('t')
      input.send_keys('e')
      input.send_keys('s')
      input.send_keys('t')

      # Should only show loading after debounce period
      # Wait less than debounce time
      sleep 0.2

      # Should still show loading or initial state (not results yet)
      # Full results should appear after full debounce + API call
      sleep 0.3

      # Now results should be loaded
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3, .text-center')
      end
    end
  end

  describe "error handling" do
    before do
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "shows error state when API call fails", js: true do
      # Mock fetch to fail
      page.execute_script("
        window.originalFetch = window.fetch;
        window.fetch = () => Promise.reject(new Error('Network error'));
      ")

      fill_in 'search', with: 'test'
      sleep 0.5

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Error performing search')
        expect(page).to have_text('Please try again')
      end

      # Restore fetch
      page.execute_script("window.fetch = window.originalFetch;")
    end
  end

  describe "accessibility" do
    before do
      visit root_path
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")
    end

    it "has proper ARIA attributes on modal", js: true do
      modal = find('[data-global-search-target="modal"]')
      expect(modal['aria-role']).to eq('dialog')
      expect(modal['aria-modal']).to eq('true')
    end

    it "focuses input when modal opens", js: true do
      focused_element = page.evaluate_script('document.activeElement.dataset.globalSearchTarget')
      expect(focused_element).to eq('input')
    end

    it "has accessible labels for controls", js: true do
      expect(page).to have_css('button[aria-label="Close search"]')
      expect(page).to have_css('input[aria-label="Search"]')
    end
  end

  describe "mobile responsiveness" do
    before(:each) do
      # Set mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667)
      visit root_path
    end

    it "works on mobile viewport", js: true do
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)')
      expect(page).to have_field('search')
    end
  end
end
