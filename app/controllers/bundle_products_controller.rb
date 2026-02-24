# frozen_string_literal: true

# Controller for managing bundle product components
# Uses ProductConfiguration under the hood but presents as "bundle_products" for UI/UX
# A bundle product is a product composed of multiple subproducts with quantities
class BundleProductsController < ApplicationController
  before_action :set_product
  before_action :set_bundle_product, only: [ :update, :destroy ]

  # GET /products/:product_id/bundle_products
  def index
    authorize :bundle_product, :index?

    # Load ProductConfigurations as "bundle_products"
    @bundle_products = @product.product_configurations_as_super
                               .includes(subproduct: :inventories)
                               .order(:configuration_position)

    # Available products (not already in bundle)
    @available_products = current_potlift_company.products
                                                  .where(product_type: [ :sellable, :configurable ])
                                                  .where.not(id: [ @product.id ] + @bundle_products.pluck(:subproduct_id))
                                                  .order(:name)
  end

  # POST /products/:product_id/bundle_products
  def create
    authorize :bundle_product, :create?

    @bundle_product = @product.product_configurations_as_super.build(bundle_product_params)

    if @bundle_product.save
      respond_to do |format|
        format.html {
          redirect_to product_bundle_products_path(@product),
                      notice: "Product added to bundle."
        }
        format.turbo_stream
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /products/:product_id/bundle_products/:id
  def update
    authorize :bundle_product, :update?

    if @bundle_product.update(bundle_product_params)
      respond_to do |format|
        format.html {
          redirect_to product_bundle_products_path(@product),
                      notice: "Quantity updated."
        }
        format.turbo_stream
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /products/:product_id/bundle_products/:id
  def destroy
    authorize :bundle_product, :destroy?

    @bundle_product.destroy
    redirect_to product_bundle_products_path(@product),
                notice: "Product removed from bundle."
  end

  # POST /products/:product_id/bundle_products/reorder
  def reorder
    authorize :bundle_product, :reorder?

    params[:order].each_with_index do |id, index|
      @product.product_configurations_as_super.find(id).update(configuration_position: index + 1)
    end

    head :ok
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_bundle_product
    @bundle_product = @product.product_configurations_as_super.find(params[:id])
  end

  def bundle_product_params
    params.require(:bundle_product).permit(:subproduct_id, :quantity)
  end
end
