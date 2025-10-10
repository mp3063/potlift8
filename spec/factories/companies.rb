FactoryBot.define do
  factory :company do
    sequence(:code) { |n| "COMP#{n}" }
    sequence(:name) { |n| "Company #{n}" }
    info { {} }
    active { true }

    # Factory trait for inactive company
    trait :inactive do
      active { false }
    end

    # Factory trait with custom info
    trait :with_info do
      info do
        {
          'timezone' => 'America/New_York',
          'currency' => 'USD',
          'settings' => {
            'notifications' => true,
            'theme' => 'light'
          }
        }
      end
    end

    # Factory trait for specific company
    trait :acme do
      code { 'ACME' }
      name { 'ACME Corporation' }
    end
  end
end
