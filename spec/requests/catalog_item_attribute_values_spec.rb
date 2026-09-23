# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/catalog_item_attribute_values", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
  let(:attribute) { company.product_attributes.find_by!(code: "short_description") }
  let!(:override) { create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: attribute, value: "Old copy") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe "PATCH /catalog_item_attribute_values/:id as turbo_stream" do
    it "replaces the whole catalog panel with the updated override row" do
      patch catalog_item_attribute_value_path(override, format: :turbo_stream), params: { value: "New copy" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(target="panel-#{catalog.code}"))
      expect(response.body).to include("New copy")
      expect(response.body).to include("Override")
      expect(response.body).to match(/<dt[^>]*title="#{Regexp.escape(attribute.name)}/)
      expect(override.reload.value).to eq("New copy")
    end

    it "loads the product's attribute definitions in one query, not one per value" do
      %w[short_description description_html].each do |code|
        attr = company.product_attributes.find_by!(code: code)
        create(:product_attribute_value, product: product, product_attribute: attr, value: "Copy for #{code}")
      end
      attribute_lookups = []
      counter = ->(*, payload) { attribute_lookups << payload[:sql] if payload[:sql].match?(/FROM "product_attributes" WHERE "product_attributes"\."id" = /) }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        patch catalog_item_attribute_value_path(override, format: :turbo_stream), params: { value: "New copy" }
      end

      # At most the edited override's own attribute; never one per product value
      expect(attribute_lookups.size).to be <= 1
    end
  end
end
