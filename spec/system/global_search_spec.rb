# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Global Search', type: :system do
  # Create company and user - these are lazily created
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  # Helper to login and ensure user/company exist
  def setup_and_login
    # Force creation of user (which also creates company)
    current_user = user
    # Login via test backdoor
    system_login(current_user)
  end

  # Helper to open search modal via keyboard shortcut
  def open_search_modal
    page.execute_script("
      const event = new KeyboardEvent('keydown', {
        key: 'k',
        metaKey: true,
        bubbles: true
      });
      document.dispatchEvent(event);
    ")
    # Wait for modal to open
    expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)
  end

  describe "opening search modal" do
    before do
      setup_and_login
    end

    it "opens search modal with keyboard shortcut", js: true do
      # Modal should be hidden initially (use visible: :all since hidden elements aren't visible)
      expect(page).to have_css('[data-global-search-target="modal"].hidden', visible: :all)

      # Press CMD+K (use 'k' with metaKey modifier)
      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Wait for modal to become visible
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      # Input should be focused - check via JavaScript since :focus pseudo-class can be flaky
      focused_target = page.evaluate_script('document.activeElement.dataset.globalSearchTarget')
      expect(focused_target).to eq('input')
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

      # Wait for modal to open
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      # Body should have overflow hidden
      overflow = page.evaluate_script("document.body.style.overflow")
      expect(overflow).to eq('hidden')
    end

    it "shows initial instructions in modal", js: true do
      # Clear any recent searches from cache so we see initial instructions
      Rails.cache.delete("recent_searches:#{user.id}")

      page.execute_script("
        const event = new KeyboardEvent('keydown', {
          key: 'k',
          metaKey: true,
          bubbles: true
        });
        document.dispatchEvent(event);
      ")

      # Wait for modal to open
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Type at least 2 characters to search')
      end
    end
  end

  describe "closing search modal" do
    before do
      setup_and_login
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

      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      # Press Escape
      page.execute_script("
        const escEvent = new KeyboardEvent('keydown', {
          key: 'Escape',
          bubbles: true
        });
        document.dispatchEvent(escEvent);
      ")

      # Modal should be hidden (use visible: :all since hidden elements aren't visible by default)
      expect(page).to have_css('[data-global-search-target="modal"].hidden', visible: :all, wait: 2)
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

      # Wait for modal to open
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      # Click close button
      within('[data-global-search-target="modal"]') do
        find('button[aria-label="Close search"]').click
      end

      # Modal should be hidden (use visible: :all since hidden elements aren't visible by default)
      expect(page).to have_css('[data-global-search-target="modal"].hidden', visible: :all, wait: 2)
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

      # Wait for modal to open
      expect(page).to have_css('[data-global-search-target="modal"]:not(.hidden)', wait: 2)

      # Close modal
      page.execute_script("
        const escEvent = new KeyboardEvent('keydown', {
          key: 'Escape',
          bubbles: true
        });
        document.dispatchEvent(escEvent);
      ")

      # Wait for modal to close
      expect(page).to have_css('[data-global-search-target="modal"].hidden', visible: :all, wait: 2)

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
    # Create test data in a before block to ensure proper ordering
    before do
      # Create test data with explicit company reference (use unique codes to avoid collisions)
      unique_suffix = SecureRandom.hex(4)
      @test_product = create(:product, company: company, name: 'iPhone 15 Pro', sku: "IP-15-PRO-#{unique_suffix}")
      @test_storage = create(:storage, company: company, name: 'Main Warehouse', code: "WH-MAIN-#{unique_suffix}")
      @test_label = create(:label, company: company, name: 'Electronics', code: "electronics-#{unique_suffix}")
      @test_attribute = create(:product_attribute, company: company, name: 'Price', code: "price-#{unique_suffix}")
      @test_catalog = create(:catalog, company: company, name: 'Webshop EU', code: "web-eu-#{unique_suffix}")

      # Login (redirects to root_path)
      setup_and_login

      # Open search modal
      open_search_modal
    end

    # Helper methods to access test data
    def product; @test_product; end
    def storage; @test_storage; end

    it "searches across all scopes and displays results", js: true do
      # Type search query (use 'iPhone' to match the test data)
      fill_in 'search', with: 'iPhone'

      # Wait for results to appear (use case-insensitive match since CSS transforms to uppercase)
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3', text: /products/i, wait: 3)
        expect(page).to have_text(product.name)
      end
    end

    it "shows loading state during search", js: true do
      # Mock fetch to delay response so we can catch loading state
      page.execute_script("
        window.originalFetch = window.fetch;
        window.fetch = function(url, options) {
          return new Promise(resolve => {
            setTimeout(() => {
              window.originalFetch(url, options).then(resolve);
            }, 500);
          });
        };
      ")

      fill_in 'search', with: 'test'

      # Should show loading state while request is pending
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('svg.animate-spin', wait: 2)
      end

      # Restore fetch
      page.execute_script("window.fetch = window.originalFetch;")
    end

    it "displays product results with correct format", js: true do
      fill_in 'search', with: 'iPhone'

      within('[data-global-search-target="results"]') do
        # Wait for and verify product name, SKU, and badge
        expect(page).to have_text('iPhone 15 Pro', wait: 3)
        expect(page).to have_text('IP-15-PRO')
        expect(page).to have_css('.bg-blue-100') # Product type badge
      end
    end

    it "displays storage results correctly", js: true do
      fill_in 'search', with: 'Main'

      within('[data-global-search-target="results"]') do
        # Use case-insensitive match since CSS transforms to uppercase
        expect(page).to have_css('h3', text: /storage locations/i, wait: 3)
        expect(page).to have_text('Main Warehouse')
        expect(page).to have_text('WH-MAIN')
      end
    end

    it "shows empty state when no results found", js: true do
      fill_in 'search', with: 'nonexistent search query xyz'

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('No results found', wait: 3)
        expect(page).to have_text('Try searching with different keywords')
      end
    end
  end

  describe "recent searches" do
    before do
      # Create product in before block to ensure proper ordering
      @test_product = create(:product, company: company, name: 'iPhone 15 Pro', sku: 'IP-15-PRO')

      # Store a recent search in cache directly (simulating a previous search with results)
      cache_key = "recent_searches:#{user.id}"
      Rails.cache.write(cache_key, [ 'iPhone' ], expires_in: 30.days)

      # Login and open modal
      setup_and_login
      open_search_modal
    end

    def product; @test_product; end

    it "loads recent searches when modal opens", js: true do
      within('[data-global-search-target="results"]') do
        # Note: CSS transforms heading to uppercase, so use case-insensitive match
        expect(page).to have_css('h3', text: /recent searches/i, wait: 2)
        expect(page).to have_text('iPhone')
      end
    end

    it "fills input when clicking recent search", js: true do
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3', text: /recent searches/i, wait: 2)
        find('button[data-action*="fillSearch"]', text: 'iPhone').click
      end

      # Should fill the input with the clicked search term
      expect(find('input[data-global-search-target="input"]').value).to eq('iPhone')
    end
  end

  describe "navigation to results" do
    before do
      unique_suffix = SecureRandom.hex(4)
      @test_product = create(:product, company: company, name: 'NavTest Product', sku: "NAVTEST-#{unique_suffix}")

      setup_and_login
      open_search_modal
    end

    def product; @test_product; end

    it "navigates to product page when clicking result", js: true do
      fill_in 'search', with: 'NavTest'

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('NavTest Product', wait: 3)
        click_link href: /\/products\/#{product.id}/
      end

      expect(page).to have_current_path(product_path(product))
    end
  end

  describe "multi-tenancy isolation" do
    before do
      @other_company = create(:company)
      @own_product = create(:product, company: company, name: 'Our Product', sku: 'OUR-1')
      @other_product = create(:product, company: @other_company, name: 'Their Product', sku: 'THEIR-1')

      setup_and_login
      open_search_modal
    end

    it "only shows results from current company", js: true do
      fill_in 'search', with: 'Product'

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Our Product', wait: 3)
        expect(page).not_to have_text('Their Product')
      end
    end
  end

  describe "debouncing" do
    before do
      setup_and_login
      open_search_modal
    end

    it "debounces search input to avoid excessive API calls", js: true do
      # Type multiple characters quickly
      input = find('input[data-global-search-target="input"]')
      input.send_keys('t')
      input.send_keys('e')
      input.send_keys('s')
      input.send_keys('t')

      # After debounce + API call, should have some content (either loading, results, or empty state)
      within('[data-global-search-target="results"]') do
        expect(page).to have_css('h3, .text-center, svg.animate-spin', wait: 3)
      end
    end
  end

  describe "error handling" do
    before do
      setup_and_login
      open_search_modal
    end

    after do
      # Ensure fetch is always restored even if test fails
      page.execute_script("if (window.originalFetch) { window.fetch = window.originalFetch; }")
    end

    it "shows error state when API call fails", js: true do
      # Mock fetch to fail
      page.execute_script("
        window.originalFetch = window.fetch;
        window.fetch = () => Promise.reject(new Error('Network error'));
      ")

      fill_in 'search', with: 'test'

      within('[data-global-search-target="results"]') do
        expect(page).to have_text('Error performing search', wait: 3)
        expect(page).to have_text('Please try again')
      end
    end
  end

  describe "accessibility" do
    before do
      setup_and_login
      open_search_modal
    end

    it "has proper ARIA attributes on modal", js: true do
      modal = find('[data-global-search-target="modal"]')
      # Note: HTML uses 'role' attribute, not 'aria-role'
      expect(modal['role']).to eq('dialog')
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
      setup_and_login
    end

    it "works on mobile viewport", js: true do
      open_search_modal
      expect(page).to have_field('search')
    end
  end
end
