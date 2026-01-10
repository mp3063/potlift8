# CustomerGroupsController
#
# Manages customer groups for group-based pricing.
# All customer groups are scoped to the current company.
#
# Routes:
# - GET    /customer_groups           - List all groups
# - GET    /customer_groups/new       - New group form
# - POST   /customer_groups           - Create group
# - GET    /customer_groups/:id       - Show group details
# - GET    /customer_groups/:id/edit  - Edit group form
# - PATCH  /customer_groups/:id       - Update group
# - DELETE /customer_groups/:id       - Delete group
#
class CustomerGroupsController < ApplicationController
  before_action :set_customer_group, only: [ :show, :edit, :update, :destroy ]

  # List all customer groups
  #
  # GET /customer_groups
  #
  def index
    @pagy, @customer_groups = pagy(
      current_potlift_company.customer_groups.order(:name),
      items: 20
    )
  end

  # Show customer group details
  #
  # GET /customer_groups/:id
  #
  def show
    @products_count = @customer_group.prices.count
  end

  # New customer group form
  #
  # GET /customer_groups/new
  #
  def new
    @customer_group = current_potlift_company.customer_groups.build
  end

  # Create new customer group
  #
  # POST /customer_groups
  #
  def create
    @customer_group = current_potlift_company.customer_groups.build(customer_group_params)

    if @customer_group.save
      redirect_to customer_groups_path,
                  notice: "Customer group created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Edit customer group form
  #
  # GET /customer_groups/:id/edit
  #
  def edit
  end

  # Update customer group
  #
  # PATCH /customer_groups/:id
  #
  def update
    if @customer_group.update(customer_group_params)
      redirect_to customer_groups_path,
                  notice: "Customer group updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # Delete customer group
  #
  # DELETE /customer_groups/:id
  #
  def destroy
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

  # Set customer group from params
  def set_customer_group
    @customer_group = current_potlift_company.customer_groups.find(params[:id])
  end

  # Strong parameters
  def customer_group_params
    params.require(:customer_group).permit(
      :name,
      :code,
      :discount_percent
    )
  end
end
