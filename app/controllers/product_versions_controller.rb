# ProductVersionsController
#
# Handles product version history and audit trail using PaperTrail.
# Allows viewing changes, comparing versions, and reverting to previous states.
#
# Routes (nested under products):
# - GET  /products/:product_id/versions        - List all versions
# - GET  /products/:product_id/versions/:id    - Show version details
# - GET  /products/:product_id/versions/compare - Compare two versions
# - POST /products/:product_id/versions/:id/revert - Revert to version
#
class ProductVersionsController < ApplicationController
  before_action :set_product
  before_action :set_version, only: [ :show, :revert ]

  # List all versions for product
  #
  # GET /products/:product_id/versions
  #
  def index
    @pagy, @versions = pagy(
      @product.versions.order(created_at: :desc),
      items: 20
    )
  end

  # Show version details with diff from previous version
  #
  # GET /products/:product_id/versions/:id
  #
  def show
    @previous_version = @product.versions
                                .where("id < ?", @version.id)
                                .order(id: :desc)
                                .first

    @changes = calculate_changes(@previous_version, @version)
  end

  # Compare two versions
  #
  # GET /products/:product_id/versions/compare?version1_id=1&version2_id=2
  #
  def compare
    @version1 = @product.versions.find(params[:version1_id])
    @version2 = @product.versions.find(params[:version2_id])

    @changes = calculate_changes(@version1, @version2)
  end

  # Revert product to a specific version
  #
  # POST /products/:product_id/versions/:id/revert
  #
  def revert
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

  # Set product from params
  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end

  # Set version from params
  def set_version
    @version = @product.versions.find(params[:id])
  end

  # Calculate changes between two versions
  #
  # @param old_version [PaperTrail::Version, nil] Previous version
  # @param new_version [PaperTrail::Version] Current version
  # @return [Hash] Hash of changed attributes with old and new values
  #
  def calculate_changes(old_version, new_version)
    changes = {}

    # Get object data from versions
    new_object = new_version.reify || @product
    old_object = old_version&.reify

    return {} unless old_object

    # Compare attributes
    comparable_attributes.each do |attr|
      old_value = old_object.send(attr)
      new_value = new_object.send(attr)

      next if old_value == new_value

      changes[attr] = {
        old: old_value,
        new: new_value,
        changed: true
      }
    end

    changes
  end

  # List of attributes to compare between versions
  #
  # @return [Array<Symbol>] Attribute names
  #
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
