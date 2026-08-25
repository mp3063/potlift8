class PricesController < ApplicationController
  before_action :set_product
  before_action :set_price, only: [ :edit, :update, :destroy ]
  before_action :load_customer_groups, only: [ :new, :create, :edit, :update ]

  def index
    authorize Price, :index?
    @base_price = @product.prices.base_prices.first
    @special_prices = @product.prices.special_prices.order(:valid_from)
    @customer_group_prices = @product.prices.group_prices.includes(:customer_group)
                            .order("customer_groups.name")
  end

  def new
    authorize Price, :new?
    @price = @product.prices.build(
      price_type: params[:price_type] || "base",
      currency: "EUR"
    )
  end

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

  def edit
    authorize @price
  end

  def update
    authorize @price
    if @price.update(price_params)
      redirect_to product_prices_path(@product),
                  notice: "Price updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @price
    @price.destroy
    redirect_to product_prices_path(@product),
                notice: "Price deleted successfully."
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_price
    @price = @product.prices.find(params[:id])
  end

  def load_customer_groups
    @customer_groups = current_potlift_company.customer_groups.order(:name)
  end

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
