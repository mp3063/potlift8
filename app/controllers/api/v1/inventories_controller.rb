module Api
  module V1
    class InventoriesController < Api::V1::BaseController
      def update_inventory
        sku = params[:sku]
        updates = params.dig(:inventory, :updates)

        if sku.blank?
          return render_error("SKU is required", status: :bad_request, error_code: "missing_parameter")
        end

        if updates.blank? || !updates.is_a?(Array)
          return render_error(
            "inventory.updates must be a non-empty array",
            status: :bad_request,
            error_code: "invalid_parameter"
          )
        end

        product = @current_company.products.find_by(sku: sku)

        unless product
          return render_error(
            "Product not found: #{sku}",
            status: :not_found,
            error_code: "product_not_found"
          )
        end

        service = InventoryUpdateService.new(@current_company, product)
        result = service.update(updates: updates)

        if result[:success]
          render_success({
            success: true,
            product: {
              id: product.id,
              sku: product.sku,
              name: product.name
            },
            inventory: result[:inventory],
            updates: result[:updates]
          })
        else
          render_error(
            result[:error],
            status: :unprocessable_entity,
            error_code: "inventory_update_failed"
          )
        end
      end

      # Reduce inventory for a product by a relative quantity (decrement).
      # Targets an explicit storage via storage_code, or falls back to the
      # product's default inventory / company default storage.
      # Negative values are allowed by design (makes overselling visible).
      def reduce_inventory
        sku = params[:sku]
        quantity = params[:quantity]

        if sku.blank?
          return render_error("SKU is required", status: :bad_request, error_code: "missing_parameter")
        end

        if quantity.blank?
          return render_error("quantity is required", status: :bad_request, error_code: "missing_parameter")
        end

        product = @current_company.products.find_by(sku: sku)

        unless product
          return render_error(
            "Product not found: #{sku}",
            status: :not_found,
            error_code: "product_not_found"
          )
        end

        service = InventoryReduceService.new(@current_company, product)
        result = service.reduce(quantity: quantity, storage_code: params[:storage_code])

        if result[:success]
          render_success({
            success: true,
            product: {
              id: product.id,
              sku: product.sku,
              name: product.name
            },
            inventory: result[:inventory],
            reduced: result[:reduced]
          })
        else
          render_error(
            result[:error],
            status: :unprocessable_entity,
            error_code: "inventory_reduce_failed"
          )
        end
      end
    end
  end
end
