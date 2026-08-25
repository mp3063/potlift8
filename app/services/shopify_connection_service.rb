# frozen_string_literal: true

class ShopifyConnectionService
  Result = Struct.new(:success, :data, :error, keyword_init: true) do
    def success?
      success
    end
  end

  attr_reader :catalog, :errors

  def initialize(catalog)
    @catalog = catalog
    @errors = []
  end

  def connect(params)
    validate_params(params)
    validate_api_token_configured
    return failure_result(@errors.join(", ")) if @errors.any?

    api_result = if connected?
      verify_result = api_client.get_shop(catalog.shop_id)
      unless verify_result.success?
        return failure_result("Cannot access linked shop. It may have been deleted or you may not have permission.")
      end

      api_client.update_shop(catalog.shop_id, params)
    else
      api_client.create_shop(params)
    end

    if api_result.success?
      shop_data = api_result.data
      update_catalog_shop_reference(shop_data)
      Result.new(success: true, data: shop_data)
    else
      failure_result(api_result.error)
    end
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  def disconnect
    return failure_result("Catalog is not connected to Shopify") unless connected?

    catalog.shop_id = nil
    catalog.info&.delete("shopify_domain_cache")

    if catalog.save
      Result.new(success: true, data: { disconnected: true })
    else
      failure_result(catalog.errors.full_messages.join(", "))
    end
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  def connected?
    catalog.shopify_connected?
  end

  def shop_details
    return failure_result("Catalog is not connected to Shopify") unless connected?

    api_client.get_credentials(catalog.shop_id)
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  def get_shop
    return failure_result("Catalog is not connected to Shopify") unless connected?

    api_client.get_shop(catalog.shop_id)
  rescue StandardError => e
    failure_result("Unexpected error: #{e.message}")
  end

  private

  def validate_params(params)
    @errors = []
    @errors << "Shopify domain is required" if params[:shopify_domain].blank?
    @errors << "API key is required" if params[:shopify_api_key].blank?
    @errors << "API secret is required" if params[:shopify_password].blank?

    if params[:shopify_domain].present? && !params[:shopify_domain].to_s.match?(/\A[\w-]+\.myshopify\.com\z/i)
      @errors << "Shopify domain must be in format: store-name.myshopify.com"
    end
  end

  # Security: Requires explicit API token configuration per catalog.
  # We don't fall back to ENV to prevent cross-catalog token sharing.
  def validate_api_token_configured
    if shopify_api_token.blank?
      @errors << "Shopify8 API token not configured for this catalog. Please set shopify_api_token in catalog settings."
    end
  end

  def update_catalog_shop_reference(shop_data)
    catalog.shop_id = shop_data[:id]
    catalog.info ||= {}
    catalog.info["shopify_domain_cache"] = shop_data[:shopify_domain]
    catalog.save!
  end

  # Uses the catalog's configured API token or falls back to ENV.
  def api_client
    @api_client ||= Shopify8ApiClient.new(
      api_token: shopify_api_token
    )
  end

  # Security: Only uses catalog-specific token, no ENV fallback.
  # This prevents cross-catalog token sharing.
  def shopify_api_token
    catalog.info&.dig("shopify_api_token")
  end

  def failure_result(message)
    Rails.logger.error("[ShopifyConnectionService] #{message}")
    Result.new(success: false, error: message)
  end
end
