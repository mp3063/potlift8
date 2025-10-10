FactoryBot.define do
  factory :storage do
    company
    sequence(:code) { |n| "WH#{n}" }
    sequence(:name) { |n| "Warehouse #{n}" }
    storage_type { :regular }
    storage_status { :active }
    info { {} }
    default { false }
    storage_position { nil }

    # Trait for regular storage (default)
    trait :regular do
      storage_type { :regular }
      code { "REGULAR" }
      name { "Regular Storage" }
    end

    # Trait for temporary storage
    trait :temporary do
      storage_type { :temporary }
      code { "TEMP" }
      name { "Temporary Storage" }
    end

    # Trait for incoming storage
    trait :incoming do
      storage_type { :incoming }
      code { "INCOMING" }
      name { "Incoming Storage" }
    end

    # Trait for deleted status
    trait :deleted do
      storage_status { :deleted }
    end

    # Trait for default storage
    trait :default_storage do
      default { true }
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'location' => 'Building A',
          'capacity' => 1000,
          'notes' => 'Main warehouse'
        }
      end
    end

    # Trait with position
    trait :positioned do
      sequence(:storage_position) { |n| n }
    end

    # Trait with products (has inventories)
    trait :with_products do
      transient do
        products_count { 3 }
      end

      after(:create) do |storage, evaluator|
        create_list(:inventory, evaluator.products_count, storage: storage)
      end
    end
  end
end
