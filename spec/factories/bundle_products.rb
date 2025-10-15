# Refactored Bundle Product Factory using ProductConfiguration
# This replaces the old BundleProduct model approach
FactoryBot.define do
  # ProductConfiguration for bundles
  factory :bundle_component, class: 'ProductConfiguration' do
    association :superproduct, factory: [:product, :bundle]
    association :subproduct, factory: [:product, :sellable]
    configuration_position { nil }

    # Default quantity for bundle components
    after(:build) do |config|
      config.info ||= {}
      config.info['quantity'] ||= 1
    end

    # Trait with specific quantity
    trait :quantity_two do
      after(:build) do |config|
        config.info = { 'quantity' => 2 }
      end
    end

    trait :quantity_three do
      after(:build) do |config|
        config.info = { 'quantity' => 3 }
      end
    end

    trait :quantity_five do
      after(:build) do |config|
        config.info = { 'quantity' => 5 }
      end
    end

    # Trait with custom quantity value
    trait :with_quantity do
      transient do
        quantity_value { 1 }
      end

      after(:build) do |config, evaluator|
        config.info = { 'quantity' => evaluator.quantity_value }
      end
    end

    # Trait with inventory on subproduct
    trait :with_subproduct_inventory do
      transient do
        subproduct_stock { 100 }
      end

      after(:create) do |config, evaluator|
        storage = create(:storage, company: config.superproduct.company)
        create(:inventory,
               product: config.subproduct,
               storage: storage,
               value: evaluator.subproduct_stock)
      end
    end

    # Trait with positioned configuration
    trait :positioned do
      sequence(:configuration_position) { |n| n }
    end

    # Trait for high quantity requirements
    trait :high_quantity do
      after(:build) do |config|
        config.info = { 'quantity' => 10 }
      end
    end
  end

  # Alias for backward compatibility with existing tests
  factory :bundle_product_config, parent: :bundle_component
end
