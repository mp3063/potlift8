class CatalogItemsController < ApplicationController
  before_action :set_catalog

  def new
    authorize CatalogItem

    existing_product_ids = @catalog.catalog_items.pluck(:product_id)
    @products = current_potlift_company.products
                                       .where.not(id: existing_product_ids)
                                       .with_attributes
                                       .with_labels
                                       .includes(:labels)
                                       .order(:sku)

    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @products = @products.where("products.name ILIKE ? OR products.sku ILIKE ?", search_term, search_term)
    end

    if params[:product_type].present?
      @products = @products.where(product_type: params[:product_type])
    end

    if params[:status].present?
      @products = @products.where(product_status: params[:status])
    end

    @pagy, @products = pagy(@products, items: 15)

    respond_to do |format|
      format.html { render layout: false }
      format.turbo_stream
    end
  end

  def create
    authorize CatalogItem

    product_ids = Array(params[:product_ids]).compact_blank

    if product_ids.blank?
      redirect_to catalog_items_path(@catalog), alert: "No products selected."
      return
    end

    added_count = 0
    errors = []

    ActiveRecord::Base.transaction do
      product_ids.each do |product_id|
        product = current_potlift_company.products.find_by(id: product_id)
        next unless product

        next if @catalog.catalog_items.exists?(product_id: product.id)

        catalog_item = @catalog.catalog_items.build(
          product: product,
          catalog_item_state: params[:catalog_item_state] || "active",
          priority: @catalog.catalog_items.maximum(:priority).to_i + 1
        )

        if catalog_item.save
          added_count += 1
        else
          errors << "#{product.sku}: #{catalog_item.errors.full_messages.join(', ')}"
        end
      end
    end

    message = if added_count > 0
                "Successfully added #{added_count} product#{'s' if added_count != 1} to catalog."
    else
                "No products were added to the catalog."
    end

    message += " Errors: #{errors.join('; ')}" if errors.any?

    redirect_to catalog_items_path(@catalog), notice: message
  end

  def destroy
    authorize CatalogItem

    product = current_potlift_company.products.find(params[:id])
    catalog_item = @catalog.catalog_items.find_by(product: product)

    if catalog_item.nil?
      respond_to do |format|
        format.html { redirect_to catalog_items_path(@catalog), alert: "Product not found in catalog." }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Product not found in catalog." } }) }
      end
      return
    end

    catalog_item.destroy

    respond_to do |format|
      format.html do
        redirect_to catalog_items_path(@catalog), notice: "Product removed from catalog."
      end

      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove("catalog_item_#{catalog_item.id}"),
          turbo_stream.prepend("flash", partial: "shared/flash", locals: { flash: { notice: "Product removed from catalog." } })
        ]
      end
    end
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to catalog_items_path(@catalog), alert: "Product not found." }
      format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { flash: { alert: "Product not found." } }) }
    end
  end

  private

  def set_catalog
    @catalog = current_potlift_company.catalogs.find_by!(code: params[:catalog_code])
  end
end
