# frozen_string_literal: true

# VCR configuration for recording and replaying HTTP interactions
# This is useful for testing external API calls without actually making real requests
#
# Usage:
#
#   RSpec.describe "External API", vcr: true do
#     it "fetches data" do
#       # First run: makes real HTTP request and records it to spec/fixtures/vcr_cassettes/
#       # Subsequent runs: replays the recorded response
#       response = HTTParty.get("https://api.example.com/data")
#       expect(response.code).to eq(200)
#     end
#   end
#
#   # With custom cassette name
#   it "fetches data", vcr: { cassette_name: "custom_name" } do
#     # Recorded to spec/fixtures/vcr_cassettes/custom_name.yml
#   end
#
#   # Record new episodes (update cassette with new requests)
#   it "fetches data", vcr: { record: :new_episodes } do
#     # Records new requests while replaying existing ones
#   end

require 'vcr'

VCR.configure do |config|
  # Directory to store cassettes (recorded HTTP interactions)
  config.cassette_library_dir = Rails.root.join('spec', 'fixtures', 'vcr_cassettes')

  # Use WebMock to intercept HTTP requests
  config.hook_into :webmock

  # Filter sensitive data from cassettes
  config.filter_sensitive_data('<AUTHLIFT8_CLIENT_ID>') { ENV['AUTHLIFT8_CLIENT_ID'] }
  config.filter_sensitive_data('<AUTHLIFT8_CLIENT_SECRET>') { ENV['AUTHLIFT8_CLIENT_SECRET'] }
  config.filter_sensitive_data('<AUTHLIFT8_SITE>') { ENV['AUTHLIFT8_SITE'] }

  # Configure request matching
  # This determines which recorded response to use for a request
  config.default_cassette_options = {
    record: :once,                    # Record cassette once, then replay
    match_requests_on: [:method, :uri] # Match on HTTP method and URI
  }

  # Allow requests to localhost during tests
  config.ignore_localhost = true

  # Configure debug output (uncomment for troubleshooting)
  # config.debug_logger = File.open(Rails.root.join('log', 'vcr.log'), 'w')
end

# Auto-configure VCR for RSpec examples tagged with :vcr
RSpec.configure do |config|
  config.around(:each, :vcr) do |example|
    # Use the example description as the cassette name
    cassette_name = example.metadata[:cassette_name] || example.full_description.gsub(/[^\w\-]/, '_')

    VCR.use_cassette(cassette_name) do
      example.run
    end
  end
end
