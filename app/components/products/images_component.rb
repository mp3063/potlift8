# frozen_string_literal: true

module Products
  # Product images component with upload and management
  #
  # Displays main image, thumbnail grid, and drag-and-drop upload area.
  # Supports image deletion and position indicators. Integrates with
  # ActiveStorage and Stimulus controller for file uploads.
  #
  # @example Render images component
  #   <%= render Products::ImagesComponent.new(product: @product) %>
  #
  class ImagesComponent < ViewComponent::Base
    attr_reader :product

    # Initialize a new images component
    #
    # @param product [Product] Product instance with attached images
    # @return [ImagesComponent]
    def initialize(product:)
      @product = product
    end

    private

    # Returns the main image (first attached image)
    #
    # @return [ActiveStorage::Attachment, nil] Main image or nil
    def main_image
      product.images.first
    end

    # Returns all images
    #
    # @return [ActiveStorage::Attached::Many] Collection of images
    def images
      product.images
    end

    # Returns whether product has any images attached
    #
    # @return [Boolean] True if images are attached
    def has_images?
      product.images.attached?
    end
  end
end
