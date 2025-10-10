FactoryBot.define do
  factory :company_state do
    company
    sequence(:code) { |n| "state_key_#{n}" }
    state { "state_value" }

    # Trait for sync status
    trait :sync_status do
      code { "last_sync" }
      state { Time.current.iso8601 }
    end

    # Trait for feature flag
    trait :feature_flag do
      code { "feature_advanced_reports" }
      state { "enabled" }
    end

    trait :feature_disabled do
      code { "feature_basic_mode" }
      state { "disabled" }
    end

    # Trait for integration state
    trait :shopify_integration do
      code { "shopify_integration_status" }
      state { "active" }
    end

    trait :api_key do
      code { "external_api_key" }
      state { "sk_test_abc123xyz789" }
    end

    # Trait for configuration
    trait :configuration do
      code { "default_currency" }
      state { "EUR" }
    end

    trait :timezone_config do
      code { "default_timezone" }
      state { "Europe/Berlin" }
    end

    # Trait for counter
    trait :counter do
      code { "product_import_count" }
      state { "150" }
    end

    # Trait with nil state
    trait :nil_state do
      state { nil }
    end

    # Trait for JSON state (stored as string)
    trait :json_state do
      code { "complex_config" }
      state do
        {
          'setting1' => 'value1',
          'setting2' => 100,
          'nested' => { 'key' => 'value' }
        }.to_json
      end
    end
  end
end
