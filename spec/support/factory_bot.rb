# frozen_string_literal: true

# FactoryBot configuration for RSpec
# This file configures FactoryBot to be available in all RSpec tests
# and provides convenient syntax methods for creating test data.
#
# Usage:
#   # Instead of:
#   FactoryBot.create(:user)
#
#   # You can use:
#   create(:user)
#   build(:user)
#   build_stubbed(:user)
#   attributes_for(:user)

RSpec.configure do |config|
  # Include FactoryBot syntax methods in all specs
  # This allows you to use create, build, etc. without FactoryBot prefix
  config.include FactoryBot::Syntax::Methods

  # Lint factories before running test suite (optional but recommended)
  # This checks that all factories are valid and can be created successfully
  # Uncomment the following block to enable factory linting:
  #
  # config.before(:suite) do
  #   FactoryBot.lint
  # end
end
