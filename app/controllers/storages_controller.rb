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
    # Get all inventories for this storage with products
    # Only eager load what we need: product (for sku, name, product_type, info)
    @inventories = @storage.inventories
                           .includes(:product)
                           .joins(:product)

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
    @storage = current_potlift_company.storages.build
  end

  # GET /storages/:code/edit
  #
  # Renders form for editing an existing storage location.
  #
  def edit
  end

  # POST /storages
  # POST /storages.turbo_stream
  #
  # Creates a new storage location.
  #
  def create
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
