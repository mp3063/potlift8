FactoryBot.define do
  factory :product_configuration do
    association :superproduct, factory: :product
    association :subproduct, factory: :product
    configuration_position { nil }
    info { {} }

    # Trait for variant configuration
    trait :variant do
      association :superproduct, factory: [ :product, :configurable_variant ]
      association :subproduct, factory: [ :product, :sellable ]
    end

    # Trait for bundle configuration with quantity
    trait :bundle_item do
      association :superproduct, factory: [ :product, :bundle ]
      association :subproduct, factory: [ :product, :sellable ]
      info { { 'quantity' => 2 } }
    end

    # Trait with specific position
    trait :positioned do
      sequence(:configuration_position) { |n| n }
    end

    # Trait with custom quantity
    trait :with_quantity do
      transient do
        quantity_value { 1 }
      end

      after(:build) do |config, evaluator|
        config.info = { 'quantity' => evaluator.quantity_value }
      end
    end
  end
end
