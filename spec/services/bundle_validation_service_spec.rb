# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BundleValidationService do
  let(:company) { create(:company) }
  let(:sellable1) { create(:product, :sellable, company: company) }
  let(:sellable2) { create(:product, :sellable, company: company) }
  let(:sellable3) { create(:product, :sellable, company: company) }
  let(:configurable) { create(:product, :configurable_variant, company: company) }
  let(:discontinued_product) { create(:product, :sellable, :discontinued, company: company) }

  let!(:config1) { create(:configuration, product: configurable, code: 'size', name: 'Size') }
  let!(:config_value1) { create(:configuration_value, configuration: config1, value: 'Small') }
  let!(:config_value2) { create(:configuration_value, configuration: config1, value: 'Medium') }

  let!(:variant1) { create(:product, :sellable, company: company, sku: 'VAR-S') }
  let!(:variant2) { create(:product, :sellable, company: company, sku: 'VAR-M') }
  let!(:variant3) { create(:product, :sellable, :discontinued, company: company, sku: 'VAR-DISC') }

  let!(:pc1) do
    create(:product_configuration,
           superproduct: configurable,
           subproduct: variant1,
           info: { 'variant_config' => { 'size' => 'Small' } })
  end

  let!(:pc2) do
    create(:product_configuration,
           superproduct: configurable,
           subproduct: variant2,
           info: { 'variant_config' => { 'size' => 'Medium' } })
  end

  let!(:pc3) do
    create(:product_configuration,
           superproduct: configurable,
           subproduct: variant3,
           info: { 'variant_config' => { 'size' => 'Large' } })
  end

  describe '#initialize' do
    it 'accepts configuration and company' do
      config = { 'components' => [] }
      service = described_class.new(config, company: company)

      expect(service).to be_a(described_class)
    end
  end

  describe '#valid?' do
    context 'with minimum valid configuration (2 sellable products)' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'returns true' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be true
      end

      it 'has no errors' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to be_empty
      end
    end

    context 'with less than 2 products' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds error message' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Bundle must contain at least 2 products')
      end
    end

    context 'with no products' do
      let(:config) do
        { 'components' => [] }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end
    end

    context 'with duplicate products' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 }
          ]
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds duplicate error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Duplicate product found in bundle')
      end
    end

    context 'with non-existent product' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => 999999, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds product not found error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Product with ID 999999 not found')
      end
    end

    context 'with discontinued product' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => discontinued_product.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds discontinued error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include("Product '#{discontinued_product.sku}' is discontinued")
      end
    end

    context 'with invalid quantity' do
      context 'quantity less than 1' do
        let(:config) do
          {
            'components' => [
              { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 0 },
              { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
            ]
          }
        end

        it 'returns false' do
          service = described_class.new(config, company: company)
          expect(service.valid?).to be false
        end

        it 'adds quantity error' do
          service = described_class.new(config, company: company)
          service.valid?
          expect(service.errors).to include("Product '#{sellable1.sku}' quantity must be between 1 and 99")
        end
      end

      context 'quantity greater than 99' do
        let(:config) do
          {
            'components' => [
              { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 100 },
              { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
            ]
          }
        end

        it 'returns false' do
          service = described_class.new(config, company: company)
          expect(service.valid?).to be false
        end
      end
    end

    context 'with too many sellable products' do
      let(:config) do
        {
          'components' => (1..11).map do |i|
            product = create(:product, :sellable, company: company)
            { 'product_id' => product.id, 'product_type' => 'sellable', 'quantity' => 1 }
          end
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds too many sellables error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Bundle cannot contain more than 10 sellable products')
      end
    end

    context 'with too many configurable products' do
      let(:configurable2) { create(:product, :configurable_variant, company: company) }
      let(:configurable3) { create(:product, :configurable_variant, company: company) }
      let(:configurable4) { create(:product, :configurable_variant, company: company) }

      let(:config) do
        {
          'components' => [
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [ { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 } ]
            },
            {
              'product_id' => configurable2.id,
              'product_type' => 'configurable',
              'variants' => [ { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 } ]
            },
            {
              'product_id' => configurable3.id,
              'product_type' => 'configurable',
              'variants' => [ { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 } ]
            },
            {
              'product_id' => configurable4.id,
              'product_type' => 'configurable',
              'variants' => [ { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 } ]
            }
          ]
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds too many configurables error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Bundle cannot contain more than 3 configurable products')
      end
    end

    context 'with too many total products' do
      let(:config) do
        {
          'components' => (1..13).map do |i|
            product = create(:product, :sellable, company: company)
            { 'product_id' => product.id, 'product_type' => 'sellable', 'quantity' => 1 }
          end
        }
      end

      it 'returns false' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds too many products error' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include('Bundle cannot contain more than 12 total products')
      end
    end

    context 'with configurable product' do
      context 'with at least one variant selected' do
        let(:config) do
          {
            'components' => [
              { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
              {
                'product_id' => configurable.id,
                'product_type' => 'configurable',
                'variants' => [
                  { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 }
                ]
              }
            ]
          }
        end

        it 'returns true' do
          service = described_class.new(config, company: company)
          expect(service.valid?).to be true
        end
      end

      context 'with no variants selected' do
        let(:config) do
          {
            'components' => [
              { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
              {
                'product_id' => configurable.id,
                'product_type' => 'configurable',
                'variants' => []
              }
            ]
          }
        end

        it 'returns false' do
          service = described_class.new(config, company: company)
          expect(service.valid?).to be false
        end

        it 'adds no variants error' do
          service = described_class.new(config, company: company)
          service.valid?
          expect(service.errors).to include("Configurable product '#{configurable.sku}' must have at least one variant selected")
        end
      end

      context 'with all variants excluded' do
        let(:config) do
          {
            'components' => [
              { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
              {
                'product_id' => configurable.id,
                'product_type' => 'configurable',
                'variants' => [
                  { 'variant_id' => variant1.id, 'included' => false, 'quantity' => 1 }
                ]
              }
            ]
          }
        end

        it 'returns false' do
          service = described_class.new(config, company: company)
          expect(service.valid?).to be false
        end
      end
    end
  end

  describe '#errors' do
    it 'returns empty array by default' do
      config = { 'components' => [] }
      service = described_class.new(config, company: company)
      expect(service.errors).to eq([])
    end

    it 'collects multiple errors' do
      config = {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 0 },
          { 'product_id' => 999999, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
      service = described_class.new(config, company: company)
      service.valid?

      expect(service.errors.size).to be >= 2
      expect(service.errors).to include("Product '#{sellable1.sku}' quantity must be between 1 and 99")
      expect(service.errors).to include('Product with ID 999999 not found')
    end
  end

  describe '#warnings' do
    context 'with discontinued variant in configurable' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 },
                { 'variant_id' => variant3.id, 'included' => true, 'quantity' => 1 }
              ]
            }
          ]
        }
      end

      it 'returns warning about discontinued variant' do
        service = described_class.new(config, company: company)
        service.valid?

        expect(service.warnings).to include("Variant '#{variant3.sku}' is discontinued and will be skipped")
      end

      it 'still validates as true' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be true
      end
    end

    context 'with combination count over 100' do
      let(:config2) { create(:configuration, product: configurable, code: 'color', name: 'Color') }
      let!(:color_values) do
        11.times.map { |i| create(:configuration_value, configuration: config2, value: "Color#{i}") }
      end

      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => (1..150).map { |i|
                variant = create(:product, :sellable, company: company)
                create(:product_configuration,
                       superproduct: configurable,
                       subproduct: variant,
                       info: { 'variant_config' => { 'size' => "Size#{i}" } })
                { 'variant_id' => variant.id, 'included' => true, 'quantity' => 1 }
              }
            }
          ]
        }
      end

      it 'returns warning about high combination count' do
        service = described_class.new(config, company: company)
        service.valid?

        expect(service.warnings).to include(/will generate \d+ combinations which may take time/)
      end
    end
  end

  describe '#combination_count' do
    context 'with sellable products only' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'returns 1' do
        service = described_class.new(config, company: company)
        expect(service.combination_count).to eq(1)
      end
    end

    context 'with one configurable product' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 },
                { 'variant_id' => variant2.id, 'included' => true, 'quantity' => 1 }
              ]
            }
          ]
        }
      end

      it 'returns count of included variants' do
        service = described_class.new(config, company: company)
        expect(service.combination_count).to eq(2)
      end
    end

    context 'with multiple configurable products' do
      let(:configurable2) { create(:product, :configurable_variant, company: company) }
      let(:config2) { create(:configuration, product: configurable2, code: 'color', name: 'Color') }
      let!(:variant4) { create(:product, :sellable, company: company) }
      let!(:variant5) { create(:product, :sellable, company: company) }
      let!(:variant6) { create(:product, :sellable, company: company) }

      let!(:pc4) do
        create(:product_configuration,
               superproduct: configurable2,
               subproduct: variant4,
               info: { 'variant_config' => { 'color' => 'Red' } })
      end

      let!(:pc5) do
        create(:product_configuration,
               superproduct: configurable2,
               subproduct: variant5,
               info: { 'variant_config' => { 'color' => 'Blue' } })
      end

      let!(:pc6) do
        create(:product_configuration,
               superproduct: configurable2,
               subproduct: variant6,
               info: { 'variant_config' => { 'color' => 'Green' } })
      end

      let(:config) do
        {
          'components' => [
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant1.id, 'included' => true, 'quantity' => 1 },
                { 'variant_id' => variant2.id, 'included' => true, 'quantity' => 1 }
              ]
            },
            {
              'product_id' => configurable2.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant4.id, 'included' => true, 'quantity' => 1 },
                { 'variant_id' => variant5.id, 'included' => true, 'quantity' => 1 },
                { 'variant_id' => variant6.id, 'included' => true, 'quantity' => 1 }
              ]
            }
          ]
        }
      end

      it 'returns cartesian product of all variants' do
        service = described_class.new(config, company: company)
        # 2 variants * 3 variants = 6 combinations
        expect(service.combination_count).to eq(6)
      end
    end

    context 'with too many combinations' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => (1..250).map { |i|
                variant = create(:product, :sellable, company: company)
                create(:product_configuration,
                       superproduct: configurable,
                       subproduct: variant,
                       info: { 'variant_config' => { 'size' => "Size#{i}" } })
                { 'variant_id' => variant.id, 'included' => true, 'quantity' => 1 }
              }
            }
          ]
        }
      end

      it 'validates as false when over 200' do
        service = described_class.new(config, company: company)
        expect(service.valid?).to be false
      end

      it 'adds error about too many combinations' do
        service = described_class.new(config, company: company)
        service.valid?
        expect(service.errors).to include(/would generate \d+ combinations, maximum is 200/)
      end
    end

    context 'with invalid configuration' do
      let(:config) do
        { 'components' => [] }
      end

      it 'returns 0' do
        service = described_class.new(config, company: company)
        expect(service.combination_count).to eq(0)
      end
    end
  end

  describe 'LIMITS constant' do
    it 'defines expected limits' do
      expect(described_class::LIMITS[:max_configurables]).to eq(3)
      expect(described_class::LIMITS[:max_sellables]).to eq(10)
      expect(described_class::LIMITS[:max_total_products]).to eq(12)
      expect(described_class::LIMITS[:max_combinations]).to eq(200)
      expect(described_class::LIMITS[:max_quantity]).to eq(99)
      expect(described_class::LIMITS[:min_quantity]).to eq(1)
    end
  end
end
