FactoryBot.define do
  factory :price do
    association :product
    value { 1999 }
    currency { 'EUR' }
    price_type { 'base' }

    trait :base do
      price_type { 'base' }
      customer_group { nil }
    end

    trait :special do
      price_type { 'special' }
      valid_from { 1.week.ago }
      valid_to { 1.week.from_now }
    end

    trait :group do
      price_type { 'group' }
      customer_group { association :customer_group, company: product.company }
    end

    trait :expired do
      price_type { 'special' }
      valid_from { 2.weeks.ago }
      valid_to { 1.week.ago }
    end

    trait :future do
      price_type { 'special' }
      valid_from { 1.week.from_now }
      valid_to { 2.weeks.from_now }
    end

    trait :eur do
      currency { 'EUR' }
    end

    trait :sek do
      currency { 'SEK' }
    end

    trait :nok do
      currency { 'NOK' }
    end
  end
end
