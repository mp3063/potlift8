require 'rails_helper'

RSpec.describe Asset, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:asset)).to be_valid
    end

    it 'creates valid assets with all types' do
      expect(create(:asset, :image)).to be_valid
      expect(create(:asset, :document)).to be_valid
      expect(create(:asset, :video)).to be_valid
      expect(create(:asset, :other)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }

    it 'has one attached file' do
      asset = create(:asset, :image)
      expect(asset.file).to be_attached
    end
  end

  # Test validations
  describe 'validations' do
    subject { build(:asset) }

    it { is_expected.to validate_presence_of(:asset_type) }
    it { is_expected.to validate_inclusion_of(:asset_type).in_array(['image', 'document', 'video', 'other']) }
    it { is_expected.to validate_presence_of(:file) }
  end

  # Test acts_as_list
  describe 'acts_as_list' do
    let(:product) { create(:product) }

    it 'sets position on create' do
      asset1 = create(:asset, :image, product: product)
      asset2 = create(:asset, :image, product: product)
      asset3 = create(:asset, :image, product: product)

      expect(asset1.position).to eq(1)
      expect(asset2.position).to eq(2)
      expect(asset3.position).to eq(3)
    end

    it 'can reorder assets' do
      asset1 = create(:asset, :image, product: product)
      asset2 = create(:asset, :image, product: product)
      asset3 = create(:asset, :image, product: product)

      asset3.move_to_top
      asset1.reload
      asset2.reload
      asset3.reload

      expect(asset3.position).to eq(1)
      expect(asset1.position).to eq(2)
      expect(asset2.position).to eq(3)
    end

    it 'scopes position to product' do
      other_product = create(:product)

      asset1 = create(:asset, :image, product: product)
      asset2 = create(:asset, :image, product: other_product)

      expect(asset1.position).to eq(1)
      expect(asset2.position).to eq(1) # Same position but different product
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:product) { create(:product) }
    let!(:image1) { create(:asset, :image, product: product) }
    let!(:image2) { create(:asset, :png, product: product) }
    let!(:document1) { create(:asset, :document, product: product) }
    let!(:video1) { create(:asset, :video, product: product) }
    let!(:other1) { create(:asset, :other, product: product) }

    describe '.images' do
      it 'returns only image assets' do
        expect(Asset.images).to contain_exactly(image1, image2)
      end
    end

    describe '.documents' do
      it 'returns only document assets' do
        expect(Asset.documents).to contain_exactly(document1)
      end
    end

    describe '.videos' do
      it 'returns only video assets' do
        expect(Asset.videos).to contain_exactly(video1)
      end
    end
  end

  # Test file type detection methods
  describe 'file type detection' do
    describe '#image?' do
      it 'returns true for image asset_type' do
        asset = create(:asset, :image)
        expect(asset.image?).to be true
      end

      it 'returns true for image content_type' do
        asset = create(:asset, asset_type: 'other')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: 'test.jpg',
          content_type: 'image/jpeg'
        )
        expect(asset.image?).to be true
      end

      it 'returns false for non-image asset' do
        asset = create(:asset, :document)
        expect(asset.image?).to be false
      end
    end

    describe '#video?' do
      it 'returns true for video asset_type' do
        asset = create(:asset, :video)
        expect(asset.video?).to be true
      end

      it 'returns true for video content_type' do
        asset = create(:asset, asset_type: 'other')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: 'test.mp4',
          content_type: 'video/mp4'
        )
        expect(asset.video?).to be true
      end

      it 'returns false for non-video asset' do
        asset = create(:asset, :document)
        expect(asset.video?).to be false
      end
    end

    describe '#document?' do
      it 'returns true for document asset_type' do
        asset = create(:asset, :document)
        expect(asset.document?).to be true
      end

      it 'returns true for pdf content_type' do
        asset = create(:asset, asset_type: 'other')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: 'test.pdf',
          content_type: 'application/pdf'
        )
        expect(asset.document?).to be true
      end

      it 'returns true for document content_type' do
        asset = create(:asset, asset_type: 'other')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: 'test.docx',
          content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
        )
        expect(asset.document?).to be true
      end

      it 'returns false for non-document asset' do
        asset = create(:asset, :image)
        expect(asset.document?).to be false
      end
    end
  end

  # Test file size calculation
  describe '#file_size_mb' do
    it 'returns file size in megabytes' do
      asset = create(:asset, :image)
      # Factory creates asset with small content, so size should be close to 0
      expect(asset.file_size_mb).to be >= 0
      expect(asset.file_size_mb).to be < 0.01 # Very small test file
    end

    it 'rounds to 2 decimal places' do
      asset = create(:asset, :image)
      expect(asset.file_size_mb).to be_a(Float)
      expect(asset.file_size_mb.to_s.split('.').last.length).to be <= 2
    end
  end

  # Integration tests
  describe 'integration' do
    let(:product) { create(:product) }

    context 'product with multiple asset types' do
      let!(:image1) { create(:asset, :image, product: product) }
      let!(:image2) { create(:asset, :png, product: product) }
      let!(:document) { create(:asset, :document, product: product) }
      let!(:video) { create(:asset, :video, product: product) }

      it 'product has all assets' do
        expect(product.product_assets.count).to eq(4)
      end

      it 'can filter assets by type' do
        expect(product.product_assets.images.count).to eq(2)
        expect(product.product_assets.documents.count).to eq(1)
        expect(product.product_assets.videos.count).to eq(1)
      end

      it 'assets are ordered by position' do
        assets = product.product_assets.order(:position)
        expect(assets.first).to eq(image1)
        expect(assets.last).to eq(video)
      end
    end

    context 'asset deletion' do
      let!(:asset) { create(:asset, :image, product: product) }

      it 'deletes when product is destroyed' do
        expect {
          product.destroy
        }.to change { Asset.count }.by(-1)
      end

      it 'purges attached file when asset is destroyed' do
        file_blob_id = asset.file.blob.id

        asset.destroy

        expect(ActiveStorage::Blob.exists?(file_blob_id)).to be false
      end
    end

    context 'reordering assets with drag-and-drop' do
      let!(:asset1) { create(:asset, :image, product: product) }
      let!(:asset2) { create(:asset, :image, product: product) }
      let!(:asset3) { create(:asset, :image, product: product) }

      it 'can move asset to specific position' do
        asset3.insert_at(1)

        asset1.reload
        asset2.reload
        asset3.reload

        expect(asset3.position).to eq(1)
        expect(asset1.position).to eq(2)
        expect(asset2.position).to eq(3)
      end

      it 'can swap asset positions' do
        original_positions = {
          asset1: asset1.position,
          asset2: asset2.position,
          asset3: asset3.position
        }

        asset1.move_to_bottom

        asset1.reload
        asset2.reload
        asset3.reload

        expect(asset1.position).to eq(3)
        expect(asset2.position).to eq(1)
        expect(asset3.position).to eq(2)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    it 'requires file to be attached' do
      asset = build(:asset, asset_type: 'image')
      asset.file.purge if asset.file.attached?

      expect(asset).not_to be_valid
      expect(asset.errors[:file]).to be_present
    end

    it 'handles various image formats' do
      formats = [
        { filename: 'test.jpg', content_type: 'image/jpeg' },
        { filename: 'test.png', content_type: 'image/png' },
        { filename: 'test.gif', content_type: 'image/gif' },
        { filename: 'test.webp', content_type: 'image/webp' }
      ]

      formats.each do |format|
        asset = create(:asset, asset_type: 'image')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: format[:filename],
          content_type: format[:content_type]
        )
        expect(asset.image?).to be true
      end
    end

    it 'handles various document formats' do
      formats = [
        { filename: 'test.pdf', content_type: 'application/pdf' },
        { filename: 'test.docx', content_type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document' },
        { filename: 'test.xlsx', content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }
      ]

      formats.each do |format|
        asset = create(:asset, asset_type: 'document')
        asset.file.attach(
          io: StringIO.new('fake'),
          filename: format[:filename],
          content_type: format[:content_type]
        )
        expect(asset.document?).to be true
      end
    end

    it 'handles invalid asset_type' do
      asset = build(:asset, asset_type: 'invalid_type')
      expect(asset).not_to be_valid
      expect(asset.errors[:asset_type]).to be_present
    end
  end

  # Multi-tenancy
  describe 'multi-tenancy' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    it 'asset inherits company context from product' do
      asset = create(:asset, :image, product: product)
      expect(asset.product.company).to eq(company)
    end
  end
end
