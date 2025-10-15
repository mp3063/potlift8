# frozen_string_literal: true

# Controller for managing product variants
# Uses ProductConfiguration under the hood but presents as "variants" for UI/UX
# A variant is a sellable product linked to a configurable product with specific configuration values
class VariantsController < ApplicationController
  before_action :set_product
  before_action :set_variant, only: [:edit, :update, :destroy]

  # GET /products/:product_id/variants
  def index
    # Load ProductConfigurations as "variants"
    @variants = @product.product_configurations_as_super
                        .includes(subproduct: :inventories)
                        .order(:configuration_position)

    @configurations = @product.configurations.order(:position)
  end

  # GET /products/:product_id/variants/new
  def new
    # Build new variant through ProductConfiguration
    @variant_product = @product.company.products.build(product_type: :sellable)
    @configurations = @product.configurations.includes(:configuration_values).order(:position)
  end

  # POST /products/:product_id/variants
  def create
    @variant_product = @product.company.products.build(variant_product_params)
    @variant_product.product_type = :sellable

    ActiveRecord::Base.transaction do
      @variant_product.save!

      # Create ProductConfiguration link
      variant_config = build_variant_config
      @product.product_configurations_as_super.create!(
        subproduct: @variant_product,
        info: { variant_config: variant_config }
      )

      redirect_to product_variants_path(@product),
                  notice: "Variant created successfully."
    end
  rescue ActiveRecord::RecordInvalid => e
    @configurations = @product.configurations.includes(:configuration_values).order(:position)
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  # POST /products/:product_id/variants/generate
  def generate
    # Generate all variant combinations
    service = VariantGeneratorService.new(@product)
    count = service.generate!

    if service.errors.any?
      redirect_to product_variants_path(@product),
                  alert: "Errors: #{service.errors.join(', ')}"
    else
      redirect_to product_variants_path(@product),
                  notice: "Generated #{count} variants successfully."
    end
  end

  # GET /products/:product_id/variants/:id/edit
  def edit
    @variant_product = @variant.subproduct
    @configurations = @product.configurations.includes(:configuration_values).order(:position)
  end

  # PATCH/PUT /products/:product_id/variants/:id
  def update
    ActiveRecord::Base.transaction do
      @variant.subproduct.update!(variant_product_params)

      # Update variant config
      variant_config = build_variant_config
      @variant.update!(info: @variant.info.merge(variant_config: variant_config))

      redirect_to product_variants_path(@product),
                  notice: "Variant updated successfully."
    end
  rescue ActiveRecord::RecordInvalid => e
    @variant_product = @variant.subproduct
    @configurations = @product.configurations.includes(:configuration_values).order(:position)
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_entity
  end

  # DELETE /products/:product_id/variants/:id
  def destroy
    @variant.subproduct.destroy # Cascades to ProductConfiguration
    redirect_to product_variants_path(@product),
                notice: "Variant deleted successfully."
  end

  # POST /products/:product_id/variants/reorder
  def reorder
    params[:order].each_with_index do |id, index|
      ProductConfiguration.find(id).update(configuration_position: index + 1)
    end

    head :ok
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_variant
    @variant = @product.product_configurations_as_super.find(params[:id])
  end

  def variant_product_params
    params.require(:variant_product).permit(:sku, :name, :description)
  end

  def build_variant_config
    config = {}
    @product.configurations.each do |configuration|
      value_id = params.dig(:variant_config, configuration.code.to_sym)
      next unless value_id.present?

      value = configuration.configuration_values.find_by(id: value_id)
      config[configuration.code] = value.value if value
    end
    config
  end
end
