# ProductInventoriesController
#
# Manages inventory records for products across storage locations.
# Nested under products route: /products/:product_id/inventories
#
class ProductInventoriesController < ApplicationController
  before_action :set_product
  before_action :set_inventory, only: [:update]

  # GET /products/:product_id/inventories
  # Display all inventory records for a product across storage locations
  def index
    @inventories = @product.inventories
      .includes(:storage)
      .order('storages.storage_position ASC, storages.name ASC')
    @storages = current_potlift_company.storages.active
  end

  # PATCH/PUT /products/:product_id/inventories/:id
  # Update inventory value for a specific storage location
  def update
    if @inventory.update(inventory_params)
      redirect_to product_inventories_path(@product),
                  notice: "Inventory updated successfully."
    else
      redirect_to product_inventories_path(@product),
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
    params.require(:inventory).permit(:value)
  end
end
