# frozen_string_literal: true

class BundleComposerController < ApplicationController
  before_action :require_authentication

  # Eager Loading:
  # - Loads subproducts for configurable products to avoid N+1
  def search
    authorize :bundle_composer, :search?
    query = params[:q].to_s.strip

    if query.blank?
      @products = []
    else
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

  def product_details
    authorize :bundle_composer, :product_details?
    @product = current_potlift_company.products.find(params[:id])

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

  # Returns:
  #   JSON with validation results:
  #   {
  #     valid: true/false,
  #     errors: ["Error 1", "Error 2"],
  #     warnings: ["Warning 1"],
  #     combination_count: 125
  #   }
  # Validation Rules:
  # - Min 2 products
  # - Max 3 configurables, max 10 sellables, max 12 total
  # - Max 200 combinations
  # - Quantity 1-99
  # - No duplicate products
  # - Products must exist and not be discontinued
  def preview
    authorize :bundle_composer, :preview?
    configuration = params[:configuration]

    if configuration.blank?
      render json: {
        valid: false,
        errors: [ "Configuration is required" ],
        warnings: [],
        combination_count: 0
      }
      return
    end

    config_hash = if configuration.respond_to?(:to_unsafe_h)
                    configuration.to_unsafe_h
    elsif configuration.is_a?(Hash)
                    configuration
    else
                    configuration
    end

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
