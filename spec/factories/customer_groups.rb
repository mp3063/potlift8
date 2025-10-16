FactoryBot.define do
  factory :customer_group do
    association :company
    sequence(:name) { |n| "Customer Group #{n}" }
    sequence(:code) { |n| "GROUP#{n}" }
    discount_percent { 10 }

    trait :vip do
      name { 'VIP Customers' }
      code { 'VIP' }
      discount_percent { 20 }
    end

    trait :wholesale do
      name { 'Wholesale' }
      code { 'WHOLESALE' }
      discount_percent { 30 }
    end

    trait :retail do
      name { 'Retail' }
      code { 'RETAIL' }
      discount_percent { 0 }
    end

    trait :no_discount do
      discount_percent { nil }
    end
  end
end
