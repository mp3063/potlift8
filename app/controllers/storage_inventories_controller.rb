# Security:
# - All operations scoped to current company via multi-tenancy
# - Validates storage belongs to company before operations
# - Validates products belong to company before adding to inventory
class StorageInventoriesController < ApplicationController
  before_action :set_storage

  def new
    authorize :storage_inventory, :new?

    @available_products = current_potlift_company.products
                                                 .where.not(product_status: :deleted)
                                                 .where.not(id: @storage.products.select(:id))
                                                 .order(:sku)

    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @available_products = @available_products.where(
        "sku ILIKE ? OR name ILIKE ?",
        search_term,
        search_term
      )
    end

    if params[:product_type].present?
      @available_products = @available_products.where(
        product_type: params[:product_type]
      )
    end

    if params[:label_id].present?
      @available_products = @available_products.joins(:product_labels)
                                               .where(product_labels: { label_id: params[:label_id] })
    end

    @available_products = @available_products.limit(100)

    @labels = current_potlift_company.labels.order(:name)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    authorize :storage_inventory, :create?

    product_ids = params[:product_ids].to_a.reject(&:blank?)

    if product_ids.empty?
      respond_to do |format|
        format.html do
          redirect_to new_storage_inventory_path(@storage),
                      alert: "Please select at least one product to add."
        end
        format.turbo_stream do
          flash.now[:alert] = "Please select at least one product to add."
          set_available_products_and_labels
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

    products = current_potlift_company.products.where(id: product_ids)

    if products.count != product_ids.count
      respond_to do |format|
        format.html do
          redirect_to new_storage_inventory_path(@storage),
                      alert: "Some products could not be found or don't belong to your company."
        end
        format.turbo_stream do
          flash.now[:alert] = "Some products could not be found or don't belong to your company."
          set_available_products_and_labels
          render :new, status: :unprocessable_entity
        end
      end
      return
    end

    created_count = 0
    failed_products = []

    products.each do |product|
      quantity = params.dig(:quantities, product.id.to_s).to_i

      next if @storage.inventories.exists?(product_id: product.id)

      inventory = @storage.inventories.build(
        product: product,
        value: quantity
      )

      if inventory.save
        created_count += 1
      else
        failed_products << product.sku
      end
    end

    if failed_products.any?
      respond_to do |format|
        format.html do
          redirect_to inventory_storage_path(@storage), status: :see_other,
                      alert: "Added #{created_count} products. Failed to add: #{failed_products.join(', ')}"
        end
        format.turbo_stream do
          flash.now[:alert] = "Added #{created_count} products. Failed to add: #{failed_products.join(', ')}"
          set_available_products_and_labels
          render :new, status: :unprocessable_entity
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to inventory_storage_path(@storage), status: :see_other,
                      notice: "Successfully added #{created_count} #{'product'.pluralize(created_count)} to #{@storage.name}."
        end
        format.turbo_stream do
          flash.now[:notice] = "Successfully added #{created_count} #{'product'.pluralize(created_count)} to #{@storage.name}."
          set_available_products_and_labels
          render :new
        end
      end
    end
  end

  def update
    authorize :storage_inventory, :update?

    @inventory = @storage.inventories.find(params[:id])
    inv_params = params[:inventory] || {}

    attrs = { value: inv_params[:value].to_i }

    if inv_params[:eta_quantity].present? || inv_params[:eta_date].present? || inv_params[:reason].present?
      info = @inventory.info || {}
      info["eta_quantity"] = inv_params[:eta_quantity].to_i if inv_params.key?(:eta_quantity)
      info["eta_date"] = inv_params[:eta_date].presence if inv_params.key?(:eta_date)
      info["last_adjustment_reason"] = inv_params[:reason] if inv_params[:reason].present?
      info["last_adjusted_at"] = Time.current.iso8601
      attrs[:info] = info

      attrs[:eta] = inv_params[:eta_date].presence if inv_params.key?(:eta_date)
    end

    if @inventory.update(attrs)
      product = @inventory.product
      product.update!(cache: (product.cache || {}).merge("inventory_updated_at" => Time.current.iso8601))

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to inventory_storage_path(@storage), notice: "Inventory updated." }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@inventory, :value),
            partial: "storages/inline_inventory_cell",
            locals: { inventory: @inventory, storage: @storage, error: true }
          )
        end
        format.html { redirect_to inventory_storage_path(@storage), alert: "Failed to update inventory." }
      end
    end
  end

  def destroy
    authorize :storage_inventory, :destroy?

    inventory = @storage.inventories.find(params[:id])
    inventory.destroy

    redirect_to inventory_storage_path(@storage), status: :see_other,
                notice: "Removed #{inventory.product.sku} from #{@storage.name}."
  end

  private

  def set_storage
    @storage = current_potlift_company.storages.find_by!(code: params[:storage_code])
  end

  def set_available_products_and_labels
    @available_products = current_potlift_company.products
                                                 .active_products
                                                 .where.not(id: @storage.products.select(:id))
                                                 .order(:sku)
                                                 .limit(100)
    @labels = current_potlift_company.labels.order(:name)
  end
end
