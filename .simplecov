# frozen_string_literal: true

# SimpleCov configuration for code coverage tracking
# This file configures SimpleCov to generate code coverage reports
# after running the test suite.
#
# Reports are generated in the /coverage directory
# Open coverage/index.html in a browser to view the report
#
# Usage:
#   # Run tests normally
#   bundle exec rspec
#
#   # View coverage report
#   open coverage/index.html

SimpleCov.start 'rails' do
  # Name the coverage report
  coverage_dir 'coverage'

  # Minimum coverage threshold (%)
  # Tests will fail if coverage falls below this percentage
  minimum_coverage 80
  minimum_coverage_by_file 50

  # Files and directories to exclude from coverage
  add_filter '/spec/'           # Don't measure test code
  add_filter '/config/'          # Skip config files
  add_filter '/vendor/'          # Skip vendor gems
  add_filter '/db/'              # Skip migrations and seeds
  add_filter '/lib/tasks/'       # Skip rake tasks

  # Groups for organizing coverage report
  add_group 'Models', 'app/models'
  add_group 'Controllers', 'app/controllers'
  add_group 'Services', 'app/services'
  add_group 'Helpers', 'app/helpers'
  add_group 'Mailers', 'app/mailers'
  add_group 'Jobs', 'app/jobs'
  add_group 'Libraries', 'lib'

  # Track files even if they have no tests
  track_files '{app,lib}/**/*.rb'

  # Refuse coverage reports if minimum is not met
  # Comment this out if you want to see reports even with low coverage
  refuse_coverage_drop
end
