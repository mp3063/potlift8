class ProductsController < ApplicationController
  before_action :set_product, only: [ :show, :edit, :update, :destroy, :duplicate, :toggle_active, :activate_variants, :attribute_value ]

  def index
    authorize Product

    # Use optimized scope with eager loading to prevent N+1 queries
    # .with_labels_only is faster than .with_search_associations for listing pages
    # .with_subproducts is needed for expandable row functionality (configurable products)
    # .includes(:bundle_variants) is needed for bundle products
    # .parent_products_only filters out variant products (displayed as expandable children)
    @products = current_potlift_company.products
                                       .parent_products_only
                                       .with_labels_only
                                       .with_subproducts
                                       .includes(bundle_variants: [ :subproducts, { product_configurations_as_super: :subproduct } ])
                                       .includes(catalog_items: :catalog)

    @filter_service = ProductFilteringService.new(@products, params, current_potlift_company)
    @products = @filter_service.call
    @current_label = @filter_service.current_label

    @available_labels = current_potlift_company.labels
                                               .root_labels
                                               .includes(:sublabels)
                                               .order(:label_positions, :name)
    @label_product_counts = LabelProductCountService.new(current_potlift_company).call

    @available_catalogs = current_potlift_company.catalogs.order(:name)

    @products = @products.order(@filter_service.sort_column => @filter_service.sort_direction)

    respond_to do |format|
      format.html do
        @pagy, @products = pagy(@products, items: params[:per_page] || 25)
      end

      format.csv do
        # For CSV export, we don't paginate - export all filtered results
        # Use readonly for better performance on read-only operations
        send_csv_export(@products.readonly_records)
      end
    end
  end

  def show
    authorize @product

    # Load product with eager loading to prevent N+1 queries
    # NOTE: Bullet may incorrectly flag :labels as unused due to ViewComponent rendering
    # catalog_item_attribute_values is needed in full despite the counter cache,
    # because the show view reads the individual override records, not just the count
    @product = current_potlift_company.products
                                      .with_attributes
                                      .includes(:labels)
                                      .includes(catalog_items: [ :catalog, :catalog_item_attribute_values ])
                                      .includes(configurations: :configuration_values)
                                      .with_subproducts
                                      # TODO: Add .with_inventory when inventory is displayed in show view
                                      .find(params[:id])

    @attribute_values = @product.product_attribute_values.each_with_object({}) do |pav, hash|
      hash[pav.product_attribute] = pav
    end

    @available_catalogs = current_potlift_company.catalogs
                                                 .where.not(id: @product.catalog_items.map(&:catalog_id))
                                                 .order(:name)

    # IMPORTANT: Include CSRF token in ETag to prevent token mismatch errors
    # When the session changes (e.g., token refresh), cached HTML with old CSRF
    # tokens would cause InvalidAuthenticityToken errors on form submissions
    fresh_when(
      etag: [
        @product,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at),
        @product.configurations.maximum(:updated_at),
        @product.subproducts.maximum(:updated_at),
        form_authenticity_token
      ],
      last_modified: [
        @product.updated_at,
        @product.product_attribute_values.maximum(:updated_at),
        @product.labels.maximum(:updated_at),
        @product.catalog_items.maximum(:updated_at),
        @product.configurations.maximum(:updated_at),
        @product.subproducts.maximum(:updated_at)
        # TODO: Add inventories.maximum(:updated_at) when inventory is displayed
      ].compact.max,
      public: false # Don't cache in public CDNs (multi-tenant data)
    )
  end

  def new
    authorize Product
    @product = current_potlift_company.products.build
  end

  def edit
    authorize @product
    @product.bundle_template if @product.product_type_bundle?
  end

  def create
    authorize Product
    @product = current_potlift_company.products.build(product_params)

    handle_info_fields(@product)

    success = false
    @generated_count = 0

    ActiveRecord::Base.transaction do
      unless @product.save
        raise ActiveRecord::Rollback
      end

      if @product.product_type_bundle? && bundle_config_present?
        result = BundleVariantGeneratorService.new(@product, bundle_configuration).call

        unless result.success?
          @product.errors.add(:base, result.errors.join(", "))
          raise ActiveRecord::Rollback
        end

        @generated_count = result.variants.count
      end

      success = true
    end

    if success
      notice_message = if @generated_count > 0
                        "Product created successfully. Generated #{@generated_count} #{'variant'.pluralize(@generated_count)}."
      else
                        "Product created successfully."
      end
      redirect_to products_path, notice: notice_message, status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @product

    handle_info_fields(@product)

    success = false
    @deleted_count = 0
    @created_count = 0

    ActiveRecord::Base.transaction do
      unless @product.update(product_params)
        raise ActiveRecord::Rollback
      end

      if @product.product_type_bundle? && should_regenerate?
        result = BundleRegeneratorService.new(@product, bundle_configuration).call

        unless result.success?
          @product.errors.add(:base, result.errors.join(", "))
          raise ActiveRecord::Rollback
        end

        @deleted_count = result.deleted_count
        @created_count = result.created_count
      end

      success = true
    end

    if success
      notice_message = if @created_count > 0
                        "Product updated successfully. Regenerated #{@created_count} #{'variant'.pluralize(@created_count)}."
      else
                        "Product updated successfully."
      end
      redirect_to products_path, notice: notice_message, status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product
    @product.destroy
    respond_to do |format|
      format.html { redirect_to products_path, notice: "Product deleted successfully.", status: :see_other }
      format.turbo_stream { render turbo_stream: turbo_stream.action(:refresh, "") }
    end
  end

  def duplicate
    authorize @product
    new_product = @product.duplicate!

    redirect_to edit_product_path(new_product), notice: "Product duplicated as #{new_product.sku}", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    redirect_to products_path, alert: "Failed to duplicate product: #{e.message}", status: :see_other
  end

  def validate_sku
    authorize Product
    sku = params[:sku]

    if sku.blank?
      render json: { valid: false, message: "SKU cannot be blank" }
      return
    end

    normalized_sku = sku.to_s.strip.upcase

    existing = current_potlift_company.products.where(sku: normalized_sku)
    existing = existing.where.not(id: params[:product_id]) if params[:product_id].present?

    if existing.exists?
      render json: { valid: false, message: "SKU already exists" }
    else
      render json: { valid: true }
    end
  end

  def toggle_active
    authorize @product
    begin
      if @product.active?
        @product.disable!
        status_text = "deactivated"
      else
        @product.activate!
        status_text = "activated"
      end

      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, notice: "Product #{status_text} successfully.", status: :see_other }
        format.turbo_stream { flash.now[:notice] = "Product #{status_text} successfully." }
      end
    rescue AASM::InvalidTransition => e
      error_message = if @product.active?
                        "Cannot deactivate product: #{e.message}"
      else
                        validator = ProductValidator.new(@product)
                        errors = validator.validate_structure
                        if errors.any?
                          "Cannot activate product: #{errors.join('. ')}."
                        else
                          "Cannot activate product. Ensure all mandatory attributes are set and product structure is valid."
                        end
      end

      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, alert: error_message, status: :see_other }
        format.turbo_stream { flash.now[:alert] = error_message }
      end
    rescue ActiveRecord::RecordInvalid => e
      @product.reload
      respond_to do |format|
        format.html { redirect_to @product, alert: "Failed to update product: #{e.message}", status: :see_other }
        format.turbo_stream { flash.now[:alert] = "Failed to update product: #{e.message}" }
      end
    end
  end

  def activate_variants
    authorize @product

    inactive_variants = @product.subproducts.where.not(product_status: :active)

    if inactive_variants.empty?
      respond_to do |format|
        format.html { redirect_to @product, notice: "All variants are already active.", status: :see_other }
        format.turbo_stream { flash.now[:notice] = "All variants are already active." }
      end
      return
    end

    activated = []
    failed = []

    inactive_variants.each do |variant|
      variant.activate!
      activated << variant.sku
    rescue AASM::InvalidTransition
      validator = ProductValidator.new(variant)
      errors = validator.validate_structure
      reason = errors.any? ? errors.join(", ") : "validation failed"
      failed << "#{variant.sku} (#{reason})"
    end

    message = []
    message << "Activated #{activated.size} variant#{'s' if activated.size != 1}." if activated.any?
    message << "Failed: #{failed.join('; ')}." if failed.any?

    @product.reload
    flash_type = failed.any? ? :alert : :notice
    respond_to do |format|
      format.html { redirect_to @product, flash_type => message.join(" "), status: :see_other }
      format.turbo_stream { flash.now[flash_type] = message.join(" ") }
    end
  end

  def attribute_value
    authorize @product
    code = params[:code]

    if code.blank?
      render json: { error: "Attribute code is required" }, status: :bad_request
      return
    end

    value = @product.read_attribute_value(code)

    render json: { value: value }
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :sku,
      :name,
      :description,
      :product_type,
      :configuration_type,
      :product_status,
      :ean,
      :active,
      label_ids: []
    )
  end

  def handle_info_fields(product)
    return unless params[:product] && params[:product][:restock_level]

    product.info ||= {}

    if params[:product][:restock_level].present?
      product.info["restock_level"] = params[:product][:restock_level].to_i
    else
      product.info["restock_level"] = 0
    end
  end

  def send_csv_export(products)
    csv_data = ProductExportService.new(products).to_csv

    send_data csv_data,
              filename: "products_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def bundle_configuration
    @bundle_configuration ||= JSON.parse(params[:bundle_configuration] || "{}")
  rescue JSON::ParserError
    {}
  end

  # Check if bundle configuration is present and valid
  # Configuration must have 'components' array to be considered present
  def bundle_config_present?
    params[:bundle_configuration].present? && bundle_configuration["components"].present?
  end

  def should_regenerate?
    params[:regenerate] == "true" && bundle_config_present?
  end
end
