FactoryBot.define do
  factory :product_asset do
    product
    product_asset_type { :image }
    asset_visibility { :public_visibility }
    asset_priority { 0 }
    name { nil }
    asset_description { nil }
    info { {} }

    # Asset type traits
    trait :image do
      product_asset_type { :image }
      sequence(:name) { |n| "product_#{n}.jpg" }
      asset_description { "Product image" }
      info do
        {
          'path' => '/images/',
          'width' => 800,
          'height' => 600,
          'format' => 'jpg'
        }
      end
    end

    trait :video do
      product_asset_type { :video }
      sequence(:name) { |n| "product_#{n}.mp4" }
      asset_description { "Product video" }
      info do
        {
          'path' => '/videos/',
          'duration' => 120,
          'format' => 'mp4',
          'size' => 10485760 # 10MB in bytes
        }
      end
    end

    trait :document do
      product_asset_type { :document }
      sequence(:name) { |n| "manual_#{n}.pdf" }
      asset_description { "Product manual" }
      info do
        {
          'path' => '/documents/',
          'pages' => 25,
          'format' => 'pdf',
          'size' => 2097152 # 2MB in bytes
        }
      end
    end

    trait :link do
      product_asset_type { :link }
      name { "Product Information Link" }
      asset_description { "External product documentation" }
      info do
        {
          'url' => 'https://example.com/product-info',
          'title' => 'Product Information'
        }
      end
    end

    # Visibility traits
    trait :private_visibility do
      asset_visibility { :private_visibility }
    end

    trait :public_visibility do
      asset_visibility { :public_visibility }
    end

    trait :catalog_only_visibility do
      asset_visibility { :catalog_only_visibility }
    end

    # Priority traits
    trait :high_priority do
      asset_priority { 10 }
    end

    trait :low_priority do
      asset_priority { -5 }
    end

    # Trait for primary product image
    trait :primary_image do
      product_asset_type { :image }
      asset_visibility { :public_visibility }
      asset_priority { 100 }
      name { "primary.jpg" }
      asset_description { "Primary product image" }
      info do
        {
          'path' => '/images/',
          'width' => 1200,
          'height' => 1200,
          'format' => 'jpg',
          'is_primary' => true
        }
      end
    end

    # Trait for thumbnail
    trait :thumbnail do
      product_asset_type { :image }
      name { "thumb.jpg" }
      asset_description { "Product thumbnail" }
      asset_priority { -10 }
      info do
        {
          'path' => '/images/',
          'width' => 150,
          'height' => 150,
          'format' => 'jpg',
          'is_thumbnail' => true
        }
      end
    end

    # Trait with rich info
    trait :with_detailed_info do
      info do
        {
          'filename' => 'original_filename.jpg',
          'upload_date' => Time.current.to_s,
          'uploaded_by' => 'admin@example.com',
          'checksum' => 'abc123def456',
          'metadata' => {
            'camera' => 'Canon EOS',
            'location' => 'Studio A'
          }
        }
      end
    end
  end
end
