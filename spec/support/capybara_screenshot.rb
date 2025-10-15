# frozen_string_literal: true

# TODO: Fix capybara-screenshot gem loading issue
# require 'capybara-screenshot/diff'
begin
  require 'capybara_screenshot_diff'

  # Configure capybara-screenshot for visual regression testing
  Capybara::Screenshot.enabled = true

  # Add OS and driver info to screenshot paths for debugging
  # This helps identify environment-specific issues
  Capybara::Screenshot.add_os_path = true
  Capybara::Screenshot.add_driver_path = true

  # Enable diff comparison
  Capybara::Screenshot::Diff.enabled = true if defined?(Capybara::Screenshot::Diff)

  # Tolerance settings for screenshot comparison
  # These values allow for minor rendering differences between environments
  if defined?(Capybara::Screenshot::Diff)
    Capybara::Screenshot::Diff.color_distance_limit = 50 if Capybara::Screenshot::Diff.respond_to?(:color_distance_limit=)
    Capybara::Screenshot::Diff.shift_distance_limit = 1 if Capybara::Screenshot::Diff.respond_to?(:shift_distance_limit=)
    Capybara::Screenshot::Diff.area_size_limit = 100 if Capybara::Screenshot::Diff.respond_to?(:area_size_limit=)
    Capybara::Screenshot::Diff.tolerance = 0.01 if Capybara::Screenshot::Diff.respond_to?(:tolerance=)
  end

  # Store screenshots in organized directory structure
  Capybara::Screenshot.save_path = Rails.root.join('spec/visual')

  # Capture strategy: :full captures entire page, :viewport captures only visible area
  # Using :full ensures we catch issues below the fold
  if defined?(Capybara::Screenshot::Diff) && Capybara::Screenshot::Diff.respond_to?(:screenshot_area=)
    Capybara::Screenshot::Diff.screenshot_area = :full
  end
rescue LoadError
  # Gem not properly loaded, skip screenshot diff functionality
end

# Skip font rendering checks to avoid cross-platform font antialiasing issues
# Uncomment if you experience font-related test failures between macOS and Linux
# Capybara::Screenshot::Diff.skip_fonts = true

RSpec.configure do |config|
  # Add screenshot comparison to component specs
  config.include Capybara::Screenshot::Diff::TestMethods, type: :component
  config.include Capybara::Screenshot::Diff::TestMethods, type: :system

  # Set up stable screenshot environment
  config.before(:each, type: :component) do
    # Disable animations for consistent screenshots
    page.execute_script(<<~JS) if respond_to?(:page)
      // Add CSS to disable animations
      const style = document.createElement('style');
      style.textContent = `
        *, *::before, *::after {
          animation-duration: 0s !important;
          animation-delay: 0s !important;
          transition-duration: 0s !important;
          transition-delay: 0s !important;
        }
      `;
      document.head.appendChild(style);
    JS
  rescue StandardError
    # Ignore errors for tests without page object
  end

  # Clean up failed screenshots after successful re-runs
  config.after(:each, type: :component) do |example|
    if example.exception.nil?
      # Test passed, clean up any old failure artifacts
      screenshot_name = example.metadata[:full_description].gsub(/\s+/, '_')
      failure_path = Rails.root.join("spec/visual/#{screenshot_name}.diff.png")
      File.delete(failure_path) if File.exist?(failure_path)
    end
  end

  # For system tests, ensure consistent window size
  config.before(:each, type: :system) do
    # Default to desktop size for system tests
    page.driver.browser.manage.window.resize_to(1440, 900) if respond_to?(:page)
  end
end
