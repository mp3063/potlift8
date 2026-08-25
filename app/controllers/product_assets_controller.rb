class ProductAssetsController < ApplicationController
  before_action :set_product
  before_action :set_asset, only: [ :edit, :update, :destroy ]

  MAX_VIDEO_SIZE = 100.megabytes
  MAX_DOCUMENT_SIZE = 20.megabytes

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

  def index
    authorize ProductAsset

    @assets = @product.product_assets.non_images.ordered.with_attached_file
    @documents = @assets.documents
    @videos = @assets.videos
    @links = @assets.links
    @product_asset = @product.product_assets.build
  end

  def new
    authorize ProductAsset

    @asset = @product.product_assets.build
    @product_asset = @asset
    @asset.asset_visibility = :public_visibility
    @asset.asset_priority = 50
  end

  def create
    authorize ProductAsset

    @asset = @product.product_assets.build(asset_params)
    @product_asset = @asset

    if @asset.link? && url_param.present?
      @asset.info ||= {}
      @asset.info["url"] = url_param
    end

    if @asset.video? && url_param.present?
      @asset.info ||= {}
      @asset.info["url"] = url_param
    end

    if @asset.document? && file_param.blank? && signed_blob_id_param.blank?
      @asset.errors.add(:file, "is required for documents")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = "File is required for document assets."
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

    if @asset.video? && file_param.blank? && url_param.blank? && signed_blob_id_param.blank?
      @asset.errors.add(:base, "Either a video file or video URL is required")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          flash.now[:alert] = "Either a video file or video URL is required."
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

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
      if signed_blob_id_param.present?
        @asset.file.attach(signed_blob_id_param)
      elsif file_param.present?
        @asset.file.attach(file_param)
      end

      respond_to do |format|
        format.html { redirect_to product_product_assets_path(@product), notice: "Asset created successfully." }
        format.turbo_stream { redirect_to product_product_assets_path(@product), notice: "Asset created successfully." }
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

  def edit
    authorize @asset

    @product_asset = @asset
    @asset_url = @asset.info&.dig("url") if @asset.link? || @asset.video?
  end

  def update
    authorize @asset

    @product_asset = @asset

    if @asset.link? && url_param.present?
      @asset.info ||= {}
      @asset.info["url"] = url_param
    end

    if @asset.video? && url_param.present?
      @asset.info ||= {}
      @asset.info["url"] = url_param
    end

    if signed_blob_id_param.present?
      @asset.file.purge if @asset.file.attached?
      @asset.file.attach(signed_blob_id_param)
    elsif file_param.present?
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

      @asset.file.purge if @asset.file.attached?
      @asset.file.attach(file_param)
    end

    if @asset.update(asset_params)
      respond_to do |format|
        format.html { redirect_to product_product_assets_path(@product), notice: "Asset updated successfully." }
        format.turbo_stream { redirect_to product_product_assets_path(@product), notice: "Asset updated successfully." }
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

  def destroy
    authorize @asset

    asset_name = @asset.name
    asset_type = @asset.product_asset_type

    @asset.file.purge if @asset.file.attached?

    @asset.destroy

    respond_to do |format|
      format.html { redirect_to product_product_assets_path(@product), notice: "#{asset_type.humanize} '#{asset_name}' deleted successfully." }
      format.turbo_stream { redirect_to product_product_assets_path(@product), notice: "#{asset_type.humanize} '#{asset_name}' deleted successfully." }
      format.json { head :no_content }
    end
  end

  def reorder
    authorize ProductAsset

    unless params[:asset_ids].is_a?(Array)
      respond_to do |format|
        format.json { render json: { error: "Invalid asset_ids parameter" }, status: :unprocessable_entity }
      end
      return
    end

    asset_ids = params[:asset_ids].map(&:to_i)

    current_asset_ids = @product.product_assets.non_images.pluck(:id)
    unless (asset_ids - current_asset_ids).empty?
      respond_to do |format|
        format.json { render json: { error: "Invalid asset IDs" }, status: :unprocessable_entity }
      end
      return
    end

    priority = asset_ids.size * 10
    asset_ids.each do |asset_id|
      ProductAsset.where(id: asset_id).update_all(asset_priority: priority)
      priority -= 10
    end

    respond_to do |format|
      format.json { render json: { success: true, message: "Assets reordered successfully" }, status: :ok }
      format.turbo_stream do
        flash.now[:notice] = "Assets reordered successfully."
        render turbo_stream: [
          turbo_stream.replace("product_assets", partial: "product_assets/list", locals: { product: @product, assets: @product.product_assets.non_images.ordered.reload }),
          turbo_stream.update("flash", partial: "shared/flash", locals: { flash: flash })
        ]
      end
    end
  end

  def bulk_destroy
    authorize ProductAsset

    unless params[:asset_ids].is_a?(Array)
      respond_to do |format|
        format.json { render json: { error: "Invalid asset_ids parameter" }, status: :unprocessable_entity }
      end
      return
    end

    asset_ids = params[:asset_ids].map(&:to_i)
    assets = @product.product_assets.non_images.where(id: asset_ids)
    deleted_count = 0

    assets.each do |asset|
      asset.file.purge if asset.file.attached?
      asset.destroy
      deleted_count += 1
    end

    respond_to do |format|
      format.json { render json: { success: true, deleted: deleted_count }, status: :ok }
      format.html { redirect_to product_product_assets_path(@product), notice: "#{deleted_count} asset(s) deleted successfully." }
    end
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to products_path, alert: "Product not found." }
      format.turbo_stream { flash.now[:alert] = "Product not found." }
      format.json { render json: { error: "Product not found" }, status: :not_found }
    end
  end

  def set_asset
    @asset = @product.product_assets.non_images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to product_path(@product, anchor: "assets"), alert: "Asset not found." }
      format.turbo_stream { flash.now[:alert] = "Asset not found." }
      format.json { render json: { error: "Asset not found" }, status: :not_found }
    end
  end

  # Note: file and url are handled separately in create/update actions
  def asset_params
    asset_key = params.key?(:product_asset) ? :product_asset : :asset
    params.require(asset_key).permit(
      :name,
      :product_asset_type,
      :asset_visibility,
      :asset_priority,
      :asset_description
    )
  end

  def url_param
    video_url = params.dig(:product_asset, :video_url) || params.dig(:asset, :video_url)
    link_url = params.dig(:product_asset, :link_url) || params.dig(:asset, :link_url)

    return video_url if video_url.present?
    return link_url if link_url.present?

    # Fallback to old format for backward compatibility
    params.dig(:asset, :url) || params.dig(:product_asset, :url)
  end

  def file_param
    params.dig(:asset, :file) || params.dig(:product_asset, :file)
  end

  def signed_blob_id_param
    params.dig(:product_asset, :signed_blob_id) || params.dig(:asset, :signed_blob_id)
  end

  def validate_file(file, asset_type)
    return "File is required" if file.blank?

    case asset_type
    when "video"
      validate_video_file(file)
    when "document"
      validate_document_file(file)
    else
      "Invalid asset type for file upload"
    end
  end

  def validate_video_file(file)
    unless ALLOWED_VIDEO_TYPES.include?(file.content_type)
      return "Invalid video file type. Allowed types: MP4, MPEG, QuickTime, AVI, WebM"
    end

    if file.size > MAX_VIDEO_SIZE
      return "Video file size exceeds #{MAX_VIDEO_SIZE / 1.megabyte}MB limit"
    end

    nil
  end

  def validate_document_file(file)
    unless ALLOWED_DOCUMENT_TYPES.include?(file.content_type)
      return "Invalid document file type. Allowed types: PDF, Word, Excel, PowerPoint, Text, CSV"
    end

    if file.size > MAX_DOCUMENT_SIZE
      return "Document file size exceeds #{MAX_DOCUMENT_SIZE / 1.megabyte}MB limit"
    end

    nil
  end
end
