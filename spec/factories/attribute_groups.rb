FactoryBot.define do
  factory :attribute_group do
    company
    sequence(:code) { |n| "group_#{n}" }
    sequence(:name) { |n| "Attribute Group #{n}" }
    description { "A collection of related product attributes" }
    position { nil }
    info { {} }

    # Trait for positioned groups
    trait :positioned do
      sequence(:position) { |n| n }
    end

    # Trait for groups with custom info
    trait :with_info do
      info do
        {
          'display_order' => 'alphabetical',
          'collapsed' => false,
          'icon' => 'folder'
        }
      end
    end

    # Predefined attribute groups
    trait :basic_info_group do
      code { 'basic_info' }
      name { 'Basic Information' }
      description { 'Core product information like name, description, and identifiers' }
    end

    trait :pricing_group do
      code { 'pricing' }
      name { 'Pricing & Cost' }
      description { 'All price-related attributes including special prices and customer group pricing' }
    end

    trait :dimensions_group do
      code { 'dimensions' }
      name { 'Dimensions & Weight' }
      description { 'Physical measurements including size, weight, and volume' }
    end

    trait :technical_group do
      code { 'technical' }
      name { 'Technical Specifications' }
      description { 'Technical details and specifications' }
    end

    trait :seo_group do
      code { 'seo' }
      name { 'SEO & Marketing' }
      description { 'Search engine optimization and marketing attributes' }
    end
  end
end
