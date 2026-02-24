# frozen_string_literal: true

module Catalogs
  # Ecosystem Navigation Hub for Shopify-connected catalogs
  #
  # Displays cross-app navigation links to Shopify Admin and Shopify8 Dashboard,
  # plus an async-loaded sync pipeline status via Turbo Frame.
  #
  # Only renders when the catalog is connected to Shopify.
  #
  # @example
  #   <%= render Catalogs::EcosystemHubComponent.new(catalog: @catalog) %>
  #
  class EcosystemHubComponent < ViewComponent::Base
    attr_reader :catalog

    def initialize(catalog:)
      @catalog = catalog
    end

    def render?
      catalog.shopify_connected?
    end

    def shop_id
      catalog.shop_id
    end

    def shopify_domain
      catalog.shopify_domain
    end

    def shopify_admin_url
      "https://#{shopify_domain}/admin" if shopify_domain.present?
    end

    def shopify8_dashboard_url
      "#{shopify8_base_url}/dashboard/shops/#{shop_id}"
    end

    def shopify8_sync_tasks_url
      "#{shopify8_base_url}/dashboard/sync_tasks?shop_id=#{shop_id}"
    end

    def sync_status_frame_src
      helpers.sync_status_catalog_path(catalog)
    end

    private

    def shopify8_base_url
      ENV.fetch("SHOPIFY8_URL", "http://localhost:3245")
    end
  end
end
