# API Inventories Controller
#
# RESTful API endpoints for inventory management.
# Allows external systems (M23, Shopify3, Bizcart) to update product inventory levels.
#
# Authentication:
# - Requires Bearer token authentication (see Api::V1::BaseController)
# - All queries are scoped to @current_company (multi-tenant)
#
# Endpoints:
# - POST /api/v1/inventories/update - Update inventory for a product
# - POST /api/v1/inventories/reduce - Reduce inventory for a product (relative decrement)
#
# @example Update inventory
#   POST /api/v1/inventories/update
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "sku": "ABC123",
#     "inventory": {
#       "updates": [
#         { "storage_code": "MAIN", "value": 100 },
#         { "storage_code": "INCOMING", "value": 50, "eta": "2025-11-15" }
#       ]
#     }
#   }
#
#   Response (Success):
#   {
#     "success": true,
#     "product": { "id": 1, "sku": "ABC123", "name": "Product Name" },
#     "inventory": {
#       "available": 100,
#       "incoming": 50,
#       "eta": "2025-11-15"
#     },
#     "updates": [
#       { "storage_code": "MAIN", "value": 100, "updated": true },
#       { "storage_code": "INCOMING", "value": 50, "eta": "2025-11-15", "updated": true }
#     ]
#   }
#
#   Response (Error):
#   {
#     "success": false,
#     "error": "Storage not found: INVALID",
#     "details": { "storage_code": "INVALID" }
#   }
#
# @example Reduce inventory
#   POST /api/v1/inventories/reduce
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "sku": "ABC123",
#     "quantity": 3,
#     "storage_code": "MAIN"
#   }
#
#   Response (Success):
#   {
#     "success": true,
#     "product": { "id": 1, "sku": "ABC123", "name": "Product Name" },
#     "inventory": {
#       "available": 97,
#       "incoming": 0,
#       "eta": null
#     },
#     "reduced": { "storage_code": "MAIN", "quantity": 3, "new_value": 97 }
#   }
#
#   Response (Error):
#   {
#     "success": false,
#     "error": "inventory_reduce_failed",
#     "message": "Storage not found: INVALID"
#   }
#
module Api
  module V1
    class InventoriesController < Api::V1::BaseController
      # POST /api/v1/inventories/update
      #
      # Update inventory levels for a product across multiple storage locations.
      # Supports ETA (Estimated Time of Arrival) for incoming inventory.
      #
      # Required Parameters:
      # - sku: Product SKU
      # - inventory[updates]: Array of inventory update objects
      #   - storage_code: Storage location code
      #   - value: Inventory quantity (integer)
      #   - eta: Estimated arrival date (optional, ISO 8601 format)
      #
      # @return [JSON] Result with success status and inventory data
      #
      def update_inventory
        # Validate required parameters
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

        # Find product by SKU
        product = @current_company.products.find_by(sku: sku)

        unless product
          return render_error(
            "Product not found: #{sku}",
            status: :not_found,
            error_code: "product_not_found"
          )
        end

        # Update inventory using service
        service = InventoryUpdateService.new(@current_company, product)
        result = service.update(updates: updates)

        if result[:success]
          # Success response
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
          # Error response
          render_error(
            result[:error],
            status: :unprocessable_entity,
            error_code: "inventory_update_failed"
          )
        end
      end

      # POST /api/v1/inventories/reduce
      #
      # Reduce inventory for a product by a relative quantity (decrement).
      # Targets an explicit storage via storage_code, or falls back to the
      # product's default inventory / company default storage.
      # Negative values are allowed by design (makes overselling visible).
      #
      # Required Parameters:
      # - sku: Product SKU
      # - quantity: Quantity to subtract (positive integer)
      #
      # Optional Parameters:
      # - storage_code: Storage location code
      #
      # @return [JSON] Result with success status and inventory data
      #
      def reduce_inventory
        # Validate required parameters
        sku = params[:sku]
        quantity = params[:quantity]

        if sku.blank?
          return render_error("SKU is required", status: :bad_request, error_code: "missing_parameter")
        end

        if quantity.blank?
          return render_error("quantity is required", status: :bad_request, error_code: "missing_parameter")
        end

        # Find product by SKU
        product = @current_company.products.find_by(sku: sku)

        unless product
          return render_error(
            "Product not found: #{sku}",
            status: :not_found,
            error_code: "product_not_found"
          )
        end

        # Reduce inventory using service
        service = InventoryReduceService.new(@current_company, product)
        result = service.reduce(quantity: quantity, storage_code: params[:storage_code])

        if result[:success]
          # Success response
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
          # Error response
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
