FactoryBot.define do
  factory :configuration do
    transient do
      use_product_company { true }
    end

    association :product, factory: [:product, :configurable_variant]
    company { use_product_company && product ? product.company : association(:company) }
    sequence(:name) { |n| "Configuration #{n}" }
    sequence(:code) { |n| "config_#{n}" }
    position { 1 }

    # Trait for size configuration
    trait :size do
      name { 'Size' }
      code { 'size' }

      after(:create) do |configuration|
        create(:configuration_value, configuration: configuration, value: 'Small', position: 1)
        create(:configuration_value, configuration: configuration, value: 'Medium', position: 2)
        create(:configuration_value, configuration: configuration, value: 'Large', position: 3)
      end
    end

    # Trait for color configuration
    trait :color do
      name { 'Color' }
      code { 'color' }

      after(:create) do |configuration|
        create(:configuration_value, configuration: configuration, value: 'Red', position: 1)
        create(:configuration_value, configuration: configuration, value: 'Blue', position: 2)
        create(:configuration_value, configuration: configuration, value: 'Green', position: 3)
      end
    end

    # Trait for material configuration
    trait :material do
      name { 'Material' }
      code { 'material' }

      after(:create) do |configuration|
        create(:configuration_value, configuration: configuration, value: 'Cotton', position: 1)
        create(:configuration_value, configuration: configuration, value: 'Polyester', position: 2)
      end
    end

    # Trait with multiple values
    trait :with_values do
      transient do
        values_count { 3 }
      end

      after(:create) do |configuration, evaluator|
        create_list(:configuration_value, evaluator.values_count, configuration: configuration)
      end
    end
  end
end
