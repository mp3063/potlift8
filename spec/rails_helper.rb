# This file is copied to spec/ when you run 'rails generate rspec:install'

# Code coverage tracking - must be loaded before other code
require 'simplecov'

require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'

# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?

# Uncomment the line below in case you have `--require rails_helper` in the `.rspec` file
# that will avoid rails generators crashing because migrations haven't been run yet
# return unless Rails.env.test?

require 'rspec/rails'

# Add additional requires below this line. Rails is not loaded until this point!

# Require testing libraries
require 'capybara/rspec'
require 'webmock/rspec'

# Configure WebMock to allow local requests
WebMock.disable_net_connect!(allow_localhost: true)

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# Auto-require all files in spec/support for convenience
Rails.root.glob('spec/support/**/*.rb').sort_by(&:to_s).each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end
RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [
    Rails.root.join('spec/fixtures')
  ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  # NOTE: We're using DatabaseCleaner instead, so set this to false
  config.use_transactional_fixtures = false

  # You can uncomment this line to turn off ActiveRecord support entirely.
  # config.use_active_record = false

  # Infer spec type from file location automatically
  # This allows you to omit `type: :controller`, `type: :model`, etc.
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces for cleaner error output
  config.filter_rails_from_backtrace!

  # Filter gems from backtrace (add more as needed)
  config.filter_gems_from_backtrace('rack', 'rack-test', 'actionpack')

  # Include request helpers for all specs
  config.include Rails.application.routes.url_helpers

  # Capybara configuration for system tests
  config.before(:each, type: :system) do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end

  # Reset sessions and cookies between tests
  config.after(:each, type: :system) do
    page.driver.browser.manage.delete_all_cookies if defined?(page)
  end

  # Configure default behavior for controller specs
  config.before(:each, type: :controller) do
    # Set up default request format
    request.env["HTTP_ACCEPT"] = "application/json" if request
  end

  # Global test helpers - available in all specs
  config.include ActionDispatch::TestProcess::FixtureFile

  # Enable aggregate failures for better error messages
  # This shows all failed expectations rather than stopping at first failure
  config.define_derived_metadata do |meta|
    meta[:aggregate_failures] = true unless meta.key?(:aggregate_failures)
  end

  # Randomize test order for better test independence
  # Use --seed option to re-run tests in same order
  config.order = :random
  Kernel.srand config.seed

  # Show slowest examples (useful for identifying slow tests)
  # Uncomment to enable:
  # config.profile_examples = 10

  # Allow focused tests (fit, fdescribe) in development
  # Warns when focus is left in test suite
  config.filter_run_when_matching :focus

  # Show more detailed failure output
  config.example_status_persistence_file_path = "spec/examples.txt"

  # Configuration for WebMock and VCR
  config.before(:each, type: :system) do
    # Allow real HTTP connections in system tests
    WebMock.allow_net_connect!
  end

  config.after(:each) do
    # Reset WebMock after each test
    WebMock.reset!
  end
end
