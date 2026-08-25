class ProductVersionsController < ApplicationController
  before_action :set_product
  before_action :set_version, only: [ :show, :revert ]

  def index
    authorize :product_version, :index?
    @pagy, @versions = pagy(
      @product.versions.order(created_at: :desc),
      items: 20
    )
  end

  def show
    authorize :product_version, :show?
    @previous_version = @product.versions
                                .where("id < ?", @version.id)
                                .order(id: :desc)
                                .first

    @changes = calculate_changes(@previous_version, @version)
  end

  def compare
    authorize :product_version, :compare?
    @versions = @product.versions.order(created_at: :desc)
    @from_version = @product.versions.find(params[:version1_id])
    @to_version = @product.versions.find(params[:version2_id])

    @changes = calculate_changes(@from_version, @to_version)
  end

  def revert
    authorize :product_version, :revert?
    reified_product = @version.reify

    unless reified_product
      redirect_to product_versions_path(@product),
                  alert: "Cannot revert to this version."
      return
    end

    if @product.update(reified_product.attributes.except("id", "created_at"))
      redirect_to product_path(@product),
                  notice: "Product reverted to version from #{@version.created_at.strftime('%Y-%m-%d %H:%M')}"
    else
      redirect_to product_versions_path(@product),
                  alert: "Failed to revert product."
    end
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  def set_version
    @version = @product.versions.find(params[:id])
  end

  def calculate_changes(old_version, new_version)
    changes = {}

    new_object = new_version.reify || @product
    old_object = old_version&.reify

    return {} unless old_object

    comparable_attributes.each do |attr|
      old_value = old_object.send(attr)
      new_value = new_object.send(attr)

      next if old_value == new_value

      changes[attr] = [ old_value, new_value ]
    end

    changes
  end

  def comparable_attributes
    [
      :sku,
      :name,
      :ean,
      :product_type,
      :product_status,
      :configuration_type,
      :info,
      :structure,
      :cache
    ]
  end
end
