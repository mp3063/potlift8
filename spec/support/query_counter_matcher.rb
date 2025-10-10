# RSpec Matcher for Database Query Counting
#
# This matcher helps detect N+1 queries and verify query optimization.
# It counts the number of SQL queries executed within a block.
#
# Usage:
#   expect { Product.all.each(&:name) }.to make_database_queries(count: 1)
#   expect { Product.includes(:company).each { |p| p.company.name } }.to make_database_queries(count: 2)
#   expect { optimized_code }.to make_database_queries(count: ..5) # At most 5 queries
#
# Examples:
#   # Exact count
#   expect { Product.find(1) }.to make_database_queries(count: 1)
#
#   # Range
#   expect { complex_operation }.to make_database_queries(count: 1..3)
#
#   # Maximum (using endless range)
#   expect { optimized_code }.to make_database_queries(count: ..5)
#

RSpec::Matchers.define :make_database_queries do |count: nil|
  supports_block_expectations

  match do |block|
    @query_count = count_queries(&block)

    case count
    when Integer
      @query_count == count
    when Range
      count.include?(@query_count)
    else
      raise ArgumentError, "Expected count to be an Integer or Range, got #{count.class}"
    end
  end

  failure_message do |block|
    case count
    when Integer
      "expected #{count} database #{pluralize_query(count)}, but #{@query_count} #{pluralize_query(@query_count)} were made"
    when Range
      "expected between #{count.min || 0} and #{count.max || 'unlimited'} database queries, but #{@query_count} #{pluralize_query(@query_count)} were made"
    end
  end

  failure_message_when_negated do |block|
    case count
    when Integer
      "expected not to make #{count} database #{pluralize_query(count)}, but exactly #{count} #{pluralize_query(count)} were made"
    when Range
      "expected not to make between #{count.min || 0} and #{count.max || 'unlimited'} database queries"
    end
  end

  description do
    case count
    when Integer
      "make exactly #{count} database #{pluralize_query(count)}"
    when Range
      "make between #{count.min || 0} and #{count.max || 'unlimited'} database queries"
    end
  end

  # Count SQL queries executed within a block
  def count_queries
    query_count = 0

    counter = lambda do |_name, _started, _finished, _unique_id, payload|
      # Only count actual SQL queries, not SCHEMA or CACHE queries
      query_count += 1 unless %w[SCHEMA CACHE].include?(payload[:name])
    end

    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      yield
    end

    query_count
  end

  # Helper to pluralize "query"
  def pluralize_query(count)
    count == 1 ? 'query' : 'queries'
  end
end
