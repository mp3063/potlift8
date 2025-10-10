# frozen_string_literal: true

# Time helpers for testing
RSpec.configure do |config|
  # Include ActiveSupport::Testing::TimeHelpers for time manipulation
  config.include ActiveSupport::Testing::TimeHelpers
end
