FactoryBot.define do
  factory :catalog_item_attribute_value do
    catalog_item
    product_attribute
    value { 'Test Value' }
    ready { true }
    info { {} }

    # Trait for unready values
    trait :not_ready do
      ready { false }
    end

    # Trait for blank value
    trait :blank_value do
      value { '' }
    end

    # Trait with numeric value
    trait :numeric_value do
      value { '1999' }

      after(:build) do |ciav|
        ciav.product_attribute.pa_type = :patype_number
        ciav.product_attribute.view_format = :view_format_general
      end
    end

    # Trait with price value
    trait :price_value do
      value { '1999' }

      after(:build) do |ciav|
        ciav.product_attribute.pa_type = :patype_number
        ciav.product_attribute.view_format = :view_format_price
      end
    end

    # Trait with text value
    trait :text_value do
      value { 'Sample text content' }

      after(:build) do |ciav|
        ciav.product_attribute.pa_type = :patype_text
      end
    end

    # Trait with boolean value
    trait :boolean_value do
      value { 'true' }

      after(:build) do |ciav|
        ciav.product_attribute.pa_type = :patype_boolean
      end
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'source' => 'manual_override',
          'updated_by' => 'admin',
          'notes' => 'Special catalog pricing'
        }
      end
    end
  end
end
