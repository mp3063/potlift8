FactoryBot.define do
  factory :bundle_template do
    association :product, factory: [ :product, :bundle ]
    company { product.company }
    configuration { {} }
    generated_variants_count { 0 }
    last_generated_at { nil }

    trait :with_configuration do
      transient do
        sellable_product { nil }
      end

      after(:build) do |template, evaluator|
        if evaluator.sellable_product
          template.configuration = {
            'components' => [
              {
                'product_id' => evaluator.sellable_product.id,
                'product_type' => 'sellable',
                'quantity' => 1
              }
            ]
          }
        end
      end
    end
  end
end
