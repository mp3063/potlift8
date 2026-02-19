require 'rails_helper'

RSpec.describe "Product Inventories", type: :request do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:storage) { create(:storage, company: company) }
  let(:inventory) { create(:inventory, product: product, storage: storage, value: 100) }

  # Mock OAuth authentication
  before do
    # Use OpenStruct to support both hash and method access
    user = OpenStruct.new(
      id: 1,
      email: 'test@example.com',
      name: 'Test User'
    )

    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", ["read", "write"], company)
    )
  end

  describe "GET /products/:product_id/inventories" do
    it "displays all inventory records for a product" do
      inventory # Create the inventory record
      get product_inventories_path(product)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(product.sku)
      expect(response.body).to include(storage.name)
    end
  end

  describe "PATCH /products/:product_id/inventories/:id" do
    context "updating only inventory value" do
      it "updates the inventory value" do
        patch product_inventory_path(product, inventory), params: {
          inventory: { value: 150 }
        }

        expect(response).to redirect_to(product_inventories_path(product))
        expect(inventory.reload.value).to eq(150)
      end
    end

    context "updating inventory value and ETA fields" do
      it "updates value and stores ETA data in info JSONB" do
        patch product_inventory_path(product, inventory), params: {
          inventory: {
            value: 150,
            eta_quantity: 50,
            eta_date: '2025-12-31'
          }
        }

        expect(response).to redirect_to(product_inventories_path(product))

        inventory.reload
        expect(inventory.value).to eq(150)
        expect(inventory.info['eta_quantity']).to eq(50)
        expect(inventory.info['eta_date']).to eq('2025-12-31')
      end
    end

    context "updating only ETA fields" do
      it "preserves existing inventory value" do
        patch product_inventory_path(product, inventory), params: {
          inventory: {
            value: 100,
            eta_quantity: 75,
            eta_date: '2026-01-15'
          }
        }

        inventory.reload
        expect(inventory.value).to eq(100)
        expect(inventory.info['eta_quantity']).to eq(75)
        expect(inventory.info['eta_date']).to eq('2026-01-15')
      end
    end

    context "preserving existing info data" do
      it "merges ETA fields with existing info data" do
        # Set some existing info data
        inventory.update(info: { 'custom_field' => 'test_value' })

        patch product_inventory_path(product, inventory), params: {
          inventory: {
            value: 120,
            eta_quantity: 30
          }
        }

        inventory.reload
        expect(inventory.value).to eq(120)
        expect(inventory.info['eta_quantity']).to eq(30)
        expect(inventory.info['custom_field']).to eq('test_value')
      end
    end

    context "clearing ETA date" do
      it "allows clearing ETA date by sending empty string" do
        inventory.update(info: { 'eta_date' => '2025-12-31', 'eta_quantity' => 50 })

        patch product_inventory_path(product, inventory), params: {
          inventory: {
            value: 100,
            eta_quantity: 50,
            eta_date: ''
          }
        }

        inventory.reload
        expect(inventory.info['eta_quantity']).to eq(50)
        expect(inventory.info['eta_date']).to be_nil
      end
    end

    context "with invalid data" do
      it "redirects with error message" do
        patch product_inventory_path(product, inventory), params: {
          inventory: { value: nil }
        }

        expect(response).to redirect_to(product_inventories_path(product))
        expect(flash[:alert]).to include("Failed to update inventory")
      end
    end
  end
end
