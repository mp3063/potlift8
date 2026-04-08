require 'rails_helper'

RSpec.describe ImportsController, type: :request do
  include ActionDispatch::Routing::UrlFor
  include Rails.application.routes.url_helpers
  include ActiveJob::TestHelper

  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  def build_upload(content, filename: "products.csv", type: "text/csv")
    file = Tempfile.new([ "products", ".csv" ])
    file.write(content)
    file.rewind
    Rack::Test::UploadedFile.new(file.path, type, original_filename: filename)
  end

  describe 'GET /imports' do
    it 'returns success and scopes to current company' do
      company.imports.create!(user: user, import_type: "products", status: "completed")
      other = create(:company)
      other.imports.create!(user: create(:user, company: other), import_type: "products", status: "completed")

      get imports_path

      expect(response).to have_http_status(:success)
      expect(assigns(:imports).map(&:company_id)).to all(eq(company.id))
    end
  end

  describe 'GET /imports/new' do
    it 'renders the new template' do
      get new_import_path
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /imports' do
    let(:csv_content) { "sku,name\nABC123,Widget\n" }

    context 'with no file' do
      it 'redirects with an error' do
        post imports_path, params: {}
        expect(response).to redirect_to(new_import_path)
        expect(flash[:alert]).to match(/select a file/i)
      end
    end

    context 'with a non-CSV file' do
      it 'redirects with an error' do
        upload = build_upload("<html/>", filename: "notes.txt", type: "text/html")
        post imports_path, params: { file: upload }
        expect(response).to redirect_to(new_import_path)
        expect(flash[:alert]).to match(/CSV/i)
      end
    end

    context 'with a file over MAX_FILE_SIZE' do
      it 'redirects with a too-large error before creating an import' do
        # Stub any UploadedFile instance to report an oversized size, since
        # the upload the controller sees is a fresh ActionDispatch wrapper.
        allow_any_instance_of(ActionDispatch::Http::UploadedFile)
          .to receive(:size).and_return(ImportsController::MAX_FILE_SIZE + 1)

        upload = build_upload(csv_content)

        expect {
          post imports_path, params: { file: upload }
        }.not_to change { Import.count }

        expect(response).to redirect_to(new_import_path)
        expect(flash[:alert]).to match(/too large/i)
      end
    end

    context 'with a valid CSV' do
      it 'creates an Import record, attaches the file, and enqueues the job with only the import id' do
        upload = build_upload(csv_content)

        expect {
          post imports_path, params: { file: upload, import_type: "products" }
        }.to change { company.imports.count }.by(1)
          .and have_enqueued_job(ProductImportJob)

        import = company.imports.last
        expect(import.file).to be_attached
        expect(import.user).to eq(user)
        expect(import.import_type).to eq("products")

        # Job argument is a single integer (the import id), NOT file content
        enqueued = ActiveJob::Base.queue_adapter.enqueued_jobs.last
        expect(enqueued[:args]).to eq([ import.id ])
      end

      it 'redirects to the progress page using the import id' do
        upload = build_upload(csv_content)
        post imports_path, params: { file: upload, import_type: "products" }

        import = company.imports.last
        expect(response).to redirect_to(progress_import_path(import.id))
      end
    end
  end

  describe 'GET /imports/:id/progress' do
    it 'exposes status fields from the Import record' do
      import = company.imports.create!(
        user: user,
        import_type: "products",
        status: "completed",
        progress: 100,
        imported_count: 3,
        updated_count: 1,
        total_rows: 4,
        errors_data: []
      )

      get progress_import_path(import.id), headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body).to include(
        "status" => "completed",
        "progress" => 100,
        "imported" => 3,
        "updated" => 1,
        "errors" => 0
      )
    end

    it 'does not expose imports from other companies' do
      other = create(:company)
      other_import = other.imports.create!(user: create(:user, company: other), import_type: "products", status: "completed")

      expect {
        get progress_import_path(other_import.id)
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe 'GET /imports/:id/errors' do
    it 'returns a CSV download when row errors exist' do
      import = company.imports.create!(
        user: user,
        import_type: "products",
        status: "completed",
        errors_data: [ { "row" => 2, "error" => "SKU is required" } ]
      )

      get errors_import_path(import.id)

      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(/text\/csv/)
      expect(response.body).to include("SKU is required")
    end

    it 'redirects when there are no errors' do
      import = company.imports.create!(
        user: user,
        import_type: "products",
        status: "completed",
        errors_data: []
      )

      get errors_import_path(import.id)

      expect(response).to redirect_to(imports_path)
    end
  end

  describe 'GET /imports/template/:type' do
    it 'downloads the products CSV template' do
      get download_template_imports_path(type: "products")
      expect(response).to have_http_status(:success)
      expect(response.content_type).to match(/text\/csv/)
      expect(response.body).to include("sku,name,description")
    end

    it 'downloads the catalog_items CSV template' do
      get download_template_imports_path(type: "catalog_items")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("product_sku,catalog_code")
    end
  end
end
