require 'rails_helper'

RSpec.describe CatalogItem, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:catalog_item)).to be_valid
    end

    it 'creates valid catalog items with all states' do
      expect(create(:catalog_item, :active)).to be_valid
      expect(create(:catalog_item, :inactive)).to be_valid
    end

    it 'creates valid catalog items with priorities' do
      expect(create(:catalog_item, :high_priority)).to be_valid
      expect(create(:catalog_item, :low_priority)).to be_valid
      expect(create(:catalog_item, :no_priority)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:catalog) }
    it { is_expected.to belong_to(:product) }
    it { is_expected.to have_many(:catalog_item_attribute_values).dependent(:destroy) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:catalog_item) }

    context 'uniqueness of catalog+product combination' do
      let(:company) { create(:company) }
      let(:catalog) { create(:catalog, company: company) }
      let(:product) { create(:product, company: company) }

      before do
        create(:catalog_item, catalog: catalog, product: product)
      end

      it 'validates uniqueness of catalog_id scoped to product_id' do
        duplicate = build(:catalog_item, catalog: catalog, product: product)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:catalog_id]).to include('has already been taken')
      end

      it 'allows same product in different catalogs' do
        other_catalog = create(:catalog, company: company)
        catalog_item = build(:catalog_item, catalog: other_catalog, product: product)
        expect(catalog_item).to be_valid
      end

      it 'allows different products in same catalog' do
        other_product = create(:product, company: company)
        catalog_item = build(:catalog_item, catalog: catalog, product: other_product)
        expect(catalog_item).to be_valid
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'catalog_item_state' do
      it 'defines all 2 states' do
        expect(CatalogItem.catalog_item_states).to eq({
          'inactive' => 0,
          'active' => 1
        })
      end

      it 'allows setting catalog item state' do
        catalog_item = create(:catalog_item, catalog_item_state: :inactive)
        expect(catalog_item.inactive?).to be true

        catalog_item.update(catalog_item_state: :active)
        expect(catalog_item.active?).to be true
      end

      it 'defaults to inactive' do
        catalog_item = create(:catalog_item)
        # Note: Factory sets active, but model defaults to inactive (0)
        # Let's test with build instead
        built_item = CatalogItem.new(
          catalog: create(:catalog),
          product: create(:product)
        )
        expect(built_item.catalog_item_state).to eq('inactive')
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }

    describe 'default_scope (priority ordering)' do
      let!(:low) { create(:catalog_item, catalog: catalog, priority: 10) }
      let!(:high) { create(:catalog_item, catalog: catalog, priority: 1000) }
      let!(:medium) { create(:catalog_item, catalog: catalog, priority: 100) }
      let!(:no_priority) { create(:catalog_item, catalog: catalog, priority: nil) }

      it 'orders by priority descending' do
        items = CatalogItem.where(catalog: catalog).to_a
        expect(items[0]).to eq(high)
        expect(items[1]).to eq(medium)
        expect(items[2]).to eq(low)
        expect(items[3]).to eq(no_priority)
      end
    end

    describe '.active_items' do
      let!(:active1) { create(:catalog_item, :active, catalog: catalog) }
      let!(:active2) { create(:catalog_item, :active, catalog: catalog) }
      let!(:inactive) { create(:catalog_item, :inactive, catalog: catalog) }

      it 'returns only active items' do
        result = CatalogItem.active_items
        expect(result).to contain_exactly(active1, active2)
        expect(result).not_to include(inactive)
      end
    end

    describe '.inactive_items' do
      let!(:inactive1) { create(:catalog_item, :inactive, catalog: catalog) }
      let!(:inactive2) { create(:catalog_item, :inactive, catalog: catalog) }
      let!(:active) { create(:catalog_item, :active, catalog: catalog) }

      it 'returns only inactive items' do
        result = CatalogItem.inactive_items
        expect(result).to contain_exactly(inactive1, inactive2)
        expect(result).not_to include(active)
      end
    end
  end

  # Test #effective_attribute_value method
  describe '#effective_attribute_value' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    let(:price_attr) do
      # Use existing system attribute created by after_create callback
      company.product_attributes.find_by(code: 'price')
    end

    let(:description_attr) do
      company.product_attributes.find_by(code: 'description_html') ||
        create(:product_attribute,
              company: company,
              code: 'test_description',
              pa_type: :patype_text,
              product_attribute_scope: :product_scope)
    end

    context 'when catalog override exists' do
      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1000')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '1500')
      end

      it 'returns catalog override value' do
        expect(catalog_item.effective_attribute_value('price')).to eq('1500')
      end
    end

    context 'when no catalog override exists' do
      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1000')
      end

      it 'falls back to product value' do
        expect(catalog_item.effective_attribute_value('price')).to eq('1000')
      end
    end

    context 'when neither catalog nor product value exists' do
      it 'returns nil' do
        expect(catalog_item.effective_attribute_value('price')).to be_nil
      end
    end

    context 'when attribute does not exist' do
      it 'returns nil' do
        expect(catalog_item.effective_attribute_value('nonexistent')).to be_nil
      end
    end
  end

  # Test #write_catalog_attribute_value method
  describe '#write_catalog_attribute_value' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    let(:catalog_scoped_attr) do
      create(:product_attribute,
            company: company,
            code: 'catalog_price',
            product_attribute_scope: :catalog_scope)
    end

    let(:product_and_catalog_scoped_attr) do
      # Use existing system attribute (created by after_create callback)
      company.product_attributes.find_by(code: 'price')
    end

    let(:product_only_attr) do
      create(:product_attribute,
            company: company,
            code: 'sku',
            product_attribute_scope: :product_scope)
    end

    context 'with catalog_scope attribute' do
      before do
        catalog_scoped_attr  # Force lazy let to execute
      end

      it 'creates catalog attribute value' do
        result = catalog_item.write_catalog_attribute_value('catalog_price', '1999')
        expect(result).to be true

        ciav = catalog_item.catalog_item_attribute_values.joins(:product_attribute)
                          .find_by(product_attributes: { code: 'catalog_price' })
        expect(ciav.value).to eq('1999')
      end
    end

    context 'with product_and_catalog_scope attribute' do
      before do
        product_and_catalog_scoped_attr  # Force lazy let to execute
      end

      it 'creates catalog attribute value' do
        result = catalog_item.write_catalog_attribute_value('price', '2999')
        expect(result).to be true

        ciav = catalog_item.catalog_item_attribute_values.joins(:product_attribute)
                          .find_by(product_attributes: { code: 'price' })
        expect(ciav.value).to eq('2999')
      end

      it 'updates existing catalog attribute value' do
        catalog_item.write_catalog_attribute_value('price', '1999')
        result = catalog_item.write_catalog_attribute_value('price', '2999')
        expect(result).to be true

        ciav = catalog_item.catalog_item_attribute_values.joins(:product_attribute)
                          .find_by(product_attributes: { code: 'price' })
        expect(ciav.value).to eq('2999')
      end
    end

    context 'with product_scope attribute' do
      before do
        product_only_attr  # Force lazy let to execute
      end

      it 'returns false and does not create value' do
        result = catalog_item.write_catalog_attribute_value('sku', 'ABC123')
        expect(result).to be false

        ciav = catalog_item.catalog_item_attribute_values.joins(:product_attribute)
                          .find_by(product_attributes: { code: 'sku' })
        expect(ciav).to be_nil
      end
    end

    context 'with non-existent attribute' do
      it 'returns false' do
        result = catalog_item.write_catalog_attribute_value('nonexistent', 'value')
        expect(result).to be false
      end
    end
  end

  # Test #sales_ready? method
  describe '#sales_ready?' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    it 'delegates to CatalogItemValidator' do
      validator_double = instance_double(CatalogItemValidator, valid?: true)
      allow(CatalogItemValidator).to receive(:new).with(catalog_item).and_return(validator_double)

      result = catalog_item.sales_ready?

      expect(result).to be true
      expect(CatalogItemValidator).to have_received(:new).with(catalog_item)
    end

    it 'returns false when validator returns false' do
      validator_double = instance_double(CatalogItemValidator, valid?: false)
      allow(CatalogItemValidator).to receive(:new).with(catalog_item).and_return(validator_double)

      result = catalog_item.sales_ready?

      expect(result).to be false
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        catalog_item = create(:catalog_item, :with_info)
        expect(catalog_item.info['featured']).to eq(true)
        expect(catalog_item.info['promotion_text']).to eq('Special offer!')
      end

      it 'defaults to empty hash' do
        catalog_item = create(:catalog_item)
        expect(catalog_item.info).to eq({})
      end
    end
  end

  # Test helper methods
  describe 'helper methods' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    describe '#effective_attribute_values_hash' do
      let(:price_attr) do
        company.product_attributes.find_by(code: 'price')
      end

      let(:weight_attr) do
        company.product_attributes.find_by(code: 'weight')
      end

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1000')
        create(:product_attribute_value, product: product, product_attribute: weight_attr, value: '500')
        create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: price_attr, value: '1500')
      end

      it 'returns merged hash with catalog overrides' do
        hash = catalog_item.effective_attribute_values_hash
        expect(hash['price']).to eq('1500')  # Catalog override
        expect(hash['weight']).to eq('500')  # Product value
      end
    end

    describe '#has_attribute_overrides?' do
      context 'with overrides' do
        let(:attr) do
          company.product_attributes.find_by(code: 'price')
        end

        before do
          create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: attr)
        end

        it 'returns true' do
          expect(catalog_item.has_attribute_overrides?).to be true
        end
      end

      context 'without overrides' do
        it 'returns false' do
          expect(catalog_item.has_attribute_overrides?).to be false
        end
      end
    end

    describe '#validation_errors' do
      it 'returns errors from CatalogItemValidator' do
        validator_double = instance_double(CatalogItemValidator, valid?: false, errors: [ 'Error 1', 'Error 2' ])
        allow(CatalogItemValidator).to receive(:new).with(catalog_item).and_return(validator_double)

        errors = catalog_item.validation_errors

        expect(errors).to eq([ 'Error 1', 'Error 2' ])
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }

    context 'complete catalog item with overrides' do
      let(:catalog_item) { create(:catalog_item, :with_overrides, :with_info, catalog: catalog) }

      it 'has all associations working' do
        expect(catalog_item.catalog_item_attribute_values.count).to be > 0
        expect(catalog_item.info).not_to be_empty
        expect(catalog_item.has_attribute_overrides?).to be true
      end
    end

    context 'catalog item deletion cascade' do
      let(:catalog_item) { create(:catalog_item, :with_overrides, catalog: catalog) }

      it 'destroys all dependent attribute values' do
        values_count = catalog_item.catalog_item_attribute_values.count

        expect do
          catalog_item.destroy
        end.to change { CatalogItemAttributeValue.count }.by(-values_count)
      end
    end

    context 'attribute override hierarchy' do
      let(:product) { create(:product, company: company) }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      let(:price_attr) do
        company.product_attributes.find_by(code: 'price')
      end

      it 'correctly prioritizes catalog values over product values' do
        # Set product value
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1000')
        expect(catalog_item.effective_attribute_value('price')).to eq('1000')

        # Add catalog override
        catalog_item.write_catalog_attribute_value('price', '1500')
        expect(catalog_item.effective_attribute_value('price')).to eq('1500')

        # Update catalog override
        catalog_item.write_catalog_attribute_value('price', '2000')
        expect(catalog_item.effective_attribute_value('price')).to eq('2000')
      end
    end
  end
end
