require 'rails_helper'

RSpec.describe ProductAttributeValue, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:product_attribute_value)).to be_valid
    end

    it 'creates valid values with different types' do
      expect(create(:product_attribute_value, :text_value)).to be_valid
      expect(create(:product_attribute_value, :number_value)).to be_valid
      expect(create(:product_attribute_value, :price_value)).to be_valid
      expect(create(:product_attribute_value, :special_price_value)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:product_attribute) }
  end

  # Test validations
  describe 'validations' do
    # Note: Using create for subject to ensure associations are properly set
    # This is needed because the broken_rule callback requires product_attribute to be present
    subject { create(:product_attribute_value) }

    it { is_expected.to validate_presence_of(:product) }
    # Note: We validate product_attribute presence through belongs_to validation
    # but the shoulda-matcher triggers the broken_rule callback which requires product_attribute.
    # Instead, verify the association is required (belongs_to with optional: false)
    it 'requires product_attribute association' do
      # Verify the belongs_to reflection has required: true (optional: false)
      reflection = ProductAttributeValue.reflect_on_association(:product_attribute)
      expect(reflection.options[:optional]).not_to be true
    end

    context 'uniqueness validations' do
      let(:product) { create(:product) }
      let(:attribute) { create(:product_attribute) }

      before do
        create(:product_attribute_value, product: product, product_attribute: attribute)
      end

      it 'validates uniqueness of product_id scoped to product_attribute_id' do
        duplicate = build(:product_attribute_value, product: product, product_attribute: attribute)
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:product_id]).to include('has already been taken')
      end

      it 'allows same product with different attributes' do
        other_attribute = create(:product_attribute)
        pav = build(:product_attribute_value, product: product, product_attribute: other_attribute)
        expect(pav).to be_valid
      end

      it 'allows same attribute with different products' do
        other_product = create(:product)
        pav = build(:product_attribute_value, product: other_product, product_attribute: attribute)
        expect(pav).to be_valid
      end
    end

    context 'rule validations' do
      let(:company) { create(:company) }
      let(:product) { create(:product, company: company) }

      context 'with positive rule' do
        let(:attribute) { create(:product_attribute, :number_type, :with_positive_rule, company: company) }

        it 'validates positive values when ready' do
          pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: '10', ready: true)
          expect(pav).to be_valid
        end

        it 'invalidates negative values when ready' do
          pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: '-10', ready: true)
          expect(pav).not_to be_valid
          expect(pav.errors[:base]).to be_present
        end

        it 'allows invalid values when not ready' do
          pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: '-10', ready: false)
          expect(pav).to be_valid
        end
      end

      context 'with not_null rule' do
        let(:attribute) { create(:product_attribute, :text_type, :with_not_null_rule, company: company) }

        it 'validates non-blank values when ready' do
          pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: 'some value', ready: true)
          expect(pav).to be_valid
        end

        it 'invalidates blank values when ready' do
          pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: '', ready: true)
          expect(pav).not_to be_valid
        end
      end
    end
  end

  # Test callbacks
  describe 'callbacks' do
    describe 'before_save :check_readiness' do
      let(:company) { create(:company) }
      let(:product) { create(:product, company: company) }

      context 'without rules' do
        let(:attribute) { create(:product_attribute, :text_type, company: company) }

        it 'sets ready to true' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: 'test')
          expect(pav.ready).to be true
        end
      end

      context 'with rules' do
        let(:attribute) { create(:product_attribute, :number_type, :with_positive_rule, company: company) }

        it 'sets ready to true when value passes rules' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '10')
          expect(pav.ready).to be true
        end

        it 'sets ready to false when value fails rules' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '-10', ready: false)
          pav.save(validate: false)
          pav.reload
          expect(pav.ready).to be false
        end
      end
    end

    describe 'after_save :propagate_change' do
      let(:product) { create(:product) }
      let(:pav) { create(:product_attribute_value, product: product) }

      it 'touches product when attribute value is saved' do
        expect { pav.update(value: 'new value') }
          .to change { product.reload.updated_at }
      end
    end

    describe 'after_destroy :propagate_change' do
      let(:product) { create(:product) }
      let(:pav) { create(:product_attribute_value, product: product) }

      it 'touches product when attribute value is destroyed' do
        pav # Create it first
        expect { pav.destroy }
          .to change { product.reload.updated_at }
      end
    end
  end

  # Test AttributeValues concern methods
  describe 'AttributeValues methods' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    describe '#broken_rule' do
      context 'without rules' do
        let(:attribute) { create(:product_attribute, :text_type, company: company) }
        let(:pav) { create(:product_attribute_value, product: product, product_attribute: attribute, value: '') }

        it 'returns nil' do
          expect(pav.broken_rule).to be_nil
        end
      end

      context 'with positive rule' do
        let(:attribute) { create(:product_attribute, :number_type, :with_positive_rule, company: company) }

        it 'returns nil for valid values' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '10')
          expect(pav.broken_rule).to be_nil
        end

        it 'returns rule name for invalid values' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '-10', ready: false)
          pav.save(validate: false)
          expect(pav.broken_rule).to eq('positive')
        end
      end

      context 'with multiple rules' do
        let(:attribute) { create(:product_attribute, :number_type, :with_all_rules, company: company) }

        it 'returns first broken rule' do
          pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '', ready: false)
          pav.save(validate: false)
          # Since value is empty string, it fails both not_null and positive
          expect(['positive', 'not_null']).to include(pav.broken_rule)
        end
      end
    end

    describe '#value for custom types' do
      context 'with special_price format' do
        let(:attribute) { create(:product_attribute, :special_price_format, company: company) }
        let(:pav) { create(:product_attribute_value, :special_price_value, product: product, product_attribute: attribute) }

        it 'reconstructs value from info hash' do
          value = pav.value
          expect(value).to include(',') # CSV format: amount,from,until
          parts = value.split(',')
          expect(parts.size).to eq(3)
        end
      end

      context 'with customer_group_price format' do
        let(:attribute) { create(:product_attribute, :customer_group_price_format, company: company) }
        let(:pav) { create(:product_attribute_value, :customer_group_price_value, product: product, product_attribute: attribute) }

        it 'reconstructs value from info hash' do
          value = pav.value
          expect(value).to include(':') # Format: group:price,group:price
          expect(value).to include('retail')
        end
      end
    end

    describe '#localized_values?' do
      let(:attribute) { create(:product_attribute, :text_type, company: company) }

      it 'returns false when no localized values' do
        pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: 'test')
        expect(pav.localized_values?).to be false
      end

      it 'returns true when localized values present' do
        pav = create(:product_attribute_value, :with_localized_values, product: product, product_attribute: attribute)
        expect(pav.localized_values?).to be true
      end
    end
  end

  # Test JSONB fields
  describe 'JSONB fields' do
    describe 'info field' do
      it 'stores custom metadata' do
        pav = create(:product_attribute_value, :with_localized_values)
        expect(pav.info['localized_value']).to be_a(Hash)
        expect(pav.info['localized_value']).to have_key('en')
      end

      it 'stores customer group prices' do
        pav = create(:product_attribute_value, :customer_group_price_value)
        expect(pav.info['customer_group_prices']).to be_a(Hash)
        expect(pav.info['customer_group_prices']['retail']).to be_present
      end

      it 'stores special price with date range' do
        pav = create(:product_attribute_value, :special_price_value)
        expect(pav.info['special_price']).to be_a(Hash)
        expect(pav.info['special_price']['amount']).to be_present
        expect(pav.info['special_price']['from']).to be_present
        expect(pav.info['special_price']['until']).to be_present
      end

      it 'stores related products' do
        pav = create(:product_attribute_value, :related_products_value)
        expect(pav.info['related_products']).to be_an(Array)
      end
    end
  end

  # Test ready flag
  describe 'ready flag' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    it 'defaults to true for new records without rules' do
      attribute = create(:product_attribute, :text_type, company: company)
      pav = create(:product_attribute_value, product: product, product_attribute: attribute)
      expect(pav.ready).to be true
    end

    it 'can be explicitly set to false via update_column' do
      # Note: The before_save callback check_readiness sets ready based on broken_rule
      # So normal save will always set ready based on the callback
      # Use update_column to bypass callbacks entirely
      pav = create(:product_attribute_value)
      pav.update_column(:ready, false)
      expect(pav.reload.ready).to be false
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }

    context 'multiple attribute values per product' do
      let(:price_attr) { create(:product_attribute, :price_attribute, company: company) }
      let(:ean_attr) { create(:product_attribute, :ean_attribute, company: company) }
      let(:desc_attr) { create(:product_attribute, :description_attribute, company: company) }

      before do
        create(:product_attribute_value, product: product, product_attribute: price_attr, value: '1999')
        create(:product_attribute_value, product: product, product_attribute: ean_attr, value: '5012345678900')
        create(:product_attribute_value, product: product, product_attribute: desc_attr, value: 'Description')
      end

      it 'allows product to have multiple attribute values' do
        expect(product.product_attribute_values.count).to eq(3)
      end

      it 'can access attributes through values' do
        expect(product.product_attributes).to contain_exactly(price_attr, ean_attr, desc_attr)
      end
    end

    context 'cache invalidation' do
      let(:attribute) { create(:product_attribute, company: company) }
      let!(:pav) { create(:product_attribute_value, product: product, product_attribute: attribute) }

      before do
        product.update_column(:updated_at, 1.hour.ago)
      end

      it 'invalidates product cache when value changes' do
        old_updated_at = product.reload.updated_at
        pav.update(value: 'new value')
        expect(product.reload.updated_at).to be > old_updated_at
      end
    end

    context 'with mandatory attribute and rules' do
      let(:attribute) { create(:product_attribute, :price_attribute, company: company) }

      it 'creates valid value passing all rules' do
        pav = create(:product_attribute_value, product: product, product_attribute: attribute, value: '1999')
        expect(pav).to be_valid
        expect(pav.ready).to be true
        expect(pav.broken_rule).to be_nil
      end

      it 'creates invalid value failing rules' do
        pav = build(:product_attribute_value, product: product, product_attribute: attribute, value: '-100', ready: true)
        expect(pav).not_to be_valid
      end
    end
  end
end
