# frozen_string_literal: true

# DatabaseCleaner configuration for RSpec
# This ensures database state is properly cleaned between tests
# to prevent test pollution and ensure test isolation.
#
# Strategies:
# - :transaction (fastest) - Wraps each test in a database transaction
#   Used for most tests (model, controller, request specs)
#
# - :truncation (slower) - Truncates tables after each test
#   Used for system/feature specs that use JavaScript/Selenium
#   because transactions don't work across multiple database connections
#
# - :deletion (slower) - Deletes all records after each test
#   Alternative to truncation, sometimes needed for specific databases

require "database_cleaner/active_record"

RSpec.configure do |config|
  # Before the entire test suite runs
  config.before(:suite) do
    # Clean the database completely before starting
    DatabaseCleaner.clean_with(:truncation)
  end

  # Before each test
  config.before(:each) do |example|
    # Use transaction strategy by default (fastest)
    DatabaseCleaner.strategy = :transaction

    # For system/feature specs, use truncation strategy
    # This is necessary because Capybara/Selenium runs in a separate thread/process
    # and transactions are not shared across database connections
    if example.metadata[:type] == :system || example.metadata[:js]
      DatabaseCleaner.strategy = :truncation
    end

    # Start the cleaning strategy
    DatabaseCleaner.start
  end

  # After each test
  config.after(:each) do
    # Clean up the database
    DatabaseCleaner.clean
  end
end
