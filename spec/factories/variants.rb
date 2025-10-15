# Refactored Variant Factory using ProductConfiguration
# This replaces the old Variant model approach
FactoryBot.define do
  # ProductConfiguration for variants
  factory :variant_configuration, class: 'ProductConfiguration' do
    association :superproduct, factory: [:product, :configurable_variant]
    association :subproduct, factory: [:product, :sellable]
    configuration_position { nil }
    info { {} }

    # Trait for variant with configuration values stored in info
    trait :with_configuration do
      transient do
        size { 'Medium' }
        color { 'Blue' }
      end

      after(:build) do |config, evaluator|
        config.info = {
          'variant_config' => {
            'size' => evaluator.size,
            'color' => evaluator.color
          }
        }
      end
    end

    # Trait for small red variant
    trait :small_red do
      after(:build) do |config|
        config.info = {
          'variant_config' => {
            'size' => 'Small',
            'color' => 'Red'
          }
        }
      end

      after(:create) do |config|
        # Update subproduct name to match variant configuration
        config.subproduct.update(name: "#{config.superproduct.name} - Small / Red")
      end
    end

    # Trait for medium blue variant
    trait :medium_blue do
      after(:build) do |config|
        config.info = {
          'variant_config' => {
            'size' => 'Medium',
            'color' => 'Blue'
          }
        }
      end

      after(:create) do |config|
        config.subproduct.update(name: "#{config.superproduct.name} - Medium / Blue")
      end
    end

    # Trait for large green variant
    trait :large_green do
      after(:build) do |config|
        config.info = {
          'variant_config' => {
            'size' => 'Large',
            'color' => 'Green'
          }
        }
      end

      after(:create) do |config|
        config.subproduct.update(name: "#{config.superproduct.name} - Large / Green")
      end
    end

    # Trait for variant with inventory
    trait :with_inventory do
      transient do
        inventory_value { 50 }
      end

      after(:create) do |config, evaluator|
        storage = create(:storage, company: config.subproduct.company)
        create(:inventory, product: config.subproduct, storage: storage, value: evaluator.inventory_value)
      end
    end

    # Trait with positioned configuration
    trait :positioned do
      sequence(:configuration_position) { |n| n }
    end

    # Trait with three dimensions (size, color, material)
    trait :with_three_dimensions do
      transient do
        size { 'Medium' }
        color { 'Blue' }
        material { 'Cotton' }
      end

      after(:build) do |config, evaluator|
        config.info = {
          'variant_config' => {
            'size' => evaluator.size,
            'color' => evaluator.color,
            'material' => evaluator.material
          }
        }
      end
    end
  end
end
