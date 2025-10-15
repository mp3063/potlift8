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

  # Include Rails routing helpers for components that use path helpers
  config.include Rails.application.routes.url_helpers, type: :component

  # Configure the default component type
  config.define_derived_metadata(file_path: %r{spec/components}) do |metadata|
    metadata[:type] = :component
  end

  # Set up request context for ViewComponent tests (needed for routing helpers)
  config.before(:each, type: :component) do
    # ViewComponent test helpers provide vc_test_controller which gives us the necessary context
    # The render_inline method automatically sets up the controller and request context
    # We just need to ensure current_page? returns false by default in tests
    allow_any_instance_of(ActionView::Helpers::UrlHelper).to receive(:current_page?).and_return(false)

    # Define missing route helpers for navigation components
    # These routes don't exist yet but are referenced in navigation components
    ActionView::Base.class_eval do
      def inventories_path
        "/inventories"
      end

      def reports_path
        "/reports"
      end

      def profile_path
        "/profile"
      end

      def settings_path
        "/settings"
      end
    end unless ActionView::Base.method_defined?(:inventories_path)
  end
end
