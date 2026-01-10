FactoryBot.define do
  factory :inventory do
    product
    storage
    value { 10 }
    info { {} }
    default { false }
    eta { nil }

    # Trait for zero stock
    trait :out_of_stock do
      value { 0 }
    end

    # Trait for high stock
    trait :high_stock do
      value { 1000 }
    end

    # Trait for default inventory location
    trait :default_location do
      default { true }
    end

    # Trait for incoming inventory with ETA
    trait :incoming_with_eta do
      association :storage, factory: [ :storage, :incoming ]
      eta { 7.days.from_now }
      value { 50 }
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'batch_number' => 'BATCH-001',
          'expiry_date' => 1.year.from_now.to_s,
          'notes' => 'Special handling required'
        }
      end
    end

    # Trait for regular storage inventory
    trait :in_regular_storage do
      association :storage, factory: [ :storage, :regular ]
    end

    # Trait for temporary storage inventory
    trait :in_temporary_storage do
      association :storage, factory: [ :storage, :temporary ]
    end

    # Trait for incoming storage inventory
    trait :in_incoming_storage do
      association :storage, factory: [ :storage, :incoming ]
    end
  end
end
