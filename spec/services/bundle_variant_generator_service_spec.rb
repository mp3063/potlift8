# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BundleVariantGeneratorService, type: :service do
  let(:company) { create(:company) }
  let(:bundle_product) { create(:product, :bundle, company: company, sku: 'BUNDLE-001', name: 'Starter Kit') }

  describe '#initialize' do
    it 'initializes with a bundle product and configuration' do
      configuration = { 'components' => [] }
      service = BundleVariantGeneratorService.new(bundle_product, configuration)
      expect(service).to be_present
    end
  end

  describe '#call' do
    context 'with invalid product type' do
      let(:sellable_product) { create(:product, :sellable, company: company) }
      let(:configuration) { { 'components' => [] } }

      it 'returns failure result' do
        service = BundleVariantGeneratorService.new(sellable_product, configuration)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to include('Product must be a bundle type')
        expect(result.variants).to be_empty
      end
    end

    context 'with invalid configuration' do
      let(:invalid_config) { { 'components' => [] } }

      it 'returns failure result with validation errors' do
        service = BundleVariantGeneratorService.new(bundle_product, invalid_config)
        result = service.call

        expect(result.success?).to be false
        expect(result.errors).to be_present
        expect(result.variants).to be_empty
      end
    end

    context 'with sellable products only' do
      let!(:sellable1) { create(:product, :sellable, company: company, sku: 'SELL-001') }
      let!(:sellable2) { create(:product, :sellable, company: company, sku: 'SELL-002') }
      let(:configuration) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'generates one bundle variant' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true
        expect(result.errors).to be_empty
        expect(result.variants.count).to eq(1)
      end

      it 'creates bundle variant product with correct attributes' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        variant = result.variants.first
        expect(variant.product_type_bundle?).to be true
        expect(variant.bundle_variant).to be true
        expect(variant.parent_bundle).to eq(bundle_product)
        expect(variant.company).to eq(company)
      end

      it 'generates SKU for the variant' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        variant = result.variants.first
        expect(variant.sku).to eq('BUNDLE-001-V1')
      end

      it 'creates ProductConfiguration records linking variant to components' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        variant = result.variants.first
        configs = variant.product_configurations_as_super.to_a

        expect(configs.count).to eq(2)

        # Check quantities are stored in info
        sellable1_config = configs.find { |c| c.subproduct_id == sellable1.id }
        sellable2_config = configs.find { |c| c.subproduct_id == sellable2.id }

        expect(sellable1_config.info['quantity']).to eq(2)
        expect(sellable2_config.info['quantity']).to eq(1)
      end

      it 'creates/updates BundleTemplate' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true

        bundle_template = bundle_product.reload.bundle_template
        expect(bundle_template).to be_present
        expect(bundle_template.configuration).to eq(configuration)
        expect(bundle_template.generated_variants_count).to eq(1)
        expect(bundle_template.last_generated_at).to be_present
      end
    end

    context 'with single configurable and sellable' do
      let!(:sellable) { create(:product, :sellable, company: company, sku: 'SELL-001') }
      let!(:configurable) { create(:product, :configurable_variant, company: company, sku: 'CONF-001') }
      let!(:variant_small) { create(:product, :sellable, company: company, sku: 'VAR-S') }
      let!(:variant_medium) { create(:product, :sellable, company: company, sku: 'VAR-M') }
      let!(:variant_large) { create(:product, :sellable, company: company, sku: 'VAR-L') }

      before do
        # Link variants to configurable using ProductConfiguration
        configurable.product_configurations_as_super.create!(
          subproduct: variant_small,
          info: { 'variant_config' => { 'size' => 'Small' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_medium,
          info: { 'variant_config' => { 'size' => 'Medium' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_large,
          info: { 'variant_config' => { 'size' => 'Large' } }
        )
      end

      let(:configuration) do
        {
          'components' => [
            { 'product_id' => sellable.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant_small.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => variant_medium.id, 'included' => true, 'quantity' => 1, 'code' => 'M' },
                { 'variant_id' => variant_large.id, 'included' => true, 'quantity' => 1, 'code' => 'L' }
              ]
            }
          ]
        }
      end

      it 'generates 3 bundle variants (one per configurable variant)' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(3)
      end

      it 'generates unique SKUs for each variant with variant codes' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        skus = result.variants.map(&:sku).sort
        expect(skus).to eq(['BUNDLE-001-L', 'BUNDLE-001-M', 'BUNDLE-001-S'])
      end

      it 'creates correct ProductConfiguration records for each variant' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        # Each bundle variant should have 2 components (sellable + one configurable variant)
        result.variants.each do |variant|
          configs = variant.product_configurations_as_super.to_a
          expect(configs.count).to eq(2)

          # Should have the sellable
          sellable_config = configs.find { |c| c.subproduct_id == sellable.id }
          expect(sellable_config).to be_present
          expect(sellable_config.info['quantity']).to eq(1)

          # Should have one of the configurable variants
          variant_config = configs.find { |c| c.subproduct_id.in?([variant_small.id, variant_medium.id, variant_large.id]) }
          expect(variant_config).to be_present
          expect(variant_config.info['quantity']).to eq(1)
        end
      end

      it 'updates BundleTemplate with correct count' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        bundle_template = bundle_product.reload.bundle_template
        expect(bundle_template.generated_variants_count).to eq(3)
      end
    end

    context 'with multiple configurables (cartesian product)' do
      let!(:configurable1) { create(:product, :configurable_variant, company: company, sku: 'CONF-1') }
      let!(:configurable2) { create(:product, :configurable_variant, company: company, sku: 'CONF-2') }

      # Configurable 1 variants (size)
      let!(:conf1_var_s) { create(:product, :sellable, company: company, sku: 'C1-S') }
      let!(:conf1_var_m) { create(:product, :sellable, company: company, sku: 'C1-M') }

      # Configurable 2 variants (color)
      let!(:conf2_var_red) { create(:product, :sellable, company: company, sku: 'C2-R') }
      let!(:conf2_var_blue) { create(:product, :sellable, company: company, sku: 'C2-B') }

      before do
        # Link variants to configurable 1
        configurable1.product_configurations_as_super.create!(
          subproduct: conf1_var_s,
          info: { 'variant_config' => { 'size' => 'Small' } }
        )
        configurable1.product_configurations_as_super.create!(
          subproduct: conf1_var_m,
          info: { 'variant_config' => { 'size' => 'Medium' } }
        )

        # Link variants to configurable 2
        configurable2.product_configurations_as_super.create!(
          subproduct: conf2_var_red,
          info: { 'variant_config' => { 'color' => 'Red' } }
        )
        configurable2.product_configurations_as_super.create!(
          subproduct: conf2_var_blue,
          info: { 'variant_config' => { 'color' => 'Blue' } }
        )
      end

      let(:configuration) do
        {
          'components' => [
            {
              'product_id' => configurable1.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => conf1_var_s.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => conf1_var_m.id, 'included' => true, 'quantity' => 1, 'code' => 'M' }
              ]
            },
            {
              'product_id' => configurable2.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => conf2_var_red.id, 'included' => true, 'quantity' => 1, 'code' => 'RED' },
                { 'variant_id' => conf2_var_blue.id, 'included' => true, 'quantity' => 1, 'code' => 'BLU' }
              ]
            }
          ]
        }
      end

      it 'generates 4 bundle variants (2 × 2 = 4 combinations)' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(4)
      end

      it 'generates unique SKUs with all variant codes' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        skus = result.variants.map(&:sku).sort
        expect(skus).to eq([
          'BUNDLE-001-BLU-M',
          'BUNDLE-001-BLU-S',
          'BUNDLE-001-RED-M',
          'BUNDLE-001-RED-S'
        ])
      end

      it 'creates all combinations correctly' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        # Verify all 4 combinations exist
        result.variants.each do |variant|
          configs = variant.product_configurations_as_super.to_a
          expect(configs.count).to eq(2)

          # Should have one variant from configurable1 and one from configurable2
          conf1_variant_ids = [conf1_var_s.id, conf1_var_m.id]
          conf2_variant_ids = [conf2_var_red.id, conf2_var_blue.id]

          conf1_config = configs.find { |c| c.subproduct_id.in?(conf1_variant_ids) }
          conf2_config = configs.find { |c| c.subproduct_id.in?(conf2_variant_ids) }

          expect(conf1_config).to be_present
          expect(conf2_config).to be_present
        end
      end
    end

    context 'excludes non-included variants' do
      let!(:sellable) { create(:product, :sellable, company: company, sku: 'SELL-001') }
      let!(:configurable) { create(:product, :configurable_variant, company: company, sku: 'CONF-001') }
      let!(:variant_s) { create(:product, :sellable, company: company, sku: 'VAR-S') }
      let!(:variant_m) { create(:product, :sellable, company: company, sku: 'VAR-M') }
      let!(:variant_l) { create(:product, :sellable, company: company, sku: 'VAR-L') }

      before do
        configurable.product_configurations_as_super.create!(
          subproduct: variant_s,
          info: { 'variant_config' => { 'size' => 'Small' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_m,
          info: { 'variant_config' => { 'size' => 'Medium' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_l,
          info: { 'variant_config' => { 'size' => 'Large' } }
        )
      end

      let(:configuration) do
        {
          'components' => [
            { 'product_id' => sellable.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant_s.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => variant_m.id, 'included' => false, 'quantity' => 1, 'code' => 'M' },
                { 'variant_id' => variant_l.id, 'included' => true, 'quantity' => 1, 'code' => 'L' }
              ]
            }
          ]
        }
      end

      it 'only generates variants for included=true' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(2) # Only S and L

        skus = result.variants.map(&:sku).sort
        expect(skus).to eq(['BUNDLE-001-L', 'BUNDLE-001-S'])
      end
    end

    context 'updating existing BundleTemplate' do
      let!(:existing_template) do
        bundle_product.create_bundle_template!(
          company: company,
          configuration: { 'old' => 'config' },
          generated_variants_count: 5,
          last_generated_at: 1.day.ago
        )
      end

      let!(:sellable1) { create(:product, :sellable, company: company, sku: 'SELL-001') }
      let!(:sellable2) { create(:product, :sellable, company: company, sku: 'SELL-002') }
      let(:configuration) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'updates existing template instead of creating new one' do
        expect {
          service = BundleVariantGeneratorService.new(bundle_product, configuration)
          service.call
        }.not_to change { BundleTemplate.count }
      end

      it 'updates template with new configuration and counts' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        template = bundle_product.reload.bundle_template
        expect(template.id).to eq(existing_template.id)
        expect(template.configuration).to eq(configuration)
        expect(template.generated_variants_count).to eq(1)
        expect(template.last_generated_at).to be >= existing_template.last_generated_at
      end
    end

    context 'mixed sellables and configurables' do
      let!(:sellable1) { create(:product, :sellable, company: company, sku: 'SELL-001') }
      let!(:sellable2) { create(:product, :sellable, company: company, sku: 'SELL-002') }
      let!(:configurable) { create(:product, :configurable_variant, company: company, sku: 'CONF-001') }
      let!(:variant_s) { create(:product, :sellable, company: company, sku: 'VAR-S') }
      let!(:variant_m) { create(:product, :sellable, company: company, sku: 'VAR-M') }

      before do
        configurable.product_configurations_as_super.create!(
          subproduct: variant_s,
          info: { 'variant_config' => { 'size' => 'Small' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_m,
          info: { 'variant_config' => { 'size' => 'Medium' } }
        )
      end

      let(:configuration) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant_s.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => variant_m.id, 'included' => true, 'quantity' => 1, 'code' => 'M' }
              ]
            }
          ]
        }
      end

      it 'generates 2 bundle variants with correct component links' do
        service = BundleVariantGeneratorService.new(bundle_product, configuration)
        result = service.call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(2)

        # Each variant should have 3 components (2 sellables + 1 configurable variant)
        result.variants.each do |variant|
          configs = variant.product_configurations_as_super.to_a
          expect(configs.count).to eq(3)

          # Check sellables are linked with correct quantities
          s1_config = configs.find { |c| c.subproduct_id == sellable1.id }
          s2_config = configs.find { |c| c.subproduct_id == sellable2.id }
          expect(s1_config.info['quantity']).to eq(2)
          expect(s2_config.info['quantity']).to eq(1)
        end
      end
    end
  end
end
