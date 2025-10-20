# Labels Controller
#
# Manages CRUD operations for hierarchical labels in the Potlift8 inventory system.
# All operations are scoped to the current company via multi-tenancy.
#
# Features:
# - Full CRUD operations (index, show, new, create, edit, update, destroy)
# - Hierarchical navigation (root labels and sublabels)
# - Label reordering within parent context
# - Product association management
# - Pagination with Pagy (25 items per page by default)
# - Turbo Stream support for dynamic updates
#
# Label Structure:
# - Root labels: parent_label_id = nil
# - Child labels: parent_label_id references parent
# - Ordering: label_positions field (integer)
#
class LabelsController < ApplicationController
  before_action :set_label, only: [:edit, :update, :destroy]

  # GET /labels
  # GET /labels.turbo_stream
  #
  # Lists root labels (parent_label_id = nil) by default.
  # If parent_id is provided, lists sublabels of that parent.
  #
  # Query Parameters:
  # - page: Page number (default: 1)
  # - per_page: Items per page (default: 25)
  # - parent_id: Parent label ID (optional, defaults to root labels)
  # - q: Search query (matches name or code)
  #
  def index
    # Load labels based on parent context with eager loading
    if params[:parent_id].present?
      @parent_label = current_potlift_company.labels.find(params[:parent_id])
      @labels = @parent_label.sublabels.with_sublabels_tree
    else
      @parent_label = nil
      @labels = current_potlift_company.labels.root_labels.with_sublabels_tree
    end

    # Apply search filter
    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @labels = @labels.where("name ILIKE ? OR code ILIKE ?", search_term, search_term)
    end

    # Paginate results
    respond_to do |format|
      format.html do
        @pagy, @labels = pagy(@labels, items: params[:per_page] || 25)
      end

      format.turbo_stream do
        @pagy, @labels = pagy(@labels, items: params[:per_page] || 25)
      end
    end
  end

  # GET /labels/:id
  #
  # Shows detailed label information including:
  # - Label details
  # - Sublabels (hierarchical children)
  # - Associated products (paginated)
  #
  def show
    # Eager load label with associations to prevent N+1 queries
    @label = current_potlift_company.labels
                                    .includes(sublabels: [:products, :sublabels])
                                    .find_by!(full_code: params[:id])

    # Load sublabels
    @sublabels = @label.sublabels

    # Load products with pagination
    @products = @label.products.includes(:labels, :inventories)
    @pagy, @products = pagy(@products, items: params[:per_page] || 25)
  rescue ActiveRecord::RecordNotFound
    # Try finding by ID if full_code lookup fails
    @label = current_potlift_company.labels
                                    .includes(sublabels: [:products, :sublabels])
                                    .find(params[:id])
    @sublabels = @label.sublabels
    @products = @label.products.includes(:labels, :inventories)
    @pagy, @products = pagy(@products, items: params[:per_page] || 25)
  end

  # GET /labels/new
  #
  # Renders form for creating a new label.
  #
  # Query Parameters:
  # - parent_id: Parent label ID (optional, for creating sublabels)
  #
  def new
    @label = current_potlift_company.labels.build

    # Set parent label if provided
    if params[:parent_id].present?
      @parent_label = current_potlift_company.labels.find(params[:parent_id])
      @label.parent_label = @parent_label
    end
  end

  # GET /labels/:id/edit
  #
  # Renders form for editing an existing label.
  #
  def edit
    # Load parent label if exists
    @parent_label = @label.parent_label if @label.parent_label_id.present?
  end

  # POST /labels
  # POST /labels.turbo_stream
  #
  # Creates a new label.
  #
  def create
    @label = current_potlift_company.labels.build(label_params)

    # Save label and handle potential database constraint violations
    begin
      if @label.save
        respond_to do |format|
          format.html do
            redirect_to labels_path(parent_id: @label.parent_label_id),
                        notice: "Label '#{@label.name}' created successfully."
          end
          format.turbo_stream { flash.now[:notice] = "Label '#{@label.name}' created successfully." }
        end
      else
        @parent_label = @label.parent_label if @label.parent_label_id.present?
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream { render :new, status: :unprocessable_entity }
        end
      end
    rescue ActiveRecord::RecordNotUnique
      # Handle unique constraint violation for full_code
      @label.errors.add(:full_code, 'has already been taken')
      @parent_label = @label.parent_label if @label.parent_label_id.present?
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  # PATCH /labels/:id
  # PUT /labels/:id
  # PATCH /labels/:id.turbo_stream
  #
  # Updates an existing label.
  #
  def update
    if @label.update(label_params)
      # If parent changed, update all children's full_code and full_name
      @label.update_label_and_children if @label.previous_changes.key?('parent_label_id')

      respond_to do |format|
        format.html do
          redirect_to labels_path(parent_id: @label.parent_label_id),
                      notice: "Label '#{@label.name}' updated successfully."
        end
        format.turbo_stream { flash.now[:notice] = "Label '#{@label.name}' updated successfully." }
      end
    else
      @parent_label = @label.parent_label if @label.parent_label_id.present?
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /labels/:id
  # DELETE /labels/:id.turbo_stream
  #
  # Destroys a label.
  #
  # Validation:
  # - Prevents deletion if label has sublabels
  # - Prevents deletion if label has associated products
  #
  def destroy
    # Check for sublabels
    if @label.sublabels.any?
      respond_to do |format|
        format.html do
          redirect_to labels_path(parent_id: @label.parent_label_id),
                      alert: "Cannot delete label '#{@label.name}' because it has #{@label.sublabels.count} sublabel(s). Please delete sublabels first."
        end
        format.turbo_stream do
          flash.now[:alert] = "Cannot delete label '#{@label.name}' because it has #{@label.sublabels.count} sublabel(s). Please delete sublabels first."
        end
      end
      return
    end

    # Check for associated products
    if @label.products.any?
      respond_to do |format|
        format.html do
          redirect_to labels_path(parent_id: @label.parent_label_id),
                      alert: "Cannot delete label '#{@label.name}' because it is assigned to #{@label.products.count} product(s). Please remove products first."
        end
        format.turbo_stream do
          flash.now[:alert] = "Cannot delete label '#{@label.name}' because it is assigned to #{@label.products.count} product(s). Please remove products first."
        end
      end
      return
    end

    # Safe to delete
    parent_id = @label.parent_label_id
    label_name = @label.name
    @label.destroy

    respond_to do |format|
      format.html do
        redirect_to labels_path(parent_id: parent_id),
                    notice: "Label '#{label_name}' deleted successfully."
      end
      format.turbo_stream { flash.now[:notice] = "Label '#{label_name}' deleted successfully." }
    end
  end

  # PATCH /labels/reorder
  # PATCH /labels/reorder.turbo_stream
  #
  # Reorders labels within a parent context.
  #
  # Parameters:
  # - order: Array of label IDs in new order [1, 3, 2, 5, 4]
  # - parent_id: Parent label ID (optional, nil for root labels)
  #
  # Response:
  # - Success: 200 OK with JSON { success: true, message: "..." }
  # - Error: 422 Unprocessable Entity with JSON { success: false, message: "..." }
  #
  def reorder
    order_array = params[:order]
    parent_id = params[:parent_id]

    if order_array.blank? || !order_array.is_a?(Array)
      respond_to do |format|
        format.json do
          render json: { success: false, message: 'Invalid order array' },
                 status: :unprocessable_entity
        end
        format.turbo_stream do
          flash.now[:alert] = 'Invalid order array'
          render :index, status: :unprocessable_entity
        end
      end
      return
    end

    # Get labels to reorder
    if parent_id.present?
      parent_label = current_potlift_company.labels.find(parent_id)
      labels = parent_label.sublabels.where(id: order_array)
    else
      labels = current_potlift_company.labels.root_labels.where(id: order_array)
    end

    # Update positions
    success = true
    Label.transaction do
      order_array.each_with_index do |label_id, index|
        label = labels.find_by(id: label_id)
        if label
          label.label_positions = index
          unless label.save
            success = false
            raise ActiveRecord::Rollback
          end
        end
      end
    end

    if success
      respond_to do |format|
        format.json do
          render json: { success: true, message: 'Labels reordered successfully' },
                 status: :ok
        end
        format.turbo_stream do
          flash.now[:notice] = 'Labels reordered successfully'
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { success: false, message: 'Failed to reorder labels' },
                 status: :unprocessable_entity
        end
        format.turbo_stream do
          flash.now[:alert] = 'Failed to reorder labels'
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  private

  # Set the label for show, edit, update, destroy actions
  # Ensures label belongs to current company
  # Raises ActiveRecord::RecordNotFound if label not found or doesn't belong to company
  def set_label
    @label = current_potlift_company.labels.find_by!(full_code: params[:id]) ||
             current_potlift_company.labels.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    # Try finding by ID if full_code lookup fails
    @label = current_potlift_company.labels.find(params[:id])
  end

  # Strong parameters for label creation/update
  def label_params
    params.require(:label).permit(
      :name,
      :code,
      :description,
      :label_type,
      :parent_label_id,
      :product_default_restriction,
      info: [:color]
    )
  end
end
