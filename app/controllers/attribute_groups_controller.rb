# frozen_string_literal: true

class AttributeGroupsController < ApplicationController
  before_action :set_attribute_group, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize AttributeGroup

    @attribute_groups = current_potlift_company.attribute_groups
      .includes(:product_attributes)
      .order(:position)
  end

  def show
    authorize @attribute_group

    @product_attributes = @attribute_group.product_attributes.order(:attribute_position)
  end

  def new
    authorize AttributeGroup

    @attribute_group = current_potlift_company.attribute_groups.build
  end

  def edit
    authorize @attribute_group
  end

  def create
    authorize AttributeGroup

    @attribute_group = current_potlift_company.attribute_groups.build(attribute_group_params)

    if @attribute_group.save
      redirect_to product_attributes_path, notice: "Attribute group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @attribute_group

    if @attribute_group.update(attribute_group_params)
      redirect_to product_attributes_path, notice: "Attribute group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @attribute_group

    if @attribute_group.product_attributes.any?
      redirect_to product_attributes_path, alert: "Cannot delete group with attributes. Move or delete attributes first."
    else
      @attribute_group.destroy
      redirect_to product_attributes_path, notice: "Attribute group deleted successfully."
    end
  end

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
