# ProductInventoriesController
#
# Manages inventory records for products across storage locations.
# Nested under products route: /products/:product_id/inventories
#
# Supports three product types with different grid layouts:
# - Sellable: storages as rows, editable value + ETA columns
# - Configurable: variants × storages spreadsheet grid
# - Bundle: read-only calculated inventory
#
class ProductInventoriesController < ApplicationController
  before_action :set_product
  before_action :set_inventory, only: [ :update ]

  # GET /products/:product_id/inventories
  # Display inventory grid for a product across storage locations
  def index
    authorize :product_inventory, :index?
    @storages = current_potlift_company.storages.active.order(:storage_position, :name)

    case @product.product_type
    when "configurable"
      load_configurable_inventory
    when "bundle"
      load_bundle_inventory
    else
      load_sellable_inventory
    end

    @has_inventory = detect_has_inventory
  end

  # PATCH /products/:product_id/inventories/batch_update
  # Batch update all inventory cells from the grid form
  def batch_update
    authorize :product_inventory, :batch_update?

    inventories_params = params[:inventories]&.to_unsafe_h || {}

    if inventories_params.empty?
      redirect_to product_inventories_path(@product), alert: "No inventory data provided."
      return
    end

    valid_product_ids = allowed_product_ids
    valid_storage_ids = @storages = current_potlift_company.storages.active.pluck(:id).to_set

    errors = []

    ActiveRecord::Base.transaction do
      inventories_params.each do |cell_key, cell_params|
        product_id, storage_id = cell_key.split("_").map(&:to_i)

        unless valid_product_ids.include?(product_id) && valid_storage_ids.include?(storage_id)
          errors << { cell_key: cell_key, messages: [ "Invalid product or storage" ] }
          next
        end

        inventory = Inventory.find_or_initialize_by(product_id: product_id, storage_id: storage_id)
        inventory.value = cell_params[:value].to_i

        # Handle ETA fields for sellable grid (stored in info JSONB)
        if cell_params[:eta_quantity].present? || cell_params.key?(:eta_date)
          info = inventory.info || {}
          info["eta_quantity"] = cell_params[:eta_quantity].to_i if cell_params[:eta_quantity].present?
          info["eta_date"] = cell_params[:eta_date].presence if cell_params.key?(:eta_date)
          inventory.info = info
        end

        unless inventory.save
          errors << { cell_key: cell_key, messages: inventory.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.empty?
      redirect_to product_inventories_path(@product), notice: "Inventory updated successfully."
    else
      flash.now[:alert] = "Failed to save #{errors.size} #{'cell'.pluralize(errors.size)}. Check highlighted fields."
      @failed_cells = errors.map { |e| e[:cell_key] }
      @storages = current_potlift_company.storages.active.order(:storage_position, :name)

      case @product.product_type
      when "configurable" then load_configurable_inventory
      when "bundle" then load_bundle_inventory
      else load_sellable_inventory
      end

      @has_inventory = detect_has_inventory
      render :index, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /products/:product_id/inventories/:id
  # Update inventory value for a specific storage location
  def update
    authorize @inventory
    update_params = { value: inventory_params[:value] }

    # Handle ETA fields in info JSONB column
    info_updates = {}

    if inventory_params[:eta_quantity].present?
      info_updates["eta_quantity"] = inventory_params[:eta_quantity].to_i
    end

    if inventory_params.key?(:eta_date)
      info_updates["eta_date"] = inventory_params[:eta_date].present? ? inventory_params[:eta_date] : nil
    end

    if info_updates.any?
      current_info = @inventory.info || {}
      update_params[:info] = current_info.merge(info_updates)
    end

    if @inventory.update(update_params)
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

  # Load inventory for sellable products (storages as rows)
  def load_sellable_inventory
    @inventories = @product.inventories
      .includes(:storage)
      .order("storages.storage_position ASC, storages.name ASC")
  end

  # Load inventory matrix for configurable products (variants × storages)
  def load_configurable_inventory
    @subproducts = @product.subproducts
      .includes(:product_configurations_as_sub)
      .order(:sku)

    subproduct_ids = @subproducts.map(&:id)

    # Build lookup hash: { [product_id, storage_id] => inventory } — O(1) cell access
    @inventory_matrix = Inventory
      .where(product_id: subproduct_ids)
      .includes(:storage)
      .index_by { |inv| [ inv.product_id, inv.storage_id ] }
  end

  # Load bundle inventory (read-only calculated values)
  def load_bundle_inventory
    @bundle_breakdown = BundleInventoryCalculator.new(@product).detailed_breakdown
  end

  # Detect whether the product (or its subproducts) has any inventory
  def detect_has_inventory
    if @product.product_type_configurable?
      subproduct_ids = @subproducts&.map(&:id) || []
      subproduct_ids.any? && Inventory.where(product_id: subproduct_ids).exists?
    else
      @product.inventories.exists?
    end
  end

  # Return set of valid product IDs that can be updated via batch_update
  def allowed_product_ids
    if @product.product_type_configurable?
      @product.subproducts.pluck(:id).to_set
    else
      Set[ @product.id ]
    end
  end
end
