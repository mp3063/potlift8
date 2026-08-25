class ProductLabelsController < ApplicationController
  before_action :set_product

  def create
    authorize :product_label, :create?
    label_id = params[:label_id]

    if label_id.blank?
      respond_to do |format|
        format.html { redirect_to @product, alert: "Please select a label." }
        format.turbo_stream { flash.now[:alert] = "Please select a label." }
        format.json { render json: { error: "Please select a label." }, status: :bad_request }
      end
      return
    end

    label = current_potlift_company.labels.find_by(id: label_id)

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label not found." }
        format.turbo_stream { flash.now[:alert] = "Label not found." }
        format.json { render json: { error: "Label not found." }, status: :not_found }
      end
      return
    end

    if @product.labels.include?(label)
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label already assigned to this product." }
        format.turbo_stream { flash.now[:alert] = "Label already assigned to this product." }
        format.json { render json: { error: "Label already assigned to this product." }, status: :unprocessable_entity }
      end
      return
    end

    @product.labels << label

    respond_to do |format|
      format.html { redirect_to @product, notice: "Label '#{label.name}' added successfully." }
      format.turbo_stream { flash.now[:notice] = "Label '#{label.name}' added successfully." }
      format.json { render json: { success: true, message: "Label '#{label.name}' added successfully." }, status: :ok }
    end
  end

  def destroy
    authorize :product_label, :destroy?
    label = @product.labels.find_by(id: params[:id])

    unless label
      respond_to do |format|
        format.html { redirect_to @product, alert: "Label not found on this product." }
        format.turbo_stream { flash.now[:alert] = "Label not found on this product." }
        format.json { render json: { error: "Label not found on this product." }, status: :not_found }
      end
      return
    end

    @product.labels.delete(label)

    respond_to do |format|
      format.html { redirect_to @product, notice: "Label '#{label.name}' removed successfully." }
      format.turbo_stream { flash.now[:notice] = "Label '#{label.name}' removed successfully." }
      format.json { render json: { success: true, message: "Label '#{label.name}' removed successfully." }, status: :ok }
    end
  end

  private

  def set_product
    @product = current_potlift_company.products.find(params[:product_id])
  end
end
