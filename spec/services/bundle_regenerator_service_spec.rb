# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BundleRegeneratorService, type: :service do
  let(:company) { create(:company) }
  let(:bundle) { create(:product, :bundle, company: company, sku: 'BUNDLE') }
  let(:sellable1) { create(:product, :sellable, company: company) }
  let(:sellable2) { create(:product, :sellable, company: company) }
  let(:sellable3) { create(:product, :sellable, company: company) }

  let(:original_config) do
    {
      'components' => [
        { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
        { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
      ]
    }
  end

  let(:new_config) do
    {
      'components' => [
        { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
        { 'product_id' => sellable3.id, 'product_type' => 'sellable', 'quantity' => 1 }
      ]
    }
  end

  before do
    # Generate original variants
    BundleVariantGeneratorService.new(bundle, original_config).call
  end

  describe '#call' do
    it 'soft deletes old variants' do
      old_variant = bundle.bundle_variants.first

      described_class.new(bundle, new_config).call

      old_variant.reload
      expect(old_variant.product_status).to eq('deleted')
      expect(old_variant.deleted_at).to be_present
    end

    it 'generates new variants' do
      result = described_class.new(bundle, new_config).call

      expect(result.success?).to be true
      expect(result.created_count).to eq(1)
    end

    it 'returns deleted and created counts' do
      result = described_class.new(bundle, new_config).call

      expect(result.deleted_count).to eq(1)
      expect(result.created_count).to eq(1)
    end

    it 'updates bundle template' do
      described_class.new(bundle, new_config).call

      template = bundle.reload.bundle_template
      expect(template.configuration).to eq(new_config)
    end

    it 'keeps old variants linked to bundle' do
      old_variant_id = bundle.bundle_variants.first.id

      described_class.new(bundle, new_config).call

      old_variant = Product.find(old_variant_id)
      expect(old_variant.parent_bundle_id).to eq(bundle.id)
    end

    it 'stores replacement metadata in old variant info' do
      old_variant = bundle.bundle_variants.first

      described_class.new(bundle, new_config).call

      old_variant.reload
      expect(old_variant.info['replaced_by_regeneration']).to be true
      expect(old_variant.info['replaced_at']).to be_present
    end

    context 'when validation fails' do
      let(:invalid_config) do
        { 'components' => [] }
      end

      it 'does not delete old variants' do
        expect {
          described_class.new(bundle, invalid_config).call
        }.not_to change { bundle.bundle_variants.where.not(product_status: :deleted).count }
      end

      it 'returns failure' do
        result = described_class.new(bundle, invalid_config).call
        expect(result.success?).to be false
      end

      it 'returns validation errors' do
        result = described_class.new(bundle, invalid_config).call
        expect(result.errors).to be_present
      end
    end

    context 'with multiple existing variants' do
      let(:configurable) { create(:product, :configurable_variant, company: company) }
      let(:variant_s) { create(:product, :sellable, company: company) }
      let(:variant_m) { create(:product, :sellable, company: company) }

      before do
        # Set up configurable with variants
        configurable.product_configurations_as_super.create!(
          subproduct: variant_s,
          info: { 'variant_config' => { 'size' => 'Small' } }
        )
        configurable.product_configurations_as_super.create!(
          subproduct: variant_m,
          info: { 'variant_config' => { 'size' => 'Medium' } }
        )

        # Create multi-variant configuration
        multi_variant_config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
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

        # Clear existing variants and generate new multi-variant setup
        bundle.bundle_variants.destroy_all
        bundle.reload
        result = BundleVariantGeneratorService.new(bundle, multi_variant_config).call
        raise "Failed to generate variants: #{result.errors.inspect}" unless result.success?
      end

      it 'deletes all old variants' do
        expect(bundle.bundle_variants.count).to eq(2)

        described_class.new(bundle, new_config).call

        # Should have 2 deleted + 1 new = 3 total (including deleted)
        expect(bundle.reload.bundle_variants.count).to eq(3)
        expect(bundle.bundle_variants.where(product_status: :deleted).count).to eq(2)
        expect(bundle.bundle_variants.where.not(product_status: :deleted).count).to eq(1)
      end

      it 'returns correct deleted count' do
        result = described_class.new(bundle, new_config).call

        expect(result.deleted_count).to eq(2)
      end
    end

    context 'transaction rollback' do
      it 'rolls back if variant generation fails' do
        # Create a scenario where generation might fail
        allow_any_instance_of(BundleVariantGeneratorService).to receive(:call)
          .and_return(BundleVariantGeneratorService::Result.new(success?: false, variants: [], errors: ['Generation failed']))

        initial_variant_count = bundle.bundle_variants.where.not(product_status: :deleted).count

        described_class.new(bundle, new_config).call

        # Old variants should not be deleted if transaction rolled back
        expect(bundle.bundle_variants.where.not(product_status: :deleted).count).to eq(initial_variant_count)
      end
    end
  end
end
