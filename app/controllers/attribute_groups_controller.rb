# frozen_string_literal: true

# AttributeGroupsController
#
# Manages CRUD operations for AttributeGroups with drag-and-drop reordering.
#
# Key Features:
# - Group creation and editing
# - Drag-and-drop position management
# - Scoped to current_potlift_company
#
class AttributeGroupsController < ApplicationController
  before_action :set_attribute_group, only: [ :show, :edit, :update, :destroy ]

  # GET /attribute_groups
  def index
    authorize AttributeGroup

    @attribute_groups = current_potlift_company.attribute_groups
      .includes(:product_attributes)
      .order(:position)
  end

  # GET /attribute_groups/:code
  def show
    authorize @attribute_group

    @product_attributes = @attribute_group.product_attributes.order(:attribute_position)
  end

  # GET /attribute_groups/new
  def new
    authorize AttributeGroup

    @attribute_group = current_potlift_company.attribute_groups.build
  end

  # GET /attribute_groups/:code/edit
  def edit
    authorize @attribute_group
  end

  # POST /attribute_groups
  def create
    authorize AttributeGroup

    @attribute_group = current_potlift_company.attribute_groups.build(attribute_group_params)

    if @attribute_group.save
      redirect_to product_attributes_path, notice: "Attribute group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH /attribute_groups/:code
  def update
    authorize @attribute_group

    if @attribute_group.update(attribute_group_params)
      redirect_to product_attributes_path, notice: "Attribute group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /attribute_groups/:code
  def destroy
    authorize @attribute_group

    if @attribute_group.product_attributes.any?
      redirect_to product_attributes_path, alert: "Cannot delete group with attributes. Move or delete attributes first."
    else
      @attribute_group.destroy
      redirect_to product_attributes_path, notice: "Attribute group deleted successfully."
    end
  end

  # PATCH /attribute_groups/reorder
  # Updates group positions
  def reorder
    authorize AttributeGroup

    params[:order].each_with_index do |id, index|
      group = current_potlift_company.attribute_groups.find(id)
      group.update_column(:position, index + 1)
    end

    head :ok
  end

  private

  def set_attribute_group
    @attribute_group = current_potlift_company.attribute_groups.find_by!(code: params[:id])
  end

  def attribute_group_params
    params.require(:attribute_group).permit(
      :name,
      :code,
      :description
    )
  end
end
