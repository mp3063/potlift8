require 'rails_helper'

RSpec.describe Product, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:product)).to be_valid
    end

    it 'creates valid products with all types' do
      expect(create(:product, :sellable)).to be_valid
      expect(create(:product, :configurable_variant)).to be_valid
      expect(create(:product, :configurable_option)).to be_valid
      expect(create(:product, :bundle)).to be_valid
    end

    it 'creates valid products with all statuses' do
      expect(create(:product, :draft)).to be_valid
      expect(create(:product, :active)).to be_valid
      expect(create(:product, :incoming)).to be_valid
      expect(create(:product, :disabled)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:sync_lock).optional }
    it { is_expected.to have_many(:product_attribute_values).dependent(:destroy) }
    it { is_expected.to have_many(:product_attributes).through(:product_attribute_values) }
    it { is_expected.to have_many(:product_labels).dependent(:destroy) }
    it { is_expected.to have_many(:labels).through(:product_labels) }
    it { is_expected.to have_many(:inventories).dependent(:destroy) }
    it { is_expected.to have_many(:storages).through(:inventories) }
    it { is_expected.to have_many(:product_assets).dependent(:destroy) }

    # Product configuration associations
    it { is_expected.to have_many(:product_configurations_as_super).dependent(:destroy) }
    it { is_expected.to have_many(:subproducts).through(:product_configurations_as_super) }
    it { is_expected.to have_many(:product_configurations_as_sub).dependent(:destroy) }
    it { is_expected.to have_many(:superproducts).through(:product_configurations_as_sub) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:product) }

    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_presence_of(:sku) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:product_type) }

    context 'SKU uniqueness' do
      let(:company) { create(:company) }

      before do
        create(:product, company: company, sku: 'ABC123')
      end

      it 'validates uniqueness of SKU scoped to company' do
        duplicate = build(:product, company: company, sku: 'ABC123')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:sku]).to include('has already been taken')
      end

      it 'allows same SKU for different companies' do
        other_company = create(:company)
        product = build(:product, company: other_company, sku: 'ABC123')
        expect(product).to be_valid
      end

      it 'validates uniqueness case-insensitively' do
        duplicate = build(:product, company: company, sku: 'abc123')
        expect(duplicate).not_to be_valid
      end
    end

    context 'configurable products' do
      it 'requires configuration_type for configurable products' do
        product = build(:product, product_type: :configurable, configuration_type: nil)
        expect(product).not_to be_valid
        expect(product.errors[:configuration_type]).to include("can't be blank")
      end

      it 'accepts configuration_type for configurable products' do
        product = build(:product, product_type: :configurable, configuration_type: :variant)
        expect(product).to be_valid
      end

      it 'does not require configuration_type for non-configurable products' do
        product = build(:product, product_type: :sellable, configuration_type: nil)
        expect(product).to be_valid
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'product_type' do
      it 'defines all 3 product types' do
        expect(Product.product_types).to eq({
          'sellable' => 1,
          'configurable' => 2,
          'bundle' => 3
        })
      end

      it 'allows setting product type' do
        product = create(:product, product_type: :sellable)
        expect(product.product_type_sellable?).to be true

        product.update(product_type: :bundle)
        expect(product.product_type_bundle?).to be true
      end
    end

    describe 'configuration_type' do
      it 'defines configuration types' do
        expect(Product.configuration_types).to eq({
          'variant' => 1,
          'option' => 2
        })
      end

      it 'allows setting configuration type' do
        product = create(:product, :configurable_variant)
        expect(product.configuration_type_variant?).to be true

        product.update(configuration_type: :option)
        expect(product.configuration_type_option?).to be true
      end
    end

    describe 'product_status' do
      it 'defines all 7 product statuses' do
        expect(Product.product_statuses).to eq({
          'draft' => 0,
          'active' => 1,
          'incoming' => 2,
          'discontinuing' => 3,
          'disabled' => 4,
          'discontinued' => 6,
          'deleted' => 999
        })
      end

      it 'allows setting product status' do
        product = create(:product, product_status: :draft)
        expect(product.product_status_draft?).to be true

        product.update(product_status: :active)
        expect(product.product_status_active?).to be true
      end

      it 'defaults to active' do
        product = create(:product)
        expect(product.product_status_active?).to be true
      end
    end
  end

  # Test callbacks
  describe 'callbacks' do
    describe 'before_validation :normalize_sku' do
      it 'strips whitespace from SKU' do
        product = create(:product, sku: '  ABC123  ')
        expect(product.sku).to eq('ABC123')
      end

      it 'converts SKU to uppercase' do
        product = create(:product, sku: 'abc123')
        expect(product.sku).to eq('ABC123')
      end

      it 'handles both trimming and uppercasing' do
        product = create(:product, sku: '  abc123  ')
        expect(product.sku).to eq('ABC123')
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }

    describe '.for_company' do
      let!(:product1) { create(:product, company: company) }
      let!(:product2) { create(:product, company: company) }
      let!(:other_product) { create(:product, company: other_company) }

      it 'returns products for specified company' do
        result = Product.for_company(company.id)
        expect(result).to contain_exactly(product1, product2)
        expect(result).not_to include(other_product)
      end
    end

    describe '.active_products' do
      let!(:active) { create(:product, :active, company: company) }
      let!(:draft) { create(:product, :draft, company: company) }
      let!(:disabled) { create(:product, :disabled, company: company) }

      it 'returns only active products' do
        result = Product.active_products
        expect(result).to contain_exactly(active)
      end
    end

    describe '.sellable_products' do
      let!(:sellable1) { create(:product, :sellable, company: company) }
      let!(:sellable2) { create(:product, :sellable, company: company) }
      let!(:configurable) { create(:product, :configurable_variant, company: company) }

      it 'returns only sellable products' do
        result = Product.sellable_products
        expect(result).to contain_exactly(sellable1, sellable2)
      end
    end

    describe '.configurable_products' do
      let!(:variant) { create(:product, :configurable_variant, company: company) }
      let!(:option) { create(:product, :configurable_option, company: company) }
      let!(:sellable) { create(:product, :sellable, company: company) }

      it 'returns only configurable products' do
        result = Product.configurable_products
        expect(result).to contain_exactly(variant, option)
      end
    end

    describe '.bundle_products' do
      let!(:bundle1) { create(:product, :bundle, company: company) }
      let!(:bundle2) { create(:product, :bundle, company: company) }
      let!(:sellable) { create(:product, :sellable, company: company) }

      it 'returns only bundle products' do
        result = Product.bundle_products
        expect(result).to contain_exactly(bundle1, bundle2)
      end
    end

    describe '.by_sku' do
      let!(:product) { create(:product, company: company, sku: 'FINDME') }
      let!(:other) { create(:product, company: company, sku: 'OTHER') }

      it 'finds product by SKU' do
        result = Product.by_sku('FINDME')
        expect(result).to contain_exactly(product)
      end
    end

    describe '.by_ean' do
      let!(:product) { create(:product, :with_ean, company: company) }
      let!(:other) { create(:product, company: company) }

      it 'finds product by EAN' do
        result = Product.by_ean(product.ean)
        expect(result).to contain_exactly(product)
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'structure field' do
      it 'stores variant configuration' do
        product = create(:product, :configurable_variant)
        expect(product.structure['variants']).to be_an(Array)
        expect(product.structure['variants'].first['sku']).to be_present
      end

      it 'stores option configuration' do
        product = create(:product, :configurable_option)
        expect(product.structure['options']).to be_an(Array)
      end

      it 'stores bundle items' do
        product = create(:product, :bundle)
        expect(product.structure['bundle_items']).to be_an(Array)
      end

      it 'defaults to empty hash' do
        product = create(:product)
        expect(product.structure).to eq({})
      end
    end

    describe 'info field' do
      it 'stores custom metadata' do
        product = create(:product, :with_info)
        expect(product.info['manufacturer']).to eq('ACME Corp')
        expect(product.info['warranty_months']).to eq(24)
      end

      it 'defaults to empty hash' do
        product = create(:product)
        expect(product.info).to eq({})
      end
    end

    describe 'cache field' do
      it 'stores cached values' do
        product = create(:product, :with_cache)
        expect(product.cache['total_inventory']).to eq(100)
        expect(product.cache['price']).to eq(1999)
      end

      it 'defaults to empty hash' do
        product = create(:product)
        expect(product.cache).to eq({})
      end
    end
  end

  # Test EAV helper methods
  describe 'EAV helper methods' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:price_attr) { create(:product_attribute, company: company, code: 'price') }
    let(:color_attr) { create(:product_attribute, company: company, code: 'color') }

    describe '#read_attribute_value' do
      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:product_attribute_value, product: product, product_attribute: color_attr, value: 'blue')
      end

      it 'reads attribute value by code' do
        expect(product.read_attribute_value('price')).to eq('1999')
        expect(product.read_attribute_value('color')).to eq('blue')
      end

      it 'returns nil for non-existent attribute' do
        expect(product.read_attribute_value('nonexistent')).to be_nil
      end

      it 'returns nil for blank code' do
        expect(product.read_attribute_value('')).to be_nil
        expect(product.read_attribute_value(nil)).to be_nil
      end
    end

    describe '#write_attribute_value' do
      it 'creates new attribute value' do
        result = product.write_attribute_value('price', '2999')
        expect(result).to be true

        value = product.product_attribute_values.joins(:product_attribute)
                       .find_by(product_attributes: { code: 'price' })
        expect(value.value).to eq('2999')
      end

      it 'updates existing attribute value' do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')

        result = product.write_attribute_value('price', '2999')
        expect(result).to be true

        value = product.product_attribute_values.joins(:product_attribute)
                       .find_by(product_attributes: { code: 'price' })
        expect(value.value).to eq('2999')
      end

      it 'returns false for non-existent attribute' do
        result = product.write_attribute_value('nonexistent', 'value')
        expect(result).to be false
      end

      it 'returns false for blank code' do
        expect(product.write_attribute_value('', 'value')).to be false
        expect(product.write_attribute_value(nil, 'value')).to be false
      end
    end

    describe '#attribute_values_hash' do
      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:product_attribute_value, product: product, product_attribute: color_attr, value: 'blue')
      end

      it 'returns hash of all attribute values' do
        hash = product.attribute_values_hash
        expect(hash['price']).to eq('1999')
        expect(hash['color']).to eq('blue')
      end

      it 'returns empty hash when no attributes' do
        new_product = create(:product, company: company)
        expect(new_product.attribute_values_hash).to eq({})
      end
    end
  end

  # Test label helper methods
  describe 'label helper methods' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:category) { create(:label, company: company, code: 'electronics') }
    let(:tag) { create(:label, company: company, code: 'featured') }

    before do
      create(:product_label, product: product, label: category)
    end

    describe '#has_label?' do
      it 'returns true if product has the label' do
        expect(product.has_label?('electronics')).to be true
      end

      it 'returns false if product does not have the label' do
        expect(product.has_label?('featured')).to be false
      end
    end
  end

  # Test inventory helper methods
  describe 'inventory helper methods' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:storage1) { create(:storage, company: company) }
    let(:storage2) { create(:storage, company: company) }
    let(:default_storage) { create(:storage, company: company, default: true) }

    describe '#total_inventory' do
      it 'returns sum of all inventory values' do
        create(:inventory, product: product, storage: storage1, value: 50)
        create(:inventory, product: product, storage: storage2, value: 30)

        expect(product.total_inventory).to eq(80)
      end

      it 'returns 0 when no inventory' do
        expect(product.total_inventory).to eq(0)
      end
    end

    describe '#in_stock?' do
      it 'returns true when inventory > 0' do
        create(:inventory, product: product, storage: storage1, value: 10)
        expect(product.in_stock?).to be true
      end

      it 'returns false when inventory is 0' do
        create(:inventory, product: product, storage: storage1, value: 0)
        expect(product.in_stock?).to be false
      end

      it 'returns false when no inventory records' do
        expect(product.in_stock?).to be false
      end
    end

    describe '#default_inventory' do
      it 'returns inventory in default storage' do
        regular = create(:inventory, product: product, storage: storage1, value: 10)
        default = create(:inventory, product: product, storage: default_storage, value: 20)

        expect(product.default_inventory).to eq(default)
      end

      it 'returns nil when no default storage' do
        create(:inventory, product: product, storage: storage1, value: 10)
        expect(product.default_inventory).to be_nil
      end
    end

    describe '#available?' do
      context 'when product is active and in stock' do
        before do
          product.update(product_status: :active)
          create(:inventory, product: product, storage: storage1, value: 10)
        end

        it 'returns true' do
          expect(product.available?).to be true
        end
      end

      context 'when product is active but not in stock' do
        before do
          product.update(product_status: :active)
        end

        it 'returns false' do
          expect(product.available?).to be false
        end
      end

      context 'when product is in stock but not active' do
        before do
          product.update(product_status: :disabled)
          create(:inventory, product: product, storage: storage1, value: 10)
        end

        it 'returns false' do
          expect(product.available?).to be false
        end
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'complete product with all associations' do
      let(:product) { create(:product, :with_attributes, :with_labels, :with_inventory, :with_assets, company: company) }

      it 'has all associations working' do
        expect(product.product_attribute_values.count).to be > 0
        expect(product.labels.count).to be > 0
        expect(product.inventories.count).to be > 0
        expect(product.product_assets.count).to be > 0
      end
    end

    context 'product lifecycle' do
      let(:product) { create(:product, company: company, product_status: :draft) }

      it 'can transition through statuses' do
        expect(product.product_status_draft?).to be true

        product.update(product_status: :active)
        expect(product.product_status_active?).to be true

        product.update(product_status: :discontinuing)
        expect(product.product_status_discontinuing?).to be true

        product.update(product_status: :discontinued)
        expect(product.product_status_discontinued?).to be true
      end
    end

    context 'product with sync tracking' do
      let(:sync_lock) { create(:sync_lock) }
      let!(:product1) { create(:product, company: company, sync_lock: sync_lock) }
      let!(:product2) { create(:product, company: company, sync_lock: sync_lock) }

      it 'groups products by sync operation' do
        synced_products = company.products.where(sync_lock: sync_lock)
        expect(synced_products).to contain_exactly(product1, product2)
      end
    end

    context 'configurable product with variants' do
      let(:product) { create(:product, :configurable_variant, company: company) }

      it 'stores variant configuration' do
        variants = product.structure['variants']
        expect(variants).to be_an(Array)
        expect(variants.length).to be > 0
        expect(variants.first).to have_key('sku')
        expect(variants.first).to have_key('attributes')
      end
    end

    context 'bundle product' do
      let(:product) { create(:product, :bundle, company: company) }

      it 'stores bundle items configuration' do
        items = product.structure['bundle_items']
        expect(items).to be_an(Array)
        expect(items.first).to have_key('sku')
        expect(items.first).to have_key('quantity')
      end
    end

    context 'product deletion cascade' do
      let(:product) { create(:product, :with_attributes, :with_labels, :with_inventory, :with_assets, company: company) }

      it 'destroys all dependent records' do
        attribute_values_count = product.product_attribute_values.count
        labels_count = product.product_labels.count
        inventory_count = product.inventories.count
        assets_count = product.product_assets.count

        expect do
          product.destroy
        end.to change { ProductAttributeValue.count }.by(-attribute_values_count)
           .and change { ProductLabel.count }.by(-labels_count)
           .and change { Inventory.count }.by(-inventory_count)
           .and change { ProductAsset.count }.by(-assets_count)
      end
    end
  end

  # Test product relationship helper methods
  describe 'product relationship helper methods' do
    let(:company) { create(:company) }

    describe '#has_variants?' do
      context 'for configurable products with subproducts' do
        let(:configurable) { create(:product, :configurable_variant, company: company) }
        let(:variant1) { create(:product, :sellable, company: company) }
        let(:variant2) { create(:product, :sellable, company: company) }

        before do
          create(:product_configuration, superproduct: configurable, subproduct: variant1)
          create(:product_configuration, superproduct: configurable, subproduct: variant2)
        end

        it 'returns true' do
          expect(configurable.has_variants?).to be true
        end
      end

      context 'for configurable products without subproducts' do
        let(:configurable) { create(:product, :configurable_variant, company: company) }

        it 'returns false' do
          expect(configurable.has_variants?).to be false
        end
      end

      context 'for bundle products' do
        let(:bundle) { create(:product, :bundle, company: company) }
        let(:component) { create(:product, :sellable, company: company) }

        before do
          create(:product_configuration, superproduct: bundle, subproduct: component)
        end

        it 'returns false (bundles are not variants)' do
          expect(bundle.has_variants?).to be false
        end
      end

      context 'for sellable products' do
        let(:sellable) { create(:product, :sellable, company: company) }

        it 'returns false' do
          expect(sellable.has_variants?).to be false
        end
      end
    end

    describe '#is_variant?' do
      context 'for products that are subproducts' do
        let(:configurable) { create(:product, :configurable_variant, company: company) }
        let(:variant) { create(:product, :sellable, company: company) }

        before do
          create(:product_configuration, superproduct: configurable, subproduct: variant)
        end

        it 'returns true' do
          expect(variant.is_variant?).to be true
        end
      end

      context 'for products that are not subproducts' do
        let(:product) { create(:product, :sellable, company: company) }

        it 'returns false' do
          expect(product.is_variant?).to be false
        end
      end

      context 'for configurable products' do
        let(:configurable) { create(:product, :configurable_variant, company: company) }

        it 'returns false (they are superproducts, not variants)' do
          expect(configurable.is_variant?).to be false
        end
      end
    end

    describe '#variants' do
      let(:configurable) { create(:product, :configurable_variant, company: company) }
      let(:variant1) { create(:product, :sellable, company: company) }
      let(:variant2) { create(:product, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: configurable, subproduct: variant1)
        create(:product_configuration, superproduct: configurable, subproduct: variant2)
      end

      it 'returns all subproducts (alias for compatibility)' do
        expect(configurable.variants).to eq(configurable.subproducts)
        expect(configurable.variants.count).to eq(2)
        expect(configurable.variants).to include(variant1, variant2)
      end
    end
  end
end
