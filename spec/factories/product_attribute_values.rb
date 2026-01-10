FactoryBot.define do
  factory :product_attribute_value do
    product
    product_attribute
    value { "Sample value" }
    info { {} }
    ready { true }

    # Trait for not ready value
    trait :not_ready do
      ready { false }
    end

    # Trait for text value
    trait :text_value do
      association :product_attribute, factory: [ :product_attribute, :text_type ]
      value { "Sample text value" }
    end

    # Trait for number value
    trait :number_value do
      association :product_attribute, factory: [ :product_attribute, :number_type ]
      value { "42" }
    end

    # Trait for boolean value
    trait :boolean_value do
      association :product_attribute, factory: [ :product_attribute, :boolean_type ]
      value { "true" }
    end

    # Trait for price value
    trait :price_value do
      association :product_attribute, factory: [ :product_attribute, :price_format ]
      value { "1999" } # 19.99 euros in cents
    end

    # Trait for weight value
    trait :weight_value do
      association :product_attribute, factory: [ :product_attribute, :weight_format ]
      value { "1500" } # 1500 grams
    end

    # Trait for EAN value
    trait :ean_value do
      association :product_attribute, factory: [ :product_attribute, :ean_format ]
      value { "5012345678900" }
    end

    # Trait for HTML value
    trait :html_value do
      association :product_attribute, factory: [ :product_attribute, :html_format ]
      value { "<p>This is <strong>HTML</strong> content</p>" }
    end

    # Trait for markdown value
    trait :markdown_value do
      association :product_attribute, factory: [ :product_attribute, :markdown_format ]
      value { "# Heading\n\nThis is **markdown** content" }
    end

    # Trait for select value
    trait :select_value do
      association :product_attribute, factory: [ :product_attribute, :select_type ]
      value { "Option 1" }
    end

    # Trait for special price (custom format)
    trait :special_price_value do
      association :product_attribute, factory: [ :product_attribute, :special_price_format ]
      value { nil }
      info do
        {
          'special_price' => {
            'amount' => 1499,
            'from' => 7.days.from_now.to_date.to_s,
            'until' => 30.days.from_now.to_date.to_s
          }
        }
      end
    end

    # Trait for customer group price (custom format)
    trait :customer_group_price_value do
      association :product_attribute, factory: [ :product_attribute, :customer_group_price_format ]
      value { nil }
      info do
        {
          'customer_group_prices' => {
            'retail' => 1999,
            'wholesale' => 1499,
            'vip' => 1299
          }
        }
      end
    end

    # Trait for related products
    trait :related_products_value do
      association :product_attribute, factory: [ :product_attribute, :related_products_format ]
      value { nil }
      info do
        {
          'related_products' => [ 'SKU001', 'SKU002', 'SKU003' ]
        }
      end
    end

    # Trait with localized values
    trait :with_localized_values do
      info do
        {
          'localized_value' => {
            'en' => 'English value',
            'de' => 'German value',
            'fr' => 'French value'
          }
        }
      end
    end

    # Trait for invalid value (breaks rules)
    trait :invalid_positive do
      association :product_attribute, factory: [ :product_attribute, :number_type, :with_positive_rule ]
      value { "-10" } # Negative number breaks positive rule
      ready { false }
    end

    trait :invalid_not_null do
      association :product_attribute, factory: [ :product_attribute, :text_type, :with_not_null_rule ]
      value { "" } # Empty string breaks not_null rule
      ready { false }
    end
  end
end
