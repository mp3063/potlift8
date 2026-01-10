# frozen_string_literal: true

RSpec::Matchers.define :exceed_query_limit do |expected|
  supports_block_expectations

  match do |block|
    @query_count = count_queries(&block)
    @query_count > expected
  end

  failure_message do
    "expected block to exceed #{expected} queries, but ran #{@query_count}"
  end

  failure_message_when_negated do
    "expected block not to exceed #{expected} queries, but ran #{@query_count}"
  end

  def count_queries(&block)
    count = 0
    counter = ->(name, start, finish, id, payload) {
      count += 1 unless payload[:name].in?([ 'SCHEMA', 'TRANSACTION', nil ]) || payload[:sql].match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record', &block)
    count
  end
end
