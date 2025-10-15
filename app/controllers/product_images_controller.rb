# ProductImagesController
#
# Manages product image uploads and deletions using ActiveStorage.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Multiple image upload with drag-and-drop support
# - ActiveStorage Direct Upload integration
# - Image validation (file type, size)
# - Image deletion
# - Turbo Stream support for dynamic updates
#
# Routes:
# - POST /products/:product_id/images - Upload images
# - DELETE /products/:product_id/images/:id - Delete image
#
class ProductImagesController < ApplicationController
  before_action :set_product
  before_action :set_image, only: [:destroy]

  # Maximum file size: 10MB
  MAX_FILE_SIZE = 10.megabytes

  # Allowed image content types
  ALLOWED_CONTENT_TYPES = %w[
    image/png
    image/jpeg
    image/jpg
    image/gif
    image/webp
  ].freeze

  # POST /products/:product_id/images
  # POST /products/:product_id/images.turbo_stream
  #
  # Uploads one or more images to the product.
  # Supports both regular form submission and ActiveStorage Direct Upload.
  #
  # Parameters:
  # - images: Array of image files
  # - signed_blob_id: ActiveStorage signed blob ID (for direct upload)
  #
  def create
    # Handle ActiveStorage Direct Upload (signed_blob_id)
    if params[:signed_blob_id].present?
      handle_direct_upload
      return
    end

    # Handle regular form upload (multiple files)
    if params[:images].blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: 'Please select at least one image.' }
        format.turbo_stream { flash.now[:alert] = 'Please select at least one image.' }
      end
      return
    end

    uploaded_count = 0
    errors = []

    Array(params[:images]).each do |image|
      # Validate file type
      unless ALLOWED_CONTENT_TYPES.include?(image.content_type)
        errors << "#{image.original_filename}: Invalid file type. Only PNG, JPG, GIF, and WebP are allowed."
        next
      end

      # Validate file size
      if image.size > MAX_FILE_SIZE
        errors << "#{image.original_filename}: File size exceeds 10MB limit."
        next
      end

      # Attach image to product
      @product.images.attach(image)
      uploaded_count += 1
    end

    # Build response message
    if uploaded_count > 0 && errors.empty?
      message = "#{uploaded_count} image(s) uploaded successfully."
      notice_type = :notice
    elsif uploaded_count > 0 && errors.any?
      message = "#{uploaded_count} image(s) uploaded. #{errors.size} failed: #{errors.join(', ')}"
      notice_type = :alert
    else
      message = "Upload failed: #{errors.join(', ')}"
      notice_type = :alert
    end

    respond_to do |format|
      format.html { redirect_to @product, notice_type => message }
      format.turbo_stream do
        flash.now[notice_type] = message
        render turbo_stream: [
          turbo_stream.replace('product_images', partial: 'products/images', locals: { product: @product }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { render json: { uploaded: uploaded_count, errors: errors }, status: uploaded_count > 0 ? :created : :unprocessable_entity }
    end
  end

  # DELETE /products/:product_id/images/:id
  # DELETE /products/:product_id/images/:id.turbo_stream
  #
  # Deletes an image from the product.
  #
  def destroy
    filename = @image.filename.to_s
    @image.purge

    respond_to do |format|
      format.html { redirect_to @product, notice: "Image '#{filename}' deleted successfully." }
      format.turbo_stream do
        flash.now[:notice] = "Image '#{filename}' deleted successfully."
        render turbo_stream: [
          turbo_stream.replace('product_images', partial: 'products/images', locals: { product: @product }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { head :no_content }
    end
  end

  private

  # Set the product from params
  # Ensures product belongs to current company
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  # Set the image attachment from params
  # Ensures image belongs to the product
  def set_image
    @image = @product.images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to @product, alert: 'Image not found.' }
      format.turbo_stream { flash.now[:alert] = 'Image not found.' }
      format.json { render json: { error: 'Image not found' }, status: :not_found }
    end
  end

  # Handle ActiveStorage Direct Upload
  #
  # This is called when using ActiveStorage's JavaScript Direct Upload feature.
  # The blob is already uploaded to storage, we just need to attach it to the product.
  #
  def handle_direct_upload
    blob = ActiveStorage::Blob.find_signed!(params[:signed_blob_id])

    # Validate blob
    unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
      respond_to do |format|
        format.json { render json: { error: 'Invalid file type' }, status: :unprocessable_entity }
      end
      return
    end

    if blob.byte_size > MAX_FILE_SIZE
      respond_to do |format|
        format.json { render json: { error: 'File size exceeds 10MB limit' }, status: :unprocessable_entity }
      end
      return
    end

    # Attach blob to product
    @product.images.attach(blob)

    respond_to do |format|
      format.json { render json: { uploaded: true, image_id: blob.id }, status: :created }
    end
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    respond_to do |format|
      format.json { render json: { error: 'Invalid signed blob ID' }, status: :unprocessable_entity }
    end
  end
end
