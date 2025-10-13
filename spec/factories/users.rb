# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    company
    sequence(:oauth_sub) { |n| "oauth_user_#{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "#{Faker::Name.first_name} #{Faker::Name.last_name}" }
    last_sign_in_at { Time.current }

    trait :with_memberships do
      after(:create) do |user|
        create_list(:company_membership, 2, user: user)
      end
    end

    trait :admin do
      after(:create) do |user|
        create(:company_membership, user: user, company: user.company, role: 'admin')
      end
    end

    trait :member do
      after(:create) do |user|
        create(:company_membership, user: user, company: user.company, role: 'member')
      end
    end

    trait :viewer do
      after(:create) do |user|
        create(:company_membership, user: user, company: user.company, role: 'viewer')
      end
    end
  end
end
