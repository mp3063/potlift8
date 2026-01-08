# frozen_string_literal: true

# Share database connection between test thread and Capybara server thread
# This ensures that test data created in the test thread is visible to the server
# without requiring transaction commits.
#
# See: https://github.com/rails/rails/issues/37270
# and: https://stackoverflow.com/questions/3736448/rails-capybara-using-transactional-fixtures

class ActiveRecord::Base
  mattr_accessor :shared_connection
  @@shared_connection = nil

  def self.connection
    @@shared_connection || ConnectionPool::Wrapper.new { retrieve_connection }
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    # Share the connection between threads for system tests
    # This allows the test thread to see data created in the server thread and vice versa
    ActiveRecord::Base.shared_connection = ActiveRecord::Base.connection
  end

  config.after(:suite) do
    # Reset shared connection
    ActiveRecord::Base.shared_connection = nil
  end
end
