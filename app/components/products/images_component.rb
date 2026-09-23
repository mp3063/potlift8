# frozen_string_literal: true

module Products
  class ImagesComponent < ViewComponent::Base
    STRIP_LIMIT = 8

    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def main_image
      product.images.first
    end

    def images
      product.images
    end

    # Memoized: the template checks this in three places, each an EXISTS query.
    def has_images?
      return @has_images if defined?(@has_images)

      @has_images = product.images.attached?
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
