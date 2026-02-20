# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Bundle Products', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    # Set up authenticated session
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

  describe 'POST /products - creating bundle with configuration' do
    let!(:sellable1) { create(:product, company: company, sku: 'COMP1', product_type: :sellable) }
    let!(:sellable2) { create(:product, company: company, sku: 'COMP2', product_type: :sellable) }

    let(:valid_bundle_attributes) do
      {
        sku: 'BUNDLE001',
        name: 'Test Bundle',
        product_type: :bundle,
        product_status: :draft
      }
    end

    context 'with valid bundle configuration (sellables only)' do
      let(:bundle_config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }.to_json
      end

      it 'creates bundle and generates variants' do
        initial_count = Product.count # Count after let! creates component products

        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config
        }

        expect(Product.count).to eq(initial_count + 2) # 1 bundle + 1 variant
      end

      it 'creates BundleTemplate with configuration' do
        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config
        }

        bundle = Product.find_by(sku: 'BUNDLE001')
        expect(bundle.bundle_template).to be_present
        expect(bundle.bundle_template.configuration['components'].count).to eq(2)
        expect(bundle.bundle_template.generated_variants_count).to eq(1)
      end

      it 'creates variant with correct associations' do
        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config
        }

        bundle = Product.find_by(sku: 'BUNDLE001')
        variant = bundle.bundle_variants.first

        expect(variant).to be_present
        expect(variant.bundle_variant).to be true
        expect(variant.parent_bundle).to eq(bundle)
        expect(variant.product_configurations_as_super.count).to eq(2)
      end

      it 'redirects with success message including variant count' do
        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config
        }

        expect(response).to redirect_to(products_path)
        follow_redirect!
        expect(response.body).to include('Product created successfully')
      end
    end

    context 'with configurable components' do
      let!(:configurable) do
        create(:product, company: company, sku: 'CONFIG1', product_type: :configurable, configuration_type: :variant)
      end
      let!(:variant1) do
        create(:product_configuration,
               superproduct: configurable,
               subproduct: create(:product, company: company, sku: 'VAR-S', product_type: :sellable),
               info: { 'variant_config' => { 'size' => 'Small' } })
      end
      let!(:variant2) do
        create(:product_configuration,
               superproduct: configurable,
               subproduct: create(:product, company: company, sku: 'VAR-M', product_type: :sellable),
               info: { 'variant_config' => { 'size' => 'Medium' } })
      end

      let(:bundle_config_with_variants) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant1.subproduct_id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => variant2.subproduct_id, 'included' => true, 'quantity' => 1, 'code' => 'M' }
              ]
            }
          ]
        }.to_json
      end

      it 'generates multiple variants for configurable combinations' do
        initial_count = Product.count

        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config_with_variants
        }

        expect(response).to have_http_status(:redirect)
        expect(Product.count).to eq(initial_count + 3) # 1 bundle + 2 variants
      end

      it 'creates variants with correct SKU patterns' do
        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: bundle_config_with_variants
        }

        bundle = Product.find_by(sku: 'BUNDLE001')
        variants = bundle.bundle_variants.order(:sku)

        expect(variants.count).to eq(2)
        expect(variants.first.sku).to eq('BUNDLE001-M') # Reversed order
        expect(variants.second.sku).to eq('BUNDLE001-S')
      end
    end

    context 'with invalid configuration' do
      let(:invalid_config) do
        {
          'components' => [
            { 'product_id' => 999999, 'product_type' => 'sellable', 'quantity' => 1 } # Non-existent product
          ]
        }.to_json
      end

      it 'does not create bundle when configuration is invalid' do
        expect {
          post products_path, params: {
            product: valid_bundle_attributes,
            bundle_configuration: invalid_config
          }
        }.not_to change(Product, :count)
      end

      it 'renders new template with errors' do
        post products_path, params: {
          product: valid_bundle_attributes,
          bundle_configuration: invalid_config
        }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('error')
      end
    end

    context 'without bundle configuration' do
      it 'creates bundle without generating variants' do
        expect {
          post products_path, params: { product: valid_bundle_attributes }
        }.to change(Product, :count).by(1)

        bundle = Product.last
        expect(bundle.bundle_variants.count).to eq(0)
        expect(bundle.bundle_template).to be_nil
      end
    end

    context 'creating non-bundle product' do
      let(:sellable_attributes) do
        {
          sku: 'SELL001',
          name: 'Sellable Product',
          product_type: :sellable,
          product_status: :draft
        }
      end

      it 'ignores bundle_configuration for non-bundle products' do
        bundle_config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }.to_json

        expect {
          post products_path, params: {
            product: sellable_attributes,
            bundle_configuration: bundle_config
          }
        }.to change(Product, :count).by(1) # Only the sellable product

        product = Product.last
        expect(product.product_type_bundle?).to be false
        expect(product.bundle_variants.count).to eq(0)
      end
    end
  end

  describe 'PATCH /products/:id - updating bundle with regeneration' do
    let(:bundle) { create(:product, company: company, sku: 'BUNDLE002', product_type: :bundle) }
    let!(:sellable1) { create(:product, company: company, sku: 'COMP3', product_type: :sellable) }
    let!(:sellable2) { create(:product, company: company, sku: 'COMP4', product_type: :sellable) }

    let!(:existing_variant) do
      variant = create(:product,
                      company: company,
                      sku: 'BUNDLE002-V1',
                      product_type: :bundle,
                      bundle_variant: true,
                      parent_bundle: bundle)
      create(:product_configuration,
             superproduct: variant,
             subproduct: sellable1,
             info: { 'quantity' => 1 })
      variant
    end

    let!(:bundle_template) do
      create(:bundle_template,
             company: company,
             product: bundle,
             configuration: {
               'components' => [
                 { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 }
               ]
             },
             generated_variants_count: 1)
    end

    context 'with regenerate flag' do
      let(:new_config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }.to_json
      end

      it 'soft-deletes old variants and creates new ones' do
        initial_count = Product.count

        patch product_path(bundle), params: {
          product: { name: 'Updated Bundle' },
          regenerate: 'true',
          bundle_configuration: new_config
        }

        expect(Product.count).to eq(initial_count + 1) # 1 new variant, old one soft-deleted

        existing_variant.reload
        expect(existing_variant.product_status).to eq('deleted')
        expect(existing_variant.deleted_at).to be_present

        new_variant = bundle.bundle_variants.where.not(product_status: :deleted).first
        expect(new_variant).to be_present
        expect(new_variant.product_configurations_as_super.count).to eq(2)
      end

      it 'updates BundleTemplate with new configuration' do
        patch product_path(bundle), params: {
          product: { name: 'Updated Bundle' },
          regenerate: 'true',
          bundle_configuration: new_config
        }

        bundle_template.reload
        expect(bundle_template.configuration['components'].count).to eq(2)
        expect(bundle_template.generated_variants_count).to eq(1)
        expect(bundle_template.last_generated_at).to be_present
      end

      it 'redirects with success message' do
        patch product_path(bundle), params: {
          product: { name: 'Updated Bundle' },
          regenerate: 'true',
          bundle_configuration: new_config
        }

        expect(response).to redirect_to(products_path)
        follow_redirect!
        expect(response.body).to include('Product updated successfully')
      end
    end

    context 'without regenerate flag' do
      it 'does not regenerate variants' do
        original_variant_count = bundle.bundle_variants.count

        patch product_path(bundle), params: {
          product: { name: 'Updated Bundle' }
        }

        expect(bundle.bundle_variants.count).to eq(original_variant_count)

        existing_variant.reload
        expect(existing_variant.product_status).not_to eq('deleted')
      end

      it 'ignores bundle_configuration without regenerate flag' do
        new_config = {
          'components' => [
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 5 }
          ]
        }.to_json

        patch product_path(bundle), params: {
          product: { name: 'Updated Bundle' },
          bundle_configuration: new_config
        }

        bundle_template.reload
        expect(bundle_template.configuration['components'].first['quantity']).to eq(1) # Unchanged
      end
    end

    context 'with invalid regeneration configuration' do
      let(:invalid_config) do
        {
          'components' => [
            { 'product_id' => 999999, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }.to_json
      end

      it 'does not update bundle or variants when regeneration fails' do
        original_name = bundle.name

        patch product_path(bundle), params: {
          product: { name: 'Should Not Update' },
          regenerate: 'true',
          bundle_configuration: invalid_config
        }

        expect(response).to have_http_status(:unprocessable_entity)

        bundle.reload
        expect(bundle.name).to eq(original_name)

        existing_variant.reload
        expect(existing_variant.product_status).not_to eq('deleted')
      end
    end

    context 'updating non-bundle product' do
      let(:sellable) { create(:product, company: company, product_type: :sellable) }

      it 'ignores regenerate flag for non-bundle products' do
        patch product_path(sellable), params: {
          product: { name: 'Updated Sellable' },
          regenerate: 'true',
          bundle_configuration: '{"components": []}'
        }

        expect(response).to redirect_to(products_path)
        sellable.reload
        expect(sellable.name).to eq('Updated Sellable')
      end
    end
  end

  describe 'bundle_configuration parameter parsing' do
    let(:bundle) { create(:product, company: company, product_type: :bundle) }

    context 'with malformed JSON' do
      it 'handles invalid JSON gracefully' do
        post products_path, params: {
          product: { sku: 'TEST', name: 'Test', product_type: :bundle },
          bundle_configuration: 'invalid json{'
        }

        # Should create bundle without variants (empty config)
        expect(Product.last.product_type_bundle?).to be true
        expect(Product.last.bundle_variants.count).to eq(0)
      end
    end

    context 'with empty configuration' do
      it 'treats empty string as no configuration' do
        post products_path, params: {
          product: { sku: 'TEST', name: 'Test', product_type: :bundle },
          bundle_configuration: ''
        }

        expect(Product.last.bundle_variants.count).to eq(0)
      end

      it 'treats empty JSON object as no configuration' do
        post products_path, params: {
          product: { sku: 'TEST', name: 'Test', product_type: :bundle },
          bundle_configuration: '{}'
        }

        expect(Product.last.bundle_variants.count).to eq(0)
      end
    end
  end
end
