class ProductAsset < ApplicationRecord
  # Associations
  belongs_to :product

  # ActiveStorage for file uploads (videos, documents)
  # Links store URL in info['url'], not as attachment
  has_one_attached :file

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
  scope :non_images, -> { where.not(product_asset_type: :image) }
  scope :ordered, -> { order(asset_priority: :desc, created_at: :asc) }
  scope :with_attached_file, -> { includes(file_attachment: :blob) }

  # Validations
  validates :product_asset_type, presence: true
  validates :asset_priority, numericality: { only_integer: true, allow_nil: true }
  validates :name, presence: true

  # URL validation for link type
  validate :validate_link_url, if: :link?

  # File helper methods for Active Storage attachments

  # Returns the filename of the attached file
  def filename
    file.attached? ? file.filename.to_s : nil
  end

  # Returns the file extension (e.g., 'pdf', 'docx')
  def file_extension
    return nil unless file.attached?
    File.extname(file.filename.to_s).delete('.').downcase
  end

  # Returns the file size in bytes
  def file_size
    file.attached? ? file.blob.byte_size : nil
  end

  # Returns the URL to the attached file
  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end

  # Alias for asset_description to match common naming
  def description
    asset_description
  end

  # Returns the stored URL for link/video assets
  def url
    info&.dig('url')
  end

  # Returns the thumbnail URL for video assets (stored in info['thumbnail_url'])
  def thumbnail_url
    info&.dig('thumbnail_url')
  end

  private

  def validate_link_url
    url = info&.dig('url')
    if url.blank?
      errors.add(:base, 'URL is required for link assets')
    elsif url.present? && !url.match?(/\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/)
      errors.add(:base, 'URL must be a valid http or https URL')
    end
  end
end
