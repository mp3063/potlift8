# frozen_string_literal: true

# ActiveJob test helpers for RSpec
RSpec.configure do |config|
  # Include ActiveJob test helpers in all specs
  config.include ActiveJob::TestHelper

  # Clear enqueued and performed jobs before each test
  config.before(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  # Ensure jobs are cleared after each test
  config.after(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
