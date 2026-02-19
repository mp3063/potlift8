# ProductInventoriesController
#
# Manages inventory records for products across storage locations.
# Nested under products route: /products/:product_id/inventories
#
class ProductInventoriesController < ApplicationController
  before_action :set_product
  before_action :set_inventory, only: [ :update ]

  # GET /products/:product_id/inventories
  # Display all inventory records for a product across storage locations
  def index
    authorize :product_inventory, :index?
    @inventories = @product.inventories
      .includes(:storage)
      .order("storages.storage_position ASC, storages.name ASC")
    @storages = current_potlift_company.storages.active
  end

  # PATCH/PUT /products/:product_id/inventories/:id
  # Update inventory value for a specific storage location
  def update
    authorize @inventory
    # Build the update parameters
    update_params = { value: inventory_params[:value] }

    # Handle ETA fields in info JSONB column
    info_updates = {}

    # Handle ETA quantity - only update if present
    if inventory_params[:eta_quantity].present?
      info_updates["eta_quantity"] = inventory_params[:eta_quantity].to_i
    end

    # Handle ETA date - support clearing by setting to nil if empty string
    if inventory_params.key?(:eta_date)
      info_updates["eta_date"] = inventory_params[:eta_date].present? ? inventory_params[:eta_date] : nil
    end

    # Merge with existing info data
    if info_updates.any?
      current_info = @inventory.info || {}
      update_params[:info] = current_info.merge(info_updates)
    end

    if @inventory.update(update_params)
      # Redirect back to storage inventory page if coming from there
      # Otherwise redirect to product inventories page
      redirect_back_or_to product_inventories_path(@product),
                          notice: "Inventory updated successfully."
    else
      redirect_back_or_to product_inventories_path(@product),
                          alert: "Failed to update inventory: #{@inventory.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_inventory
    @inventory = @product.inventories.find(params[:id])
  end

  def inventory_params
    params.require(:inventory).permit(:value, :eta_quantity, :eta_date, :reason)
  end
end
