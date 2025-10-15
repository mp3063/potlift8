FactoryBot.define do
  factory :asset do
    product
    asset_type { 'image' }
    position { 1 }

    # Use ActiveStorage attachment
    after(:build) do |asset|
      asset.file.attach(
        io: StringIO.new('fake image content'),
        filename: 'test-image.jpg',
        content_type: 'image/jpeg'
      )
    end

    # Trait for image asset
    trait :image do
      asset_type { 'image' }

      after(:build) do |asset|
        asset.file.attach(
          io: StringIO.new('fake image content'),
          filename: 'product-image.jpg',
          content_type: 'image/jpeg'
        )
      end
    end

    # Trait for PNG image
    trait :png do
      asset_type { 'image' }

      after(:build) do |asset|
        asset.file.attach(
          io: StringIO.new('fake png content'),
          filename: 'product-image.png',
          content_type: 'image/png'
        )
      end
    end

    # Trait for document asset
    trait :document do
      asset_type { 'document' }

      after(:build) do |asset|
        asset.file.attach(
          io: StringIO.new('fake pdf content'),
          filename: 'manual.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    # Trait for video asset
    trait :video do
      asset_type { 'video' }

      after(:build) do |asset|
        asset.file.attach(
          io: StringIO.new('fake video content'),
          filename: 'product-video.mp4',
          content_type: 'video/mp4'
        )
      end
    end

    # Trait for other asset type
    trait :other do
      asset_type { 'other' }

      after(:build) do |asset|
        asset.file.attach(
          io: StringIO.new('fake file content'),
          filename: 'data.csv',
          content_type: 'text/csv'
        )
      end
    end
  end
end
