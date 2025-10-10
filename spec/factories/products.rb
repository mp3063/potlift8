FactoryBot.define do
  factory :product do
    company
    sequence(:sku) { |n| "SKU#{n.to_s.rjust(6, '0')}" }
    sequence(:name) { |n| "Product #{n}" }
    ean { nil }
    product_type { :sellable }
    configuration_type { nil }
    product_status { :active }
    structure { {} }
    info { {} }
    cache { {} }
    sync_lock { nil }

    # Trait for sellable product (default)
    trait :sellable do
      product_type { :sellable }
      configuration_type { nil }
    end

    # Trait for configurable product with variant
    trait :configurable_variant do
      product_type { :configurable }
      configuration_type { :variant }
      structure do
        {
          'variants' => [
            { 'sku' => 'VAR001', 'attributes' => { 'size' => 'S' } },
            { 'sku' => 'VAR002', 'attributes' => { 'size' => 'M' } }
          ]
        }
      end
    end

    # Trait for configurable product with options
    trait :configurable_option do
      product_type { :configurable }
      configuration_type { :option }
      structure do
        {
          'options' => [
            { 'sku' => 'OPT001', 'name' => 'Gift wrap' },
            { 'sku' => 'OPT002', 'name' => 'Extended warranty' }
          ]
        }
      end
    end

    # Trait for bundle product
    trait :bundle do
      product_type { :bundle }
      configuration_type { nil }
      structure do
        {
          'bundle_items' => [
            { 'sku' => 'ITEM001', 'quantity' => 1 },
            { 'sku' => 'ITEM002', 'quantity' => 2 }
          ]
        }
      end
    end

    # Product status traits
    trait :draft do
      product_status { :draft }
    end

    trait :active do
      product_status { :active }
    end

    trait :incoming do
      product_status { :incoming }
    end

    trait :discontinuing do
      product_status { :discontinuing }
    end

    trait :disabled do
      product_status { :disabled }
    end

    trait :discontinued do
      product_status { :discontinued }
    end

    trait :deleted do
      product_status { :deleted }
    end

    # Trait with EAN
    trait :with_ean do
      sequence(:ean) { |n| "501234567890#{n}" }
    end

    # Trait with sync lock
    trait :synced do
      association :sync_lock
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'manufacturer' => 'ACME Corp',
          'warranty_months' => 24,
          'origin_country' => 'DE'
        }
      end
    end

    # Trait with cache data
    trait :with_cache do
      cache do
        {
          'total_inventory' => 100,
          'price' => 1999,
          'last_updated' => Time.current.to_s
        }
      end
    end

    # Trait for product with assets
    trait :with_assets do
      transient do
        assets_count { 3 }
      end

      after(:create) do |product, evaluator|
        create_list(:product_asset, evaluator.assets_count, product: product)
      end
    end

    # Trait for product with labels
    trait :with_labels do
      transient do
        labels_count { 2 }
      end

      after(:create) do |product, evaluator|
        labels = create_list(:label, evaluator.labels_count)
        labels.each do |label|
          create(:product_label, product: product, label: label)
        end
      end
    end

    # Trait for product with inventory
    trait :with_inventory do
      transient do
        storages_count { 2 }
        stock_quantity { 10 }
      end

      after(:create) do |product, evaluator|
        evaluator.storages_count.times do
          create(:inventory, product: product, value: evaluator.stock_quantity)
        end
      end
    end

    # Trait for product with attributes
    trait :with_attributes do
      transient do
        attributes_count { 3 }
      end

      after(:create) do |product, evaluator|
        attributes = create_list(:product_attribute, evaluator.attributes_count)
        attributes.each do |attr|
          create(:product_attribute_value, product: product, product_attribute: attr)
        end
      end
    end
  end
end
