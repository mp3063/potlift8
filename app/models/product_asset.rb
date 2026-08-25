class ProductAsset < ApplicationRecord
  belongs_to :product

  has_one_attached :file

  enum :product_asset_type, {
    image: 1,
    video: 2,
    document: 3,
    link: 4
  }

  enum :asset_visibility, {
    private_visibility: 1,
    public_visibility: 2,
    catalog_only_visibility: 3
  }

  scope :visible, -> { where.not(asset_visibility: :private_visibility) }
  scope :images, -> { where(product_asset_type: :image) }
  scope :videos, -> { where(product_asset_type: :video) }
  scope :documents, -> { where(product_asset_type: :document) }
  scope :links, -> { where(product_asset_type: :link) }
  scope :non_images, -> { where.not(product_asset_type: :image) }
  scope :ordered, -> { order(asset_priority: :desc, created_at: :asc) }
  scope :with_attached_file, -> { includes(file_attachment: :blob) }

  validates :product_asset_type, presence: true
  validates :asset_priority, numericality: { only_integer: true, allow_nil: true }
  validates :name, presence: true

  validate :validate_link_url, if: :link?

  def filename
    file.attached? ? file.filename.to_s : nil
  end

  def file_extension
    return nil unless file.attached?
    File.extname(file.filename.to_s).delete(".").downcase
  end

  def file_size
    file.attached? ? file.blob.byte_size : nil
  end

  def file_url
    return nil unless file.attached?
    Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true)
  end

  def description
    asset_description
  end

  def url
    info&.dig("url")
  end

  def thumbnail_url
    info&.dig("thumbnail_url")
  end

  private

  def validate_link_url
    url = info&.dig("url")
    if url.blank?
      errors.add(:base, "URL is required for link assets")
    elsif url.present? && !url.match?(/\A#{URI::RFC2396_PARSER.make_regexp(%w[http https])}\z/)
      errors.add(:base, "URL must be a valid http or https URL")
    end
  end
end
