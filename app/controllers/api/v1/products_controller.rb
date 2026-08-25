module Api
  module V1
    class ProductsController < Api::V1::BaseController
      def index
        page = params[:page]&.to_i || 1
        per_page = [ params[:per_page]&.to_i || 50, 100 ].min

        # Build base query (eager loading not needed for basic serializer)
        products = @current_company.products

        if params[:status].present?
          products = products.where(product_status: params[:status])
        else
          products = products.active_products
        end

        if params[:type].present?
          products = products.where(product_type: params[:type])
        else
          products = products.sellable_products
        end

        total = products.count
        products = products.offset((page - 1) * per_page).limit(per_page)

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

      def show
        product = @current_company.products
                                  .with_labels
                                  .find_by!(sku: params[:sku])

        serialized_product = ProductDetailSerializer.new(product).as_json

        render_success({ product: serialized_product })
      end

      def update
        product = @current_company.products.find_by!(sku: params[:sku])

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
