FactoryBot.define do
  factory :sync_lock do
    sequence(:timestamp) { |n| "2025-10-10-#{1000 + n}" }

    # Trait for recent sync
    trait :recent do
      timestamp { Time.current.strftime("%Y-%m-%d-%H%M") }
    end

    # Trait for old sync
    trait :old do
      timestamp { 1.year.ago.strftime("%Y-%m-%d-%H%M") }
    end

    # Trait for today's sync
    trait :today do
      timestamp { Date.today.strftime("%Y-%m-%d-0000") }
    end

    # Trait with custom timestamp format
    trait :with_date do
      timestamp { Date.current.to_s }
    end

    # Trait with products
    trait :with_products do
      transient do
        products_count { 5 }
      end

      after(:create) do |sync_lock, evaluator|
        create_list(:product, evaluator.products_count, sync_lock: sync_lock)
      end
    end
  end
end
