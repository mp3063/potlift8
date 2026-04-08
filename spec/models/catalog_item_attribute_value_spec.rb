require 'rails_helper'

RSpec.describe CatalogItemAttributeValue, type: :model do
  before do
    allow_any_instance_of(Company).to receive(:provision_system_attributes).and_return(true)
  end

  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:catalog_item_attribute_value)).to be_valid
    end

    it 'creates valid values with different types' do
      expect(create(:catalog_item_attribute_value, :numeric_value)).to be_valid
      expect(create(:catalog_item_attribute_value, :price_value)).to be_valid
      expect(create(:catalog_item_attribute_value, :text_value)).to be_valid
      expect(create(:catalog_item_attribute_value, :boolean_value)).to be_valid
    end

    it 'creates valid values with ready states' do
      expect(create(:catalog_item_attribute_value, ready: true)).to be_valid
      expect(create(:catalog_item_attribute_value, :not_ready)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:catalog_item) }
    it { is_expected.to belong_to(:product_attribute) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:catalog_item_attribute_value) }

    it { is_expected.to validate_presence_of(:value) }

    context 'uniqueness of catalog_item+product_attribute combination' do
      let(:company) { create(:company) }
      let(:catalog) { create(:catalog, company: company) }
      let(:product) { create(:product, company: company) }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
      let(:product_attribute) do
        create(:product_attribute,
              company: company,
              product_attribute_scope: :catalog_scope)
      end

      before do
        create(:catalog_item_attribute_value,
              catalog_item: catalog_item,
              product_attribute: product_attribute)
      end

      it 'validates uniqueness of catalog_item_id scoped to product_attribute_id' do
        duplicate = build(:catalog_item_attribute_value,
                         catalog_item: catalog_item,
                         product_attribute: product_attribute)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:catalog_item_id]).to include('has already been taken')
      end

      it 'allows same attribute for different catalog items' do
        other_catalog_item = create(:catalog_item, catalog: catalog)
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: other_catalog_item,
                    product_attribute: product_attribute)
        expect(ciav).to be_valid
      end

      it 'allows different attributes for same catalog item' do
        other_attribute = create(:product_attribute,
                                company: company,
                                product_attribute_scope: :catalog_scope)
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: catalog_item,
                    product_attribute: other_attribute)
        expect(ciav).to be_valid
      end
    end

    context 'attribute scope validation' do
      let(:company) { create(:company) }
      let(:catalog) { create(:catalog, company: company) }
      let(:catalog_item) { create(:catalog_item, catalog: catalog) }

      let(:catalog_scoped_attr) do
        create(:product_attribute,
              company: company,
              product_attribute_scope: :catalog_scope)
      end

      let(:product_and_catalog_scoped_attr) do
        create(:product_attribute,
              company: company,
              product_attribute_scope: :product_and_catalog_scope)
      end

      let(:product_only_attr) do
        create(:product_attribute,
              company: company,
              product_attribute_scope: :product_scope)
      end

      it 'allows catalog_scope attributes' do
        catalog_scoped_attr  # Force lazy let
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: catalog_item,
                    product_attribute: catalog_scoped_attr)
        expect(ciav).to be_valid
      end

      it 'allows product_and_catalog_scope attributes' do
        product_and_catalog_scoped_attr  # Force lazy let
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: catalog_item,
                    product_attribute: product_and_catalog_scoped_attr)
        expect(ciav).to be_valid
      end

      it 'rejects product_scope attributes' do
        product_only_attr  # Force lazy let
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: catalog_item,
                    product_attribute: product_only_attr)
        expect(ciav).not_to be_valid
        expect(ciav.errors[:base]).to include(/doesn't allow catalog-level values/)
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog) }

    describe '.ready_values' do
      let!(:ready1) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: true) }
      let!(:ready2) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: true) }
      let!(:not_ready) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: false) }

      it 'returns only ready values' do
        result = CatalogItemAttributeValue.ready_values
        expect(result).to contain_exactly(ready1, ready2)
        expect(result).not_to include(not_ready)
      end
    end

    describe '.pending_values' do
      let!(:pending1) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: false) }
      let!(:pending2) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: false) }
      let!(:ready) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: true) }

      it 'returns only pending values' do
        result = CatalogItemAttributeValue.pending_values
        expect(result).to contain_exactly(pending1, pending2)
        expect(result).not_to include(ready)
      end
    end

    describe '.for_attribute' do
      let(:price_attr) do
        create(:product_attribute,
              company: company,
              code: 'price',
              product_attribute_scope: :catalog_scope)
      end

      let(:weight_attr) do
        create(:product_attribute,
              company: company,
              code: 'weight',
              product_attribute_scope: :catalog_scope)
      end

      let!(:price_value) do
        create(:catalog_item_attribute_value,
              catalog_item: catalog_item,
              product_attribute: price_attr)
      end

      let!(:weight_value) do
        create(:catalog_item_attribute_value,
              catalog_item: catalog_item,
              product_attribute: weight_attr)
      end

      it 'returns values for specified attribute code' do
        result = CatalogItemAttributeValue.for_attribute('price')
        expect(result).to contain_exactly(price_value)
        expect(result).not_to include(weight_value)
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        ciav = create(:catalog_item_attribute_value, :with_info)
        expect(ciav.info['source']).to eq('manual_override')
        expect(ciav.info['updated_by']).to eq('admin')
      end

      it 'defaults to empty hash' do
        ciav = create(:catalog_item_attribute_value)
        expect(ciav.info).to eq({})
      end
    end
  end

  # Test helper methods
  describe 'helper methods' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    describe '#company' do
      let(:ciav) { create(:catalog_item_attribute_value, catalog_item: catalog_item) }

      it 'returns the owning company through associations' do
        expect(ciav.company).to eq(company)
      end
    end

    describe '#product' do
      let(:ciav) { create(:catalog_item_attribute_value, catalog_item: catalog_item) }

      it 'returns the associated product' do
        expect(ciav.product).to eq(product)
      end
    end

    describe '#catalog' do
      let(:ciav) { create(:catalog_item_attribute_value, catalog_item: catalog_item) }

      it 'returns the associated catalog' do
        expect(ciav.catalog).to eq(catalog)
      end
    end

    describe '#complete?' do
      context 'when ready and value present' do
        let(:ciav) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: true, value: 'test') }

        it 'returns true' do
          expect(ciav.complete?).to be true
        end
      end

      context 'when not ready' do
        let(:ciav) { create(:catalog_item_attribute_value, catalog_item: catalog_item, ready: false, value: 'test') }

        it 'returns false' do
          expect(ciav.complete?).to be false
        end
      end

      context 'when value is blank' do
        let(:ciav) { build(:catalog_item_attribute_value, catalog_item: catalog_item, ready: true, value: '') }

        it 'returns false' do
          # Can't save because value is required, so just test the logic
          ciav.save(validate: false)
          expect(ciav.complete?).to be false
        end
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:catalog) { create(:catalog, company: company) }
    let(:product) { create(:product, company: company) }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    context 'attribute override workflow' do
      let(:price_attr) do
        create(:product_attribute,
              company: company,
              code: 'price',
              pa_type: :patype_number,
              view_format: :view_format_price,
              product_attribute_scope: :product_and_catalog_scope)
      end

      it 'creates and updates catalog-specific price' do
        # Create product price
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1000')

        # Create catalog override
        ciav = create(:catalog_item_attribute_value,
                     catalog_item: catalog_item,
                     product_attribute: price_attr,
                     value: '1500')

        expect(ciav.value).to eq('1500')
        expect(ciav.ready).to be true

        # Update catalog override
        ciav.update(value: '2000')
        expect(ciav.value).to eq('2000')
      end
    end

    context 'scope enforcement' do
      let(:sku_attr) do
        create(:product_attribute,
              company: company,
              code: 'sku',
              product_attribute_scope: :product_scope)
      end

      it 'prevents creating catalog values for product-only attributes' do
        sku_attr  # Force lazy let
        ciav = build(:catalog_item_attribute_value,
                    catalog_item: catalog_item,
                    product_attribute: sku_attr,
                    value: 'SKU123')

        expect(ciav).not_to be_valid
        expect(ciav.errors[:base]).to include(/doesn't allow catalog-level values/)
      end
    end

    context 'multiple attributes per catalog item' do
      let(:price_attr) do
        create(:product_attribute,
              company: company,
              code: 'price',
              product_attribute_scope: :catalog_scope)
      end

      let(:description_attr) do
        create(:product_attribute,
              company: company,
              code: 'description',
              product_attribute_scope: :catalog_scope)
      end

      it 'allows multiple attribute overrides per catalog item' do
        price_value = create(:catalog_item_attribute_value,
                            catalog_item: catalog_item,
                            product_attribute: price_attr,
                            value: '1999')

        description_value = create(:catalog_item_attribute_value,
                                   catalog_item: catalog_item,
                                   product_attribute: description_attr,
                                   value: 'Special catalog description')

        expect(catalog_item.catalog_item_attribute_values.count).to eq(2)
        expect(catalog_item.catalog_item_attribute_values).to include(price_value, description_value)
      end
    end

    context 'deletion cascade' do
      let(:attr) do
        create(:product_attribute,
              company: company,
              product_attribute_scope: :catalog_scope)
      end

      let!(:ciav) do
        create(:catalog_item_attribute_value,
              catalog_item: catalog_item,
              product_attribute: attr)
      end

      it 'is destroyed when catalog item is destroyed' do
        expect do
          catalog_item.destroy
        end.to change { CatalogItemAttributeValue.count }.by(-1)
      end

      it 'is destroyed when product attribute is destroyed' do
        expect do
          attr.destroy
        end.to change { CatalogItemAttributeValue.count }.by(-1)
      end
    end
  end
end
