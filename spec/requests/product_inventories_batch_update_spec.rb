require 'rails_helper'

RSpec.describe "Product Inventories Batch Update", type: :request do
  let(:company) { create(:company) }
  let(:storage1) { create(:storage, company: company, code: "MAIN", name: "Main Warehouse") }
  let(:storage2) { create(:storage, company: company, code: "SHOP1", name: "Shop 1") }

  before do
    user = OpenStruct.new(id: 1, email: 'test@example.com', name: 'Test User')
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe "PATCH /products/:product_id/inventories/batch_update" do
    context "sellable product" do
      let(:product) { create(:product, company: company, product_type: :sellable) }

      it "creates inventory records for the product" do
        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{product.id}_#{storage1.id}" => { value: "100" },
            "#{product.id}_#{storage2.id}" => { value: "25" }
          }
        }

        expect(response).to redirect_to(product_inventories_path(product))
        expect(flash[:notice]).to eq("Inventory updated successfully.")

        inv1 = Inventory.find_by(product: product, storage: storage1)
        inv2 = Inventory.find_by(product: product, storage: storage2)
        expect(inv1.value).to eq(100)
        expect(inv2.value).to eq(25)
      end

      it "updates existing inventory records" do
        create(:inventory, product: product, storage: storage1, value: 50)

        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{product.id}_#{storage1.id}" => { value: "200" }
          }
        }

        expect(response).to redirect_to(product_inventories_path(product))
        expect(Inventory.find_by(product: product, storage: storage1).value).to eq(200)
      end

      it "handles ETA fields for sellable products" do
        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{product.id}_#{storage1.id}" => {
              value: "100",
              eta_quantity: "50",
              eta_date: "2026-06-01"
            }
          }
        }

        inv = Inventory.find_by(product: product, storage: storage1)
        expect(inv.value).to eq(100)
        expect(inv.info["eta_quantity"]).to eq(50)
        expect(inv.info["eta_date"]).to eq("2026-06-01")
      end

      it "rejects invalid storage IDs" do
        other_company = create(:company)
        other_storage = create(:storage, company: other_company)

        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{product.id}_#{other_storage.id}" => { value: "100" }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Inventory.count).to eq(0)
      end
    end

    context "configurable product" do
      let(:product) { create(:product, company: company, product_type: :configurable, configuration_type: :variant) }
      let(:variant1) { create(:product, company: company, product_type: :sellable, sku: "VAR-1") }
      let(:variant2) { create(:product, company: company, product_type: :sellable, sku: "VAR-2") }

      before do
        create(:product_configuration, superproduct: product, subproduct: variant1)
        create(:product_configuration, superproduct: product, subproduct: variant2)
      end

      it "creates inventory for subproducts (variants)" do
        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{variant1.id}_#{storage1.id}" => { value: "50" },
            "#{variant1.id}_#{storage2.id}" => { value: "10" },
            "#{variant2.id}_#{storage1.id}" => { value: "75" },
            "#{variant2.id}_#{storage2.id}" => { value: "15" }
          }
        }

        expect(response).to redirect_to(product_inventories_path(product))
        expect(Inventory.count).to eq(4)
        expect(Inventory.find_by(product: variant1, storage: storage1).value).to eq(50)
        expect(Inventory.find_by(product: variant2, storage: storage2).value).to eq(15)
      end

      it "rejects product IDs that are not subproducts" do
        other_product = create(:product, company: company)

        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{other_product.id}_#{storage1.id}" => { value: "100" }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(Inventory.count).to eq(0)
      end
    end

    context "atomic transaction" do
      let(:product) { create(:product, company: company, product_type: :sellable) }

      it "rolls back all changes if any cell fails validation" do
        # Create one valid and one with an invalid storage
        other_company = create(:company)
        invalid_storage = create(:storage, company: other_company)

        patch batch_update_product_inventories_path(product), params: {
          inventories: {
            "#{product.id}_#{storage1.id}" => { value: "100" },
            "#{product.id}_#{invalid_storage.id}" => { value: "50" }
          }
        }

        expect(response).to have_http_status(:unprocessable_entity)
        # Both should be rolled back
        expect(Inventory.count).to eq(0)
      end
    end

    context "empty params" do
      let(:product) { create(:product, company: company) }

      it "redirects with alert when no inventory data provided" do
        patch batch_update_product_inventories_path(product), params: {}

        expect(response).to redirect_to(product_inventories_path(product))
        expect(flash[:alert]).to eq("No inventory data provided.")
      end
    end
  end
end
