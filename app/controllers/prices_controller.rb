# PricesController
#
# Manages product pricing including base prices, special pricing, and customer group pricing.
# All prices are scoped to the current company through the product association.
#
# Routes (nested under products):
# - GET    /products/:product_id/prices        - List all prices
# - GET    /products/:product_id/prices/new    - New price form
# - POST   /products/:product_id/prices        - Create price
# - GET    /products/:product_id/prices/:id/edit - Edit price form
# - PATCH  /products/:product_id/prices/:id    - Update price
# - DELETE /products/:product_id/prices/:id    - Delete price
#
class PricesController < ApplicationController
  before_action :set_product
  before_action :set_price, only: [ :edit, :update, :destroy ]
  before_action :load_customer_groups, only: [ :new, :create, :edit, :update ]

  # List all prices for product
  #
  # GET /products/:product_id/prices
  #
  def index
    authorize Price, :index?
    @base_price = @product.prices.base_prices.first
    @special_prices = @product.prices.special_prices.order(:valid_from)
    @customer_group_prices = @product.prices.group_prices.includes(:customer_group)
                            .order("customer_groups.name")
  end

  # New price form
  #
  # GET /products/:product_id/prices/new?price_type=base
  #
  def new
    authorize Price, :new?
    @price = @product.prices.build(
      price_type: params[:price_type] || "base",
      currency: "EUR"
    )
  end

  # Create new price
  #
  # POST /products/:product_id/prices
  #
  def create
    authorize Price, :create?
    @price = @product.prices.build(price_params)

    if @price.save
      redirect_to product_prices_path(@product),
                  notice: "Price created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Edit price form
  #
  # GET /products/:product_id/prices/:id/edit
  #
  def edit
    authorize @price
  end

  # Update price
  #
  # PATCH /products/:product_id/prices/:id
  #
  def update
    authorize @price
    if @price.update(price_params)
      redirect_to product_prices_path(@product),
                  notice: "Price updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Delete price
  #
  # DELETE /products/:product_id/prices/:id
  #
  def destroy
    authorize @price
    @price.destroy
    redirect_to product_prices_path(@product),
                notice: "Price deleted successfully."
  end

  private

  # Set product from params
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  # Set price from params
  def set_price
    @price = @product.prices.find(params[:id])
  end

  # Load customer groups for dropdowns
  def load_customer_groups
    @customer_groups = current_potlift_company.customer_groups.order(:name)
  end

  # Strong parameters
  def price_params
    params.require(:price).permit(
      :value,
      :currency,
      :price_type,
      :customer_group_id,
      :valid_from,
      :valid_to
    )
  end
end
