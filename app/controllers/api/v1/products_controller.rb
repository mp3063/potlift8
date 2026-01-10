# API Products Controller
#
# RESTful API endpoints for product management.
# Provides list, show, and update operations for external systems (M23, Shopify3, Bizcart).
#
# Authentication:
# - Requires Bearer token authentication (see Api::V1::BaseController)
# - All queries are scoped to @current_company (multi-tenant)
#
# Endpoints:
# - GET /api/v1/products - List active, sellable products
# - GET /api/v1/products/:sku - Show product details by SKU
# - PATCH /api/v1/products/:sku - Update product
#
# @example List products
#   GET /api/v1/products
#   Authorization: Bearer <token>
#
#   Response:
#   {
#     "products": [
#       { "id": 1, "sku": "ABC123", "name": "Product 1", ... }
#     ],
#     "meta": { "total": 100, "page": 1, "per_page": 50 }
#   }
#
# @example Show product
#   GET /api/v1/products/ABC123
#   Authorization: Bearer <token>
#
#   Response:
#   {
#     "product": { "id": 1, "sku": "ABC123", ..., "inventory": {...} }
#   }
#
# @example Update product
#   PATCH /api/v1/products/ABC123
#   Authorization: Bearer <token>
#   Content-Type: application/json
#
#   {
#     "product": {
#       "name": "Updated Name",
#       "product_status": "active",
#       "ean": "1234567890123",
#       "info": { "description": "New description" }
#     }
#   }
#
module Api
  module V1
    class ProductsController < Api::V1::BaseController
      # GET /api/v1/products
      #
      # List active, sellable products with basic information and inventory.
      # Returns paginated results (50 per page).
      #
      # Query Parameters:
      # - page: Page number (default: 1)
      # - per_page: Results per page (default: 50, max: 100)
      # - status: Filter by product_status (optional)
      # - type: Filter by product_type (optional)
      #
      # @return [JSON] Paginated list of products
      #
      def index
        # Parse pagination parameters
        page = params[:page]&.to_i || 1
        per_page = [ params[:per_page]&.to_i || 50, 100 ].min # Max 100 per page

        # Build base query (eager loading not needed for basic serializer)
        products = @current_company.products

        # Apply status filter if provided
        if params[:status].present?
          products = products.where(product_status: params[:status])
        else
          # Default to active products
          products = products.active_products
        end

        # Apply type filter if provided
        if params[:type].present?
          products = products.where(product_type: params[:type])
        else
          # Default to sellable products
          products = products.sellable_products
        end

        # Paginate results
        total = products.count
        products = products.offset((page - 1) * per_page).limit(per_page)

        # Serialize products
        serialized_products = ProductSerializer.collection(products)

        render_success({
          products: serialized_products,
          meta: {
            total: total,
            page: page,
            per_page: per_page,
            total_pages: (total.to_f / per_page).ceil
          }
        })
      end

      # GET /api/v1/products/:sku
      #
      # Show detailed product information by SKU.
      # Includes attributes, inventory, and labels.
      #
      # @return [JSON] Detailed product data
      #
      def show
        product = @current_company.products
                                  .with_labels
                                  .find_by!(sku: params[:sku])

        serialized_product = ProductDetailSerializer.new(product).as_json

        render_success({ product: serialized_product })
      end

      # PATCH /api/v1/products/:sku
      # PUT /api/v1/products/:sku
      #
      # Update product information.
      # Allowed fields: name, product_status, ean, info
      #
      # @return [JSON] Updated product data
      #
      def update
        product = @current_company.products.find_by!(sku: params[:sku])

        # Update product with permitted parameters
        if product.update(product_params)
          serialized_product = ProductDetailSerializer.new(product).as_json
          render_success({ product: serialized_product })
        else
          render_error(
            product.errors.full_messages.join(", "),
            status: :unprocessable_entity,
            error_code: "validation_failed"
          )
        end
      end

      private

      # Strong parameters for product update
      #
      # @return [ActionController::Parameters] Permitted parameters
      #
      def product_params
        params.require(:product).permit(
          :name,
          :product_status,
          :ean,
          info: {}
        )
      end
    end
  end
end
