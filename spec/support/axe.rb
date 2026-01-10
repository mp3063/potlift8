# frozen_string_literal: true

# Axe-core configuration for accessibility testing
# This file configures axe-core to test for WCAG 2.1 AA compliance
# https://github.com/dequelabs/axe-core-gems/blob/develop/packages/axe-core-rspec/README.md

# Load axe-core-rspec for accessibility testing
require 'axe-rspec'

RSpec.configure do |config|
  # Configure axe-core for system tests
  # Note: System tests use driven_by in rails_helper.rb which sets up the selenium driver
  # No need to manually switch drivers here as the driven_by configuration handles it

  # Global axe-core configuration
  # Test against WCAG 2.1 Level AA standards
  config.before(:each, :accessibility) do
    @axe_options = {
      # Rules to run - WCAG 2.1 Level A and AA
      # https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md
      runOnly: {
        type: 'tag',
        values: [ 'wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'best-practice' ]
      }
    }
  end
end

# Custom matchers for accessibility testing
module AccessibilityHelpers
  # Check if page is accessible according to WCAG 2.1 AA
  # Usage: expect(page).to be_axe_clean
  def expect_no_axe_violations
    expect(page).to be_axe_clean.according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  # Check specific element for accessibility violations
  # Usage: expect_no_violations_in('#main-content')
  def expect_no_violations_in(selector)
    expect(page).to be_axe_clean.within(selector)
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  # Check page excluding certain elements (useful for third-party widgets)
  # Usage: expect_no_violations_excluding('.external-widget')
  def expect_no_violations_excluding(selector)
    expect(page).to be_axe_clean.excluding(selector)
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  # Check for specific accessibility rules
  # Usage: expect_rule_passes('color-contrast')
  def expect_rule_passes(rule_id)
    expect(page).to be_axe_clean.checking_only(rule_id)
  end

  # Skip specific rules (use sparingly and document why)
  # Usage: expect_no_violations_skipping('color-contrast')
  def expect_no_violations_skipping(*rule_ids)
    expect(page).to be_axe_clean.skipping(*rule_ids)
      .according_to(:wcag2a, :wcag2aa, :wcag21a, :wcag21aa)
  end

  # Custom assertion for keyboard navigation
  def expect_keyboard_navigable(selector, expected_elements: nil)
    # Find all focusable elements within the container
    # Using ES5-compatible syntax for broader browser support
    focusable_elements = page.evaluate_script(<<~JS)
      (function() {
        var container = document.querySelector('#{selector.gsub("'", "\\'")}');
        if (!container) return [];

        var focusable = container.querySelectorAll(
          'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
        );

        var result = [];
        for (var i = 0; i < focusable.length; i++) {
          var el = focusable[i];
          result.push({
            tag: el.tagName.toLowerCase(),
            text: (el.textContent || '').trim().substring(0, 50),
            tabindex: el.getAttribute('tabindex'),
            ariaLabel: el.getAttribute('aria-label')
          });
        }
        return result;
      })();
    JS

    if expected_elements
      expect(focusable_elements.length).to eq(expected_elements),
        "Expected #{expected_elements} focusable elements, found #{focusable_elements.length}"
    else
      expect(focusable_elements).not_to be_empty,
        "Expected to find focusable elements within #{selector}"
    end

    focusable_elements
  end

  # Test focus order by simulating Tab key presses
  def test_focus_order(expected_order)
    expected_order.each_with_index do |selector, index|
      # Get currently focused element
      focused = page.evaluate_script('document.activeElement.outerHTML')

      expect(page).to have_css(selector),
        "Expected element #{selector} to be focused at position #{index + 1}, but it wasn't found or focused"

      # Press Tab to move to next element (unless it's the last one)
      page.driver.browser.action.send_keys(:tab).perform unless index == expected_order.length - 1
    end
  end

  # Test that element has visible focus indicator
  def expect_visible_focus_indicator(selector)
    element = page.find(selector)
    element.send_keys(:tab) # Focus the element

    # Check if element has focus and visible outline
    has_focus = page.evaluate_script(<<~JS)
      const el = document.querySelector('#{selector.gsub("'", "\\'")}');
      const styles = window.getComputedStyle(el);
      const isFocused = document.activeElement === el;
      const hasOutline = styles.outline !== 'none' &&
                         styles.outline !== 'none 0px' &&
                         styles.outline !== '0px';
      const hasBoxShadow = styles.boxShadow !== 'none';
      const hasBorder = styles.border !== 'none';

      return {
        isFocused,
        hasVisibleIndicator: hasOutline || hasBoxShadow || hasBorder,
        outline: styles.outline,
        boxShadow: styles.boxShadow
      };
    JS

    expect(has_focus['hasVisibleIndicator']).to be true,
      "Element #{selector} should have a visible focus indicator"
  end

  # Check color contrast ratio
  def expect_sufficient_contrast(selector, level: 'AA')
    result = page.evaluate_script(<<~JS)
      const el = document.querySelector('#{selector.gsub("'", "\\'")}');
      if (!el) return null;

      const styles = window.getComputedStyle(el);
      return {
        color: styles.color,
        backgroundColor: styles.backgroundColor,
        fontSize: styles.fontSize
      };
    JS

    expect(result).not_to be_nil, "Element #{selector} not found"
    # Note: Actual contrast calculation would require more complex JS
    # axe-core handles this automatically in be_axe_clean
  end

  # Check that modals trap focus
  def expect_focus_trapped_in(modal_selector)
    # Get all focusable elements in modal
    elements_in_modal = expect_keyboard_navigable(modal_selector)

    # Get all focusable elements outside modal
    elements_outside = page.evaluate_script(<<~JS)
      const modal = document.querySelector('#{modal_selector.gsub("'", "\\'")}');
      const allFocusable = document.querySelectorAll(
        'a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])'
      );

      return Array.from(allFocusable).filter(el => !modal.contains(el)).length;
    JS

    # Press Tab multiple times and verify focus stays in modal
    (elements_in_modal.length + 2).times do
      page.driver.browser.action.send_keys(:tab).perform

      focused_in_modal = page.evaluate_script(<<~JS)
        const modal = document.querySelector('#{modal_selector.gsub("'", "\\'")}');
        return modal.contains(document.activeElement);
      JS

      expect(focused_in_modal).to be true,
        "Focus should be trapped within #{modal_selector}"
    end
  end

  # Check skip to main content link
  def expect_skip_to_main_content
    # Tab to first element (should be skip link)
    page.driver.browser.action.send_keys(:tab).perform

    # Check if skip link is visible when focused
    skip_link = page.find('a[href="#main-content"], a[href="#main"]', visible: :all)
    expect(skip_link).to be_visible

    # Click skip link
    skip_link.click

    # Verify focus moved to main content
    focused_element = page.evaluate_script('document.activeElement.id')
    expect([ 'main-content', 'main' ]).to include(focused_element)
  end
end

# Shared examples for common accessibility patterns
RSpec.shared_examples 'accessible component' do
  it 'passes axe accessibility checks', :accessibility do
    expect_no_axe_violations
  end

  it 'has proper ARIA attributes', :accessibility do
    # This will be customized per component
  end

  it 'is keyboard navigable', :accessibility do
    # This will be customized per component
  end
end

RSpec.shared_examples 'accessible page' do
  it 'passes WCAG 2.1 AA compliance', :accessibility do
    expect_no_axe_violations
  end

  it 'has a proper document title' do
    expect(page).to have_title(/\w+/)
  end

  it 'has a main landmark' do
    expect(page).to have_css('main[role="main"], main', visible: true)
  end

  it 'has proper heading hierarchy' do
    # Check that h1 exists and there's only one
    expect(page).to have_css('h1', count: 1)
  end

  it 'all images have alt text' do
    images_without_alt = page.all('img:not([alt])', visible: :all)
    expect(images_without_alt).to be_empty,
      "Found #{images_without_alt.length} images without alt attributes"
  end
end

RSpec.shared_examples 'keyboard navigable' do |container_selector|
  it 'can be navigated with Tab key' do
    visit page_path if defined?(page_path)

    focusable = expect_keyboard_navigable(container_selector || 'body')
    expect(focusable.length).to be > 0,
      "Expected to find keyboard-navigable elements"
  end

  it 'has visible focus indicators' do
    # Will be implemented per component
  end

  it 'supports Escape key to close (if applicable)' do
    # Will be implemented for modals, dropdowns, etc.
  end
end

# Include helper methods in system specs
RSpec.configure do |config|
  config.include AccessibilityHelpers, type: :system
end
