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
  before_action :set_image, only: [:update, :destroy]

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

  # PATCH /products/:product_id/images/reorder
  # PATCH /products/:product_id/images/reorder.json
  # PATCH /products/:product_id/images/reorder.turbo_stream
  #
  # Reorders product images based on drag-and-drop.
  # ActiveStorage orders attachments by ID (primary key), so we must detach and
  # reattach in the desired order to get sequential IDs.
  #
  # Parameters:
  # - image_ids: Array of image attachment IDs in new order
  #
  def reorder
    unless params[:image_ids].is_a?(Array)
      respond_to do |format|
        format.json { render json: { error: 'Invalid image_ids parameter' }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    image_ids = params[:image_ids].map(&:to_i)

    # Verify all image IDs belong to this product
    current_image_ids = @product.images.map(&:id)
    unless (image_ids - current_image_ids).empty?
      respond_to do |format|
        format.json { render json: { error: 'Invalid image IDs' }, status: :unprocessable_entity }
        format.turbo_stream { head :unprocessable_entity }
      end
      return
    end

    # Use a transaction to ensure atomicity
    ActiveRecord::Base.transaction do
      # Collect blobs with their metadata BEFORE detaching
      # Map each attachment ID to its blob
      blob_map = {}
      image_ids.each do |attachment_id|
        attachment = @product.images.find(attachment_id)
        blob_map[attachment_id] = attachment.blob
      end

      # Detach all images (removes attachment records but keeps blobs)
      @product.images.detach

      # Reattach blobs in the new order
      # New attachments will get sequential IDs in this order
      image_ids.each do |attachment_id|
        blob = blob_map[attachment_id]
        @product.images.attach(blob)
      end
    end

    # Force reload to get fresh attachment records (must be outside transaction)
    # Reset the association to clear any caching
    @product.images.reset
    @product.reload

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = 'Images reordered successfully'
        render turbo_stream: [
          turbo_stream.replace('product_images_card', partial: 'products/images', locals: { product: @product }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { render json: { success: true, message: 'Images reordered successfully' }, status: :ok }
    end
  end

  # PATCH /products/:product_id/images/:id
  # PATCH /products/:product_id/images/:id.turbo_stream
  #
  # Updates image metadata (alt text, caption, description).
  #
  def update
    # ActiveStorage attachments don't have direct metadata fields
    # We'll store metadata in the blob's metadata hash
    metadata = {}
    metadata[:alt_text] = params[:alt_text] if params[:alt_text].present?
    metadata[:caption] = params[:caption] if params[:caption].present?
    metadata[:description] = params[:description] if params[:description].present?

    @image.blob.update(metadata: @image.blob.metadata.merge(metadata))

    respond_to do |format|
      format.html { redirect_to @product, notice: 'Image metadata updated successfully.' }
      format.turbo_stream do
        flash.now[:notice] = 'Image metadata updated successfully.'
        render turbo_stream: [
          turbo_stream.replace('product_images', partial: 'products/images', locals: { product: @product }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { render json: { success: true, metadata: metadata }, status: :ok }
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

  # DELETE /products/:product_id/images/bulk_destroy
  # DELETE /products/:product_id/images/bulk_destroy.json
  #
  # Deletes multiple images at once.
  #
  # Parameters:
  # - image_ids: Array of image attachment IDs to delete
  #
  def bulk_destroy
    unless params[:image_ids].is_a?(Array)
      respond_to do |format|
        format.json { render json: { error: 'Invalid image_ids parameter' }, status: :unprocessable_entity }
      end
      return
    end

    image_ids = params[:image_ids].map(&:to_i)
    deleted_count = 0

    image_ids.each do |image_id|
      begin
        image = @product.images.find(image_id)
        image.purge
        deleted_count += 1
      rescue ActiveRecord::RecordNotFound
        # Skip invalid IDs
        next
      end
    end

    message = "#{deleted_count} #{deleted_count == 1 ? 'image' : 'images'} deleted successfully."

    respond_to do |format|
      format.html { redirect_to @product, notice: message }
      format.turbo_stream do
        flash.now[:notice] = message
        render turbo_stream: [
          turbo_stream.replace('product_images', partial: 'products/images', locals: { product: @product }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { render json: { success: true, deleted: deleted_count, message: message }, status: :ok }
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
