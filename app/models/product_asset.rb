class ProductAsset < ApplicationRecord
  # Associations
  belongs_to :product

  # Enums for asset types (image, video, document, link)
  enum :product_asset_type, {
    image: 1,
    video: 2,
    document: 3,
    link: 4
  }

  # Enums for visibility levels
  enum :asset_visibility, {
    private_visibility: 1,
    public_visibility: 2,
    catalog_only_visibility: 3
  }

  # Scopes
  scope :visible, -> { where.not(asset_visibility: :private_visibility) }
  scope :images, -> { where(product_asset_type: :image) }
  scope :videos, -> { where(product_asset_type: :video) }
  scope :documents, -> { where(product_asset_type: :document) }
  scope :links, -> { where(product_asset_type: :link) }
  scope :ordered, -> { order(asset_priority: :desc, created_at: :asc) }

  # Validations
  validates :product_asset_type, presence: true
  validates :asset_priority, numericality: { only_integer: true, allow_nil: true }
end
