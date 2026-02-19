# frozen_string_literal: true

require "rails_helper"

RSpec.describe Catalogs::ShopifyConnectionComponent, type: :component do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }

  # Mock the ShopifyConnectionService and its Result struct
  let(:connection_service) { instance_double(ShopifyConnectionService) }
  let(:success_result) do
    ShopifyConnectionService::Result.new(
      success: true,
      data: shop_details_data
    )
  end
  let(:failure_result) do
    ShopifyConnectionService::Result.new(
      success: false,
      error: "Unable to fetch shop details"
    )
  end
  let(:shop_details_data) do
    {
      shopify_domain: "test-store.myshopify.com",
      api_key_hint: "a1b2",
      api_secret_configured: true,
      location_id: "gid://shopify/Location/123456789"
    }
  end

  describe "when connected with successful details fetch" do
    before do
      # Set up catalog as connected
      catalog.info ||= {}
      catalog.info["shop_id"] = 123
      catalog.info["shopify_domain_cache"] = "test-store.myshopify.com"
      catalog.save!

      allow(connection_service).to receive(:connected?).and_return(true)
      allow(connection_service).to receive(:shop_details).and_return(success_result)
    end

    it "shows Connected badge" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Connected")
      expect(page).to have_css("span.bg-green-100.text-green-800", text: "Connected")
    end

    it "displays store domain" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Store")
      expect(page).to have_text("test-store.myshopify.com")
    end

    it "displays masked API key hint" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("API Key")
      expect(page).to have_text("****a1b2")
    end

    it "displays secret status as Configured" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("API Secret")
      expect(page).to have_css("span.text-green-600", text: "Configured")
    end

    it "displays location ID when present" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Location ID")
      expect(page).to have_text("gid://shopify/Location/123456789")
    end

    it "shows Update Credentials button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_button("Update Credentials")
    end

    it "shows Disconnect button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_button("Disconnect")
    end

    it "includes turbo confirm on disconnect button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("button[data-turbo-confirm]", text: "Disconnect")
    end

    context "when secret is not configured" do
      let(:shop_details_data) do
        {
          shopify_domain: "test-store.myshopify.com",
          api_key_hint: "a1b2",
          api_secret_configured: false,
          location_id: nil
        }
      end

      it "displays secret status as Not configured in red" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("span.text-red-600", text: "Not configured")
      end
    end

    context "when location ID is not set" do
      let(:shop_details_data) do
        {
          shopify_domain: "test-store.myshopify.com",
          api_key_hint: "a1b2",
          api_secret_configured: true,
          location_id: nil
        }
      end

      it "displays Not set for location ID" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_text("Location ID")
        expect(page).to have_css("span.text-gray-400", text: "Not set")
      end
    end

    context "when API key hint is empty" do
      let(:shop_details_data) do
        {
          shopify_domain: "test-store.myshopify.com",
          api_key_hint: nil,
          api_secret_configured: true,
          location_id: nil
        }
      end

      it "displays Not configured for API key" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_text("API Key")
        expect(page).to have_text("Not configured")
      end
    end
  end

  describe "when connected but details fetch fails" do
    before do
      # Set up catalog as connected with cached domain
      catalog.info ||= {}
      catalog.info["shop_id"] = 123
      catalog.info["shopify_domain_cache"] = "cached-store.myshopify.com"
      catalog.save!

      allow(connection_service).to receive(:connected?).and_return(true)
      allow(connection_service).to receive(:shop_details).and_return(failure_result)
    end

    it "shows warning message about cached information" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Unable to fetch shop details")
      expect(page).to have_text("Showing cached information")
    end

    it "shows warning in yellow alert box" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("div.bg-yellow-50.border-yellow-200")
    end

    it "falls back to cached domain from catalog.shopify_domain" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("cached-store.myshopify.com")
    end

    it "still shows Connected badge" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("span.bg-green-100.text-green-800", text: "Connected")
    end

    it "still shows Disconnect button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_button("Disconnect")
    end

    it "still shows Update Credentials button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_button("Update Credentials")
    end
  end

  describe "when not connected" do
    before do
      allow(connection_service).to receive(:connected?).and_return(false)
    end

    it "shows Not Connected badge" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Not Connected")
      expect(page).to have_css("span.bg-gray-100.text-gray-800", text: "Not Connected")
    end

    it "displays introductory text about connecting" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Connect this catalog to a Shopify store")
    end

    describe "connection form" do
      it "renders a form" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("form")
      end

      it "has Store URL field (required)" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("label", text: /Store URL/)
        expect(page).to have_css("span.text-red-600", text: "*")
        expect(page).to have_css("input[name='shopify_domain'][required]")
        expect(page).to have_css("input[placeholder='my-store.myshopify.com']")
      end

      it "has API Key field (required)" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("label", text: /API Key/)
        expect(page).to have_css("input[name='shopify_api_key'][required]")
      end

      it "has API Secret field (required)" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("label", text: /API Secret/)
        expect(page).to have_css("input[name='shopify_password'][required]")
        expect(page).to have_css("input[type='password'][name='shopify_password']")
      end

      it "has Location ID field (optional)" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        # Rails humanizes :location_id to "Location id"
        expect(page).to have_css("label", text: "Location")
        # Should NOT have required indicator
        expect(page).to have_css("input[name='location_id']")
        expect(page).not_to have_css("input[name='location_id'][required]")
        expect(page).to have_text("Optional")
      end

      it "shows Connect to Shopify button" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("input[type='submit'][value='Connect to Shopify']")
      end

      it "has green submit button styling" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("input.bg-green-600")
      end

      it "includes disable_with for loading state" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_css("input[data-disable-with='Connecting...']")
      end

      it "has required attributes for accessibility" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        # Form fields have required attribute for browser validation
        expect(page).to have_css("input[name='shopify_domain'][required]")
        expect(page).to have_css("input[name='shopify_api_key'][required]")
        expect(page).to have_css("input[name='shopify_password'][required]")
      end

      it "has helper text for Store URL field" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_text("Your Shopify store domain (e.g., my-store.myshopify.com)")
      end

      it "has helper text for Location ID field" do
        render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

        expect(page).to have_text("Leave blank to use the primary location")
      end
    end

    it "does not show Disconnect button" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).not_to have_button("Disconnect")
    end

    it "does not show Update Credentials link" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).not_to have_link("Update Credentials")
    end
  end

  describe "component structure" do
    before do
      allow(connection_service).to receive(:connected?).and_return(false)
    end

    it "renders within a CardComponent" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("div.bg-white.rounded-lg.shadow-sm")
    end

    it "has Shopify Connection header" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_text("Shopify Connection")
    end

    it "has Shopify icon in header" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("svg.text-green-600")
    end

    it "has Stimulus controller data attribute" do
      render_inline(described_class.new(catalog: catalog, connection_service: connection_service))

      expect(page).to have_css("div[data-controller='shopify-connection']")
    end
  end
end
