FactoryBot.define do
  factory :product_label do
    product
    label

    # Trait for association with root label
    trait :with_root_label do
      association :label, factory: [:label, :root]
    end

    # Trait for association with child label
    trait :with_child_label do
      association :label, factory: [:label, :child]
    end

    # Trait for category type label
    trait :category_label do
      association :label, factory: [:label, :category_type]
    end

    # Trait for tag type label
    trait :tag_label do
      association :label, factory: [:label, :tag_type]
    end

    # Trait for brand type label
    trait :brand_label do
      association :label, factory: [:label, :brand_type]
    end
  end
end
