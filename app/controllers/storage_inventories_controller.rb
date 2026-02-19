# Storage Inventories Controller
#
# Manages adding products to storage locations in the Potlift8 inventory system.
# Handles bulk creation of inventory records for products not yet in a storage.
#
# Features:
# - Product selection modal for adding inventory to storage
# - Filters out products already in storage
# - Bulk inventory creation with initial quantities
# - Search and filter support for product selection
# - Turbo Stream support for dynamic updates
#
# Security:
# - All operations scoped to current company via multi-tenancy
# - Validates storage belongs to company before operations
# - Validates products belong to company before adding to inventory
#
class StorageInventoriesController < ApplicationController
  before_action :set_storage

  # GET /storages/:code/inventories/new
  # GET /storages/:code/inventories/new.turbo_stream
  #
  # Shows modal for adding products to storage.
  # Displays products not yet in this storage with search/filter capability.
  #
  # Query Parameters:
  # - search: Filter products by SKU or name
  # - product_type: Filter by product type (sellable, configurable, bundle)
  # - label_id: Filter by label
  #
  def new
    authorize :storage_inventory, :new?

    # Get all active products not already in this storage
    @available_products = current_potlift_company.products
                                                 .active_products
                                                 .where.not(id: @storage.products.select(:id))
                                                 .order(:sku)

    # Apply search filter if provided
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @available_products = @available_products.where(
        "sku ILIKE ? OR name ILIKE ?",
        search_term,
        search_term
      )
    end

    # Apply product type filter if provided
    if params[:product_type].present?
      @available_products = @available_products.where(
        product_type: params[:product_type]
      )
    end

    # Apply label filter if provided
    if params[:label_id].present?
      @available_products = @available_products.joins(:product_labels)
                                               .where(product_labels: { label_id: params[:label_id] })
    end

    # Limit results for performance (paginate if needed)
    @available_products = @available_products.limit(100)

    # Load labels for filtering dropdown
    @labels = current_potlift_company.labels.order(:name)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # POST /storages/:code/inventories
  # POST /storages/:code/inventories.turbo_stream
  #
  # Creates inventory records for selected products.
  # Handles bulk creation with initial quantities.
  #
  # Parameters:
  # - product_ids: Array of product IDs to add
  # - quantities: Hash of product_id => initial_quantity
  #
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

    # Verify all products belong to current company
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

    # Create inventory records
    created_count = 0
    failed_products = []

    products.each do |product|
      # Get quantity for this product (default to 0)
      quantity = params.dig(:quantities, product.id.to_s).to_i

      # Skip if inventory already exists
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
          redirect_to inventory_storage_path(@storage),
                      alert: "Added #{created_count} products. Failed to add: #{failed_products.join(', ')}"
        end
        format.turbo_stream do
          flash.now[:alert] = "Added #{created_count} products. Failed to add: #{failed_products.join(', ')}"
          # Template will close modal and show flash
        end
      end
    else
      respond_to do |format|
        format.html do
          redirect_to inventory_storage_path(@storage),
                      notice: "Successfully added #{created_count} #{'product'.pluralize(created_count)} to #{@storage.name}."
        end
        format.turbo_stream do
          flash.now[:notice] = "Successfully added #{created_count} #{'product'.pluralize(created_count)} to #{@storage.name}."
          # Template will close modal and show flash
        end
      end
    end
  end

  private

  # Set the storage for all actions
  # Uses code as parameter (via to_param)
  # Ensures storage belongs to current company
  # Raises ActiveRecord::RecordNotFound if storage not found or doesn't belong to company
  def set_storage
    @storage = current_potlift_company.storages.find_by!(code: params[:storage_code])
  end

  # Set available products and labels for rendering the new form
  # Used by create action when re-rendering form after validation errors
  def set_available_products_and_labels
    @available_products = current_potlift_company.products
                                                 .active_products
                                                 .where.not(id: @storage.products.select(:id))
                                                 .order(:sku)
                                                 .limit(100)
    @labels = current_potlift_company.labels.order(:name)
  end
end
