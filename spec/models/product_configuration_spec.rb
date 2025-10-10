require 'rails_helper'

RSpec.describe ProductConfiguration, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      superproduct = create(:product, :configurable_variant)
      subproduct = create(:product, :sellable)
      config = build(:product_configuration, superproduct: superproduct, subproduct: subproduct)
      expect(config).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:superproduct).class_name('Product') }
    it { is_expected.to belong_to(:subproduct).class_name('Product') }
  end

  # Test validations
  describe 'validations' do
    let(:company) { create(:company) }
    let(:superproduct) { create(:product, :configurable_variant, company: company) }
    let(:subproduct) { create(:product, :sellable, company: company) }

    subject { build(:product_configuration, superproduct: superproduct, subproduct: subproduct) }

    it { is_expected.to validate_presence_of(:superproduct_id) }
    it { is_expected.to validate_presence_of(:subproduct_id) }

    context 'uniqueness validation' do
      before do
        create(:product_configuration, superproduct: superproduct, subproduct: subproduct)
      end

      it 'validates uniqueness of superproduct_id scoped to subproduct_id' do
        duplicate = build(:product_configuration, superproduct: superproduct, subproduct: subproduct)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:superproduct_id]).to include('and subproduct combination already exists')
      end

      it 'allows same subproduct with different superproduct' do
        other_superproduct = create(:product, :configurable_variant, company: company)
        config = build(:product_configuration, superproduct: other_superproduct, subproduct: subproduct)
        expect(config).to be_valid
      end

      it 'allows same superproduct with different subproduct' do
        other_subproduct = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: superproduct, subproduct: other_subproduct)
        expect(config).to be_valid
      end
    end

    context 'circular dependency prevention' do
      it 'prevents a product from being its own subproduct' do
        config = build(:product_configuration, superproduct: superproduct, subproduct: superproduct)
        expect(config).not_to be_valid
        expect(config.errors[:base]).to include('A product cannot be its own subproduct')
      end
    end

    context 'superproduct type validation' do
      it 'allows configurable superproducts' do
        configurable = create(:product, :configurable_variant, company: company)
        sellable = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: configurable, subproduct: sellable)
        expect(config).to be_valid
      end

      it 'allows bundle superproducts' do
        bundle = create(:product, :bundle, company: company)
        sellable = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: bundle, subproduct: sellable)
        expect(config).to be_valid
      end

      it 'rejects sellable superproducts' do
        sellable_super = create(:product, :sellable, company: company)
        sellable_sub = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: sellable_super, subproduct: sellable_sub)
        expect(config).not_to be_valid
        expect(config.errors[:superproduct]).to include('must be a configurable or bundle product')
      end
    end

    context 'subproduct type validation for configurable superproducts' do
      let(:configurable) { create(:product, :configurable_variant, company: company) }

      it 'allows sellable subproducts' do
        sellable = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: configurable, subproduct: sellable)
        expect(config).to be_valid
      end

      it 'rejects configurable subproducts' do
        configurable_sub = create(:product, :configurable_variant, company: company)
        config = build(:product_configuration, superproduct: configurable, subproduct: configurable_sub)
        expect(config).not_to be_valid
        expect(config.errors[:subproduct]).to include('must be sellable for configurable superproducts')
      end

      it 'rejects bundle subproducts' do
        bundle_sub = create(:product, :bundle, company: company)
        config = build(:product_configuration, superproduct: configurable, subproduct: bundle_sub)
        expect(config).not_to be_valid
        expect(config.errors[:subproduct]).to include('must be sellable for configurable superproducts')
      end
    end

    context 'subproduct type validation for bundle superproducts' do
      let(:bundle) { create(:product, :bundle, company: company) }

      it 'allows sellable subproducts in bundles' do
        sellable = create(:product, :sellable, company: company)
        config = build(:product_configuration, superproduct: bundle, subproduct: sellable)
        expect(config).to be_valid
      end

      it 'allows configurable subproducts in bundles' do
        configurable = create(:product, :configurable_variant, company: company)
        config = build(:product_configuration, superproduct: bundle, subproduct: configurable)
        expect(config).to be_valid
      end

      it 'rejects bundle subproducts in bundles' do
        bundle_sub = create(:product, :bundle, company: company)
        config = build(:product_configuration, superproduct: bundle, subproduct: bundle_sub)
        expect(config).not_to be_valid
        expect(config.errors[:subproduct]).to include('cannot be a bundle when superproduct is a bundle')
      end
    end
  end

  # Test default scope
  describe 'default scope' do
    let(:company) { create(:company) }
    let(:superproduct) { create(:product, :configurable_variant, company: company) }
    let!(:sub1) { create(:product, :sellable, company: company, sku: 'SUB003') }
    let!(:sub2) { create(:product, :sellable, company: company, sku: 'SUB001') }
    let!(:sub3) { create(:product, :sellable, company: company, sku: 'SUB002') }

    let!(:config1) { create(:product_configuration, superproduct: superproduct, subproduct: sub1, configuration_position: 2) }
    let!(:config2) { create(:product_configuration, superproduct: superproduct, subproduct: sub2, configuration_position: 1) }
    let!(:config3) { create(:product_configuration, superproduct: superproduct, subproduct: sub3, configuration_position: nil) }

    it 'orders by configuration_position first, then by SKU' do
      configs = ProductConfiguration.where(superproduct: superproduct).to_a
      expect(configs.map(&:id)).to eq([config2.id, config1.id, config3.id])
    end

    it 'handles null positions correctly' do
      # Nulls should come last
      configs = ProductConfiguration.where(superproduct: superproduct).to_a
      null_configs = configs.select { |c| c.configuration_position.nil? }
      expect(null_configs.last).to eq(config3)
    end
  end

  # Test quantity methods
  describe '#quantity' do
    let(:company) { create(:company) }
    let(:bundle) { create(:product, :bundle, company: company) }
    let(:subproduct) { create(:product, :sellable, company: company) }

    context 'with quantity in info' do
      it 'returns the stored quantity' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: { 'quantity' => 5 })
        expect(config.quantity).to eq(5)
      end

      it 'handles string quantities' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: { 'quantity' => '3' })
        expect(config.quantity).to eq(3)
      end

      it 'handles zero quantity as default of 1' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: { 'quantity' => 0 })
        expect(config.quantity).to eq(1)
      end

      it 'handles negative quantity as default of 1' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: { 'quantity' => -5 })
        expect(config.quantity).to eq(1)
      end
    end

    context 'without quantity in info' do
      it 'returns default quantity of 1' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: {})
        expect(config.quantity).to eq(1)
      end

      it 'returns 1 when info is empty hash' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: {})
        expect(config.quantity).to eq(1)
      end

      it 'returns 1 when quantity key is missing' do
        config = create(:product_configuration, superproduct: bundle, subproduct: subproduct, info: { 'other_data' => 'value' })
        expect(config.quantity).to eq(1)
      end
    end
  end

  describe '#quantity=' do
    let(:company) { create(:company) }
    let(:bundle) { create(:product, :bundle, company: company) }
    let(:subproduct) { create(:product, :sellable, company: company) }
    let(:config) { create(:product_configuration, superproduct: bundle, subproduct: subproduct) }

    it 'stores quantity in info field' do
      config.quantity = 3
      config.save
      expect(config.reload.info['quantity']).to eq(3)
    end

    it 'converts string to integer' do
      config.quantity = '7'
      config.save
      expect(config.reload.info['quantity']).to eq(7)
    end

    it 'initializes info hash if empty' do
      config.info = {}
      config.save
      config.reload
      config.quantity = 5
      config.save
      expect(config.reload.info['quantity']).to eq(5)
    end

    it 'preserves other info fields' do
      config.info = { 'variant_name' => 'Blue Large', 'quantity' => 1 }
      config.save
      config.quantity = 2
      config.save
      expect(config.reload.info['variant_name']).to eq('Blue Large')
      expect(config.reload.info['quantity']).to eq(2)
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'variant relationship (configurable product)' do
      let(:tshirt) { create(:product, :configurable_variant, company: company, name: 'T-Shirt') }
      let(:small) { create(:product, :sellable, company: company, sku: 'TSHIRT-S', name: 'T-Shirt Small') }
      let(:medium) { create(:product, :sellable, company: company, sku: 'TSHIRT-M', name: 'T-Shirt Medium') }
      let(:large) { create(:product, :sellable, company: company, sku: 'TSHIRT-L', name: 'T-Shirt Large') }

      before do
        create(:product_configuration, superproduct: tshirt, subproduct: small, configuration_position: 1)
        create(:product_configuration, superproduct: tshirt, subproduct: medium, configuration_position: 2)
        create(:product_configuration, superproduct: tshirt, subproduct: large, configuration_position: 3)
      end

      it 'establishes variant relationships correctly' do
        expect(tshirt.subproducts.count).to eq(3)
        expect(tshirt.subproducts).to include(small, medium, large)
      end

      it 'maintains ordering by configuration_position' do
        expect(tshirt.subproducts.to_a).to eq([small, medium, large])
      end

      it 'allows reverse lookup from variant to parent' do
        expect(small.superproducts).to include(tshirt)
        expect(small.superproducts.count).to eq(1)
      end
    end

    context 'bundle relationship' do
      let(:starter_kit) { create(:product, :bundle, company: company, name: 'Starter Kit') }
      let(:item1) { create(:product, :sellable, company: company, sku: 'ITEM-001') }
      let(:item2) { create(:product, :sellable, company: company, sku: 'ITEM-002') }
      let(:item3) { create(:product, :sellable, company: company, sku: 'ITEM-003') }

      before do
        create(:product_configuration, superproduct: starter_kit, subproduct: item1, info: { 'quantity' => 2 })
        create(:product_configuration, superproduct: starter_kit, subproduct: item2, info: { 'quantity' => 1 })
        create(:product_configuration, superproduct: starter_kit, subproduct: item3, info: { 'quantity' => 3 })
      end

      it 'establishes bundle relationships correctly' do
        expect(starter_kit.subproducts.count).to eq(3)
        expect(starter_kit.subproducts).to include(item1, item2, item3)
      end

      it 'stores quantities for bundle components' do
        config1 = starter_kit.product_configurations_as_super.find_by(subproduct: item1)
        config2 = starter_kit.product_configurations_as_super.find_by(subproduct: item2)
        config3 = starter_kit.product_configurations_as_super.find_by(subproduct: item3)

        expect(config1.quantity).to eq(2)
        expect(config2.quantity).to eq(1)
        expect(config3.quantity).to eq(3)
      end

      it 'allows calculating total components in bundle' do
        total = starter_kit.product_configurations_as_super.sum(&:quantity)
        expect(total).to eq(6)
      end
    end

    context 'mixed relationships' do
      let(:configurable) { create(:product, :configurable_variant, company: company) }
      let(:variant1) { create(:product, :sellable, company: company) }
      let(:variant2) { create(:product, :sellable, company: company) }
      let(:bundle) { create(:product, :bundle, company: company) }

      before do
        create(:product_configuration, superproduct: configurable, subproduct: variant1)
        create(:product_configuration, superproduct: configurable, subproduct: variant2)
        create(:product_configuration, superproduct: bundle, subproduct: configurable, info: { 'quantity' => 1 })
      end

      it 'allows a configurable product to be a component in a bundle' do
        expect(bundle.subproducts).to include(configurable)
        expect(configurable.superproducts).to include(bundle)
      end

      it 'maintains separate relationships' do
        expect(configurable.subproducts.count).to eq(2)
        expect(configurable.superproducts.count).to eq(1)
      end
    end

    context 'cascade deletion' do
      let(:superproduct) { create(:product, :configurable_variant, company: company) }
      let(:subproduct) { create(:product, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: superproduct, subproduct: subproduct)
      end

      it 'deletes configurations when superproduct is destroyed' do
        expect do
          superproduct.destroy
        end.to change { ProductConfiguration.count }.by(-1)
      end

      it 'deletes configurations when subproduct is destroyed' do
        expect do
          subproduct.destroy
        end.to change { ProductConfiguration.count }.by(-1)
      end
    end

    context 'multiple configurations' do
      let(:company) { create(:company) }
      let(:bundle1) { create(:product, :bundle, company: company, name: 'Bundle 1') }
      let(:bundle2) { create(:product, :bundle, company: company, name: 'Bundle 2') }
      let(:product_a) { create(:product, :sellable, company: company, sku: 'PROD-A') }

      before do
        create(:product_configuration, superproduct: bundle1, subproduct: product_a, info: { 'quantity' => 2 })
        create(:product_configuration, superproduct: bundle2, subproduct: product_a, info: { 'quantity' => 5 })
      end

      it 'allows a product to be in multiple bundles' do
        expect(product_a.superproducts.count).to eq(2)
        expect(product_a.superproducts).to include(bundle1, bundle2)
      end

      it 'maintains separate quantities for each bundle' do
        config1 = ProductConfiguration.find_by(superproduct: bundle1, subproduct: product_a)
        config2 = ProductConfiguration.find_by(superproduct: bundle2, subproduct: product_a)

        expect(config1.quantity).to eq(2)
        expect(config2.quantity).to eq(5)
      end
    end
  end
end
