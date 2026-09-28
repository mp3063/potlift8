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
  end
end
