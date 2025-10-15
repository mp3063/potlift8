# frozen_string_literal: true

# Controller for managing product configurations (e.g., Size, Color)
# Configurations define the axes of variation for configurable products
class ConfigurationsController < ApplicationController
  before_action :set_product
  before_action :set_configuration, only: [:edit, :update, :destroy]

  # GET /products/:product_id/configurations
  def index
    @configurations = @product.configurations
                              .includes(:configuration_values)
                              .order(:position)
  end

  # GET /products/:product_id/configurations/new
  def new
    @configuration = @product.configurations.build
    @configuration.configuration_values.build # For nested form
  end

  # POST /products/:product_id/configurations
  def create
    @configuration = @product.configurations.build(configuration_params)
    @configuration.company = current_potlift_company

    if @configuration.save
      redirect_to product_configurations_path(@product),
                  notice: "Configuration created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /products/:product_id/configurations/:id/edit
  def edit
  end

  # PATCH/PUT /products/:product_id/configurations/:id
  def update
    if @configuration.update(configuration_params)
      redirect_to product_configurations_path(@product),
                  notice: "Configuration updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /products/:product_id/configurations/:id
  def destroy
    # Prevent deletion if variants exist
    if @product.product_configurations_as_super.any?
      redirect_to product_configurations_path(@product),
                  alert: "Cannot delete configuration with existing variants."
      return
    end

    @configuration.destroy
    redirect_to product_configurations_path(@product),
                notice: "Configuration deleted successfully."
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_configuration
    @configuration = @product.configurations.find(params[:id])
  end

  def configuration_params
    params.require(:configuration).permit(
      :name,
      :code,
      :position,
      configuration_values_attributes: [:id, :value, :position, :_destroy]
    )
  end
end
