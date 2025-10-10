FactoryBot.define do
  factory :catalog_item do
    catalog
    product
    priority { 100 }
    catalog_item_state { :active }
    info { {} }

    # State traits
    trait :active do
      catalog_item_state { :active }
    end

    trait :inactive do
      catalog_item_state { :inactive }
    end

    # Priority traits
    trait :high_priority do
      priority { 1000 }
    end

    trait :low_priority do
      priority { 10 }
    end

    trait :no_priority do
      priority { nil }
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'featured' => true,
          'promotion_text' => 'Special offer!',
          'display_order' => 1
        }
      end
    end

    # Trait with attribute overrides
    trait :with_overrides do
      transient do
        overrides_count { 2 }
      end

      after(:create) do |catalog_item, evaluator|
        company = catalog_item.catalog.company

        # Create catalog-scoped attributes
        attributes = create_list(:product_attribute, evaluator.overrides_count,
                                 company: company,
                                 product_attribute_scope: :catalog_scope)

        attributes.each do |attr|
          create(:catalog_item_attribute_value,
                catalog_item: catalog_item,
                product_attribute: attr)
        end
      end
    end

    # Trait with price override
    trait :with_price_override do
      after(:create) do |catalog_item|
        company = catalog_item.catalog.company
        price_attr = create(:product_attribute,
                           company: company,
                           code: 'price',
                           pa_type: :patype_number,
                           view_format: :view_format_price,
                           product_attribute_scope: :product_and_catalog_scope)

        create(:catalog_item_attribute_value,
              catalog_item: catalog_item,
              product_attribute: price_attr,
              value: '1999')
      end
    end
  end
end
