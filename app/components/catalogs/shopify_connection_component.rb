# frozen_string_literal: true

module Catalogs
  # Shopify connection management component for catalogs
  #
  # Displays connection status and credentials for Shopify integration.
  # Shows either a connected state with shop details and disconnect option,
  # or a disconnected state with a connection form.
  #
  # @example Connected state
  #   <%= render Catalogs::ShopifyConnectionComponent.new(
  #     catalog: @catalog,
  #     connection_service: @connection_service
  #   ) %>
  #
  # @example Disconnected state
  #   <%= render Catalogs::ShopifyConnectionComponent.new(
  #     catalog: @catalog,
  #     connection_service: @connection_service
  #   ) %>
  #
  class ShopifyConnectionComponent < ViewComponent::Base
    attr_reader :catalog, :connection_service

    # Initialize a new Shopify connection component
    #
    # @param catalog [Catalog] The catalog to manage Shopify connection for
    # @param connection_service [ShopifyConnectionService] Service for fetching shop details
    # @return [ShopifyConnectionComponent]
    def initialize(catalog:, connection_service:)
      @catalog = catalog
      @connection_service = connection_service
      @shop_details = nil
      @details_error = nil
    end

    # Eagerly fetch shop details before rendering
    # so that details_error? is available in the template
    def before_render
      shop_details if connected?
    end

    # Check if catalog is connected to Shopify
    #
    # @return [Boolean] true if connected
    def connected?
      connection_service.connected?
    end

    # Get shop details from Shopify8
    #
    # Memoizes result and handles errors gracefully.
    #
    # @return [Hash, nil] Shop details or nil if fetch failed
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

    # Get the Shopify store domain
    #
    # Falls back to cached domain if API call fails.
    #
    # @return [String, nil] Store domain
    def store_domain
      shop_details&.dig(:shopify_domain) || catalog.shopify_domain
    end

    # Get masked API key hint for display
    #
    # @return [String] Masked key like "****a1b2" or "Not configured"
    def api_key_hint
      hint = shop_details&.dig(:api_key_hint)
      hint.present? ? "****#{hint}" : "Not configured"
    end

    # Get API secret status for display
    #
    # @return [String] "Configured" or "Not configured"
    def secret_status
      shop_details&.dig(:api_secret_configured) ? "Configured" : "Not configured"
    end

    # Get the location ID
    #
    # @return [String, nil] Shopify location ID
    def location_id
      shop_details&.dig(:location_id)
    end

    # Check if there was an error fetching details
    #
    # @return [Boolean] true if fetch failed
    def details_error?
      @details_error.present?
    end

    # Get the error message
    #
    # @return [String, nil] Error message
    def details_error_message
      @details_error
    end

    private

    # Route helper for connect action
    #
    # @return [String] Connect route path
    def connect_path
      helpers.connect_shopify_catalog_path(catalog)
    end

    # Route helper for disconnect action
    #
    # @return [String] Disconnect route path
    def disconnect_path
      helpers.disconnect_shopify_catalog_path(catalog)
    end
  end
end
