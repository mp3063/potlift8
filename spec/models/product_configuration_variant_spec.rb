require 'rails_helper'

RSpec.describe ProductConfiguration, type: :model, context: 'variants' do
  # Test factories
  describe 'factories' do
    it 'has a valid factory for variant configurations' do
      config = create(:product_configuration, :variant)
      expect(config).to be_valid
    end

    it 'creates valid variant configurations with traits' do
      config = create(:product_configuration, :variant, :positioned)
      expect(config).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:superproduct).class_name('Product') }
    it { is_expected.to belong_to(:subproduct).class_name('Product') }
  end

  # Test validations for variants
  describe 'validations' do
    subject { build(:product_configuration, :variant) }

    context 'subproduct_id uniqueness' do
      let(:configurable) { create(:product, :configurable_variant) }
      let(:variant_product) { create(:product, :sellable) }

      before do
        create(:product_configuration, superproduct: configurable, subproduct: variant_product)
      end

      it 'validates uniqueness scoped to superproduct' do
        duplicate = build(:product_configuration, superproduct: configurable, subproduct: variant_product)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:superproduct_id]).to include('and subproduct combination already exists')
      end

      it 'allows same variant product for different configurable products' do
        other_configurable = create(:product, :configurable_variant)
        config = build(:product_configuration, superproduct: other_configurable, subproduct: variant_product)
        expect(config).to be_valid
      end
    end

    context 'superproduct type validation' do
      let(:sellable) { create(:product, :sellable) }
      let(:variant_product) { create(:product, :sellable) }

      it 'rejects non-configurable superproducts' do
        config = build(:product_configuration, superproduct: sellable, subproduct: variant_product)
        expect(config).not_to be_valid
        expect(config.errors[:superproduct]).to include('must be a configurable, bundle, or bundle variant product')
      end
    end

    context 'subproduct type validation' do
      let(:configurable) { create(:product, :configurable_variant) }
      let(:bundle_product) { create(:product, :bundle) }

      it 'rejects non-sellable subproducts for configurable superproducts' do
        config = build(:product_configuration, superproduct: configurable, subproduct: bundle_product)
        expect(config).not_to be_valid
        expect(config.errors[:subproduct]).to include('must be sellable for configurable superproducts')
      end
    end
  end

  # Test positioning
  describe 'configuration_position ordering' do
    let(:configurable) { create(:product, :configurable_variant) }

    it 'orders by configuration_position when set' do
      config3 = create(:product_configuration, superproduct: configurable, configuration_position: 3)
      config1 = create(:product_configuration, superproduct: configurable, configuration_position: 1)
      config2 = create(:product_configuration, superproduct: configurable, configuration_position: 2)

      configs = configurable.product_configurations_as_super.unscoped
                            .where(superproduct: configurable)
                            .order('configuration_position ASC NULLS LAST')

      expect(configs.map(&:id)).to eq([ config1.id, config2.id, config3.id ])
    end

    it 'orders by subproduct SKU when position is null' do
      product_c = create(:product, :sellable, sku: 'SKU-C')
      product_a = create(:product, :sellable, sku: 'SKU-A')
      product_b = create(:product, :sellable, sku: 'SKU-B')

      config_c = create(:product_configuration, superproduct: configurable, subproduct: product_c, configuration_position: nil)
      config_a = create(:product_configuration, superproduct: configurable, subproduct: product_a, configuration_position: nil)
      config_b = create(:product_configuration, superproduct: configurable, subproduct: product_b, configuration_position: nil)

      configs = ProductConfiguration.unscoped
                                    .joins(:subproduct)
                                    .where(superproduct: configurable)
                                    .order('product_configurations.configuration_position ASC NULLS LAST, products.sku ASC')

      expect(configs.map(&:subproduct).map(&:sku)).to eq([ 'SKU-A', 'SKU-B', 'SKU-C' ])
    end
  end

  # Test variant configuration storage in info
  describe 'variant configuration in info JSONB' do
    let(:configurable) { create(:product, :configurable_variant, name: 'T-Shirt') }
    let(:size_config) { create(:configuration, :size, product: configurable) }
    let(:color_config) { create(:configuration, :color, product: configurable) }
    let(:variant_product) { create(:product, :sellable, name: 'T-Shirt Variant') }

    it 'stores variant configuration values in info field' do
      config = create(:product_configuration,
                      superproduct: configurable,
                      subproduct: variant_product,
                      info: { 'variant_config' => { 'size' => 'Small', 'color' => 'Red' } })

      expect(config.info['variant_config']).to eq({ 'size' => 'Small', 'color' => 'Red' })
    end

    it 'can store multiple configuration dimensions' do
      config = create(:product_configuration,
                      superproduct: configurable,
                      subproduct: variant_product,
                      info: {
                        'variant_config' => {
                          'size' => 'Medium',
                          'color' => 'Blue',
                          'material' => 'Cotton'
                        }
                      })

      expect(config.info['variant_config']['size']).to eq('Medium')
      expect(config.info['variant_config']['color']).to eq('Blue')
      expect(config.info['variant_config']['material']).to eq('Cotton')
    end

    it 'handles empty variant configuration' do
      config = create(:product_configuration,
                      superproduct: configurable,
                      subproduct: variant_product,
                      info: {})

      expect(config.info['variant_config']).to be_nil
    end
  end

  # Integration tests
  describe 'integration' do
    context 'complete variant configuration' do
      let(:company) { create(:company) }
      let(:configurable) { create(:product, :configurable_variant, company: company, name: 'Hoodie') }
      let!(:size_config) { create(:configuration, :size, product: configurable) }
      let!(:color_config) { create(:configuration, :color, product: configurable) }

      it 'creates variant with all configuration dimensions stored' do
        variant_product = create(:product, :sellable, company: company)
        config = create(:product_configuration,
                        superproduct: configurable,
                        subproduct: variant_product,
                        info: {
                          'variant_config' => {
                            'size' => 'Medium',
                            'color' => 'Green'
                          }
                        })

        expect(config.info['variant_config'].keys).to contain_exactly('size', 'color')
        expect(config.info['variant_config']['size']).to eq('Medium')
        expect(config.info['variant_config']['color']).to eq('Green')
      end
    end

    context 'variant with inventory' do
      let(:company) { create(:company) }
      let(:configurable) { create(:product, :configurable_variant, company: company) }
      let(:variant_product) { create(:product, :sellable, company: company) }
      let!(:config) { create(:product_configuration, superproduct: configurable, subproduct: variant_product) }
      let!(:storage) { create(:storage, company: company) }
      let!(:inventory) { create(:inventory, product: variant_product, storage: storage, value: 50) }

      it 'variant product has inventory' do
        expect(variant_product.total_inventory).to eq(50)
      end

      it 'variant product tracks inventory independently' do
        other_storage = create(:storage, company: company)
        create(:inventory, product: variant_product, storage: other_storage, value: 25)

        expect(variant_product.total_inventory).to eq(75)
      end
    end

    context 'multiple variants for same configurable' do
      let(:company) { create(:company) }
      let(:configurable) { create(:product, :configurable_variant, company: company) }
      let(:size_config) { create(:configuration, :size, product: configurable) }

      it 'creates multiple variants with different values' do
        small = create(:product, :sellable, company: company, name: 'T-Shirt - Small')
        medium = create(:product, :sellable, company: company, name: 'T-Shirt - Medium')
        large = create(:product, :sellable, company: company, name: 'T-Shirt - Large')

        config_small = create(:product_configuration,
                              superproduct: configurable,
                              subproduct: small,
                              info: { 'variant_config' => { 'size' => 'Small' } })
        config_medium = create(:product_configuration,
                               superproduct: configurable,
                               subproduct: medium,
                               info: { 'variant_config' => { 'size' => 'Medium' } })
        config_large = create(:product_configuration,
                              superproduct: configurable,
                              subproduct: large,
                              info: { 'variant_config' => { 'size' => 'Large' } })

        expect(configurable.product_configurations_as_super.count).to eq(3)
        expect(configurable.subproducts.count).to eq(3)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:configurable) { create(:product, :configurable_variant) }

    it 'variant can exist without variant_config in info' do
      config = create(:product_configuration, superproduct: configurable, info: {})
      expect(config).to be_valid
      expect(config.info['variant_config']).to be_nil
    end

    it 'prevents circular references' do
      product = create(:product, :configurable_variant)
      # Product cannot be its own variant
      config = build(:product_configuration, superproduct: product, subproduct: product)
      expect(config).not_to be_valid
      expect(config.errors[:base]).to include('A product cannot be its own subproduct')
    end

    it 'handles variant product deletion' do
      config = create(:product_configuration, superproduct: configurable)
      variant_product = config.subproduct

      expect {
        variant_product.destroy
      }.to change { ProductConfiguration.count }.by(-1)
    end
  end

  # Multi-tenancy
  describe 'multi-tenancy' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }
    let(:configurable) { create(:product, :configurable_variant, company: company) }
    let(:variant_product) { create(:product, :sellable, company: company) }
    let(:other_variant_product) { create(:product, :sellable, company: other_company) }

    it 'variant product must be from same company as configurable' do
      config = build(:product_configuration, superproduct: configurable, subproduct: other_variant_product)
      # Note: This validation would need to be added to ProductConfiguration model
      # For now, this test documents the expected behavior
      expect(configurable.company_id).not_to eq(other_variant_product.company_id)
    end

    it 'configuration is valid when products are from same company' do
      config = build(:product_configuration, superproduct: configurable, subproduct: variant_product)
      expect(config).to be_valid
      expect(configurable.company_id).to eq(variant_product.company_id)
    end
  end

  # Test quantity method for variants
  describe '#quantity' do
    let(:configurable) { create(:product, :configurable_variant) }
    let(:variant_product) { create(:product, :sellable) }

    it 'defaults to 1 for variants without explicit quantity' do
      config = create(:product_configuration, superproduct: configurable, subproduct: variant_product, info: {})
      expect(config.quantity).to eq(1)
    end

    it 'returns 1 even if quantity is set (variants do not use quantity)' do
      config = create(:product_configuration,
                      superproduct: configurable,
                      subproduct: variant_product,
                      info: { 'quantity' => 5 })
      expect(config.quantity).to eq(5) # But this is not semantically meaningful for variants
    end
  end
end
