# frozen_string_literal: true

module Products
  class ImagesComponent < ViewComponent::Base
    STRIP_LIMIT = 8

    attr_reader :product

    # gallery_open: re-renders triggered from inside the gallery keep it expanded
    def initialize(product:, gallery_open: false)
      @product = product
      @gallery_open = gallery_open
    end

    private

    def main_image
      images.first
    end

    # Loaded once with blobs; the strip, badge and gallery all read this array,
    # so counts and lookups stay in memory instead of hitting the database.
    def images
      @images ||= product.images.includes(:blob).to_a
    end

    def has_images?
      images.any?
    end

    # Thumbnails shown in the collapsed strip. When more than STRIP_LIMIT images
    # exist, the last slot is reserved for the "+N" tile.
    def strip_images
      return images.to_a if images.count <= STRIP_LIMIT

      images.first(STRIP_LIMIT - 1)
    end

    def overflow_count
      return 0 if images.count <= STRIP_LIMIT

      images.count - (STRIP_LIMIT - 1)
    end
  end
end
