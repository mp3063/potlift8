# frozen_string_literal: true

module Products
  class ImagesComponent < ViewComponent::Base
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

    def has_images?
      product.images.attached?
    end
  end
end
