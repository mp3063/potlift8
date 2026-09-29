require 'rails_helper'

RSpec.describe 'CatalogImports', type: :request do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product) { create(:product, company: company, sku: 'PROD1') }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  def upload(csv)
    file = Tempfile.new([ 'import', '.csv' ])
    file.write(csv)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, 'text/csv')
  end

  describe 'POST /catalogs/:code/imports' do
    it 'writes a price-only row for an existing catalog item and counts it as updated' do
      item = catalog.catalog_items.create!(product: product, catalog_item_state: :active)

      post catalog_imports_path(catalog.code), params: { file: upload("product_sku,price_override\nPROD1,29.99\n") }

      expect(item.reload.effective_attribute_value('price')).to eq('2999')
      expect(flash[:notice]).to match(/1 updated/)
      expect(flash[:notice]).not_to match(/skipped/)
    end

    context 'when the price attribute is not catalog-scoped' do
      before do
        company.product_attributes.find_by(code: 'price').update_column(:product_attribute_scope, ProductAttribute.product_attribute_scopes[:product_scope])
      end

      it 'counts a failed price override on an existing item as failed' do
        catalog.catalog_items.create!(product: product, catalog_item_state: :active)

        post catalog_imports_path(catalog.code), params: { file: upload("product_sku,price_override\nPROD1,29.99\n") }

        expect(flash[:alert]).to match(/1 failed/)
        expect(flash[:alert]).to match(/Row 2: price override could not be saved/)
      end

      it 'reports a new item whose price override failed' do
        product
        post catalog_imports_path(catalog.code), params: { file: upload("product_sku,price_override\nPROD1,29.99\n") }

        expect(flash[:alert]).to match(/Row 2: added, but the price override could not be saved/)
        expect(catalog.catalog_items.exists?(product: product)).to be(true)
      end
    end
  end
end
