class StoragesController < ApplicationController
  before_action :set_storage, only: [ :show, :edit, :update, :destroy, :inventory ]

  def index
    authorize Storage

    # Eager load inventories and products to prevent N+1 queries
    # inventories.count and products.count queries are optimized
    @storages = current_potlift_company.storages
                                       .includes(:inventories, :products)
                                       .order(sort_column => sort_direction)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def show
    authorize @storage

    redirect_to inventory_storage_path(@storage)
  end

  def inventory
    authorize @storage
    response.headers["Cache-Control"] = "no-cache, no-store"

    @inventories = @storage.inventories
                           .includes(product: :product_configurations_as_sub)
                           .joins(:product)

    if params[:q].present?
      escaped = params[:q].gsub("%", "\\%").gsub("_", "\\_")
      search_term = "%#{escaped}%"

      parent_ids = current_potlift_company.products
                     .where("sku ILIKE ? OR name ILIKE ?", search_term, search_term)
                     .pluck(:id)
      subproduct_ids = ProductConfiguration.where(superproduct_id: parent_ids).pluck(:subproduct_id)

      @inventories = @inventories.where(
        "products.sku ILIKE :term OR products.name ILIKE :term OR products.id IN (:sub_ids)",
        term: search_term, sub_ids: subproduct_ids.presence || [0]
      )
    end

    case params[:sort]
    when "sku"
      @inventories = @inventories.order("products.sku #{sort_direction}")
    when "name"
      @inventories = @inventories.order("products.name #{sort_direction}")
    when "value"
      @inventories = @inventories.order("inventories.value #{sort_direction}")
    else
      @inventories = @inventories.order("products.sku #{sort_direction}")
    end

    @grouped_inventories = build_grouped_inventories(@inventories)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def new
    authorize Storage

    @storage = current_potlift_company.storages.build
  end

  def edit
    authorize @storage
  end

  def create
    authorize Storage

    @storage = current_potlift_company.storages.build(storage_params)

    if @storage.save
      respond_to do |format|
        format.html { redirect_to storages_path, notice: "Storage location created successfully." }
        format.turbo_stream { flash.now[:notice] = "Storage location created successfully." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @storage

    if @storage.update(storage_params)
      respond_to do |format|
        format.html { redirect_to storages_path, notice: "Storage location updated successfully." }
        format.turbo_stream { flash.now[:notice] = "Storage location updated successfully." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Destroys a storage location.
  # Prevents deletion if storage has inventory (saldo > 0).
  def destroy
    authorize @storage

    if @storage.has_inventory?
      respond_to do |format|
        format.html do
          redirect_to storages_path,
                      alert: "Cannot delete storage '#{@storage.name}' because it contains inventory. " \
                             "Please move or remove all inventory first."
        end
        format.turbo_stream do
          flash.now[:alert] = "Cannot delete storage '#{@storage.name}' because it contains inventory. " \
                             "Please move or remove all inventory first."
        end
      end
      return
    end

    @storage.destroy

    respond_to do |format|
      format.html { redirect_to storages_path, notice: "Storage location deleted successfully." }
      format.turbo_stream { flash.now[:notice] = "Storage location deleted successfully." }
    end
  end

  private

  def build_grouped_inventories(inventories)
    inventory_list = inventories.to_a

    child_product_ids = Set.new
    parent_children = Hash.new { |h, k| h[k] = [] }

    inventory_list.each do |inv|
      parent_config = inv.product.product_configurations_as_sub.first
      next unless parent_config

      parent_children[parent_config.superproduct_id] << inv
      child_product_ids << inv.product_id
    end

    grouped_parent_ids = parent_children.select { |_, children| children.size >= 2 }.keys.to_set
    child_product_ids = Set.new
    parent_children.each do |parent_id, children|
      if grouped_parent_ids.include?(parent_id)
        children.each { |inv| child_product_ids << inv.product_id }
      end
    end

    parent_products = current_potlift_company.products.where(id: grouped_parent_ids).index_by(&:id)

    result = []
    inserted_parents = Set.new

    inventory_list.each do |inv|
      if child_product_ids.include?(inv.product_id)
        parent_id = inv.product.product_configurations_as_sub.first.superproduct_id
        next unless grouped_parent_ids.include?(parent_id)

        unless inserted_parents.include?(parent_id)
          inserted_parents << parent_id
          children = parent_children[parent_id].sort_by { |i| i.product.sku }
          total_value = children.sum(&:value)
          result << {
            type: :parent,
            product: parent_products[parent_id],
            total_value: total_value,
            children: children
          }
        end
      else
        result << { type: :standalone, inventory: inv }
      end
    end

    result
  end

  def set_storage
    @storage = current_potlift_company.storages.find_by!(code: params[:code] || params[:id])
  end

  def storage_params
    params.require(:storage).permit(
      :name,
      :code,
      :storage_type,
      :storage_status,
      :storage_position,
      :default,
      info: {}
    )
  end

  def sort_column
    allowed_columns = %w[code name storage_type created_at]
    allowed_columns.include?(params[:sort]) ? params[:sort] : "code"
  end

  def sort_direction
    allowed_directions = %w[asc desc]
    allowed_directions.include?(params[:direction]) ? params[:direction] : "asc"
  end
end
