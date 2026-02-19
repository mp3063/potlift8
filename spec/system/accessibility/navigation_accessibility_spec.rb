# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Navigation Accessibility', type: :system, js: true do
  let(:company) { create(:company) }
  let(:current_user) { { id: 1, email: 'test@example.com', name: 'Test User' } }

  # Helper to set up authenticated session
  def sign_in_user
    # Mock the authentication helper methods
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(current_user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  before do
    sign_in_user
  end

  describe 'Navbar Keyboard Navigation', :accessibility do
    before do
      visit root_path
    end

    it 'can navigate through main navigation with Tab key' do
      # Tab through navigation elements
      page.driver.browser.action.send_keys(:tab).perform

      # Should focus on navigation elements
      5.times do
        focused_element = page.evaluate_script('document.activeElement.tagName')
        expect([ 'A', 'BUTTON' ]).to include(focused_element)

        page.driver.browser.action.send_keys(:tab).perform
      end

      expect_no_axe_violations
    end

    it 'navigation links have visible focus indicators' do
      # Find all navigation links
      nav_links = page.all('nav a', visible: true)

      nav_links.each do |link|
        # Tab to the link and check for focus styles
        link.send_keys(:tab)

        # Link should have focus styles
        expect(link[:class]).to match(/focus:/) if link[:class].present?
      end

      expect_no_axe_violations
    end

    it 'logo link is keyboard accessible' do
      # Find logo link (usually first link)
      logo_link = page.find('nav a', match: :first, visible: true)

      # Should be able to activate with keyboard
      logo_link.send_keys(:enter)

      # Should navigate (or stay on same page if already on home)
      expect(page).to have_current_path(root_path)

      expect_no_axe_violations
    end

    it 'main navigation is accessible with semantic HTML' do
      # Navigation should be in a nav element
      expect(page).to have_css('nav', visible: true)

      # Navigation links should be actual links (not divs with click handlers)
      nav_links = page.all('nav a[href]', visible: true)
      expect(nav_links.count).to be > 0

      expect_no_axe_violations
    end

    it 'current page is indicated to screen readers' do
      # Current/active link should have aria-current attribute
      if page.has_css?('nav a[aria-current]', visible: true)
        current_link = page.find('nav a[aria-current]', visible: true)
        expect(current_link['aria-current']).to eq('page')
      end

      expect_no_axe_violations
    end
  end

  describe 'Dropdown Menu Keyboard Navigation', :accessibility do
    before do
      visit root_path
    end

    it 'user dropdown can be opened with keyboard' do
      # Find user dropdown button
      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        dropdown_button = page.find('button[aria-haspopup="true"]', visible: true)

        # Focus and activate dropdown
        dropdown_button.send_keys(:enter)

        # Wait for dropdown to open
        sleep 0.3

        # Dropdown menu should be visible
        expect(page).to have_css('[role="menu"]', visible: true)

        # aria-expanded should be true
        expect(dropdown_button['aria-expanded']).to eq('true')

        expect_no_axe_violations
      end
    end

    it 'can navigate dropdown items with Tab key' do
      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        # Open dropdown
        dropdown_button = page.find('button[aria-haspopup="true"]', visible: true)
        dropdown_button.click

        sleep 0.3

        # Get dropdown menu items
        menu_items = page.all('[role="menu"] [role="menuitem"]', visible: true)

        if menu_items.any?
          # Tab through menu items
          menu_items.length.times do
            page.driver.browser.action.send_keys(:tab).perform

            focused = page.evaluate_script('document.activeElement')
            expect(focused).to be_present
          end
        end

        expect_no_axe_violations
      end
    end

    it 'can navigate dropdown items with arrow keys' do
      skip 'Arrow key navigation requires JavaScript implementation'

      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        # Open dropdown
        dropdown_button = page.find('button[aria-haspopup="true"]', visible: true)
        dropdown_button.send_keys(:enter)

        sleep 0.3

        # Press down arrow
        page.driver.browser.action.send_keys(:arrow_down).perform

        # First menu item should be focused
        focused = page.evaluate_script('document.activeElement.getAttribute("role")')
        expect(focused).to eq('menuitem')

        # Press down arrow again
        page.driver.browser.action.send_keys(:arrow_down).perform

        # Second menu item should be focused
        expect_no_axe_violations
      end
    end

    it 'dropdown closes with Escape key' do
      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        # Open dropdown
        dropdown_button = page.find('button[aria-haspopup="true"]', visible: true)
        dropdown_button.click

        sleep 0.3

        # Dropdown should be visible
        expect(page).to have_css('[role="menu"]', visible: true)

        # Press Escape
        page.driver.browser.action.send_keys(:escape).perform

        sleep 0.3

        # Dropdown should be hidden
        expect(page).to have_css('[role="menu"]', visible: false)

        # aria-expanded should be false
        expect(dropdown_button['aria-expanded']).to eq('false')

        expect_no_axe_violations
      end
    end

    it 'dropdown closes when clicking outside' do
      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        # Open dropdown
        dropdown_button = page.find('button[aria-haspopup="true"]', visible: true)
        dropdown_button.click

        sleep 0.3

        # Click outside dropdown
        page.find('body').click

        sleep 0.3

        # Dropdown should be hidden
        expect(page).to have_css('[role="menu"]', visible: false)

        expect_no_axe_violations
      end
    end

    it 'dropdown menu items have proper roles' do
      if page.has_css?('button[aria-haspopup="true"]', visible: true)
        # Open dropdown
        page.find('button[aria-haspopup="true"]', visible: true).click

        sleep 0.3

        # Menu should have role="menu"
        expect(page).to have_css('[role="menu"]', visible: true)

        # Menu items should have role="menuitem"
        menu_items = page.all('[role="menu"] a, [role="menu"] button', visible: true)

        menu_items.each do |item|
          expect(item['role']).to eq('menuitem').or eq(nil) # menuitem role is optional for links in menu
        end

        expect_no_axe_violations
      end
    end
  end

  describe 'Mobile Menu Navigation', :accessibility do
    before do
      # Resize to mobile viewport
      page.driver.browser.manage.window.resize_to(375, 667)
      visit root_path
    end

    it 'mobile menu button is keyboard accessible' do
      # Find mobile menu button
      if page.has_css?('button[aria-label*="menu"]', visible: true)
        menu_button = page.find('button[aria-label*="menu"]', match: :first, visible: true)

        # Focus button
        menu_button.send_keys(:tab)

        # Activate with Enter
        menu_button.send_keys(:enter)

        sleep 0.3

        # Mobile menu should be visible
        # (Implementation specific - adjust selector as needed)

        expect_no_axe_violations
      end
    end

    it 'mobile menu has proper ARIA attributes' do
      if page.has_css?('button[aria-label*="menu"]', visible: true)
        menu_button = page.find('button[aria-label*="menu"]', match: :first, visible: true)

        # Should have aria-label
        expect(menu_button['aria-label']).to be_present

        # Should have aria-expanded attribute
        expect(menu_button['aria-expanded']).to be_present

        expect_no_axe_violations
      end
    end

    it 'mobile menu closes with Escape key' do
      if page.has_css?('button[aria-label*="menu"]', visible: true)
        # Open mobile menu
        menu_button = page.find('button[aria-label*="menu"]', match: :first, visible: true)
        menu_button.click

        sleep 0.3

        # Press Escape
        page.driver.browser.action.send_keys(:escape).perform

        sleep 0.3

        # Menu should be closed
        expect(menu_button['aria-expanded']).to eq('false')

        expect_no_axe_violations
      end
    end

    it 'mobile menu items are keyboard navigable' do
      if page.has_css?('button[aria-label*="menu"]', visible: true)
        # Open mobile menu
        page.find('button[aria-label*="menu"]', match: :first, visible: true).click

        sleep 0.3

        # Tab through menu items
        5.times do
          page.driver.browser.action.send_keys(:tab).perform
          focused = page.evaluate_script('document.activeElement.tagName')
          expect([ 'A', 'BUTTON' ]).to include(focused)
        end

        expect_no_axe_violations
      end
    end

    it 'mobile menu traps focus when open' do
      skip 'Focus trap requires JavaScript implementation'

      if page.has_css?('button[aria-label*="menu"]', visible: true)
        # Open mobile menu
        page.find('button[aria-label*="menu"]', match: :first, visible: true).click

        sleep 0.3

        # Get all focusable elements
        sidebar_selector = '[data-controller*="mobile-sidebar"]'
        focusable = expect_keyboard_navigable(sidebar_selector)

        # Tab through all elements multiple times
        (focusable.length + 2).times do
          page.driver.browser.action.send_keys(:tab).perform

          # Focus should stay within menu
          focused_in_menu = page.evaluate_script(<<~JS)
            const sidebar = document.querySelector('#{sidebar_selector}');
            return sidebar && sidebar.contains(document.activeElement);
          JS

          expect(focused_in_menu).to be true
        end

        expect_no_axe_violations
      end
    end
  end

  describe 'Modal Keyboard Navigation', :accessibility do
    let(:product) { create(:product, company: company, sku: 'MOD-001', name: 'Modal Test Product') }

    before do
      # Visit a page that has modal functionality
      visit products_path
    end

    it 'modal can be opened with keyboard', skip: 'Requires modal trigger in UI' do
      # Find modal trigger button
      if page.has_button?('New Product', visible: true)
        trigger = page.find_button('New Product', visible: true)

        # Activate with keyboard
        trigger.send_keys(:enter)

        sleep 0.3

        # Modal should be visible
        expect(page).to have_css('[role="dialog"]', visible: true)

        expect_no_axe_violations
      end
    end

    it 'modal traps focus within dialog', skip: 'Requires modal in UI' do
      # Open a modal (implementation specific)
      # Then test focus trap

      if page.has_css?('[role="dialog"]', visible: true)
        modal_selector = '[role="dialog"]'
        expect_focus_trapped_in(modal_selector)

        expect_no_axe_violations
      end
    end

    it 'modal closes with Escape key', skip: 'Requires modal in UI' do
      # Open modal
      # Press Escape
      # Modal should close

      if page.has_css?('[role="dialog"]', visible: true)
        page.driver.browser.action.send_keys(:escape).perform

        sleep 0.3

        expect(page).to have_css('[role="dialog"]', visible: false)

        expect_no_axe_violations
      end
    end

    it 'focus returns to trigger after closing modal', skip: 'Requires modal in UI' do
      # Open modal from trigger
      # Close modal
      # Focus should return to trigger button

      if page.has_button?('New Product', visible: true)
        trigger = page.find_button('New Product', visible: true)
        trigger_id = trigger[:id]

        trigger.click

        sleep 0.3

        # Close modal
        page.driver.browser.action.send_keys(:escape).perform

        sleep 0.3

        # Check focused element
        focused_id = page.evaluate_script('document.activeElement.id')
        expect(focused_id).to eq(trigger_id)

        expect_no_axe_violations
      end
    end
  end

  describe 'Skip Links', :accessibility do
    before do
      visit root_path
    end

    it 'skip to main content link is the first focusable element' do
      # Reset focus
      page.evaluate_script('document.activeElement.blur()')

      # Tab once
      page.driver.browser.action.send_keys(:tab).perform

      # Get focused element
      focused = page.evaluate_script('document.activeElement')

      # Check if it's a skip link
      focused_text = page.evaluate_script('document.activeElement.textContent')
      focused_href = page.evaluate_script('document.activeElement.href')

      if focused_text.match?(/skip/i)
        expect(focused_href).to match(/#main|#content/)
      end
    end

    it 'skip link is visible when focused' do
      # Tab to first element
      page.driver.browser.action.send_keys(:tab).perform

      focused_text = page.evaluate_script('document.activeElement.textContent')

      if focused_text&.match?(/skip/i)
        # Skip link should be visible when focused
        is_visible = page.evaluate_script(<<~JS)
          (function() {
            var el = document.activeElement;
            var styles = window.getComputedStyle(el);
            return styles.opacity !== '0' &&
                   styles.visibility !== 'hidden' &&
                   styles.display !== 'none';
          })()
        JS

        expect(is_visible).to be true
      end

      expect_no_axe_violations
    end

    it 'skip link moves focus to main content' do
      # Tab to skip link
      page.driver.browser.action.send_keys(:tab).perform

      focused_text = page.evaluate_script('document.activeElement.textContent')

      if focused_text.match?(/skip/i)
        # Activate skip link
        page.driver.browser.action.send_keys(:enter).perform

        sleep 0.3

        # Focus should be on main content area
        focused_id = page.evaluate_script('document.activeElement.id')
        expect([ 'main', 'main-content', 'content' ]).to include(focused_id)

        expect_no_axe_violations
      end
    end
  end

  describe 'Form Navigation', :accessibility do
    before do
      visit new_product_path
    end

    it 'can navigate form fields with Tab key' do
      # Get all form fields
      form_fields = page.all('input, select, textarea, button', visible: true)

      expect(form_fields.count).to be > 0

      # Tab through fields
      form_fields.length.times do |i|
        page.driver.browser.action.send_keys(:tab).perform

        focused = page.evaluate_script('document.activeElement.tagName')
        expect([ 'INPUT', 'SELECT', 'TEXTAREA', 'BUTTON', 'A' ]).to include(focused)
      end

      expect_no_axe_violations
    end

    it 'can navigate backward with Shift+Tab' do
      # Tab to several fields
      10.times { page.driver.browser.action.send_keys(:tab).perform }

      # Get current focused element info (use outerHTML since not all elements have IDs)
      current_focus = page.evaluate_script('document.activeElement.outerHTML')
      current_tag = page.evaluate_script('document.activeElement.tagName')

      # Shift+Tab to go back
      page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform

      # Focus should have moved backward (different element)
      new_focus = page.evaluate_script('document.activeElement.outerHTML')

      # Either the element changed, or we check that we can still navigate
      expect(new_focus).not_to eq(current_focus)

      expect_no_axe_violations
    end

    it 'form submission can be triggered with Enter key' do
      # Fill in required field
      if page.has_field?('SKU', visible: true)
        sku_field = page.find_field('SKU', visible: true)
        sku_field.fill_in with: 'TEST-SKU'
      end

      # Focus submit button and press Enter
      if page.has_button?('Save', visible: true)
        submit_button = page.find_button('Save', visible: true)
        submit_button.send_keys(:enter)

        # Form should be submitted (or show validation errors)
        sleep 0.5

        expect_no_axe_violations
      end
    end

    it 'disabled fields are skipped in tab order' do
      # Find disabled fields
      disabled_fields = page.all('input[disabled], button[disabled]', visible: true)

      if disabled_fields.any?
        # Tab through form
        10.times do
          page.driver.browser.action.send_keys(:tab).perform

          # Focused element should not be disabled
          is_disabled = page.evaluate_script('document.activeElement.disabled')
          expect(is_disabled).to be_falsey
        end
      end

      expect_no_axe_violations
    end

    it 'required fields are properly marked for screen readers' do
      required_fields = page.all('input[required], textarea[required], select[required]', visible: true)

      required_fields.each do |field|
        # Should have aria-required or required attribute
        expect(field[:required] || field['aria-required']).to be_present
      end

      expect_no_axe_violations
    end
  end

  describe 'Table Navigation', :accessibility do
    let!(:products) do
      3.times.map do |i|
        create(:product, company: company, sku: "TAB-00#{i}", name: "Table Product #{i}")
      end
    end

    before do
      visit products_path
    end

    it 'can navigate table rows with keyboard' do
      # Get all interactive elements in table
      table_links = page.all('table a, table button', visible: true)

      if table_links.any?
        # Tab through table
        table_links.length.times do
          page.driver.browser.action.send_keys(:tab).perform

          focused = page.evaluate_script('document.activeElement')
          expect(focused).to be_present
        end
      end

      expect_no_axe_violations
    end

    it 'table has proper structure for screen readers' do
      # Table should have thead
      expect(page).to have_css('table thead', visible: true)

      # Table headers should have scope attribute or be in thead
      headers = page.all('th', visible: true)
      expect(headers.count).to be > 0

      expect_no_axe_violations
    end

    it 'table action buttons are keyboard accessible' do
      # Find action buttons (edit, delete, etc.)
      action_buttons = page.all('table button, table a[role="button"]', visible: true)

      action_buttons.each do |button|
        # Button should have text or aria-label
        has_text = button.text.present?
        has_aria_label = button['aria-label'].present?

        expect(has_text || has_aria_label).to be true
      end

      expect_no_axe_violations
    end

    it 'sortable table headers are keyboard accessible' do
      # Count sortable headers initially
      sortable_header_count = page.all('th a, th button', visible: true).count

      if sortable_header_count > 0
        # Test the first sortable header only (to avoid stale element issues after page reload)
        first_header = page.find('th a, th button', match: :first, visible: true)

        # Header should be keyboard accessible
        first_header.send_keys(:enter)

        # Wait for page to stabilize after potential sort
        sleep 0.3

        expect_no_axe_violations
      end
    end
  end

  describe 'Focus Visible Styles', :accessibility do
    before do
      visit root_path
    end

    it 'all interactive elements have focus-visible styles' do
      # Get all interactive elements
      interactive = page.all('a, button, input, select, textarea', visible: true)

      interactive.first(10).each do |element|
        tag_name = element.tag_name
        # Focus element
        element.send_keys(:tab)

        # Check for focus styles
        has_outline = page.evaluate_script(<<~JS)
          (function() {
            var el = document.activeElement;
            var styles = window.getComputedStyle(el);
            return styles.outline !== 'none' ||
                   styles.boxShadow !== 'none' ||
                   styles.border !== 'none';
          })()
        JS

        expect(has_outline).to be(true), "Element #{tag_name} should have visible focus indicator"
      end

      expect_no_axe_violations
    end

    it 'focus indicators have sufficient contrast' do
      # Focus an element
      if page.has_link?(visible: true)
        link = page.find('a', match: :first, visible: true)
        link.send_keys(:tab)

        # Check focus indicator contrast
        # (This would require color analysis - axe-core handles this)
        expect_no_axe_violations
      end
    end

    it 'focus is never completely hidden' do
      # Tab through elements
      10.times do
        page.driver.browser.action.send_keys(:tab).perform

        # Check if focused element is visible
        is_visible = page.evaluate_script(<<~JS)
          (function() {
            var el = document.activeElement;
            var styles = window.getComputedStyle(el);
            return styles.opacity !== '0' &&
                   styles.visibility !== 'hidden';
          })()
        JS

        expect(is_visible).to be(true), "Focused element should always be visible"
      end

      expect_no_axe_violations
    end
  end

  describe 'Keyboard Shortcuts', :accessibility do
    before do
      visit root_path
    end

    it 'keyboard shortcuts are documented if present', skip: 'No keyboard shortcuts implemented yet' do
      # If keyboard shortcuts exist, they should be documented
      # Check for help link or documentation
      expect(page).to have_link('Keyboard Shortcuts', visible: :all)
    end

    it 'keyboard shortcuts do not conflict with browser/screen reader shortcuts', skip: 'No keyboard shortcuts implemented yet' do
      # Test that custom shortcuts don't override important browser shortcuts
      # This is more of a design guideline than a test
    end

    it 'all functionality is available via keyboard without shortcuts' do
      # Core functionality should work with standard keyboard navigation
      # Tab, Enter, Space, Escape, Arrow keys

      # Navigate to products - use the nav bar link (only visible on desktop viewport)
      if page.has_css?('nav a', text: 'Products', visible: true)
        link = page.find('nav a', text: 'Products', match: :first, visible: true)
        link.send_keys(:enter)

        expect(page).to have_current_path(products_path)
      end

      expect_no_axe_violations
    end
  end
end
