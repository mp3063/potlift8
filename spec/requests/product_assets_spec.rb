# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ProductAssets', type: :request do
  let(:company) { create(:company) }
  let(:other_company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:product) { create(:product, company: company, sku: 'PROD-001', name: 'Test Product') }
  let(:other_product) { create(:product, company: other_company, sku: 'OTHER-001', name: 'Other Product') }

  before do
    # Mock authentication
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe 'authentication requirements' do
    before do
      # Remove authentication mocks
      allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(false)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
    end

    it 'requires authentication for index' do
      get product_product_assets_path(product)
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for new' do
      get new_product_product_asset_path(product)
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for create' do
      post product_product_assets_path(product), params: { asset: { name: 'Test' } }
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for edit' do
      asset = create(:product_asset, :document, product: product)
      get edit_product_product_asset_path(product, asset)
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for update' do
      asset = create(:product_asset, :document, product: product)
      patch product_product_asset_path(product, asset), params: { asset: { name: 'Updated' } }
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for destroy' do
      asset = create(:product_asset, :document, product: product)
      delete product_product_asset_path(product, asset)
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end

    it 'requires authentication for reorder' do
      post reorder_product_product_assets_path(product), params: { asset_ids: [1, 2] }
      expect(response).to redirect_to(auth_login_path)
      expect(flash[:alert]).to eq('Please sign in to continue.')
    end
  end

  describe 'GET /products/:product_id/product_assets' do
    let!(:document1) { create(:product_asset, :document, product: product, name: 'Manual.pdf', asset_priority: 10) }
    let!(:document2) { create(:product_asset, :document, product: product, name: 'Guide.pdf', asset_priority: 5) }
    let!(:video1) { create(:product_asset, :video, product: product, name: 'Demo Video', asset_priority: 20) }
    let!(:link1) { create(:product_asset, :link, product: product, name: 'Product Page') }
    let!(:other_asset) { create(:product_asset, :document, product: other_product, name: 'Other.pdf') }

    it 'returns successful response' do
      get product_product_assets_path(product)
      expect(response).to be_successful
    end

    it 'displays only current company product assets' do
      get product_product_assets_path(product)
      expect(response.body).to include('Manual.pdf')
      expect(response.body).to include('Guide.pdf')
      expect(response.body).to include('Demo Video')
      expect(response.body).to include('Product Page')
      expect(response.body).not_to include('Other.pdf')
    end

    it 'separates assets by type' do
      get product_product_assets_path(product)
      expect(assigns(:documents).pluck(:name)).to contain_exactly('Manual.pdf', 'Guide.pdf')
      expect(assigns(:videos).pluck(:name)).to contain_exactly('Demo Video')
      expect(assigns(:links).pluck(:name)).to contain_exactly('Product Page')
    end

    it 'orders assets by priority descending' do
      get product_product_assets_path(product)
      asset_names = assigns(:assets).pluck(:name)
      expect(asset_names.first).to eq('Demo Video') # priority 20
      expect(asset_names.second).to eq('Manual.pdf') # priority 10
    end

    it 'excludes image assets' do
      image_asset = create(:product_asset, :image, product: product, name: 'Photo.jpg')
      get product_product_assets_path(product)
      expect(response.body).not_to include('Photo.jpg')
    end

    it 'redirects with alert for other company product' do
      get product_product_assets_path(other_product)
      expect(response).to redirect_to(products_path)
      follow_redirect!
      expect(response.body).to include('Product not found')
    end
  end

  describe 'GET /products/:product_id/product_assets/new' do
    it 'returns successful response' do
      get new_product_product_asset_path(product)
      expect(response).to be_successful
    end

    it 'renders form' do
      get new_product_product_asset_path(product)
      expect(response.body).to include('form')
      expect(response.body).to include('product_asset_type')
    end

    it 'builds new asset with defaults' do
      get new_product_product_asset_path(product)
      asset = assigns(:asset)
      expect(asset).to be_new_record
      expect(asset.asset_visibility).to eq('public_visibility')
      expect(asset.asset_priority).to eq(50)
    end

    it 'redirects with alert for other company product' do
      get new_product_product_asset_path(other_product)
      expect(response).to redirect_to(products_path)
    end
  end

  describe 'POST /products/:product_id/product_assets' do
    context 'with document asset' do
      let(:file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf') }

      let(:valid_params) do
        {
          asset: {
            name: 'Product Manual',
            product_asset_type: 'document',
            asset_visibility: 'public_visibility',
            asset_priority: 10,
            asset_description: 'User manual for product',
            file: file
          }
        }
      end

      it 'creates document asset with file' do
        expect {
          post product_product_assets_path(product), params: valid_params
        }.to change(product.product_assets, :count).by(1)

        asset = product.product_assets.last
        expect(asset.name).to eq('Product Manual')
        expect(asset.product_asset_type).to eq('document')
        expect(asset.asset_visibility).to eq('public_visibility')
        expect(asset.asset_priority).to eq(10)
        expect(asset.file).to be_attached
      end

      it 'redirects to product with success notice' do
        post product_product_assets_path(product), params: valid_params
        expect(response).to redirect_to(product_path(product, anchor: 'assets'))
        follow_redirect!
        expect(response.body).to include('Asset created successfully')
      end

      it 'validates file presence for document type' do
        invalid_params = valid_params.deep_dup
        invalid_params[:asset].delete(:file)

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates document file type' do
        invalid_file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.txt'), 'application/octet-stream')
        invalid_params = valid_params.deep_dup
        invalid_params[:asset][:file] = invalid_file

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates document file size limit' do
        # Mock file size check
        allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(25.megabytes)

        expect {
          post product_product_assets_path(product), params: valid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with video asset' do
      let(:video_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/sample_video.mp4'), 'video/mp4') }

      let(:valid_params) do
        {
          asset: {
            name: 'Product Demo',
            product_asset_type: 'video',
            asset_visibility: 'public_visibility',
            asset_description: 'Product demonstration video',
            file: video_file
          }
        }
      end

      it 'creates video asset with file' do
        expect {
          post product_product_assets_path(product), params: valid_params
        }.to change(product.product_assets.videos, :count).by(1)

        asset = product.product_assets.videos.last
        expect(asset.name).to eq('Product Demo')
        expect(asset.file).to be_attached
      end

      it 'creates video asset with URL only (no file)' do
        url_params = {
          product_asset: {
            name: 'YouTube Demo',
            product_asset_type: 'video',
            asset_visibility: 'public_visibility',
            asset_description: 'Product video on YouTube',
            video_url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
          }
        }

        expect {
          post product_product_assets_path(product), params: url_params
        }.to change(product.product_assets.videos, :count).by(1)

        asset = product.product_assets.videos.last
        expect(asset.name).to eq('YouTube Demo')
        expect(asset.info['url']).to eq('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
        expect(asset.file).not_to be_attached
      end

      it 'accepts Vimeo URLs for video assets' do
        vimeo_params = {
          product_asset: {
            name: 'Vimeo Demo',
            product_asset_type: 'video',
            asset_visibility: 'public_visibility',
            video_url: 'https://vimeo.com/123456789'
          }
        }

        expect {
          post product_product_assets_path(product), params: vimeo_params
        }.to change(product.product_assets.videos, :count).by(1)

        asset = product.product_assets.videos.last
        expect(asset.info['url']).to eq('https://vimeo.com/123456789')
        expect(asset.file).not_to be_attached
      end

      it 'validates that video has either file OR URL (not both empty)' do
        invalid_params = {
          product_asset: {
            name: 'Product Demo',
            product_asset_type: 'video',
            asset_visibility: 'public_visibility'
          }
        }

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates video file type' do
        invalid_file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
        invalid_params = valid_params.deep_dup
        invalid_params[:asset][:file] = invalid_file

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates video file size limit' do
        # Mock file size check
        allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(150.megabytes)

        expect {
          post product_product_assets_path(product), params: valid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with link asset' do
      let(:valid_params) do
        {
          asset: {
            name: 'Product Website',
            product_asset_type: 'link',
            asset_visibility: 'public_visibility',
            asset_description: 'Official product website',
            url: 'https://example.com/product'
          }
        }
      end

      it 'creates link asset with URL in info' do
        expect {
          post product_product_assets_path(product), params: valid_params
        }.to change(product.product_assets.links, :count).by(1)

        asset = product.product_assets.links.last
        expect(asset.name).to eq('Product Website')
        expect(asset.info['url']).to eq('https://example.com/product')
        expect(asset.file).not_to be_attached
      end

      it 'redirects to product with success notice' do
        post product_product_assets_path(product), params: valid_params
        expect(response).to redirect_to(product_path(product, anchor: 'assets'))
        follow_redirect!
        expect(response.body).to include('Asset created successfully')
      end

      it 'validates URL presence for link type' do
        invalid_params = valid_params.deep_dup
        invalid_params[:asset].delete(:url)

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates URL format for link type' do
        invalid_params = valid_params.deep_dup
        invalid_params[:asset][:url] = 'not-a-valid-url'

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'accepts YouTube URLs' do
        youtube_params = valid_params.deep_dup
        youtube_params[:asset][:url] = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'

        expect {
          post product_product_assets_path(product), params: youtube_params
        }.to change(ProductAsset, :count).by(1)

        asset = ProductAsset.last
        expect(asset.info['url']).to eq('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
      end

      it 'accepts Vimeo URLs' do
        vimeo_params = valid_params.deep_dup
        vimeo_params[:asset][:url] = 'https://vimeo.com/123456789'

        expect {
          post product_product_assets_path(product), params: vimeo_params
        }.to change(ProductAsset, :count).by(1)

        asset = ProductAsset.last
        expect(asset.info['url']).to eq('https://vimeo.com/123456789')
      end
    end

    context 'with missing required fields' do
      it 'validates name presence' do
        invalid_params = {
          asset: {
            product_asset_type: 'link',
            url: 'https://example.com'
          }
        }

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates product_asset_type presence' do
        file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
        invalid_params = {
          asset: {
            name: 'Test Asset',
            file: file
          }
        }

        expect {
          post product_product_assets_path(product), params: invalid_params
        }.not_to change(ProductAsset, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'scopes asset to correct product' do
      file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
      params = {
        asset: {
          name: 'Test Document',
          product_asset_type: 'document',
          file: file
        }
      }

      post product_product_assets_path(product), params: params
      asset = ProductAsset.last
      expect(asset.product).to eq(product)
    end

    it 'redirects with alert for other company product' do
      file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
      params = {
        asset: {
          name: 'Test',
          product_asset_type: 'document',
          file: file
        }
      }

      post product_product_assets_path(other_product), params: params
      expect(response).to redirect_to(products_path)
    end
  end

  describe 'GET /products/:product_id/product_assets/:id/edit' do
    let(:asset) { create(:product_asset, :document, product: product, name: 'Original Name') }

    it 'returns successful response' do
      get edit_product_product_asset_path(product, asset)
      expect(response).to be_successful
    end

    it 'renders edit form' do
      get edit_product_product_asset_path(product, asset)
      expect(response.body).to include('form')
      expect(response.body).to include('Original Name')
    end

    it 'populates URL field for link assets' do
      link_asset = create(:product_asset, :link, product: product)
      get edit_product_product_asset_path(product, link_asset)

      expect(assigns(:asset_url)).to eq(link_asset.info['url'])
    end

    it 'redirects for other company product' do
      other_asset = create(:product_asset, :document, product: other_product)

      get edit_product_product_asset_path(other_product, other_asset)
      expect(response).to redirect_to(products_path)
    end

    it 'redirects for non-existent asset' do
      get edit_product_product_asset_path(product, 999999)
      expect(response).to redirect_to(product_path(product, anchor: 'assets'))
    end
  end

  describe 'PATCH /products/:product_id/product_assets/:id' do
    let(:asset) { create(:product_asset, :document, product: product, name: 'Original Name', asset_priority: 10) }

    context 'with valid metadata update' do
      let(:update_params) do
        {
          asset: {
            name: 'Updated Name',
            asset_priority: 20,
            asset_description: 'Updated description',
            asset_visibility: 'private_visibility'
          }
        }
      end

      it 'updates asset metadata' do
        patch product_product_asset_path(product, asset), params: update_params
        asset.reload

        expect(asset.name).to eq('Updated Name')
        expect(asset.asset_priority).to eq(20)
        expect(asset.asset_description).to eq('Updated description')
        expect(asset.asset_visibility).to eq('private_visibility')
      end

      it 'redirects to product with success notice' do
        patch product_product_asset_path(product, asset), params: update_params
        expect(response).to redirect_to(product_path(product, anchor: 'assets'))
        follow_redirect!
        expect(response.body).to include('Asset updated successfully')
      end
    end

    context 'with link URL update' do
      let(:link_asset) { create(:product_asset, :link, product: product) }

      let(:update_params) do
        {
          asset: {
            name: 'Updated Link',
            url: 'https://updated-example.com'
          }
        }
      end

      it 'updates link URL in info' do
        patch product_product_asset_path(product, link_asset), params: update_params
        link_asset.reload

        expect(link_asset.name).to eq('Updated Link')
        expect(link_asset.info['url']).to eq('https://updated-example.com')
      end

      it 'validates URL format' do
        invalid_params = update_params.deep_dup
        invalid_params[:asset][:url] = 'invalid-url'

        patch product_product_asset_path(product, link_asset), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with file replacement' do
      let(:new_file) { fixture_file_upload(Rails.root.join('spec/fixtures/files/sample_updated.pdf'), 'application/pdf') }

      let(:update_params) do
        {
          asset: {
            name: 'Updated Document',
            file: new_file
          }
        }
      end

      it 'replaces attached file' do
        original_blob = asset.file.blob
        patch product_product_asset_path(product, asset), params: update_params
        asset.reload

        expect(asset.file).to be_attached
        expect(asset.file.blob).not_to eq(original_blob)
      end

      it 'validates new file type' do
        invalid_file = fixture_file_upload(Rails.root.join('spec/fixtures/files/invalid.exe'), 'application/octet-stream')
        invalid_params = update_params.deep_dup
        invalid_params[:asset][:file] = invalid_file

        patch product_product_asset_path(product, asset), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates new file size' do
        allow_any_instance_of(ActionDispatch::Http::UploadedFile).to receive(:size).and_return(30.megabytes)

        patch product_product_asset_path(product, asset), params: update_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'with invalid data' do
      it 'validates name presence' do
        invalid_params = { asset: { name: '' } }
        patch product_product_asset_path(product, asset), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'validates priority numericality' do
        invalid_params = { asset: { asset_priority: 'invalid' } }
        patch product_product_asset_path(product, asset), params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    it 'redirects for other company product' do
      other_asset = create(:product_asset, :document, product: other_product)
      params = { asset: { name: 'Hacked' } }

      patch product_product_asset_path(other_product, other_asset), params: params
      expect(response).to redirect_to(products_path)
    end
  end

  describe 'DELETE /products/:product_id/product_assets/:id' do
    let!(:asset) { create(:product_asset, :document, product: product, name: 'Test Document') }

    it 'deletes asset' do
      expect {
        delete product_product_asset_path(product, asset)
      }.to change(product.product_assets, :count).by(-1)
    end

    it 'redirects to product with success notice' do
      delete product_product_asset_path(product, asset)
      expect(response).to redirect_to(product_path(product, anchor: 'assets'))
      follow_redirect!
      expect(response.body).to include('deleted successfully')
      expect(response.body).to include('Test Document')
    end

    it 'purges attached file when deleting' do
      file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
      asset_with_file = create(:product_asset, :document, product: product)
      asset_with_file.file.attach(file)

      expect(asset_with_file.file).to be_attached
      delete product_product_asset_path(product, asset_with_file)
      expect(ActiveStorage::Blob.exists?(asset_with_file.file.blob.id)).to be false
    end

    it 'redirects for other company product' do
      other_asset = create(:product_asset, :document, product: other_product)

      delete product_product_asset_path(other_product, other_asset)
      expect(response).to redirect_to(products_path)
      expect(ProductAsset.exists?(other_asset.id)).to be true
    end

    it 'redirects for non-existent asset' do
      delete product_product_asset_path(product, 999999)
      expect(response).to redirect_to(product_path(product, anchor: 'assets'))
    end

    context 'with turbo_stream format' do
      it 'responds with turbo stream' do
        delete product_product_asset_path(product, asset), headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response).to be_successful
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'POST /products/:product_id/product_assets/reorder' do
    let!(:asset1) { create(:product_asset, :document, product: product, asset_priority: 10) }
    let!(:asset2) { create(:product_asset, :video, product: product, asset_priority: 20) }
    let!(:asset3) { create(:product_asset, :link, product: product, asset_priority: 30) }

    context 'with valid asset IDs' do
      let(:reorder_params) do
        { asset_ids: [asset3.id, asset1.id, asset2.id] }
      end

      it 'updates asset priorities in new order' do
        post reorder_product_product_assets_path(product), params: reorder_params, as: :json

        asset1.reload
        asset2.reload
        asset3.reload

        # First in array should have highest priority
        expect(asset3.asset_priority).to be > asset1.asset_priority
        expect(asset1.asset_priority).to be > asset2.asset_priority
      end

      it 'returns JSON success response' do
        post reorder_product_product_assets_path(product), params: reorder_params, as: :json
        expect(response).to be_successful
        expect(JSON.parse(response.body)['success']).to be true
        expect(JSON.parse(response.body)['message']).to eq('Assets reordered successfully')
      end

      it 'sets priority with proper spacing' do
        post reorder_product_product_assets_path(product), params: reorder_params, as: :json

        asset1.reload
        asset2.reload
        asset3.reload

        # Priority should be spaced by 10
        expect(asset3.asset_priority).to eq(30) # 3 * 10
        expect(asset1.asset_priority).to eq(20) # 2 * 10
        expect(asset2.asset_priority).to eq(10) # 1 * 10
      end
    end

    context 'with invalid parameters' do
      it 'validates asset_ids parameter is an array' do
        post reorder_product_product_assets_path(product), params: { asset_ids: 'not-an-array' }, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('Invalid asset_ids parameter')
      end

      it 'rejects asset IDs not belonging to product' do
        other_asset = create(:product_asset, :document, product: other_product)
        invalid_params = { asset_ids: [asset1.id, other_asset.id] }

        post reorder_product_product_assets_path(product), params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('Invalid asset IDs')
      end

      it 'rejects non-existent asset IDs' do
        invalid_params = { asset_ids: [asset1.id, 999999] }

        post reorder_product_product_assets_path(product), params: invalid_params, as: :json
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)['error']).to include('Invalid asset IDs')
      end
    end

    context 'with partial reordering' do
      it 'allows reordering subset of assets' do
        reorder_params = { asset_ids: [asset2.id, asset1.id] }

        post reorder_product_product_assets_path(product), params: reorder_params, as: :json
        expect(response).to be_successful

        asset1.reload
        asset2.reload

        expect(asset2.asset_priority).to be > asset1.asset_priority
      end
    end

    it 'returns 404 for other company product (JSON)' do
      params = { asset_ids: [asset1.id] }

      post reorder_product_product_assets_path(other_product), params: params, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'multi-tenancy isolation' do
    it 'prevents accessing assets from other companies' do
      other_asset = create(:product_asset, :document, product: other_product)

      # Index - should not see other company assets
      get product_product_assets_path(product)
      expect(response.body).not_to include(other_asset.name)

      # Edit - should redirect for other company
      get edit_product_product_asset_path(other_product, other_asset)
      expect(response).to redirect_to(products_path)

      # Update - should redirect for other company
      patch product_product_asset_path(other_product, other_asset), params: { asset: { name: 'Hacked' } }
      expect(response).to redirect_to(products_path)

      # Delete - should redirect for other company
      delete product_product_asset_path(other_product, other_asset)
      expect(response).to redirect_to(products_path)
    end

    it 'scopes new assets to current company via product' do
      file = fixture_file_upload(Rails.root.join('spec/fixtures/files/sample.pdf'), 'application/pdf')
      params = {
        asset: {
          name: 'Test Document',
          product_asset_type: 'document',
          file: file
        }
      }

      post product_product_assets_path(product), params: params
      asset = ProductAsset.last
      expect(asset.product.company).to eq(company)
    end
  end
end
