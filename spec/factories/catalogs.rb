FactoryBot.define do
  factory :catalog do
    company
    sequence(:code) { |n| "CATALOG#{n}" }
    sequence(:name) { |n| "Catalog #{n}" }
    catalog_type { :webshop }
    currency_code { 'eur' }
    info { {} }
    cache { {} }
    sync_lock { nil }

    # Trait for webshop catalog (default)
    trait :webshop do
      catalog_type { :webshop }
    end

    # Trait for supply catalog
    trait :supply do
      catalog_type { :supply }
    end

    # Currency traits
    trait :eur do
      currency_code { 'eur' }
    end

    trait :sek do
      currency_code { 'sek' }
    end

    trait :nok do
      currency_code { 'nok' }
    end

    # Trait with sync lock
    trait :synced do
      association :sync_lock
    end

    # Trait with custom info
    trait :with_info do
      info do
        {
          'description' => 'Catalog description',
          'region' => 'EU',
          'tax_rate' => 0.25
        }
      end
    end

    # Trait with cache data
    trait :with_cache do
      cache do
        {
          'products_count' => 100,
          'active_items' => 85,
          'last_updated' => Time.current.to_s
        }
      end
    end

    # Trait with catalog items
    trait :with_items do
      transient do
        items_count { 3 }
      end

      after(:create) do |catalog, evaluator|
        create_list(:catalog_item, evaluator.items_count, catalog: catalog)
      end
    end
  end
end
