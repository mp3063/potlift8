# frozen_string_literal: true

# Visual testing helpers for responsive component testing
module VisualTestHelpers
  # Standard breakpoints matching Tailwind CSS defaults
  # These viewport sizes represent common device categories
  VIEWPORTS = {
    mobile: [ 375, 667 ],     # iPhone SE (smallest common mobile)
    tablet: [ 768, 1024 ],    # iPad portrait
    desktop: [ 1440, 900 ]    # Standard desktop
  }.freeze

  # Convenience method to test component at multiple viewports
  #
  # @param component [ViewComponent::Base] Component instance to test
  # @param name [String] Base name for screenshot files
  # @param viewports [Array<Symbol>] Array of viewport keys from VIEWPORTS
  #
  # @example Test navbar at all breakpoints
  #   screenshot_component(
  #     Shared::NavbarComponent.new(user: user),
  #     name: "navbar_authenticated",
  #     viewports: [:mobile, :tablet, :desktop]
  #   )
  #
  def screenshot_component(component, name:, viewports: [ :desktop ])
    Array(viewports).each do |viewport|
      width, height = VIEWPORTS.fetch(viewport) do
        raise ArgumentError, "Unknown viewport: #{viewport}. Valid options: #{VIEWPORTS.keys.join(', ')}"
      end

      # Resize browser window if in system test context
      resize_to(width, height) if respond_to?(:page) && page.driver.browser.respond_to?(:manage)

      # Render component
      render_inline(component)

      # Take screenshot with viewport info in name
      screenshot_name = "#{name}_#{viewport}_#{width}x#{height}"
      screenshot_and_compare(screenshot_name)
    end
  end

  # Take screenshot and compare with baseline
  #
  # @param name [String] Screenshot name
  #
  def screenshot_and_compare(name)
    # Ensure any animations have completed
    sleep 0.1

    # Take screenshot
    screenshot(name)

    # Compare with baseline
    expect(page).to match_screenshot(name)
  end

  # Test component in multiple states
  #
  # @param component_class [Class] Component class
  # @param name [String] Base name for screenshots
  # @param states [Array<Hash>] Array of state configurations
  #
  # @example Test button in different states
  #   screenshot_states(
  #     Ui::ButtonComponent,
  #     name: "button",
  #     states: [
  #       { label: "default", props: {} },
  #       { label: "disabled", props: { disabled: true } },
  #       { label: "loading", props: { loading: true } }
  #     ]
  #   ) { "Button Text" }
  #
  def screenshot_states(component_class, name:, states:, &block)
    states.each do |state|
      label = state[:label]
      props = state[:props] || {}

      component = component_class.new(**props)
      render_inline(component, &block)

      screenshot_and_compare("#{name}_#{label}")
    end
  end

  # Test component with different content lengths
  #
  # @param component_class [Class] Component class
  # @param name [String] Base name for screenshots
  # @param contents [Hash] Hash of label => content
  #
  def screenshot_contents(component_class, name:, contents:, **props)
    contents.each do |label, content|
      component = component_class.new(**props)
      render_inline(component) { content }

      screenshot_and_compare("#{name}_#{label}")
    end
  end

  private

  # Resize browser window to specific dimensions
  def resize_to(width, height)
    return unless respond_to?(:page)
    return unless page.driver.browser.respond_to?(:manage)

    page.driver.browser.manage.window.resize_to(width, height)

    # Give browser time to complete resize
    sleep 0.05
  rescue StandardError => e
    # Log but don't fail if resize is not supported
    warn "Could not resize browser: #{e.message}"
  end
end

RSpec.configure do |config|
  # Include helpers in component and system specs
  config.include VisualTestHelpers, type: :component
  config.include VisualTestHelpers, type: :system
end
