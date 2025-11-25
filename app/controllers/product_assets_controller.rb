# ProductAssetsController
#
# Manages product assets (videos, documents, links) using ActiveStorage.
# Images are handled separately by ProductImagesController.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - File upload for videos and documents via ActiveStorage
# - URL management for link assets and video URLs (YouTube/Vimeo)
# - Asset metadata management (name, description, visibility, priority)
# - Drag-and-drop reordering
# - Turbo Stream support for dynamic updates
#
# Asset Types (handled by this controller):
# - video (2): Video files with ActiveStorage OR video URLs (YouTube/Vimeo) stored in info['url']
# - document (3): PDF, Word, Excel, etc. with ActiveStorage (file required)
# - link (4): External URLs stored in info['url']
#
# Routes:
# - GET /products/:product_id/product_assets - List assets
# - GET /products/:product_id/product_assets/new - New asset form
# - POST /products/:product_id/product_assets - Create asset
# - GET /products/:product_id/product_assets/:id/edit - Edit asset form
# - PATCH /products/:product_id/product_assets/:id - Update asset
# - DELETE /products/:product_id/product_assets/:id - Delete asset
# - POST /products/:product_id/product_assets/reorder - Reorder assets
#
class ProductAssetsController < ApplicationController
  before_action :set_product
  before_action :set_asset, only: [:edit, :update, :destroy]

  # Maximum file sizes by type
  MAX_VIDEO_SIZE = 100.megabytes
  MAX_DOCUMENT_SIZE = 20.megabytes

  # Allowed content types
  ALLOWED_VIDEO_TYPES = %w[
    video/mp4
    video/mpeg
    video/quicktime
    video/x-msvideo
    video/webm
  ].freeze

  ALLOWED_DOCUMENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    text/plain
    text/csv
  ].freeze

  # GET /products/:product_id/product_assets
  # GET /products/:product_id/product_assets.turbo_stream
  #
  # Lists all non-image assets (videos, documents, links) for a product.
  # Images are handled by ProductImagesController.
  #
  def index
    @assets = @product.product_assets.non_images.ordered.with_attached_file
    @documents = @assets.documents
    @videos = @assets.videos
    @links = @assets.links
    @product_asset = @product.product_assets.build
  end

  # GET /products/:product_id/product_assets/new
  # GET /products/:product_id/product_assets/new.turbo_stream
  #
  # Renders form for creating a new asset.
  # Supports all asset types: video, document, link.
  #
  def new
    @asset = @product.product_assets.build
    # Default to public visibility and medium priority
    @asset.asset_visibility = :public_visibility
    @asset.asset_priority = 50
  end

  # POST /products/:product_id/product_assets
  # POST /products/:product_id/product_assets.turbo_stream
  #
  # Creates a new asset (video, document, or link).
  # For videos: attaches file via ActiveStorage OR stores URL in info['url'] (YouTube/Vimeo)
  # For documents: attaches file via ActiveStorage (required)
  # For links: stores URL in info['url']
  #
  # Parameters:
  # - asset[name]: Asset name/title (required)
  # - asset[product_asset_type]: Type (video/document/link) (required)
  # - asset[asset_visibility]: Visibility level (private/public/catalog_only)
  # - asset[asset_priority]: Sort order priority (integer)
  # - asset[asset_description]: Description text
  # - asset[file]: File upload (for video/document) - required for documents, optional for videos with URL
  # - asset[url]: URL (for link type, or video type as alternative to file)
  #
  def create
    @asset = @product.product_assets.build(asset_params)

    # Handle link URL separately (stored in info JSONB)
    if @asset.link? && url_param.present?
      @asset.info ||= {}
      @asset.info['url'] = url_param
    end

    # Store URL for video type (similar to link type)
    if @asset.video? && url_param.present?
      @asset.info ||= {}
      @asset.info['url'] = url_param
    end

    # Validate file presence for document types (always required)
    if @asset.document? && file_param.blank?
      @asset.errors.add(:file, 'is required for documents')
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = 'File is required for document assets.'
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

    # Validate that video has either file OR URL (at least one required)
    if @asset.video? && file_param.blank? && url_param.blank?
      @asset.errors.add(:base, 'Either a video file or video URL is required')
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = 'Either a video file or video URL is required.'
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

    # Validate file type and size
    if file_param.present?
      file = file_param
      validation_error = validate_file(file, @asset.product_asset_type)

      if validation_error
        @asset.errors.add(:file, validation_error)
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            flash.now[:alert] = "File upload error: #{validation_error}"
            render :new, status: :unprocessable_entity
          end
        end
        return
      end
    end

    if @asset.save
      # Attach file after save (for video/document)
      if file_param.present?
        @asset.file.attach(file_param)
      end

      respond_to do |format|
        format.html { redirect_to product_path(@product, anchor: 'assets'), notice: 'Asset created successfully.' }
        format.turbo_stream do
          flash.now[:notice] = 'Asset created successfully.'
          render turbo_stream: [
            turbo_stream.replace('product_assets', partial: 'product_assets/list', locals: { product: @product, assets: @product.product_assets.non_images.ordered }),
            turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
          ]
        end
        format.json { render json: @asset, status: :created }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = "Failed to create asset: #{@asset.errors.full_messages.join(', ')}"
          render :new, status: :unprocessable_entity
        end
        format.json { render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # GET /products/:product_id/product_assets/:id/edit
  # GET /products/:product_id/product_assets/:id/edit.turbo_stream
  #
  # Renders form for editing an existing asset.
  # Allows updating metadata and replacing files.
  #
  def edit
    # Populate URL field for link and video assets
    @asset_url = @asset.info&.dig('url') if @asset.link? || @asset.video?
  end

  # PATCH /products/:product_id/product_assets/:id
  # PATCH /products/:product_id/product_assets/:id.turbo_stream
  #
  # Updates asset metadata and optionally replaces the file.
  #
  # Parameters:
  # - asset[name]: Asset name/title
  # - asset[asset_visibility]: Visibility level
  # - asset[asset_priority]: Sort order priority
  # - asset[asset_description]: Description text
  # - asset[file]: Replacement file (optional, for video/document)
  # - asset[url]: Updated URL (for link type or video type)
  #
  def update
    # Handle link URL update
    if @asset.link? && url_param.present?
      @asset.info ||= {}
      @asset.info['url'] = url_param
    end

    # Handle video URL update (similar to link type)
    if @asset.video? && url_param.present?
      @asset.info ||= {}
      @asset.info['url'] = url_param
    end

    # Validate and attach new file if provided
    if file_param.present?
      file = file_param
      validation_error = validate_file(file, @asset.product_asset_type)

      if validation_error
        @asset.errors.add(:file, validation_error)
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            flash.now[:alert] = "File upload error: #{validation_error}"
            render :edit, status: :unprocessable_entity
          end
        end
        return
      end

      # Purge old file and attach new one
      @asset.file.purge if @asset.file.attached?
      @asset.file.attach(file_param)
    end

    if @asset.update(asset_params)
      respond_to do |format|
        format.html { redirect_to product_path(@product, anchor: 'assets'), notice: 'Asset updated successfully.' }
        format.turbo_stream do
          flash.now[:notice] = 'Asset updated successfully.'
          render turbo_stream: [
            turbo_stream.replace('product_assets', partial: 'product_assets/list', locals: { product: @product, assets: @product.product_assets.non_images.ordered }),
            turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
          ]
        end
        format.json { render json: @asset, status: :ok }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = "Failed to update asset: #{@asset.errors.full_messages.join(', ')}"
          render :edit, status: :unprocessable_entity
        end
        format.json { render json: { errors: @asset.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /products/:product_id/product_assets/:id
  # DELETE /products/:product_id/product_assets/:id.turbo_stream
  #
  # Deletes an asset and its associated file (if any).
  #
  def destroy
    asset_name = @asset.name
    asset_type = @asset.product_asset_type

    # Purge file if attached
    @asset.file.purge if @asset.file.attached?

    @asset.destroy

    respond_to do |format|
      format.html { redirect_to product_path(@product, anchor: 'assets'), notice: "#{asset_type.humanize} '#{asset_name}' deleted successfully." }
      format.turbo_stream do
        flash.now[:notice] = "#{asset_type.humanize} '#{asset_name}' deleted successfully."
        render turbo_stream: [
          turbo_stream.replace('product_assets', partial: 'product_assets/list', locals: { product: @product, assets: @product.product_assets.non_images.ordered }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
      format.json { head :no_content }
    end
  end

  # POST /products/:product_id/product_assets/reorder
  # POST /products/:product_id/product_assets/reorder.json
  #
  # Reorders assets based on drag-and-drop.
  # Updates asset_priority for each asset based on position.
  #
  # Parameters:
  # - asset_ids: Array of asset IDs in new order
  #
  def reorder
    unless params[:asset_ids].is_a?(Array)
      respond_to do |format|
        format.json { render json: { error: 'Invalid asset_ids parameter' }, status: :unprocessable_entity }
      end
      return
    end

    asset_ids = params[:asset_ids].map(&:to_i)

    # Verify all asset IDs belong to this product
    current_asset_ids = @product.product_assets.non_images.pluck(:id)
    unless (asset_ids - current_asset_ids).empty?
      respond_to do |format|
        format.json { render json: { error: 'Invalid asset IDs' }, status: :unprocessable_entity }
      end
      return
    end

    # Update priorities (highest priority = first in list)
    # Reverse the array so first item gets highest priority
    priority = asset_ids.size * 10
    asset_ids.each do |asset_id|
      ProductAsset.where(id: asset_id).update_all(asset_priority: priority)
      priority -= 10
    end

    respond_to do |format|
      format.json { render json: { success: true, message: 'Assets reordered successfully' }, status: :ok }
      format.turbo_stream do
        flash.now[:notice] = 'Assets reordered successfully.'
        render turbo_stream: [
          turbo_stream.replace('product_assets', partial: 'product_assets/list', locals: { product: @product, assets: @product.product_assets.non_images.ordered.reload }),
          turbo_stream.update('flash', partial: 'shared/flash', locals: { flash: flash })
        ]
      end
    end
  end

  private

  # Set the product from params
  # Ensures product belongs to current company
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to products_path, alert: 'Product not found.' }
      format.turbo_stream { flash.now[:alert] = 'Product not found.' }
      format.json { render json: { error: 'Product not found' }, status: :not_found }
    end
  end

  # Set the asset from params
  # Ensures asset belongs to the product
  def set_asset
    @asset = @product.product_assets.non_images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to product_path(@product, anchor: 'assets'), alert: 'Asset not found.' }
      format.turbo_stream { flash.now[:alert] = 'Asset not found.' }
      format.json { render json: { error: 'Asset not found' }, status: :not_found }
    end
  end

  # Strong parameters for asset
  # Permits only safe attributes for mass assignment
  #
  # Note: file and url are handled separately in create/update actions
  def asset_params
    # Accept both :product_asset (from form_with) and :asset namespaces
    asset_key = params.key?(:product_asset) ? :product_asset : :asset
    params.require(asset_key).permit(
      :name,
      :product_asset_type,
      :asset_visibility,
      :asset_priority,
      :asset_description
    )
  end

  # Get URL from params (can be in :asset or :product_asset namespace)
  def url_param
    params.dig(:asset, :url) || params.dig(:product_asset, :url)
  end

  # Get file from params (can be in :asset or :product_asset namespace)
  def file_param
    params.dig(:asset, :file) || params.dig(:product_asset, :file)
  end

  # Validate file based on asset type
  #
  # @param file [ActionDispatch::Http::UploadedFile] Uploaded file
  # @param asset_type [String] Asset type (video, document)
  # @return [String, nil] Error message or nil if valid
  #
  def validate_file(file, asset_type)
    return 'File is required' if file.blank?

    case asset_type
    when 'video'
      validate_video_file(file)
    when 'document'
      validate_document_file(file)
    else
      'Invalid asset type for file upload'
    end
  end

  # Validate video file
  #
  # @param file [ActionDispatch::Http::UploadedFile] Uploaded file
  # @return [String, nil] Error message or nil if valid
  #
  def validate_video_file(file)
    unless ALLOWED_VIDEO_TYPES.include?(file.content_type)
      return 'Invalid video file type. Allowed types: MP4, MPEG, QuickTime, AVI, WebM'
    end

    if file.size > MAX_VIDEO_SIZE
      return "Video file size exceeds #{MAX_VIDEO_SIZE / 1.megabyte}MB limit"
    end

    nil
  end

  # Validate document file
  #
  # @param file [ActionDispatch::Http::UploadedFile] Uploaded file
  # @return [String, nil] Error message or nil if valid
  #
  def validate_document_file(file)
    unless ALLOWED_DOCUMENT_TYPES.include?(file.content_type)
      return 'Invalid document file type. Allowed types: PDF, Word, Excel, PowerPoint, Text, CSV'
    end

    if file.size > MAX_DOCUMENT_SIZE
      return "Document file size exceeds #{MAX_DOCUMENT_SIZE / 1.megabyte}MB limit"
    end

    nil
  end
end
