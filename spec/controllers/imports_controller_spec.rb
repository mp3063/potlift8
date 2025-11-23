require 'rails_helper'

RSpec.describe ImportsController, type: :request do
  include ActionDispatch::Routing::UrlFor
  include Rails.application.routes.url_helpers

  let(:company) { create(:company) }
  let(:user) { { id: 1, email: 'user@example.com', name: 'Test User' } }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({ id: company.id, code: company.code, name: company.name })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
  end

  describe 'GET /imports' do
    let(:redis) { instance_double(Redis) }

    before do
      allow(Redis).to receive(:new).and_return(redis)
    end

    context 'when there are imports in Redis' do
      let(:import_data) do
        {
          'status' => 'completed',
          'import_type' => 'products',
          'total_rows' => 10,
          'success_count' => 8,
          'failed_count' => 2,
          'started_at' => Time.current.iso8601
        }.to_json
      end

      before do
        allow(redis).to receive(:keys).with('import_progress:*').and_return(['import_progress:job-123'])
        allow(redis).to receive(:get).with('import_progress:job-123').and_return(import_data)
      end

      it 'returns success status' do
        get imports_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the index template' do
        get imports_path
        expect(response.body).to include('Import History')
        expect(response.body).to include('job-123')
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow(redis).to receive(:keys).and_raise(Redis::BaseError, 'Connection failed')
      end

      it 'handles Redis errors gracefully' do
        get imports_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('No imports yet')
      end
    end
  end

  describe 'GET /imports/new' do
    it 'renders the new template' do
      get new_import_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Import Products')
    end

    it 'accepts import type parameter' do
      get new_import_path(type: 'catalog_items')
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET /imports/template/:type' do
    context 'for products template' do
      it 'downloads CSV file' do
        get download_template_imports_path(type: 'products')
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'sets correct filename' do
        get download_template_imports_path(type: 'products')
        expect(response.headers['Content-Disposition']).to include("products_import_template_#{Date.today}.csv")
      end

      it 'includes CSV headers' do
        get download_template_imports_path(type: 'products')
        csv_data = response.body
        expect(csv_data).to include('sku,name,description')
      end

      it 'includes example row' do
        get download_template_imports_path(type: 'products')
        csv_data = response.body
        expect(csv_data).to include('EXAMPLE-001')
        expect(csv_data).to include('Example Product')
      end

      it 'includes instructions' do
        get download_template_imports_path(type: 'products')
        csv_data = response.body
        expect(csv_data).to include('# SKU is required')
      end
    end

    context 'for catalog_items template' do
      it 'downloads CSV file' do
        get download_template_imports_path(type: 'catalog_items')
        expect(response).to have_http_status(:success)
        expect(response.content_type).to eq('text/csv; charset=utf-8')
      end

      it 'sets correct filename' do
        get download_template_imports_path(type: 'catalog_items')
        expect(response.headers['Content-Disposition']).to include("catalog_items_import_template_#{Date.today}.csv")
      end

      it 'includes catalog-specific headers' do
        get download_template_imports_path(type: 'catalog_items')
        csv_data = response.body
        expect(csv_data).to include('product_sku,catalog_code')
      end
    end

    context 'with unknown import type' do
      it 'redirects to new import path' do
        get download_template_imports_path(type: 'unknown')
        expect(response).to redirect_to(new_import_path)
      end

      it 'sets error flash message' do
        get download_template_imports_path(type: 'unknown')
        follow_redirect!
        expect(response.body).to include('Unknown import type')
      end
    end

    context 'without type parameter' do
      it 'defaults to products template' do
        get download_template_imports_path(type: '')
        expect(response).to have_http_status(:success)
        expect(response.headers['Content-Disposition']).to include('products_import_template')
      end
    end
  end

  describe 'POST /imports' do
    let(:csv_content) { "sku,name\nTEST-001,Test Product" }
    let(:csv_file) { fixture_file_upload('files/products.csv', 'text/csv') }

    context 'with valid CSV file' do
      before do
        allow(ProductImportJob).to receive(:perform_later).and_return(
          double(job_id: 'job-123')
        )
      end

      it 'enqueues import job' do
        expect(ProductImportJob).to receive(:perform_later)
          .with(company.id, anything, user[:id])
        post imports_path, params: { file: csv_file, import_type: 'products' }
      end

      it 'redirects to progress page' do
        post imports_path, params: { file: csv_file, import_type: 'products' }
        expect(response).to redirect_to(progress_import_path('job-123'))
      end

      it 'sets success flash message' do
        post imports_path, params: { file: csv_file, import_type: 'products' }
        follow_redirect!
        expect(response.body).to include('Import started')
      end
    end

    context 'without file parameter' do
      it 'redirects to new import path' do
        post imports_path, params: { import_type: 'products' }
        expect(response).to redirect_to(new_import_path)
      end

      it 'sets error flash message' do
        post imports_path, params: { import_type: 'products' }
        follow_redirect!
        expect(response.body).to include('Please select a file to import')
      end
    end

    context 'with invalid file type' do
      let(:invalid_file) { fixture_file_upload('files/image.png', 'image/png') }

      it 'redirects to new import path' do
        post imports_path, params: { file: invalid_file, import_type: 'products' }
        expect(response).to redirect_to(new_import_path)
      end

      it 'sets error flash message' do
        post imports_path, params: { file: invalid_file, import_type: 'products' }
        follow_redirect!
        expect(response.body).to include('Please upload a CSV file')
      end
    end
  end

  describe 'GET /imports/:id/progress' do
    let(:redis) { instance_double(Redis) }
    let(:job_id) { 'job-123' }
    let(:progress_data) do
      {
        'status' => 'processing',
        'total_rows' => 100,
        'processed_rows' => 50,
        'success_count' => 48,
        'failed_count' => 2,
        'current_row' => 51
      }.to_json
    end

    before do
      allow(Redis).to receive(:new).and_return(redis)
    end

    context 'with existing progress data' do
      before do
        allow(redis).to receive(:get).with("import_progress:#{job_id}").and_return(progress_data)
      end

      it 'renders progress page' do
        get progress_import_path(job_id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('processing')
      end

      it 'returns JSON format' do
        get progress_import_path(job_id, format: :json)
        json = JSON.parse(response.body)
        expect(json['status']).to eq('processing')
        expect(json['total_rows']).to eq(100)
      end
    end

    context 'without progress data' do
      before do
        allow(redis).to receive(:get).with("import_progress:#{job_id}").and_return(nil)
      end

      it 'shows pending status' do
        get progress_import_path(job_id)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('pending')
      end
    end

    context 'when Redis is unavailable' do
      before do
        allow(redis).to receive(:get).and_raise(Redis::BaseError, 'Connection failed')
      end

      it 'handles Redis errors gracefully in HTML' do
        get progress_import_path(job_id)
        expect(response).to have_http_status(:success)
      end

      it 'returns service unavailable status for JSON' do
        get progress_import_path(job_id, format: :json)
        expect(response).to have_http_status(:service_unavailable)
      end
    end
  end
end
