# Tracks the lifecycle of a CSV import (products, catalog items, etc).
# The uploaded CSV is stored as an ActiveStorage blob on this record, so
# background jobs only need the import ID — the full file content never
# travels through the job arguments column or the job logs.
class Import < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes

  belongs_to :company
  belongs_to :user
  has_one_attached :file

  validates :import_type, presence: true, inclusion: { in: %w[products catalog_items] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  scope :recent, -> { order(created_at: :desc) }

  def row_errors
    errors_data || []
  end

  def success_count
    imported_count + updated_count
  end

  def failed_count
    row_errors.size
  end

  def finished?
    status == "completed" || status == "failed"
  end
end
