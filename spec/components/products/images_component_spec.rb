# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ImagesComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  def attach_images(count)
    count.times do |i|
      product.images.attach(
        io: File.open(Rails.root.join("spec", "fixtures", "files", "test_image.png")),
        filename: "test-#{i}.png",
        content_type: "image/png"
      )
    end
  end

  it "renders the images header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("h3", text: "Images")
  end

  it "renders an Upload label bound to the hidden multi-file input" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("label[for='file-upload']", text: "Upload")
    expect(page).to have_css("input#file-upload[type='file'][multiple][accept='image/*'].sr-only")
    expect(page).to have_css("#product_images_card.group")
    expect(page).to have_css("label[for='file-upload'][class*='group-has-[#file-upload:focus-visible]:ring-2']")
  end

  it "keeps the image-upload controller on the form with dropzone and progress targets inside it" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("form[data-controller='image-upload']")
    expect(page).to have_css("form [data-image-upload-target='dropzone'][data-action*='drop->image-upload#handleDrop']")
    expect(page).to have_css("form [data-image-upload-target='progressContainer']")
    expect(page).to have_css("form input[data-image-upload-target='input'][data-action='change->image-upload#handleFiles']")
  end

  context "without images" do
    it "shows the one-line empty state and no gallery toggle" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No images yet. Upload or drop files here.")
      expect(page).not_to have_css("details")
      expect(page).not_to have_css("[data-controller*='product-images']")
    end

    it "does not show a count badge" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("h3 ~ span.rounded-full")
    end
  end

  context "with images attached" do
    before { attach_images(3) }

    it "shows the image count next to the header" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.rounded-full", text: "3")
    end

    it "renders a thumbnail strip with the primary marker on the first image only" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-image-upload-target='dropzone'] img", count: 3)
      expect(page).to have_css("[data-image-upload-target='dropzone'] .sr-only", text: "Primary image", count: 1)
    end

    it "puts the full gallery behind a Manage images toggle, outside the upload form" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("details summary", text: "Manage images")
      # Capybara treats non-summary children of a closed <details> as invisible,
      # and collapsed-by-default is the requirement, so match regardless of visibility.
      expect(page).to have_css("details [data-controller='product-images bulk-images image-reorder image-metadata']", visible: :all)
      expect(page).not_to have_css("form details")
    end
  end

  context "with more than eight images" do
    before { attach_images(10) }

    it "shows seven thumbnails and a +3 overflow tile" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-image-upload-target='dropzone'] img", count: 7)
      expect(page).to have_css("[data-image-upload-target='dropzone'] div", text: "+3")
    end
  end

  describe "gallery template" do
    let(:template_content) { File.read(Rails.root.join("app/components/products/images_component.html.erb")) }

    it "keeps selectImage and deleteImage actions without :stop modifiers" do
      expect(template_content).to include("click->product-images#selectImage")
      expect(template_content).not_to include("click->product-images#selectImage:stop")
      expect(template_content).to include("click->product-images#deleteImage")
      expect(template_content).not_to include("click->product-images#deleteImage:stop")
    end
  end
end
