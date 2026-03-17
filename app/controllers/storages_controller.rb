# Storages Controller
#
# Manages CRUD operations for storage locations in the Potlift8 inventory system.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Full CRUD operations (index, show, new, create, edit, update, destroy)
# - Inventory view for each storage (shows all products with stock levels)
# - Sorting by code, name, storage_type, created_at
# - Turbo Stream support for dynamic updates
# - Protection against deleting storages with inventory
#
class StoragesController < ApplicationController
  before_action :set_storage, only: [ :show, :edit, :update, :destroy, :inventory ]

  # GET /storages
  # GET /storages.turbo_stream
  #
  # Lists all storage locations with inventory statistics.
  #
  # Query Parameters:
  # - sort: Sort column (code, name, storage_type, created_at)
  # - direction: Sort direction (asc, desc)
  #
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

  # GET /storages/:code
  #
  # Redirects to the inventory action to show storage details.
  #
  def show
    authorize @storage

    redirect_to inventory_storage_path(@storage)
  end

  # GET /storages/:code/inventory
  # GET /storages/:code/inventory.turbo_stream
  #
  # Shows all products in this storage location with their inventory levels.
  #
  # Query Parameters:
  # - sort: Sort column (sku, name, value)
  # - direction: Sort direction (asc, desc)
  #
  def inventory
    authorize @storage
    response.headers["Cache-Control"] = "no-cache, no-store"

    # Get all inventories for this storage with products and their parent relationships
    @inventories = @storage.inventories
                           .includes(product: :product_configurations_as_sub)
                           .joins(:product)

    # Apply search filter
    if params[:q].present?
      escaped = params[:q].gsub("%", "\\%").gsub("_", "\\_")
      search_term = "%#{escaped}%"

      # Also find subproducts of matching parent products (configurable/bundle)
      parent_ids = current_potlift_company.products
                     .where("sku ILIKE ? OR name ILIKE ?", search_term, search_term)
                     .pluck(:id)
      subproduct_ids = ProductConfiguration.where(superproduct_id: parent_ids).pluck(:subproduct_id)

      @inventories = @inventories.where(
        "products.sku ILIKE :term OR products.name ILIKE :term OR products.id IN (:sub_ids)",
        term: search_term, sub_ids: subproduct_ids.presence || [0]
      )
    end

    # Apply sorting
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

    # Group inventories: parent products with their variant inventories nested underneath
    @grouped_inventories = build_grouped_inventories(@inventories)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # GET /storages/new
  #
  # Renders form for creating a new storage location.
  #
  def new
    authorize Storage

    @storage = current_potlift_company.storages.build
  end

  # GET /storages/:code/edit
  #
  # Renders form for editing an existing storage location.
  #
  def edit
    authorize @storage
  end

  # POST /storages
  # POST /storages.turbo_stream
  #
  # Creates a new storage location.
  #
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

  # PATCH /storages/:code
  # PUT /storages/:code
  # PATCH /storages/:code.turbo_stream
  #
  # Updates an existing storage location.
  #
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

  # DELETE /storages/:code
  # DELETE /storages/:code.turbo_stream
  #
  # Destroys a storage location.
  # Prevents deletion if storage has inventory (saldo > 0).
  #
  def destroy
    authorize @storage

    # Check if storage has any inventory
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

  # Build grouped inventory list: subproducts of configurable/bundle products
  # are grouped under a virtual parent row. Standalone products appear as-is.
  def build_grouped_inventories(inventories)
    inventory_list = inventories.to_a

    # Find which inventories are subproducts and group by parent
    child_product_ids = Set.new
    parent_children = Hash.new { |h, k| h[k] = [] }

    inventory_list.each do |inv|
      parent_config = inv.product.product_configurations_as_sub.first
      next unless parent_config

      parent_children[parent_config.superproduct_id] << inv
      child_product_ids << inv.product_id
    end

    # Only group when there are 2+ children from the same parent
    grouped_parent_ids = parent_children.select { |_, children| children.size >= 2 }.keys.to_set
    child_product_ids = Set.new
    parent_children.each do |parent_id, children|
      if grouped_parent_ids.include?(parent_id)
        children.each { |inv| child_product_ids << inv.product_id }
      end
    end

    # Load parent products for virtual rows
    parent_products = current_potlift_company.products.where(id: grouped_parent_ids).index_by(&:id)

    # Build the grouped list
    result = []
    inserted_parents = Set.new

    inventory_list.each do |inv|
      if child_product_ids.include?(inv.product_id)
        # Find this child's parent
        parent_id = inv.product.product_configurations_as_sub.first.superproduct_id
        next unless grouped_parent_ids.include?(parent_id)

        # Insert virtual parent row before first child
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
        # Children are rendered via the parent's children array, skip here
      else
        result << { type: :standalone, inventory: inv }
      end
    end

    result
  end

  # Set the storage for show, edit, update, destroy, inventory actions
  # Uses code as parameter (via to_param and routes param: :code)
  # Ensures storage belongs to current company
  # Raises ActiveRecord::RecordNotFound if storage not found or doesn't belong to company
  def set_storage
    @storage = current_potlift_company.storages.find_by!(code: params[:code] || params[:id])
  end

  # Strong parameters for storage creation/update
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

  # Get sort column from params
  # Defaults to code if invalid or not provided
  #
  # @return [String] The column to sort by
  #
  def sort_column
    allowed_columns = %w[code name storage_type created_at]
    allowed_columns.include?(params[:sort]) ? params[:sort] : "code"
  end

  # Get sort direction from params
  # Defaults to asc if invalid or not provided
  #
  # @return [String] The sort direction (asc or desc)
  #
  def sort_direction
    allowed_directions = %w[asc desc]
    allowed_directions.include?(params[:direction]) ? params[:direction] : "asc"
  end
end
