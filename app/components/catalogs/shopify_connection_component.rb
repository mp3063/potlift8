# frozen_string_literal: true

module Catalogs
  class ShopifyConnectionComponent < ViewComponent::Base
    attr_reader :catalog, :connection_service

    def initialize(catalog:, connection_service:)
      @catalog = catalog
      @connection_service = connection_service
      @shop_details = nil
      @details_error = nil
    end

    def before_render
      shop_details if connected?
    end

    def connected?
      connection_service.connected?
    end

    def shop_details
      return @shop_details if @shop_details_fetched

      @shop_details_fetched = true

      if connected?
        result = connection_service.shop_details
        if result.success?
          @shop_details = result.data
        else
          @details_error = result.error
        end
      end

      @shop_details
    end

    # Falls back to cached domain if API call fails.
    def store_domain
      shop_details&.dig(:shopify_domain) || catalog.shopify_domain
    end

    def api_key_hint
      hint = shop_details&.dig(:api_key_hint)
      hint.present? ? "****#{hint}" : "Not configured"
    end

    def secret_status
      shop_details&.dig(:api_secret_configured) ? "Configured" : "Not configured"
    end

    def location_id
      shop_details&.dig(:location_id)
    end

    def details_error?
      @details_error.present?
    end

    def details_error_message
      @details_error
    end

    private

    def connect_path
      helpers.connect_shopify_catalog_path(catalog)
    end

    def disconnect_path
      helpers.disconnect_shopify_catalog_path(catalog)
    end
  end
end
