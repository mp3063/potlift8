require 'rails_helper'

RSpec.describe VariantGeneratorService, type: :service do
  let(:company) { create(:company) }
  let(:configurable_product) { create(:product, :configurable_variant, company: company, name: 'T-Shirt') }

  describe '#initialize' do
    it 'initializes with a configurable product' do
      service = VariantGeneratorService.new(configurable_product)
      expect(service.product).to eq(configurable_product)
    end

    it 'raises error for non-configurable product' do
      sellable = create(:product, :sellable, company: company)
      service = VariantGeneratorService.new(sellable)
      service.generate!
      expect(service.errors).to include('Product must be configurable type')
    end
  end

  describe '#generate!' do
    context 'with no configurations' do
      it 'returns 0 and does not create product configurations' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          count = service.generate!
          expect(count).to eq(0)
        }.not_to change { ProductConfiguration.count }
      end
    end

    context 'with one configuration (size)' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }

      it 'generates variant for each value' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          service.generate!
        }.to change { ProductConfiguration.count }.by(3) # Small, Medium, Large

        expect(configurable_product.product_configurations_as_super.count).to eq(3)
      end

      it 'creates variant products with correct naming' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        variants = configurable_product.product_configurations_as_super
                                       .includes(:subproduct)
                                       .order('products.sku')

        variant_names = variants.map { |pc| pc.subproduct.name }
        expect(variant_names).to include('T-Shirt - Small')
        expect(variant_names).to include('T-Shirt - Medium')
        expect(variant_names).to include('T-Shirt - Large')
      end

      it 'stores variant_config in ProductConfiguration.info' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        small_config = configurable_product.product_configurations_as_super.find do |pc|
          pc.info['variant_config']&.dig('size') == 'Small'
        end

        expect(small_config).to be_present
        expect(small_config.info['variant_config']).to eq({ 'size' => 'Small' })
      end

      it 'returns correct count' do
        service = VariantGeneratorService.new(configurable_product)
        count = service.generate!

        expect(count).to eq(3)
      end
    end

    context 'with two configurations (size and color)' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }
      let!(:color_config) { create(:configuration, :color, product: configurable_product) }

      it 'generates all combinations (3 sizes × 3 colors = 9 variants)' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          service.generate!
        }.to change { ProductConfiguration.count }.by(9)

        expect(configurable_product.product_configurations_as_super.count).to eq(9)
      end

      it 'creates variants with correct names' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        # Check specific combinations
        small_red = configurable_product.product_configurations_as_super.find do |pc|
          pc.info['variant_config'] == { 'size' => 'Small', 'color' => 'Red' }
        end

        expect(small_red).to be_present
        expect(small_red.subproduct.name).to eq('T-Shirt - Small / Red')
      end

      it 'each variant has exactly 2 configuration dimensions' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        configurable_product.product_configurations_as_super.each do |pc|
          expect(pc.info['variant_config'].keys.size).to eq(2)
        end
      end

      it 'creates all size-color combinations' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        sizes = [ 'Small', 'Medium', 'Large' ]
        colors = [ 'Red', 'Blue', 'Green' ]

        sizes.each do |size|
          colors.each do |color|
            variant = configurable_product.product_configurations_as_super.find do |pc|
              pc.info['variant_config'] == { 'size' => size, 'color' => color }
            end

            expect(variant).to be_present, "Expected variant for #{size} / #{color} but not found"
          end
        end
      end

      it 'returns correct count' do
        service = VariantGeneratorService.new(configurable_product)
        count = service.generate!

        expect(count).to eq(9)
      end
    end

    context 'with three configurations (size, color, material)' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }
      let!(:color_config) { create(:configuration, :color, product: configurable_product) }
      let!(:material_config) { create(:configuration, :material, product: configurable_product) }

      it 'generates all combinations (3 × 3 × 2 = 18 variants)' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          service.generate!
        }.to change { ProductConfiguration.count }.by(18)

        expect(configurable_product.product_configurations_as_super.count).to eq(18)
      end

      it 'each variant has exactly 3 configuration dimensions' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        configurable_product.product_configurations_as_super.each do |pc|
          expect(pc.info['variant_config'].keys.size).to eq(3)
        end
      end

      it 'creates variant with all three dimensions' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        variant = configurable_product.product_configurations_as_super.find do |pc|
          pc.info['variant_config'] == { 'size' => 'Small', 'color' => 'Red', 'material' => 'Cotton' }
        end

        expect(variant).to be_present
        expect(variant.subproduct.name).to eq('T-Shirt - Small / Red / Cotton')
      end

      it 'returns correct count' do
        service = VariantGeneratorService.new(configurable_product)
        count = service.generate!

        expect(count).to eq(18)
      end
    end

    context 'with existing variants' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }
      let!(:color_config) { create(:configuration, :color, product: configurable_product) }

      before do
        # Create one variant manually using ProductConfiguration
        variant_product = create(:product, :sellable, company: company, name: 'T-Shirt - Small / Red')
        create(:product_configuration,
               superproduct: configurable_product,
               subproduct: variant_product,
               info: { 'variant_config' => { 'size' => 'Small', 'color' => 'Red' } })
      end

      it 'skips existing combinations' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          service.generate!
        }.to change { ProductConfiguration.count }.by(8) # 9 total - 1 existing = 8 new

        expect(configurable_product.product_configurations_as_super.count).to eq(9)
      end

      it 'does not duplicate existing variants' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        small_red_variants = configurable_product.product_configurations_as_super.select do |pc|
          pc.info['variant_config'] == { 'size' => 'Small', 'color' => 'Red' }
        end

        expect(small_red_variants.count).to eq(1)
      end
    end

    context 'with configuration values in specific order' do
      let!(:color_config) { create(:configuration, :color, product: configurable_product, position: 1) }
      let!(:size_config) { create(:configuration, :size, product: configurable_product, position: 2) }

      it 'orders variant name by configuration position' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        variant = configurable_product.product_configurations_as_super.find do |pc|
          pc.info['variant_config'] == { 'size' => 'Small', 'color' => 'Red' }
        end

        # Color (position 1) should come before Size (position 2)
        expect(variant.subproduct.name).to eq('T-Shirt - Red / Small')
      end
    end
  end

  describe '#valid_for_generation?' do
    context 'with valid configurations' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }

      it 'returns true' do
        service = VariantGeneratorService.new(configurable_product)
        expect(service.valid_for_generation?).to be true
      end
    end

    context 'with configurations but no values' do
      let!(:empty_config) { create(:configuration, product: configurable_product, name: 'Empty', code: 'empty') }

      it 'returns false' do
        service = VariantGeneratorService.new(configurable_product)
        expect(service.valid_for_generation?).to be false
      end
    end

    context 'with no configurations' do
      it 'returns false' do
        service = VariantGeneratorService.new(configurable_product)
        expect(service.valid_for_generation?).to be false
      end
    end
  end

  describe '#variant_count' do
    context 'with one configuration' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }

      it 'returns correct count without creating variants' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          count = service.variant_count
          expect(count).to eq(3)
        }.not_to change { ProductConfiguration.count }
      end
    end

    context 'with two configurations' do
      let!(:size_config) { create(:configuration, :size, product: configurable_product) }
      let!(:color_config) { create(:configuration, :color, product: configurable_product) }

      it 'returns Cartesian product count' do
        service = VariantGeneratorService.new(configurable_product)
        expect(service.variant_count).to eq(9) # 3 sizes × 3 colors
      end
    end
  end

  describe '#preview' do
    let!(:size_config) { create(:configuration, :size, product: configurable_product) }
    let!(:color_config) { create(:configuration, :color, product: configurable_product) }

    it 'returns preview of variants without creating them' do
      service = VariantGeneratorService.new(configurable_product)

      expect {
        previews = service.preview
        expect(previews.size).to eq(9)
      }.not_to change { ProductConfiguration.count }
    end

    it 'indicates existing vs new variants' do
      # Create one variant manually
      variant_product = create(:product, :sellable, company: company)
      create(:product_configuration,
             superproduct: configurable_product,
             subproduct: variant_product,
             info: { 'variant_config' => { 'size' => 'Small', 'color' => 'Red' } })

      service = VariantGeneratorService.new(configurable_product)
      previews = service.preview

      existing = previews.select { |p| p[:exists] }
      new_variants = previews.select { |p| !p[:exists] }

      expect(existing.size).to eq(1)
      expect(new_variants.size).to eq(8)
    end
  end

  describe 'error handling' do
    let!(:size_config) { create(:configuration, :size, product: configurable_product) }

    it 'handles variant creation failure gracefully' do
      service = VariantGeneratorService.new(configurable_product)

      # Mock a validation failure
      allow_any_instance_of(Product).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)

      expect {
        count = service.generate!
        expect(count).to eq(0)
      }.not_to change { ProductConfiguration.count }
    end

    it 'collects errors during generation' do
      service = VariantGeneratorService.new(configurable_product)

      # Simulate error
      allow_any_instance_of(Product).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new)

      service.generate!
      expect(service.errors).not_to be_empty
    end
  end

  describe 'performance considerations' do
    let!(:size_config) { create(:configuration, :size, product: configurable_product) }
    let!(:color_config) { create(:configuration, :color, product: configurable_product) }

    it 'generates variants in bulk efficiently' do
      service = VariantGeneratorService.new(configurable_product)

      # Measure database queries (use query counting gem if available)
      start_time = Time.current
      service.generate!
      duration = Time.current - start_time

      # Should complete in reasonable time (< 2 seconds for 9 variants)
      expect(duration).to be < 2.seconds
    end

    it 'creates all variants in a single transaction' do
      service = VariantGeneratorService.new(configurable_product)

      # If any variant fails, all should be rolled back
      expect(ActiveRecord::Base).to receive(:transaction).at_least(:once).and_call_original

      service.generate!
    end
  end

  describe 'integration scenarios' do
    context 'real-world t-shirt example' do
      let!(:size_config) do
        config = create(:configuration, product: configurable_product, name: 'Size', code: 'size', position: 1)
        create(:configuration_value, configuration: config, value: 'XS', position: 1)
        create(:configuration_value, configuration: config, value: 'S', position: 2)
        create(:configuration_value, configuration: config, value: 'M', position: 3)
        create(:configuration_value, configuration: config, value: 'L', position: 4)
        create(:configuration_value, configuration: config, value: 'XL', position: 5)
        config
      end

      let!(:color_config) do
        config = create(:configuration, product: configurable_product, name: 'Color', code: 'color', position: 2)
        create(:configuration_value, configuration: config, value: 'Black', position: 1)
        create(:configuration_value, configuration: config, value: 'White', position: 2)
        create(:configuration_value, configuration: config, value: 'Navy', position: 3)
        config
      end

      it 'generates 15 variants (5 sizes × 3 colors)' do
        service = VariantGeneratorService.new(configurable_product)

        expect {
          count = service.generate!
          expect(count).to eq(15)
        }.to change { ProductConfiguration.count }.by(15)
      end

      it 'all variants have correct SKU format' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        configurable_product.product_configurations_as_super.each do |pc|
          expect(pc.subproduct.sku).to be_present
          expect(pc.subproduct.sku).to match(/^SKU\d+-[A-Z-]+$/)
        end
      end

      it 'all variants belong to same company' do
        service = VariantGeneratorService.new(configurable_product)
        service.generate!

        configurable_product.product_configurations_as_super.each do |pc|
          expect(pc.subproduct.company_id).to eq(company.id)
        end
      end
    end
  end

  describe 'edge cases' do
    it 'handles single configuration with single value' do
      config = create(:configuration, product: configurable_product, name: 'Option', code: 'option')
      create(:configuration_value, configuration: config, value: 'Only Choice')

      service = VariantGeneratorService.new(configurable_product)

      expect {
        count = service.generate!
        expect(count).to eq(1)
      }.to change { ProductConfiguration.count }.by(1)
    end

    it 'handles many configuration values' do
      config = create(:configuration, product: configurable_product, name: 'Size', code: 'size')
      10.times do |i|
        create(:configuration_value, configuration: config, value: "Size #{i + 1}")
      end

      service = VariantGeneratorService.new(configurable_product)

      expect {
        service.generate!
      }.to change { ProductConfiguration.count }.by(10)
    end

    it 'handles unicode characters in configuration values' do
      config = create(:configuration, product: configurable_product, name: 'Size', code: 'size')
      create(:configuration_value, configuration: config, value: 'Größe XL')
      create(:configuration_value, configuration: config, value: 'サイズ M')

      service = VariantGeneratorService.new(configurable_product)

      expect {
        service.generate!
      }.to change { ProductConfiguration.count }.by(2)

      pc = configurable_product.product_configurations_as_super.first
      expect(pc.subproduct.name).to include(configurable_product.name)
    end
  end
end
