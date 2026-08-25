class LabelsController < ApplicationController
  before_action :set_label, only: [ :edit, :update, :destroy ]

  def index
    authorize Label

    if params[:parent_id].present?
      @parent_label = current_potlift_company.labels.find(params[:parent_id])
      @labels = @parent_label.sublabels.with_sublabels_tree
    else
      @parent_label = nil
      @labels = current_potlift_company.labels.root_labels.with_sublabels_tree
    end

    if params[:q].present?
      search_term = "%#{params[:q]}%"
      @labels = @labels.where("name ILIKE ? OR code ILIKE ?", search_term, search_term)
    end

    respond_to do |format|
      format.html do
        @pagy, @labels = pagy(@labels, items: params[:per_page] || 25)
      end

      format.turbo_stream do
        @pagy, @labels = pagy(@labels, items: params[:per_page] || 25)
      end
    end
  end

  def show
    # Eager load label with associations to prevent N+1 queries
    @label = current_potlift_company.labels
                                    .includes(sublabels: [ :products, :sublabels ])
                                    .find_by!(full_code: params[:id])
    authorize @label

    @sublabels = @label.sublabels

    @products = @label.products.includes(:labels, :inventories)
    @pagy, @products = pagy(@products, items: params[:per_page] || 25)
  rescue ActiveRecord::RecordNotFound
    @label = current_potlift_company.labels
                                    .includes(sublabels: [ :products, :sublabels ])
                                    .find(params[:id])
    authorize @label
    @sublabels = @label.sublabels
    @products = @label.products.includes(:labels, :inventories)
    @pagy, @products = pagy(@products, items: params[:per_page] || 25)
  end

  def new
    authorize Label

    @label = current_potlift_company.labels.build

    if params[:parent_id].present?
      @parent_label = current_potlift_company.labels.find(params[:parent_id])
      @label.parent_label = @parent_label
    end
  end

  def edit
    authorize @label

    @parent_label = @label.parent_label if @label.parent_label_id.present?
  end

  def create
    authorize Label

    @label = current_potlift_company.labels.build(label_params)

    begin
      if @label.save
        @label = current_potlift_company.labels
                                        .includes(:products, :parent_label, sublabels: [ :products, :sublabels ])
                                        .find(@label.id)

        if @label.parent_label_id.present?
          @label.parent_label.reload
          @label.parent_label = current_potlift_company.labels
                                                       .includes(:products, sublabels: [ :products, :sublabels ])
                                                       .find(@label.parent_label_id)
        end

        respond_to do |format|
          format.html do
            redirect_to labels_path(parent_id: @label.parent_label_id),
                        notice: "Label '#{@label.name}' created successfully."
          end
          format.turbo_stream do
            render :create
          end
        end
      else
        @parent_label = @label.parent_label if @label.parent_label_id.present?
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream { render :new, status: :unprocessable_entity }
        end
      end
    rescue ActiveRecord::RecordNotUnique
      @label.errors.add(:full_code, "has already been taken")
      @parent_label = @label.parent_label if @label.parent_label_id.present?
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    authorize @label

    if @label.update(label_params)
      needs_cascade = @label.previous_changes.key?("parent_label_id") ||
                      @label.previous_changes.key?("code") ||
                      @label.previous_changes.key?("name")
      @label.sublabels.each(&:update_label_and_children) if needs_cascade && @label.sublabels.any?

      redirect_to labels_path(parent_id: @label.parent_label_id),
                  notice: "Label '#{@label.name}' updated successfully.",
                  status: :see_other
    else
      @parent_label = @label.parent_label if @label.parent_label_id.present?
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # Validation:
  # - Prevents deletion if label has sublabels
  # - Prevents deletion if label has associated products
  def destroy
    authorize @label

    if @label.sublabels.any?
      @error_message = "Cannot delete label '#{@label.name}' because it has #{@label.sublabels.count} sublabel(s). Please delete sublabels first."

      respond_to do |format|
        format.html do
          redirect_to labels_path(parent_id: @label.parent_label_id),
                      alert: @error_message
        end
        format.turbo_stream do
          render :destroy_error_sublabels
        end
      end
      return
    end

    if @label.products.any?
      @error_message = "Cannot delete label '#{@label.name}' because it is assigned to #{@label.products.count} product(s). Please remove products first."

      respond_to do |format|
        format.html do
          redirect_to labels_path(parent_id: @label.parent_label_id),
                      alert: @error_message
        end
        format.turbo_stream do
          render :destroy_error_products
        end
      end
      return
    end

    @label_id = @label.id
    @parent_label_id = @label.parent_label_id
    @label_name = @label.name

    @parent_should_update = false
    if @parent_label_id.present?
      parent_label = current_potlift_company.labels.find(@parent_label_id)
      @parent_should_update = parent_label.sublabels.count == 1
    end

    @label.destroy

    # Reload parent with associations if needed for turbo stream update
    if @parent_should_update
      @parent_label = current_potlift_company.labels
                                             .includes(:products, sublabels: [ :products, :sublabels ])
                                             .find(@parent_label_id)
    end

    respond_to do |format|
      format.html do
        redirect_to labels_path(parent_id: @parent_label_id),
                    notice: "Label '#{@label_name}' deleted successfully."
      end
      format.turbo_stream do
        render :destroy
      end
    end
  end

  def reorder
    authorize Label

    order_array = params[:order]
    parent_id = params[:parent_id]

    if order_array.blank? || !order_array.is_a?(Array)
      respond_to do |format|
        format.json do
          render json: { success: false, message: "Invalid order array" },
                 status: :unprocessable_entity
        end
        format.turbo_stream do
          flash.now[:alert] = "Invalid order array"
          render :index, status: :unprocessable_entity
        end
      end
      return
    end

    if parent_id.present?
      parent_label = current_potlift_company.labels.find(parent_id)
      labels = parent_label.sublabels.where(id: order_array)
    else
      labels = current_potlift_company.labels.root_labels.where(id: order_array)
    end

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
          render json: { success: true, message: "Labels reordered successfully" },
                 status: :ok
        end
        format.turbo_stream do
          flash.now[:notice] = "Labels reordered successfully"
        end
      end
    else
      respond_to do |format|
        format.json do
          render json: { success: false, message: "Failed to reorder labels" },
                 status: :unprocessable_entity
        end
        format.turbo_stream do
          flash.now[:alert] = "Failed to reorder labels"
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_label
    @label = current_potlift_company.labels.find_by(full_code: params[:id])

    # Fall back to finding by ID if full_code lookup fails
    unless @label
      @label = current_potlift_company.labels.find(params[:id])
    end
  end

  def label_params
    params.require(:label).permit(
      :name,
      :code,
      :description,
      :label_type,
      :parent_label_id,
      :product_default_restriction,
      info: [ :color ]
    )
  end
end
