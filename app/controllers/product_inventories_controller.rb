class ProductInventoriesController < ApplicationController
  before_action :set_product
  before_action :set_inventory, only: [ :update ]

  def index
    authorize :product_inventory, :index?
    @all_storages = current_potlift_company.storages.active.order(:storage_position, :name)

    case @product.product_type
    when "configurable"
      load_configurable_inventory
    when "bundle"
      load_bundle_inventory
    else
      load_sellable_inventory
    end

    @has_inventory = detect_has_inventory

    if @has_inventory
      @storages = storages_with_inventory
    else
      @storages = @all_storages
    end
  end

  def batch_update
    authorize :product_inventory, :batch_update?

    inventories_params = params[:inventories]&.to_unsafe_h || {}

    if inventories_params.empty?
      redirect_to product_inventories_path(@product), alert: "No inventory data provided."
      return
    end

    valid_product_ids = allowed_product_ids
    valid_storage_ids = current_potlift_company.storages.active.pluck(:id).to_set

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
      @all_storages = current_potlift_company.storages.active.order(:storage_position, :name)

      case @product.product_type
      when "configurable" then load_configurable_inventory
      when "bundle" then load_bundle_inventory
      else load_sellable_inventory
      end

      @has_inventory = detect_has_inventory
      @storages = @has_inventory ? storages_with_inventory : @all_storages
      render :index, status: :unprocessable_entity
    end
  end

  def update
    authorize @inventory
    update_params = { value: inventory_params[:value] }

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

  def load_sellable_inventory
    @inventories = @product.inventories
      .includes(:storage)
      .order("storages.storage_position ASC, storages.name ASC")
  end

  def load_configurable_inventory
    @subproducts = @product.subproducts
      .includes(:product_configurations_as_sub)
      .order(:sku)

    subproduct_ids = @subproducts.map(&:id)

    @inventory_matrix = Inventory
      .where(product_id: subproduct_ids)
      .includes(:storage)
      .index_by { |inv| [ inv.product_id, inv.storage_id ] }
  end

  def load_bundle_inventory
    @bundle_breakdown = BundleInventoryCalculator.new(@product).detailed_breakdown
  end

  def detect_has_inventory
    if @product.product_type_configurable?
      subproduct_ids = @subproducts&.map(&:id) || []
      subproduct_ids.any? && Inventory.where(product_id: subproduct_ids).exists?
    else
      @product.inventories.exists?
    end
  end

  def storages_with_inventory
    product_ids = if @product.product_type_configurable?
                    @subproducts&.map(&:id) || @product.subproducts.pluck(:id)
                  else
                    [ @product.id ]
                  end

    storage_ids = Inventory.where(product_id: product_ids).distinct.pluck(:storage_id)
    @all_storages.where(id: storage_ids)
  end

  def allowed_product_ids
    if @product.product_type_configurable?
      @product.subproducts.pluck(:id).to_set
    else
      Set[ @product.id ]
    end
  end
end
