# frozen_string_literal: true

# ViewComponent test support
#
# This file configures ViewComponent testing for RSpec.
# It includes the necessary test helpers and configuration.

require 'view_component/test_helpers'
require 'capybara/rspec'

RSpec.configure do |config|
  # Include ViewComponent test helpers for component specs
  config.include ViewComponent::TestHelpers, type: :component

  # Include Capybara for component specs (for page assertions)
  config.include Capybara::RSpecMatchers, type: :component

  # Configure the default component type
  config.define_derived_metadata(file_path: %r{spec/components}) do |metadata|
    metadata[:type] = :component
  end
end
