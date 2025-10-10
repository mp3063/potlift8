require 'rails_helper'

RSpec.describe ProductAsset, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:product_asset)).to be_valid
    end

    it 'creates valid assets with all types' do
      expect(create(:product_asset, :image)).to be_valid
      expect(create(:product_asset, :video)).to be_valid
      expect(create(:product_asset, :document)).to be_valid
      expect(create(:product_asset, :link)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:product_asset) }

    it { is_expected.to validate_presence_of(:product_asset_type) }
    it { is_expected.to validate_numericality_of(:asset_priority).only_integer.allow_nil }
  end

  # Test enums
  describe 'enums' do
    describe 'product_asset_type' do
      it 'defines all 4 asset types' do
        expect(ProductAsset.product_asset_types).to eq({
          'image' => 1,
          'video' => 2,
          'document' => 3,
          'link' => 4
        })
      end

      it 'allows setting asset type' do
        asset = create(:product_asset, product_asset_type: :image)
        expect(asset.image?).to be true

        asset.update(product_asset_type: :video)
        expect(asset.video?).to be true
      end
    end

    describe 'asset_visibility' do
      it 'defines all 3 visibility levels' do
        expect(ProductAsset.asset_visibilities).to eq({
          'private_visibility' => 1,
          'public_visibility' => 2,
          'catalog_only_visibility' => 3
        })
      end

      it 'allows setting visibility' do
        asset = create(:product_asset, asset_visibility: :private_visibility)
        expect(asset.private_visibility?).to be true

        asset.update(asset_visibility: :public_visibility)
        expect(asset.public_visibility?).to be true
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:product) { create(:product) }

    describe '.visible' do
      let!(:public_asset) { create(:product_asset, :public_visibility, product: product) }
      let!(:catalog_asset) { create(:product_asset, :catalog_only_visibility, product: product) }
      let!(:private_asset) { create(:product_asset, :private_visibility, product: product) }

      it 'returns only non-private assets' do
        result = ProductAsset.visible
        expect(result).to contain_exactly(public_asset, catalog_asset)
        expect(result).not_to include(private_asset)
      end
    end

    describe '.images' do
      let!(:image1) { create(:product_asset, :image, product: product) }
      let!(:image2) { create(:product_asset, :image, product: product) }
      let!(:video) { create(:product_asset, :video, product: product) }

      it 'returns only image assets' do
        result = ProductAsset.images
        expect(result).to contain_exactly(image1, image2)
        expect(result).not_to include(video)
      end
    end

    describe '.videos' do
      let!(:video1) { create(:product_asset, :video, product: product) }
      let!(:video2) { create(:product_asset, :video, product: product) }
      let!(:image) { create(:product_asset, :image, product: product) }

      it 'returns only video assets' do
        result = ProductAsset.videos
        expect(result).to contain_exactly(video1, video2)
      end
    end

    describe '.documents' do
      let!(:doc1) { create(:product_asset, :document, product: product) }
      let!(:doc2) { create(:product_asset, :document, product: product) }
      let!(:image) { create(:product_asset, :image, product: product) }

      it 'returns only document assets' do
        result = ProductAsset.documents
        expect(result).to contain_exactly(doc1, doc2)
      end
    end

    describe '.links' do
      let!(:link1) { create(:product_asset, :link, product: product) }
      let!(:link2) { create(:product_asset, :link, product: product) }
      let!(:image) { create(:product_asset, :image, product: product) }

      it 'returns only link assets' do
        result = ProductAsset.links
        expect(result).to contain_exactly(link1, link2)
      end
    end

    describe '.ordered' do
      let!(:high_priority) { create(:product_asset, product: product, asset_priority: 10, created_at: 2.days.ago) }
      let!(:medium_priority) { create(:product_asset, product: product, asset_priority: 5, created_at: 1.day.ago) }
      let!(:low_priority) { create(:product_asset, product: product, asset_priority: -5, created_at: Time.current) }
      let!(:zero_priority_old) { create(:product_asset, product: product, asset_priority: 0, created_at: 3.days.ago) }
      let!(:zero_priority_new) { create(:product_asset, product: product, asset_priority: 0, created_at: 1.hour.ago) }

      it 'orders by priority desc, then created_at asc' do
        result = ProductAsset.ordered.to_a

        expect(result[0]).to eq(high_priority)
        expect(result[1]).to eq(medium_priority)
        # Zero priority items ordered by created_at
        expect(result.index(zero_priority_old)).to be < result.index(zero_priority_new)
        expect(result.last).to eq(low_priority)
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores image metadata' do
        asset = create(:product_asset, :image)
        expect(asset.info['width']).to eq(800)
        expect(asset.info['height']).to eq(600)
        expect(asset.info['format']).to eq('jpg')
      end

      it 'stores video metadata' do
        asset = create(:product_asset, :video)
        expect(asset.info['duration']).to eq(120)
        expect(asset.info['format']).to eq('mp4')
      end

      it 'stores document metadata' do
        asset = create(:product_asset, :document)
        expect(asset.info['pages']).to eq(25)
        expect(asset.info['format']).to eq('pdf')
      end

      it 'stores link metadata' do
        asset = create(:product_asset, :link)
        expect(asset.info['url']).to be_present
        expect(asset.info['title']).to be_present
      end

      it 'defaults to empty hash' do
        asset = create(:product_asset, info: nil)
        asset.reload
        expect(asset.info).to eq({})
      end
    end
  end

  # Test priority system
  describe 'priority system' do
    let(:product) { create(:product) }

    it 'accepts positive priorities' do
      asset = create(:product_asset, product: product, asset_priority: 100)
      expect(asset.asset_priority).to eq(100)
    end

    it 'accepts zero priority' do
      asset = create(:product_asset, product: product, asset_priority: 0)
      expect(asset.asset_priority).to eq(0)
    end

    it 'accepts negative priorities' do
      asset = create(:product_asset, product: product, asset_priority: -10)
      expect(asset.asset_priority).to eq(-10)
    end

    it 'allows nil priority' do
      asset = create(:product_asset, product: product, asset_priority: nil)
      expect(asset.asset_priority).to be_nil
    end

    it 'rejects non-integer priorities' do
      asset = build(:product_asset, product: product, asset_priority: 5.5)
      expect(asset).not_to be_valid
      expect(asset.errors[:asset_priority]).to be_present
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    context 'image gallery' do
      let!(:primary) { create(:product_asset, :primary_image, product: product) }
      let!(:thumbnail) { create(:product_asset, :thumbnail, product: product) }
      let!(:gallery1) { create(:product_asset, :image, product: product, asset_priority: 5) }
      let!(:gallery2) { create(:product_asset, :image, product: product, asset_priority: 3) }

      it 'maintains image gallery with priorities' do
        ordered_images = product.product_assets.images.ordered

        expect(ordered_images.first).to eq(primary) # highest priority
        expect(ordered_images).to include(gallery1, gallery2)
        expect(ordered_images.last).to eq(thumbnail) # negative priority
      end
    end

    context 'mixed media types' do
      before do
        create(:product_asset, :image, product: product)
        create(:product_asset, :video, product: product)
        create(:product_asset, :document, product: product)
        create(:product_asset, :link, product: product)
      end

      it 'stores multiple asset types per product' do
        expect(product.product_assets.count).to eq(4)
        expect(product.product_assets.images.count).to eq(1)
        expect(product.product_assets.videos.count).to eq(1)
        expect(product.product_assets.documents.count).to eq(1)
        expect(product.product_assets.links.count).to eq(1)
      end
    end

    context 'visibility control' do
      let!(:public_asset) { create(:product_asset, product: product, asset_visibility: :public_visibility) }
      let!(:catalog_asset) { create(:product_asset, product: product, asset_visibility: :catalog_only_visibility) }
      let!(:private_asset) { create(:product_asset, product: product, asset_visibility: :private_visibility) }

      it 'filters assets by visibility' do
        expect(product.product_assets.visible).to contain_exactly(public_asset, catalog_asset)
      end

      it 'includes all assets without filter' do
        expect(product.product_assets.count).to eq(3)
      end
    end

    context 'asset deletion' do
      let!(:asset) { create(:product_asset, product: product) }

      it 'is destroyed when product is destroyed' do
        expect { product.destroy }.to change { ProductAsset.count }.by(-1)
      end
    end

    context 'primary image workflow' do
      it 'can identify primary image by priority' do
        create(:product_asset, :image, product: product, asset_priority: 0)
        create(:product_asset, :image, product: product, asset_priority: 5)
        primary = create(:product_asset, :primary_image, product: product)

        highest_priority = product.product_assets.images.ordered.first
        expect(highest_priority).to eq(primary)
      end
    end

    context 'with detailed metadata' do
      let(:asset) { create(:product_asset, :with_detailed_info, product: product) }

      it 'stores comprehensive asset information' do
        expect(asset.info['filename']).to be_present
        expect(asset.info['upload_date']).to be_present
        expect(asset.info['checksum']).to be_present
        expect(asset.info['metadata']).to be_a(Hash)
      end
    end
  end
end
