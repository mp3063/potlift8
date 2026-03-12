require 'rails_helper'

RSpec.describe ProductAttribute, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:product_attribute)).to be_valid
    end

    it 'creates valid attributes with all pa_types' do
      expect(create(:product_attribute, :text_type)).to be_valid
      expect(create(:product_attribute, :number_type)).to be_valid
      expect(create(:product_attribute, :boolean_type)).to be_valid
      expect(create(:product_attribute, :select_type)).to be_valid
      expect(create(:product_attribute, :multiselect_type)).to be_valid
      expect(create(:product_attribute, :date_type)).to be_valid
      expect(create(:product_attribute, :rich_text_type)).to be_valid
    end

    it 'creates valid attributes with all view_formats' do
      expect(create(:product_attribute, :price_format)).to be_valid
      expect(create(:product_attribute, :weight_format)).to be_valid
      expect(create(:product_attribute, :ean_format)).to be_valid
      expect(create(:product_attribute, :markdown_format)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:attribute_group).optional }
    it { is_expected.to have_many(:product_attribute_values).dependent(:destroy) }
    it { is_expected.to have_many(:products).through(:product_attribute_values) }

    context 'with attribute group' do
      let(:company) { create(:company) }
      let(:group) { create(:attribute_group, company: company) }
      let(:attr) { create(:product_attribute, company: company, attribute_group: group) }

      it 'belongs to an attribute group' do
        expect(attr.attribute_group).to eq(group)
      end

      it 'can be ungrouped (nil group)' do
        ungrouped = create(:product_attribute, company: company, attribute_group: nil)
        expect(ungrouped.attribute_group).to be_nil
      end
    end
  end

  # Test validations
  describe 'validations' do
    subject { build(:product_attribute) }

    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:pa_type) }
    it { is_expected.to validate_presence_of(:company) }

    context 'uniqueness validations' do
      let(:company) { create(:company) }

      before do
        # Use a non-system code to avoid collision with system attributes
        create(:product_attribute, company: company, code: 'custom_test_attr')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:product_attribute, company: company, code: 'custom_test_attr')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        attr = build(:product_attribute, company: other_company, code: 'custom_test_attr')
        expect(attr).to be_valid
      end

      it 'validates uniqueness case-insensitively' do
        duplicate = build(:product_attribute, company: company, code: 'CUSTOM_TEST_ATTR')
        expect(duplicate).not_to be_valid
      end
    end
  end

  # Test enums
  describe 'enums' do
    describe 'pa_type' do
      it 'defines all 7 attribute types plus custom' do
        expect(ProductAttribute.pa_types).to eq({
          'patype_text' => 1,
          'patype_number' => 2,
          'patype_boolean' => 3,
          'patype_select' => 4,
          'patype_multiselect' => 5,
          'patype_date' => 6,
          'patype_rich_text' => 7,
          'patype_custom' => 99
        })
      end

      it 'allows setting pa_type' do
        attr = create(:product_attribute, pa_type: :patype_text)
        expect(attr.patype_text?).to be true

        attr.update(pa_type: :patype_number)
        expect(attr.patype_number?).to be true
      end
    end

    describe 'view_format' do
      it 'defines all 12 view formats' do
        expect(ProductAttribute.view_formats).to eq({
          'view_format_general' => 0,
          'view_format_price' => 1,
          'view_format_weight' => 2,
          'view_format_html' => 3,
          'view_format_ean' => 4,
          'view_format_markdown' => 5,
          'view_format_price_hash' => 6,
          'view_format_external_image_list' => 7,
          'view_format_special_price' => 8,
          'view_format_customer_group_price' => 9,
          'view_format_selectable' => 10,
          'view_format_related_products' => 11
        })
      end

      it 'allows setting view_format' do
        attr = create(:product_attribute, view_format: :view_format_general)
        expect(attr.view_format_general?).to be true

        attr.update(view_format: :view_format_price)
        expect(attr.view_format_price?).to be true
      end
    end

    describe 'product_attribute_scope' do
      it 'defines all 3 scope types' do
        expect(ProductAttribute.product_attribute_scopes).to eq({
          'product_scope' => 0,
          'catalog_scope' => 1,
          'product_and_catalog_scope' => 3
        })
      end

      it 'allows setting product_attribute_scope' do
        attr = create(:product_attribute, product_attribute_scope: :product_scope)
        expect(attr.product_scope?).to be true

        attr.update(product_attribute_scope: :catalog_scope)
        expect(attr.catalog_scope?).to be true
      end
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:company) { create(:company) }

    describe 'default_scope' do
      let!(:attr3) { create(:product_attribute, company: company, attribute_position: 3) }
      let!(:attr1) { create(:product_attribute, company: company, attribute_position: 1) }
      let!(:attr_nil) { create(:product_attribute, company: company, attribute_position: nil) }

      it 'orders by attribute_position asc with nulls last' do
        attrs = company.product_attributes.to_a
        expect(attrs.index(attr1)).to be < attrs.index(attr3)
        expect(attrs.index(attr3)).to be < attrs.index(attr_nil)
      end
    end

    describe '.all_mandatory' do
      let!(:mandatory1) { create(:product_attribute, :mandatory, company: company) }
      let!(:mandatory2) { create(:product_attribute, :mandatory, company: company) }
      let!(:optional) { create(:product_attribute, company: company, mandatory: false) }

      it 'returns only mandatory attributes' do
        result = ProductAttribute.all_mandatory
        expect(result).to include(mandatory1, mandatory2)
        expect(result).not_to include(optional)
      end
    end

    describe '.all_with_rules' do
      let!(:with_rules1) { create(:product_attribute, :with_positive_rule, company: company) }
      let!(:with_rules2) { create(:product_attribute, :with_not_null_rule, company: company) }
      let!(:without_rules) { create(:product_attribute, company: company, has_rules: false) }

      it 'returns only attributes with rules' do
        result = ProductAttribute.all_with_rules
        expect(result).to include(with_rules1, with_rules2)
        expect(result).not_to include(without_rules)
      end
    end

    describe '.all_mandatory_or_with_rules' do
      let!(:mandatory) { create(:product_attribute, :mandatory, company: company, has_rules: false) }
      let!(:with_rules) { create(:product_attribute, :with_positive_rule, company: company, mandatory: false) }
      let!(:both) { create(:product_attribute, :mandatory, :with_positive_rule, company: company) }
      let!(:neither) { create(:product_attribute, company: company, mandatory: false, has_rules: false) }

      it 'returns attributes that are mandatory or have rules' do
        result = ProductAttribute.all_mandatory_or_with_rules
        expect(result).to include(mandatory, with_rules, both)
        expect(result).not_to include(neither)
      end
    end
  end

  # Test callbacks
  describe 'callbacks' do
    describe 'before_save :check_for_rules' do
      it 'sets has_rules to true when rules are present' do
        attr = create(:product_attribute, rules: [ 'positive', 'not_null' ])
        expect(attr.has_rules).to be true
      end

      it 'sets has_rules to false when rules is empty hash' do
        attr = create(:product_attribute, rules: {})
        expect(attr.has_rules).to be false
      end

      it 'sets has_rules to false when rules is empty array' do
        attr = create(:product_attribute, rules: [])
        expect(attr.has_rules).to be false
      end
    end

    describe 'after_save :propagate_change' do
      let(:company) { create(:company) }
      let(:attr) { create(:product_attribute, company: company) }
      let(:product) { create(:product, company: company) }
      let!(:pav) { create(:product_attribute_value, product: product, product_attribute: attr) }

      it 'touches all products using this attribute' do
        # Reload attr to refresh the products association after PAV was created
        attr.reload
        expect(attr.products).to receive(:each).and_call_original

        attr.update(name: 'Updated Name')
      end

      it 'updates product timestamps when attribute changes' do
        # Reload attr to refresh the products association after PAV was created
        attr.reload

        # Create a time reference in the past
        past_time = 1.day.ago
        product.update_column(:updated_at, past_time)

        attr.update(name: 'Updated Name')

        expect(product.reload.updated_at).to be > past_time
      end
    end
  end

  # Test RulesService methods
  describe 'RulesService methods' do
    let(:attr) { create(:product_attribute) }

    describe '#positive' do
      it 'returns true for positive integers' do
        expect(attr.positive('10')).to be true
        expect(attr.positive('1')).to be true
        expect(attr.positive('999999')).to be true
      end

      it 'returns false for zero' do
        expect(attr.positive('0')).to be false
      end

      it 'returns false for negative numbers' do
        expect(attr.positive('-5')).to be false
        expect(attr.positive('-100')).to be false
      end

      it 'returns false for non-numeric values' do
        expect(attr.positive('abc')).to be false
        expect(attr.positive('12.5')).to be false
      end
    end

    describe '#not_null' do
      it 'returns true for present values' do
        expect(attr.not_null('value')).to be true
        expect(attr.not_null('0')).to be true
        expect(attr.not_null('false')).to be true
      end

      it 'returns false for blank values' do
        expect(attr.not_null('')).to be false
        expect(attr.not_null(nil)).to be false
        expect(attr.not_null('   ')).to be false
      end
    end
  end

  # Test instance methods
  describe 'instance methods' do
    describe '#to_param' do
      let(:attr) { create(:product_attribute, code: 'special-price') }

      it 'returns code for URL parameter' do
        expect(attr.to_param).to eq('special-price')
      end
    end

    describe '#avjson' do
      let(:company) { create(:company) }
      let(:product) { create(:product, company: company) }

      context 'with view_format_general' do
        let(:attr) { create(:product_attribute, :general_format, company: company) }
        let(:av) { create(:product_attribute_value, product: product, product_attribute: attr, value: 'Test Value') }

        it 'returns value and display' do
          result = attr.avjson(av)
          expect(result['value']).to eq('Test Value')
          expect(result['display']).to eq('Test Value')
        end

        it 'includes localized values if present' do
          av.update(info: { 'localized_value' => { 'en' => 'English', 'de' => 'German' } })
          result = attr.avjson(av)
          expect(result['localized_value']).to eq({ 'en' => 'English', 'de' => 'German' })
        end
      end

      context 'with view_format_price' do
        let(:attr) { create(:product_attribute, :price_format, company: company) }
        let(:av) { create(:product_attribute_value, product: product, product_attribute: attr, value: '1999') }

        it 'formats price in cents to euros' do
          result = attr.avjson(av)
          expect(result['value']).to eq('1999')
          expect(result['display']).to include('19')
        end
      end

      context 'with view_format_weight' do
        let(:attr) { create(:product_attribute, :weight_format, company: company) }
        let(:av) { create(:product_attribute_value, product: product, product_attribute: attr, value: '1500') }

        it 'formats weight with units' do
          # Add weight units to i18n for this test
          # units: :weight looks up the key "en.weight" directly
          I18n.backend.store_translations(:en, { weight: { unit: 'g', thousand: 'kg' } })

          result = attr.avjson(av)
          expect(result['value']).to eq('1500')
          expect(result['display']).to be_present
        end
      end

      context 'with view_format_ean' do
        let(:attr) { create(:product_attribute, :ean_format, company: company) }
        let(:av) { create(:product_attribute_value, product: product, product_attribute: attr, value: '5012345678900') }

        it 'returns EAN value' do
          result = attr.avjson(av)
          expect(result['value']).to eq('5012345678900')
          expect(result['display']).to eq('5012345678900')
        end
      end

      context 'with view_format_customer_group_price' do
        let(:attr) { create(:product_attribute, :customer_group_price_format, company: company) }
        let(:av) do
          create(:product_attribute_value, :customer_group_price_value,
                 product: product, product_attribute: attr)
        end

        it 'formats customer group prices' do
          result = attr.avjson(av)
          expect(result['value']).to be_a(Hash)
          expect(result['value']).to have_key('retail')
          expect(result['display']).to include('retail')
        end
      end

      context 'with view_format_special_price' do
        let(:attr) { create(:product_attribute, :special_price_format, company: company) }
        let(:av) do
          create(:product_attribute_value, :special_price_value,
                 product: product, product_attribute: attr)
        end

        it 'formats special price with date range' do
          result = attr.avjson(av)
          expect(result['value']).to be_a(Hash)
          expect(result['value']).to have_key('amount')
          expect(result['value']).to have_key('from')
          expect(result['value']).to have_key('until')
          expect(result['display']).to include('-') # Date range separator
        end
      end

      context 'with view_format_related_products' do
        let(:attr) { create(:product_attribute, :related_products_format, company: company) }
        let(:av) do
          create(:product_attribute_value, :related_products_value,
                 product: product, product_attribute: attr)
        end

        it 'returns related products SKUs' do
          result = attr.avjson(av)
          expect(result['value']).to be_an(Array)
          expect(result['display']).to be_an(Array)
        end
      end

      context 'with unknown view_format' do
        it 'raises ArgumentError' do
          attr = create(:product_attribute, company: company)
          av = create(:product_attribute_value, product: product, product_attribute: attr)

          # Stub to return invalid format
          allow(attr).to receive(:view_format).and_return('invalid_format')

          expect { attr.avjson(av) }.to raise_error(ArgumentError, /Unknown view format/)
        end
      end
    end
  end

  # Test acts_as_list positioning within groups
  describe 'acts_as_list positioning' do
    let(:company) { create(:company) }
    let(:group1) { create(:attribute_group, company: company) }
    let(:group2) { create(:attribute_group, company: company) }

    context 'position assignment' do
      it 'assigns position automatically when created' do
        attr1 = create(:product_attribute, company: company, attribute_group: group1)
        attr2 = create(:product_attribute, company: company, attribute_group: group1)
        attr3 = create(:product_attribute, company: company, attribute_group: group1)

        expect(attr1.attribute_position).to eq(1)
        expect(attr2.attribute_position).to eq(2)
        expect(attr3.attribute_position).to eq(3)
      end

      it 'positions are scoped to company and attribute_group' do
        attr1_g1 = create(:product_attribute, company: company, attribute_group: group1)
        attr2_g1 = create(:product_attribute, company: company, attribute_group: group1)
        attr1_g2 = create(:product_attribute, company: company, attribute_group: group2)
        attr2_g2 = create(:product_attribute, company: company, attribute_group: group2)

        # Each group has independent positioning starting at 1
        expect(attr1_g1.attribute_position).to eq(1)
        expect(attr2_g1.attribute_position).to eq(2)
        expect(attr1_g2.attribute_position).to eq(1)
        expect(attr2_g2.attribute_position).to eq(2)
      end

      it 'ungrouped attributes have separate positioning' do
        attr1_grouped = create(:product_attribute, company: company, attribute_group: group1)
        attr1_ungrouped = create(:product_attribute, company: company, attribute_group: nil)
        attr2_grouped = create(:product_attribute, company: company, attribute_group: group1)
        attr2_ungrouped = create(:product_attribute, company: company, attribute_group: nil)

        # Grouped attributes
        expect(attr1_grouped.attribute_position).to eq(1)
        expect(attr2_grouped.attribute_position).to eq(2)

        # Ungrouped attributes (separate sequence)
        expect(attr1_ungrouped.attribute_position).to eq(1)
        expect(attr2_ungrouped.attribute_position).to eq(2)
      end

      it 'different companies have independent positioning' do
        other_company = create(:company)
        attr1 = create(:product_attribute, company: company, attribute_group: group1)
        attr2 = create(:product_attribute, company: other_company, attribute_group: nil)

        expect(attr1.attribute_position).to eq(1)
        expect(attr2.attribute_position).to eq(1)
      end
    end

    context 'reordering methods' do
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group1, name: 'First') }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group1, name: 'Second') }
      let!(:attr3) { create(:product_attribute, company: company, attribute_group: group1, name: 'Third') }
      let!(:attr_other_group) { create(:product_attribute, company: company, attribute_group: group2, name: 'Other Group') }

      it 'moves attribute to top within group' do
        attr3.move_to_top

        expect(attr3.reload.attribute_position).to eq(1)
        expect(attr1.reload.attribute_position).to eq(2)
        expect(attr2.reload.attribute_position).to eq(3)
      end

      it 'moves attribute to bottom within group' do
        attr1.move_to_bottom

        expect(attr2.reload.attribute_position).to eq(1)
        expect(attr3.reload.attribute_position).to eq(2)
        expect(attr1.reload.attribute_position).to eq(3)
      end

      it 'moves attribute higher within group' do
        attr3.move_higher

        expect(attr1.reload.attribute_position).to eq(1)
        expect(attr3.reload.attribute_position).to eq(2)
        expect(attr2.reload.attribute_position).to eq(3)
      end

      it 'moves attribute lower within group' do
        attr1.move_lower

        expect(attr2.reload.attribute_position).to eq(1)
        expect(attr1.reload.attribute_position).to eq(2)
        expect(attr3.reload.attribute_position).to eq(3)
      end

      it 'does not affect other group positions' do
        original_position = attr_other_group.attribute_position

        attr2.move_to_top

        expect(attr_other_group.reload.attribute_position).to eq(original_position)
      end
    end

    context 'moving between groups' do
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 1) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 2) }
      let!(:attr3) { create(:product_attribute, company: company, attribute_group: group2, attribute_position: 1) }

      it 'reorders when attribute moves to different group' do
        attr1.update(attribute_group: group2)

        # When attr1 moves to group2 with explicit position 1, it keeps that position
        # and bumps attr3 (which was at position 1) to position 2
        expect(attr1.reload.attribute_position).to eq(1)
        expect(attr3.reload.attribute_position).to eq(2)

        # group1 should be reordered - attr2 moves to position 1
        expect(attr2.reload.attribute_position).to eq(1)
      end

      it 'reorders when attribute becomes ungrouped' do
        attr1.update(attribute_group: nil)

        # attr1 gets new position in ungrouped sequence
        expect(attr1.reload.attribute_position).to eq(1)

        # group1 should be reordered
        expect(attr2.reload.attribute_position).to eq(1)
      end
    end

    context 'default_scope ordering' do
      let!(:attr3) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 3) }
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 1) }
      let!(:attr_nil) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: nil) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group1, attribute_position: 2) }

      it 'orders by attribute_position asc with nulls last' do
        attrs = group1.product_attributes.to_a
        expect(attrs).to eq([ attr1, attr2, attr3, attr_nil ])
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'complete attribute with rules' do
      let(:attr) do
        # Use the system-created price attribute (already exists from after_create)
        company.product_attributes.find_by(code: 'price')
      end

      it 'has all properties configured correctly' do
        expect(attr.code).to eq('price')
        expect(attr.patype_number?).to be true
        expect(attr.view_format_price?).to be true
        expect(attr.mandatory).to be true
        expect(attr.has_rules).to be true
        expect(attr.rules).to contain_exactly('positive', 'not_null')
      end

      it 'validates values correctly' do
        expect(attr.positive('1999')).to be true
        expect(attr.not_null('1999')).to be true
        expect(attr.positive('-10')).to be false
        expect(attr.not_null('')).to be false
      end
    end

    context 'attribute with products' do
      let(:attr) { create(:product_attribute, company: company) }
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }

      before do
        create(:product_attribute_value, product: product1, product_attribute: attr)
        create(:product_attribute_value, product: product2, product_attribute: attr)
      end

      it 'can access products through attribute values' do
        # Reload to clear any cached association state
        expect(attr.reload.products).to contain_exactly(product1, product2)
      end

      it 'destroys attribute values when attribute is destroyed' do
        expect { attr.destroy }.to change { ProductAttributeValue.count }.by(-2)
      end
    end

    context 'select and multiselect types' do
      let(:select_attr) { create(:product_attribute, :select_type, company: company) }
      let(:multiselect_attr) { create(:product_attribute, :multiselect_type, company: company) }

      it 'stores options in info field' do
        expect(select_attr.info['options']).to be_an(Array)
        expect(select_attr.info['options']).not_to be_empty
        expect(multiselect_attr.info['options']).to be_an(Array)
      end
    end

    context 'grouped attributes' do
      let(:group) { create(:attribute_group, company: company, code: 'test_grouping', name: 'Test Grouping') }
      let(:attr1) { create(:product_attribute, :price_format, company: company, attribute_group: group, code: 'custom_price_test') }
      let(:attr2) { create(:product_attribute, :price_format, company: company, attribute_group: group, code: 'custom_special_test') }
      let(:ungrouped_attr) { create(:product_attribute, company: company, attribute_group: nil) }

      it 'can belong to an attribute group' do
        expect(attr1.attribute_group).to eq(group)
        expect(attr2.attribute_group).to eq(group)
        expect(ungrouped_attr.attribute_group).to be_nil
      end

      it 'maintains position within group' do
        expect(attr1.attribute_position).to eq(1)
        expect(attr2.attribute_position).to eq(2)
      end

      it 'can access group attributes' do
        expect(group.product_attributes).to include(attr1, attr2)
        expect(group.product_attributes).not_to include(ungrouped_attr)
      end

      it 'survives group deletion (nullifies group_id)' do
        # Force creation of attrs before destroying group
        attr1_id = attr1.id
        attr2_id = attr2.id

        group.destroy

        expect(attr1.reload.attribute_group_id).to be_nil
        expect(attr2.reload.attribute_group_id).to be_nil
        expect(ProductAttribute.exists?(attr1_id)).to be true
        expect(ProductAttribute.exists?(attr2_id)).to be true
      end
    end
  end
end
