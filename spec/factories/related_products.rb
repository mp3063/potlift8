FactoryBot.define do
  factory :related_product do
    transient do
      shared_company { nil }
    end

    product { association(:product, company: shared_company || association(:company)) }
    related_to { association(:product, company: product.company) }
    relation_type { 'cross_sell' }
    position { 1 }

    # Relation type traits
    trait :cross_sell do
      relation_type { 'cross_sell' }
    end

    trait :upsell do
      relation_type { 'upsell' }
    end

    trait :alternative do
      relation_type { 'alternative' }
    end

    trait :accessory do
      relation_type { 'accessory' }
    end

    trait :similar do
      relation_type { 'similar' }
    end
  end
end
