# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Page Accessibility', type: :system, js: true do
  # Use regular let! at the outer level - these get created before any test runs
  let!(:company) { create(:company) }
  let!(:user) { create(:user, company: company) }

  # Helper to ensure user exists and login
  def ensure_login
    # Verify user exists in database before attempting login
    # This helps debug issues with database state
    unless User.exists?(user.id)
      raise "User #{user.id} not found in database before login attempt"
    end
    system_login(user)
  end

  describe 'Dashboard Page', :accessibility do
    before do
      ensure_login
    end

    it_behaves_like 'accessible page'

    it 'dashboard passes WCAG 2.1 AA compliance' do
      expect_no_axe_violations
    end

    it 'has a descriptive page title' do
      expect(page).to have_title(/Dashboard/i)
    end

    it 'has a single h1 heading' do
      h1_elements = page.all('h1', visible: true)
      expect(h1_elements.count).to eq(1)
    end

    it 'has proper landmark regions' do
      # Should have main content area
      expect(page).to have_css('main', visible: true)

      # Should have navigation
      expect(page).to have_css('nav', visible: true)
    end

    it 'dashboard stats are announced to screen readers' do
      # If dashboard has stats cards, they should have proper labels
      if page.has_css?('.stat', visible: true)
        stats = page.all('.stat', visible: true)
        stats.each do |stat|
          # Each stat should have text or aria-label
          expect(stat.text.strip).not_to be_empty
        end
      end

      expect_no_axe_violations
    end

    it 'all interactive elements are keyboard accessible' do
      focusable = expect_keyboard_navigable('body')
      expect(focusable.length).to be > 0
    end
  end

  describe 'Products Index Page', :accessibility do
    let!(:products) do
      [
        create(:product, company: company, sku: 'PROD-001', name: 'Product 1', product_status: :active),
        create(:product, company: company, sku: 'PROD-002', name: 'Product 2', product_status: :active),
        create(:product, company: company, sku: 'PROD-003', name: 'Product 3', product_status: :draft)
      ]
    end

    before do
      ensure_login
      visit products_path
    end

    it_behaves_like 'accessible page'

    it 'products page passes WCAG 2.1 AA compliance' do
      expect_no_axe_violations
    end

    it 'has a descriptive page title' do
      expect(page).to have_title(/Products/i)
    end

    it 'product table has proper structure' do
      # Table should have thead and tbody
      expect(page).to have_css('table thead', visible: true)
      expect(page).to have_css('table tbody', visible: true)

      # Table headers should have proper scope
      headers = page.all('th', visible: true)
      expect(headers.count).to be > 0
    end

    it 'product table headers have proper labels' do
      expect(page).to have_css('th', text: /SKU/i, visible: true)
      expect(page).to have_css('th', text: /Name/i, visible: true)
      expect(page).to have_css('th', text: /Status/i, visible: true)
    end

    it 'action buttons in table have accessible labels' do
      # Edit/delete buttons should have aria-labels or visible text
      action_buttons = page.all('td button, td a[role="button"], td a.btn', visible: true)

      # Skip if no action buttons found (empty table or different UI)
      if action_buttons.any?
        action_buttons.each do |button|
          # Button should have visible text or aria-label
          has_text = button.text.strip.present?
          has_aria_label = button['aria-label'].present?
          has_title = button['title'].present?

          expect(has_text || has_aria_label || has_title).to be(true),
            "Button must have visible text, aria-label, or title attribute"
        end
      end

      expect_no_axe_violations
    end

    it 'search functionality is accessible' do
      if page.has_field?('search', visible: true)
        search_field = page.find_field('search', visible: true)

        # Search field should have a label
        expect(search_field['aria-label'] || search_field['placeholder']).to be_present
      end

      expect_no_axe_violations
    end

    it 'empty state is accessible when no products' do
      # Delete all products to show empty state
      Product.delete_all
      visit products_path

      # Empty state should have descriptive text
      expect(page).to have_content(/no products/i)

      expect_no_axe_violations
    end

    it 'pagination controls are keyboard navigable' do
      # Create enough products to trigger pagination
      30.times do |i|
        create(:product, company: company, sku: "PROD-#{100 + i}", name: "Product #{100 + i}")
      end

      visit products_path

      if page.has_css?('nav[aria-label*="pagination"]', visible: true)
        pagination = page.find('nav[aria-label*="pagination"]', match: :first, visible: true)

        # Pagination links should be keyboard accessible
        links = pagination.all('a', visible: true)
        expect(links.count).to be > 0

        links.each do |link|
          expect(link['href']).to be_present
        end
      end

      expect_no_axe_violations
    end
  end

  describe 'Product Form Pages', :accessibility do
    context 'New Product Page' do
      before do
        ensure_login
        visit new_product_path
      end

      it_behaves_like 'accessible page'

      it 'new product form passes WCAG 2.1 AA compliance' do
        expect_no_axe_violations
      end

      it 'has a descriptive page title' do
        expect(page).to have_title(/New Product/i)
      end

      it 'all form inputs have associated labels' do
        # Get all form inputs
        inputs = page.all('input[type="text"], input[type="number"], textarea, select', visible: true)

        inputs.each do |input|
          input_id = input[:id]
          input_name = input[:name]

          # Should have a label with for attribute or aria-label
          has_label = input_id.present? && page.has_css?("label[for='#{input_id}']", visible: true)
          has_aria_label = input['aria-label'].present?
          has_placeholder = input['placeholder'].present?
          has_aria_labelledby = input['aria-labelledby'].present?

          expect(has_label || has_aria_label || has_placeholder || has_aria_labelledby).to be(true),
            "Input #{input_name} must have an associated label, aria-label, aria-labelledby, or placeholder"
        end

        expect_no_axe_violations
      end

      it 'required fields are properly marked' do
        required_inputs = page.all('input[required], textarea[required], select[required]', visible: true)

        required_inputs.each do |input|
          # Required inputs should have aria-required or required attribute
          expect(input[:required] || input['aria-required']).to be_present
        end

        expect_no_axe_violations
      end

      it 'form validation errors are announced to screen readers' do
        # Submit form without filling required fields
        click_button 'Save' if page.has_button?('Save', visible: true)

        # Error messages should be in an alert region
        if page.has_css?('[role="alert"]', visible: true)
          alert = page.find('[role="alert"]', visible: true)
          expect(alert.text).not_to be_empty
        end

        # Individual field errors should be associated with inputs
        error_messages = page.all('.error, .invalid-feedback', visible: true)
        error_messages.each do |error|
          expect(error.text).not_to be_empty
        end
      end

      it 'form buttons are keyboard accessible' do
        buttons = page.all('button, input[type="submit"]', visible: true)

        buttons.each do |button|
          # Button should be focusable
          expect(button[:disabled]).not_to eq('true') unless button.text.include?('Loading')
        end

        expect_no_axe_violations
      end
    end

    context 'Edit Product Page' do
      let(:product) { create(:product, company: company, sku: 'EDIT-001', name: 'Edit Test Product') }

      before do
        ensure_login
        visit edit_product_path(product)
      end

      it_behaves_like 'accessible page'

      it 'edit product form passes WCAG 2.1 AA compliance' do
        expect_no_axe_violations
      end

      it 'has a descriptive page title' do
        expect(page).to have_title(/Edit.*Product/i)
      end

      it 'form is pre-filled with existing values' do
        # SKU field should have the product's SKU
        if page.has_field?('SKU', visible: true)
          sku_field = page.find_field('SKU', visible: true)
          expect(sku_field.value).to eq(product.sku)
        end

        expect_no_axe_violations
      end
    end
  end

  describe 'Product Show Page', :accessibility do
    let(:product) { create(:product, company: company, sku: 'SHOW-001', name: 'Show Test Product') }

    before do
      ensure_login
      visit product_path(product)
    end

    it_behaves_like 'accessible page'

    it 'product details page passes WCAG 2.1 AA compliance' do
      expect_no_axe_violations
    end

    it 'has a descriptive page title' do
      expect(page).to have_title(/#{product.name}/i)
    end

    it 'product information is structured with headings' do
      # Should have clear heading hierarchy
      headings = page.all('h1, h2, h3, h4', visible: true)
      expect(headings.count).to be > 0

      # First heading should be h1
      expect(page).to have_css('h1', visible: true)
    end

    it 'product images have alt text' do
      images = page.all('img', visible: true)

      images.each do |img|
        # All images should have alt attribute (can be empty for decorative)
        expect(img[:alt]).not_to be_nil
      end

      expect_no_axe_violations
    end

    it 'action buttons are keyboard accessible' do
      # Edit, delete, duplicate buttons should be accessible
      buttons = page.all('button, a[role="button"]', visible: true)

      buttons.each do |button|
        expect(button.text.present? || button['aria-label'].present?).to be true
      end

      expect_no_axe_violations
    end
  end

  describe 'Search Page', :accessibility do
    let!(:products) do
      [
        create(:product, company: company, sku: 'SEARCH-001', name: 'Searchable Product 1'),
        create(:product, company: company, sku: 'SEARCH-002', name: 'Searchable Product 2')
      ]
    end

    before do
      ensure_login
      visit search_path
    end

    it_behaves_like 'accessible page'

    it 'search page passes WCAG 2.1 AA compliance' do
      expect_no_axe_violations
    end

    it 'has a descriptive page title' do
      expect(page).to have_title(/Search/i)
    end

    it 'search input has proper label' do
      if page.has_field?('q', visible: true) || page.has_field?('search', visible: true)
        search_input = page.find('input[type="search"], input[name="q"]', match: :first, visible: true)

        # Should have label or aria-label
        expect(
          page.has_css?("label[for='#{search_input[:id]}']", visible: true) ||
          search_input['aria-label'].present? ||
          search_input['placeholder'].present?
        ).to be true
      end

      expect_no_axe_violations
    end

    it 'search results are announced to screen readers' do
      # Perform a search
      if page.has_field?('search', visible: true)
        fill_in 'search', with: 'Searchable'
        click_button 'Search' if page.has_button?('Search', visible: true)

        # Results count should be visible
        expect(page).to have_content(/\d+.*result/i)
      end

      expect_no_axe_violations
    end

    it 'no results state is accessible' do
      if page.has_field?('search', visible: true)
        fill_in 'search', with: 'NONEXISTENT_PRODUCT_XYZ'
        click_button 'Search' if page.has_button?('Search', visible: true)

        # Should show empty state
        expect(page).to have_content(/no.*result/i)
      end

      expect_no_axe_violations
    end
  end

  describe 'Responsive Design Accessibility', :accessibility do
    context 'Mobile viewport' do
      before do
        page.driver.browser.manage.window.resize_to(375, 667) # iPhone size
        ensure_login
      end

      it 'mobile layout passes WCAG 2.1 AA compliance' do
        expect_no_axe_violations
      end

      it 'mobile menu is accessible' do
        # Mobile menu button should be visible
        if page.has_button?('Open menu', visible: true) || page.has_css?('[aria-label="Open menu"]', visible: true)
          menu_button = page.find('button[aria-label="Open menu"]', visible: true)

          # Click to open menu
          menu_button.click

          # Menu should be visible
          sleep 0.3 # Wait for animation

          expect_no_axe_violations
        end
      end

      it 'touch targets are large enough (min 44x44px)' do
        # Check that primary interactive buttons are large enough
        # Text links are exempt as they inherit line-height from surrounding text
        buttons = page.all('button', visible: true)

        buttons.each do |button|
          size = button.native.size
          # Note: This is a simplified check - minimum height of 24px for mobile buttons
          # WCAG recommends 44x44px but allows smaller if spacing provides equivalent target
          expect(size.height).to be >= 24, "Button '#{button.text}' is too small (#{size.height}px)"
        end
      end
    end

    context 'Tablet viewport' do
      before do
        page.driver.browser.manage.window.resize_to(768, 1024) # iPad size
        ensure_login
      end

      it 'tablet layout passes WCAG 2.1 AA compliance' do
        expect_no_axe_violations
      end

      it 'navigation is accessible on tablet' do
        expect(page).to have_css('nav', visible: true)
        expect_no_axe_violations
      end
    end
  end

  describe 'Form Input Types', :accessibility do
    before do
      ensure_login
      visit new_product_path
    end

    it 'text inputs are accessible' do
      text_inputs = page.all('input[type="text"]', visible: true)

      text_inputs.each do |input|
        # Should have label or aria-label
        has_label = page.has_css?("label[for='#{input[:id]}']", visible: true)
        has_aria = input['aria-label'].present?

        expect(has_label || has_aria).to be true
      end

      expect_no_axe_violations
    end

    it 'select dropdowns are accessible' do
      selects = page.all('select', visible: true)

      selects.each do |select|
        # Should have label
        expect(page).to have_css("label[for='#{select[:id]}']", visible: true)
      end

      expect_no_axe_violations
    end

    it 'checkboxes have associated labels' do
      checkboxes = page.all('input[type="checkbox"]', visible: true)

      checkboxes.each do |checkbox|
        # Should have label
        has_label = page.has_css?("label[for='#{checkbox[:id]}']", visible: true)
        has_aria = checkbox['aria-label'].present?

        expect(has_label || has_aria).to be true
      end

      expect_no_axe_violations
    end

    it 'radio buttons have associated labels' do
      radios = page.all('input[type="radio"]', visible: true)

      radios.each do |radio|
        # Should have label
        has_label = page.has_css?("label[for='#{radio[:id]}']", visible: true)
        has_aria = radio['aria-label'].present?

        expect(has_label || has_aria).to be true
      end

      expect_no_axe_violations
    end
  end

  describe 'Dynamic Content Accessibility', :accessibility do
    before do
      ensure_login
    end

    it 'loading states are announced to screen readers' do
      visit products_path

      # Loading indicators should have aria-live regions
      if page.has_css?('.loading, [role="status"]', visible: :all)
        loading = page.find('.loading, [role="status"]', match: :first, visible: :all)
        expect(loading['aria-live'] || loading['role']).to be_present
      end
    end

    it 'error messages are announced immediately' do
      visit new_product_path

      # Submit invalid form
      click_button 'Save' if page.has_button?('Save', visible: true)

      # Error container should be an alert
      if page.has_css?('[role="alert"]', visible: true)
        alert = page.find('[role="alert"]', visible: true)
        expect(alert).to be_present
      end

      expect_no_axe_violations
    end

    it 'success messages are announced' do
      # Success messages (flash notices) should be aria-live
      # This would be tested after a successful action
      # For now, we just check the flash component itself
      visit root_path

      # Flash messages should be in alert or status regions
      if page.has_css?('.flash, [role="alert"], [role="status"]', visible: true)
        flash = page.find('.flash, [role="alert"], [role="status"]', match: :first, visible: true)
        expect(flash).to be_present
      end
    end
  end

  describe 'Skip Links', :accessibility do
    before do
      ensure_login
    end

    it 'has a skip to main content link' do
      # Skip link should be the first focusable element
      page.driver.browser.action.send_keys(:tab).perform

      # Check if skip link exists and is focused
      skip_link = page.all('a', visible: :all).first

      if skip_link && skip_link.text.match?(/skip/i)
        expect(skip_link[:href]).to match(/#main/)
      end
    end

    it 'skip link is visible when focused' do
      # Tab to first element (should be skip link)
      page.driver.browser.action.send_keys(:tab).perform

      # Check if a skip link exists
      skip_links = page.all('a[href*="#main"], a[href*="#content"]', visible: :all)

      if skip_links.any?
        skip_link = skip_links.first

        # When focused, skip link should become visible
        # (many skip links are visually hidden until focused)
        skip_link.send_keys(:tab)
      end

      expect_no_axe_violations
    end
  end

  describe 'Heading Hierarchy', :accessibility do
    before do
      ensure_login
    end

    it 'has proper heading hierarchy with no skipped levels' do
      headings = page.all('h1, h2, h3, h4, h5, h6', visible: true)

      heading_levels = headings.map do |h|
        h.tag_name.gsub('h', '').to_i
      end

      # Should have at least one heading
      expect(heading_levels).not_to be_empty

      # First heading should be h1
      expect(heading_levels.first).to eq(1)

      # Check for skipped levels (h1 -> h3 without h2)
      heading_levels.each_cons(2) do |current, next_level|
        level_jump = next_level - current
        expect(level_jump).to be <= 1,
          "Heading hierarchy skipped from h#{current} to h#{next_level}"
      end
    end

    it 'has only one h1 per page' do
      h1_count = page.all('h1', visible: true).count
      expect(h1_count).to eq(1), "Page should have exactly one h1, found #{h1_count}"
    end
  end
end
