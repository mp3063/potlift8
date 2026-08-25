# frozen_string_literal: true

class RelatedProductsController < ApplicationController
  before_action :set_product
  before_action :set_related_product, only: [ :destroy ]

  def index
    authorize :related_product, :index?
    @related_products_by_type = RelatedProduct.relation_types.keys.index_with do |relation_type|
      @product.related_products
              .where(relation_type: relation_type)
              .includes(:related_to)
              .order(:position)
    end

    @available_products = current_potlift_company.products
                                                  .where.not(id: @product.id)
                                                  .order(:name)
  end

  def create
    authorize :related_product, :create?
    @related_product = @product.related_products.build(related_product_params)

    if @related_product.save
      redirect_to product_related_products_path(@product),
                  notice: "Related product added successfully."
    else
      redirect_to product_related_products_path(@product),
                  alert: @related_product.errors.full_messages.join(", ")
    end
  end

  def destroy
    authorize :related_product, :destroy?
    @related_product.destroy
    redirect_to product_related_products_path(@product),
                notice: "Related product removed."
  end

  def reorder
    authorize :related_product, :reorder?
    params[:order].each_with_index do |id, index|
      @product.related_products.find(id).update(position: index + 1)
    end

    head :ok
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_related_product
    @related_product = @product.related_products.find(params[:id])
  end

  def related_product_params
    params.require(:related_product).permit(:related_to_id, :relation_type)
  end
end
