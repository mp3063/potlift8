# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ImagesComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  it "renders images header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Images")
  end

  it "renders upload area" do
    render_inline(described_class.new(product: product))

    expect(page).to have_text("Upload files")
    expect(page).to have_text("or drag and drop")
    expect(page).to have_text("PNG, JPG, GIF up to 10MB")
  end

  it "renders file input with correct attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("input[type='file'][multiple='multiple'][accept='image/*']", visible: false)
  end

  context "without images" do
    it "does not render main image area" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("[data-product-images-target='mainImage']")
    end

    it "does not render thumbnail grid" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("[data-product-images-target='thumbnails']")
    end
  end

  context "with images attached", skip: "Requires ActiveStorage setup in test" do
    before do
      # This would require ActiveStorage configuration and fixture files
      # Skip for now, implement when ActiveStorage is configured in test env
    end

    it "renders main image"
    it "renders thumbnail grid"
    it "displays position indicators"
    it "shows delete button on hover"
    it "includes proper alt text"
  end

  it "includes Stimulus controller data attributes" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-controller='image-upload']")
    expect(page).to have_css("[data-image-upload-target='dropzone']")
    expect(page).to have_css("[data-image-upload-target='input']")
    expect(page).to have_css("[data-image-upload-target='progressContainer']")
  end

  it "includes drag and drop event handlers" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("[data-action*='drop->image-upload#handleDrop']")
    expect(page).to have_css("[data-action*='dragover->image-upload#handleDragOver']")
    expect(page).to have_css("[data-action*='dragleave->image-upload#handleDragLeave']")
  end

  it "uses blue-600 color scheme for hover states" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css(".hover\\:border-blue-400")
    expect(page).to have_css(".text-blue-600")
  end

  it "includes focus ring with blue-500" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css(".focus-within\\:ring-blue-500")
  end
end
