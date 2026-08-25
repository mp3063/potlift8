class CustomerGroupsController < ApplicationController
  before_action :set_customer_group, only: [ :show, :edit, :update, :destroy ]

  def index
    authorize CustomerGroup

    @pagy, @customer_groups = pagy(
      current_potlift_company.customer_groups.order(:name),
      items: 20
    )
  end

  def show
    authorize @customer_group

    @products_count = @customer_group.prices.count
  end

  def new
    authorize CustomerGroup

    @customer_group = current_potlift_company.customer_groups.build
  end

  def create
    authorize CustomerGroup

    @customer_group = current_potlift_company.customer_groups.build(customer_group_params)

    if @customer_group.save
      redirect_to customer_groups_path,
                  notice: "Customer group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer_group
  end

  def update
    authorize @customer_group

    if @customer_group.update(customer_group_params)
      redirect_to customer_groups_path,
                  notice: "Customer group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer_group

    if @customer_group.prices.any?
      redirect_to customer_groups_path,
                  alert: "Cannot delete customer group with existing prices."
      return
    end

    @customer_group.destroy
    redirect_to customer_groups_path,
                notice: "Customer group deleted successfully."
  end

  private

  def set_customer_group
    @customer_group = current_potlift_company.customer_groups.find(params[:id])
  end

  def customer_group_params
    params.require(:customer_group).permit(
      :name,
      :code,
      :discount_percent
    )
  end
end
