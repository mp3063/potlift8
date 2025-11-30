# frozen_string_literal: true

# Bundle Composer Controller
#
# Provides AJAX endpoints for the bundle composer interface:
# - Search for products to add to bundle
# - Get product details with variants (for configurable products)
# - Preview bundle configuration and validate before generation
#
# All actions require authentication and are scoped to current_potlift_company.
#
# Examples:
#
#   # Search for products
#   GET /bundle_composer/search?q=shirt
#   Returns: Turbo stream with product results
#
#   # Get product details with variants
#   GET /bundle_composer/product/123
#   Returns: Turbo stream with product details and variant list
#
#   # Preview bundle configuration
#   POST /bundle_composer/preview
#   Params: { configuration: { components: [...] } }
#   Returns: JSON with validation results and combination count
#
class BundleComposerController < ApplicationController
  before_action :require_authentication

  # GET /bundle_composer/search?q=shirt
  #
  # Search for products to add to bundle.
  #
  # Filtering:
  # - Only sellable and configurable products
  # - Excludes discontinued products
  # - Excludes bundle variants (generated variants)
  # - Excludes bundle products
  # - Case-insensitive search on name and SKU
  #
  # Eager Loading:
  # - Loads subproducts for configurable products to avoid N+1
  #
  # Returns:
  # - Turbo stream or HTML partial with search results
  # - Limited to 20 results
  #
  def search
    query = params[:q].to_s.strip

    # Return empty if no query
    if query.blank?
      @products = []
    else
      # Search products by name or SKU
      # Only sellable and configurable types
      # Exclude discontinued, bundle variants, and bundle products
      @products = current_potlift_company.products
                                         .where(product_type: [ :sellable, :configurable ])
                                         .where.not(product_status: :discontinued)
                                         .not_bundle_variants
                                         .where("LOWER(name) LIKE :query OR LOWER(sku) LIKE :query",
                                                query: "%#{query.downcase}%")
                                         .includes(product_configurations_as_super: :subproduct)
                                         .limit(20)
    end

    respond_to do |format|
      format.json do
        render json: {
          products: @products.map do |product|
            {
              id: product.id,
              name: product.name,
              sku: product.sku,
              product_type: product.product_type
            }
          end
        }
      end
      format.turbo_stream
      format.html { render partial: "bundle_composer/search_results" }
    end
  end

  # GET /bundle_composer/product/:id
  #
  # Get detailed product information including variants for configurable products.
  #
  # For sellable products:
  # - Returns product details only
  #
  # For configurable products:
  # - Returns product details
  # - Loads all variants (subproducts)
  # - Identifies discontinued variants
  #
  # Raises:
  # - ActiveRecord::RecordNotFound if product not found or belongs to another company
  #
  def product_details
    @product = current_potlift_company.products.find(params[:id])

    # Load variants for configurable products
    if @product.product_type_configurable?
      @variants = @product.subproducts.includes(:inventories)
      @discontinued_variant_ids = @variants.select(&:product_status_discontinued?).map(&:id)
    else
      @variants = []
      @discontinued_variant_ids = []
    end

    respond_to do |format|
      format.json do
        render json: {
          id: @product.id,
          name: @product.name,
          sku: @product.sku,
          product_type: @product.product_type,
          variants: @variants.map do |variant|
            {
              id: variant.id,
              name: variant.name,
              sku: variant.sku,
              variant_code: variant.info&.dig("variant_code"),
              discontinued: @discontinued_variant_ids.include?(variant.id)
            }
          end
        }
      end
      format.turbo_stream
      format.html { render partial: "bundle_composer/product_details" }
    end
  end

  # POST /bundle_composer/preview
  #
  # Validate bundle configuration and calculate combination count.
  #
  # Params:
  #   configuration: {
  #     components: [
  #       { product_id: 123, product_type: 'sellable', quantity: 2 },
  #       {
  #         product_id: 456,
  #         product_type: 'configurable',
  #         variants: [
  #           { variant_id: 789, included: true, quantity: 1 }
  #         ]
  #       }
  #     ]
  #   }
  #
  # Returns:
  #   JSON with validation results:
  #   {
  #     valid: true/false,
  #     errors: ["Error 1", "Error 2"],
  #     warnings: ["Warning 1"],
  #     combination_count: 125
  #   }
  #
  # Validation Rules:
  # - Min 2 products
  # - Max 3 configurables, max 10 sellables, max 12 total
  # - Max 200 combinations
  # - Quantity 1-99
  # - No duplicate products
  # - Products must exist and not be discontinued
  #
  def preview
    configuration = params[:configuration]

    # Validate configuration presence
    if configuration.blank?
      render json: {
        valid: false,
        errors: [ "Configuration is required" ],
        warnings: [],
        combination_count: 0
      }
      return
    end

    # Convert to hash - handles both ActionController::Parameters and Hash
    config_hash = if configuration.respond_to?(:to_unsafe_h)
                    configuration.to_unsafe_h
    elsif configuration.is_a?(Hash)
                    configuration
    else
                    # For non-hash/non-params values (like String from malformed requests)
                    configuration
    end

    # Use BundleValidationService to validate
    service = BundleValidationService.new(config_hash, company: current_potlift_company)

    if service.valid?
      render json: {
        valid: true,
        errors: [],
        warnings: service.warnings,
        combination_count: service.combination_count
      }
    else
      render json: {
        valid: false,
        errors: service.errors,
        warnings: service.warnings,
        combination_count: service.combination_count
      }
    end
  end
end
