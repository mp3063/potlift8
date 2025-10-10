FactoryBot.define do
  factory :product_attribute do
    company
    sequence(:code) { |n| "attr#{n}" }
    sequence(:name) { |n| "Attribute #{n}" }
    pa_type { :patype_text }
    view_format { :view_format_general }
    product_attribute_scope { :product_scope }
    mandatory { false }
    has_rules { false }
    rules { {} }
    attribute_position { nil }
    info { {} }

    # Trait for mandatory attribute
    trait :mandatory do
      mandatory { true }
    end

    # Trait with rules
    trait :with_positive_rule do
      has_rules { true }
      rules { ['positive'] }
    end

    trait :with_not_null_rule do
      has_rules { true }
      rules { ['not_null'] }
    end

    trait :with_all_rules do
      has_rules { true }
      rules { ['positive', 'not_null'] }
    end

    # Trait with position
    trait :positioned do
      sequence(:attribute_position) { |n| n }
    end

    # PA Type traits (7 types)
    trait :text_type do
      pa_type { :patype_text }
      view_format { :view_format_general }
    end

    trait :number_type do
      pa_type { :patype_number }
      view_format { :view_format_general }
    end

    trait :boolean_type do
      pa_type { :patype_boolean }
      view_format { :view_format_general }
    end

    trait :select_type do
      pa_type { :patype_select }
      view_format { :view_format_selectable }
      info do
        {
          'options' => ['Option 1', 'Option 2', 'Option 3']
        }
      end
    end

    trait :multiselect_type do
      pa_type { :patype_multiselect }
      view_format { :view_format_selectable }
      info do
        {
          'options' => ['Option A', 'Option B', 'Option C']
        }
      end
    end

    trait :date_type do
      pa_type { :patype_date }
      view_format { :view_format_general }
    end

    trait :rich_text_type do
      pa_type { :patype_rich_text }
      view_format { :view_format_html }
    end

    trait :custom_type do
      pa_type { :patype_custom }
    end

    # View Format traits (12 formats)
    trait :general_format do
      view_format { :view_format_general }
    end

    trait :price_format do
      view_format { :view_format_price }
      pa_type { :patype_number }
    end

    trait :weight_format do
      view_format { :view_format_weight }
      pa_type { :patype_number }
    end

    trait :html_format do
      view_format { :view_format_html }
      pa_type { :patype_rich_text }
    end

    trait :ean_format do
      view_format { :view_format_ean }
      pa_type { :patype_text }
    end

    trait :markdown_format do
      view_format { :view_format_markdown }
      pa_type { :patype_text }
    end

    trait :price_hash_format do
      view_format { :view_format_price_hash }
      pa_type { :patype_custom }
    end

    trait :external_image_list_format do
      view_format { :view_format_external_image_list }
      pa_type { :patype_custom }
    end

    trait :special_price_format do
      view_format { :view_format_special_price }
      pa_type { :patype_custom }
    end

    trait :customer_group_price_format do
      view_format { :view_format_customer_group_price }
      pa_type { :patype_custom }
    end

    trait :selectable_format do
      view_format { :view_format_selectable }
      pa_type { :patype_select }
    end

    trait :related_products_format do
      view_format { :view_format_related_products }
      pa_type { :patype_custom }
    end

    # Product Attribute Scope traits (3 scopes)
    trait :product_scope do
      product_attribute_scope { :product_scope }
    end

    trait :catalog_scope do
      product_attribute_scope { :catalog_scope }
    end

    trait :product_and_catalog_scope do
      product_attribute_scope { :product_and_catalog_scope }
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'description' => 'Detailed attribute description',
          'help_text' => 'This is how to use this attribute',
          'validation_message' => 'Please enter a valid value'
        }
      end
    end

    # Complete attribute examples
    trait :price_attribute do
      code { 'price' }
      name { 'Price' }
      pa_type { :patype_number }
      view_format { :view_format_price }
      mandatory { true }
      has_rules { true }
      rules { ['positive', 'not_null'] }
    end

    trait :ean_attribute do
      code { 'ean' }
      name { 'EAN Code' }
      pa_type { :patype_text }
      view_format { :view_format_ean }
      mandatory { false }
    end

    trait :description_attribute do
      code { 'description' }
      name { 'Description' }
      pa_type { :patype_rich_text }
      view_format { :view_format_html }
      mandatory { true }
      has_rules { true }
      rules { ['not_null'] }
    end
  end
end
