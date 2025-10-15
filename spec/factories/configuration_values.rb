FactoryBot.define do
  factory :configuration_value do
    configuration
    sequence(:value) { |n| "Value #{n}" }
    position { 1 }

    # Specific value traits
    trait :small do
      value { 'Small' }
    end

    trait :medium do
      value { 'Medium' }
    end

    trait :large do
      value { 'Large' }
    end

    trait :red do
      value { 'Red' }
    end

    trait :blue do
      value { 'Blue' }
    end

    trait :green do
      value { 'Green' }
    end
  end
end
