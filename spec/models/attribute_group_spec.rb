require 'rails_helper'

RSpec.describe AttributeGroup, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:attribute_group)).to be_valid
    end

    it 'creates valid groups with predefined traits' do
      expect(create(:attribute_group, :basic_info_group)).to be_valid
      expect(create(:attribute_group, :pricing_group)).to be_valid
      expect(create(:attribute_group, :dimensions_group)).to be_valid
      expect(create(:attribute_group, :technical_group)).to be_valid
      expect(create(:attribute_group, :seo_group)).to be_valid
    end

    it 'creates positioned groups' do
      group = create(:attribute_group, :positioned)
      expect(group.position).to be_present
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to have_many(:product_attributes).dependent(:nullify) }

    context 'with product attributes' do
      let(:company) { create(:company) }
      let(:group) { create(:attribute_group, company: company) }
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group) }
      let!(:ungrouped_attr) { create(:product_attribute, company: company, attribute_group: nil) }

      it 'returns only attributes belonging to the group' do
        expect(group.product_attributes).to contain_exactly(attr1, attr2)
        expect(group.product_attributes).not_to include(ungrouped_attr)
      end

      it 'nullifies attribute_group_id when group is destroyed' do
        group.destroy

        attr1.reload
        attr2.reload

        expect(attr1.attribute_group_id).to be_nil
        expect(attr2.attribute_group_id).to be_nil
        expect(ProductAttribute.exists?(attr1.id)).to be true
        expect(ProductAttribute.exists?(attr2.id)).to be true
      end
    end
  end

  # Test validations
  describe 'validations' do
    subject { build(:attribute_group) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.to validate_presence_of(:company) }

    context 'code format validation' do
      let(:company) { create(:company) }

      it 'allows valid codes with lowercase letters, numbers, and underscores' do
        expect(build(:attribute_group, company: company, code: 'valid_code')).to be_valid
        expect(build(:attribute_group, company: company, code: 'valid123')).to be_valid
        expect(build(:attribute_group, company: company, code: 'valid_code_123')).to be_valid
        expect(build(:attribute_group, company: company, code: 'abc123xyz')).to be_valid
      end

      it 'rejects codes with uppercase letters' do
        group = build(:attribute_group, company: company, code: 'InvalidCode')
        expect(group).not_to be_valid
        expect(group.errors[:code]).to include('only allows lowercase letters, numbers, and underscores')
      end

      it 'rejects codes with spaces' do
        group = build(:attribute_group, company: company, code: 'invalid code')
        expect(group).not_to be_valid
        expect(group.errors[:code]).to include('only allows lowercase letters, numbers, and underscores')
      end

      it 'rejects codes with special characters' do
        group = build(:attribute_group, company: company, code: 'invalid-code')
        expect(group).not_to be_valid
        expect(group.errors[:code]).to include('only allows lowercase letters, numbers, and underscores')
      end

      it 'rejects codes with hyphens' do
        group = build(:attribute_group, company: company, code: 'invalid-code')
        expect(group).not_to be_valid
      end
    end

    context 'uniqueness validations' do
      let(:company) { create(:company) }

      before do
        create(:attribute_group, company: company, code: 'pricing')
      end

      it 'validates uniqueness of code scoped to company' do
        duplicate = build(:attribute_group, company: company, code: 'pricing')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different companies' do
        other_company = create(:company)
        group = build(:attribute_group, company: other_company, code: 'pricing')
        expect(group).to be_valid
      end

      it 'validates uniqueness case-insensitively' do
        duplicate = build(:attribute_group, company: company, code: 'PRICING')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'validates uniqueness with mixed case' do
        duplicate = build(:attribute_group, company: company, code: 'Pricing')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end
    end
  end

  # Test acts_as_list positioning
  describe 'acts_as_list positioning' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }

    context 'position assignment' do
      it 'assigns position automatically when created' do
        group1 = create(:attribute_group, company: company)
        group2 = create(:attribute_group, company: company)
        group3 = create(:attribute_group, company: company)

        expect(group1.position).to eq(1)
        expect(group2.position).to eq(2)
        expect(group3.position).to eq(3)
      end

      it 'positions are scoped to company' do
        group1 = create(:attribute_group, company: company)
        group2 = create(:attribute_group, company: other_company)
        group3 = create(:attribute_group, company: company)

        expect(group1.position).to eq(1)
        expect(group2.position).to eq(1) # Different company, starts at 1
        expect(group3.position).to eq(2) # Same company as group1
      end
    end

    context 'reordering methods' do
      let!(:group1) { create(:attribute_group, company: company, name: 'First') }
      let!(:group2) { create(:attribute_group, company: company, name: 'Second') }
      let!(:group3) { create(:attribute_group, company: company, name: 'Third') }
      let!(:other_company_group) { create(:attribute_group, company: other_company, name: 'Other') }

      it 'moves group to top' do
        group3.move_to_top

        expect(group3.reload.position).to eq(1)
        expect(group1.reload.position).to eq(2)
        expect(group2.reload.position).to eq(3)
      end

      it 'moves group to bottom' do
        group1.move_to_bottom

        expect(group2.reload.position).to eq(1)
        expect(group3.reload.position).to eq(2)
        expect(group1.reload.position).to eq(3)
      end

      it 'moves group higher' do
        group3.move_higher

        expect(group1.reload.position).to eq(1)
        expect(group3.reload.position).to eq(2)
        expect(group2.reload.position).to eq(3)
      end

      it 'moves group lower' do
        group1.move_lower

        expect(group2.reload.position).to eq(1)
        expect(group1.reload.position).to eq(2)
        expect(group3.reload.position).to eq(3)
      end

      it 'inserts at specific position' do
        group1.insert_at(3)

        expect(group2.reload.position).to eq(1)
        expect(group3.reload.position).to eq(2)
        expect(group1.reload.position).to eq(3)
      end

      it 'does not affect other company positions' do
        original_position = other_company_group.position

        group2.move_to_top

        expect(other_company_group.reload.position).to eq(original_position)
      end
    end

    context 'position queries' do
      let!(:group1) { create(:attribute_group, company: company) }
      let!(:group2) { create(:attribute_group, company: company) }
      let!(:group3) { create(:attribute_group, company: company) }

      it 'identifies first item' do
        expect(group1.first?).to be true
        expect(group2.first?).to be false
      end

      it 'identifies last item' do
        expect(group3.last?).to be true
        expect(group2.last?).to be false
      end

      it 'returns higher_item' do
        expect(group2.higher_item).to eq(group1)
        expect(group1.higher_item).to be_nil
      end

      it 'returns lower_item' do
        expect(group2.lower_item).to eq(group3)
        expect(group3.lower_item).to be_nil
      end
    end

    context 'deletion reordering' do
      let!(:group1) { create(:attribute_group, company: company) }
      let!(:group2) { create(:attribute_group, company: company) }
      let!(:group3) { create(:attribute_group, company: company) }

      it 'reorders positions when middle item is deleted' do
        group2.destroy

        expect(group1.reload.position).to eq(1)
        expect(group3.reload.position).to eq(2)
      end

      it 'reorders positions when first item is deleted' do
        group1.destroy

        expect(group2.reload.position).to eq(1)
        expect(group3.reload.position).to eq(2)
      end
    end
  end

  # Test instance methods
  describe 'instance methods' do
    describe '#to_param' do
      let(:group) { create(:attribute_group, code: 'basic_info') }

      it 'returns code for URL parameter' do
        expect(group.to_param).to eq('basic_info')
      end

      it 'allows finding by code' do
        expect(AttributeGroup.find_by(code: group.to_param)).to eq(group)
      end
    end
  end

  # Multi-tenancy tests
  describe 'multi-tenancy' do
    let(:company1) { create(:company) }
    let(:company2) { create(:company) }
    let!(:group1) { create(:attribute_group, company: company1, code: 'pricing', name: 'Company 1 Pricing') }
    let!(:group2) { create(:attribute_group, company: company2, code: 'pricing', name: 'Company 2 Pricing') }

    it 'allows same code for different companies' do
      expect(group1).to be_valid
      expect(group2).to be_valid
      expect(group1.code).to eq(group2.code)
    end

    it 'scopes queries by company' do
      company1_groups = company1.attribute_groups
      company2_groups = company2.attribute_groups

      expect(company1_groups).to include(group1)
      expect(company1_groups).not_to include(group2)

      expect(company2_groups).to include(group2)
      expect(company2_groups).not_to include(group1)
    end

    it 'prevents accessing other company groups via find_by code' do
      # When querying with company scope
      found = company1.attribute_groups.find_by(code: 'pricing')
      expect(found).to eq(group1)
      expect(found).not_to eq(group2)
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }

    context 'complete group with attributes' do
      let(:group) { create(:attribute_group, :pricing_group, company: company) }
      let!(:attr1) { create(:product_attribute, :price_format, company: company, attribute_group: group, code: 'price', name: 'Price') }
      let!(:attr2) { create(:product_attribute, :price_format, company: company, attribute_group: group, code: 'special_price', name: 'Special Price') }
      let!(:attr3) { create(:product_attribute, company: company, attribute_group: group, code: 'cost', name: 'Cost') }

      it 'has all properties configured correctly' do
        expect(group.code).to eq('pricing')
        expect(group.name).to eq('Pricing & Cost')
        expect(group.product_attributes.count).to eq(3)
      end

      it 'returns attributes in order' do
        attributes = group.product_attributes.to_a
        expect(attributes).to eq([attr1, attr2, attr3])
      end

      it 'nullifies attributes when destroyed' do
        group.destroy

        expect(ProductAttribute.exists?(attr1.id)).to be true
        expect(attr1.reload.attribute_group_id).to be_nil
        expect(attr2.reload.attribute_group_id).to be_nil
        expect(attr3.reload.attribute_group_id).to be_nil
      end
    end

    context 'group with mixed scope attributes' do
      let(:group) { create(:attribute_group, company: company) }
      let!(:product_attr) { create(:product_attribute, :product_scope, company: company, attribute_group: group) }
      let!(:catalog_attr) { create(:product_attribute, :catalog_scope, company: company, attribute_group: group) }
      let!(:both_attr) { create(:product_attribute, :product_and_catalog_scope, company: company, attribute_group: group) }

      it 'supports attributes with different scopes in same group' do
        expect(group.product_attributes.count).to eq(3)
        expect(group.product_attributes).to include(product_attr, catalog_attr, both_attr)
      end
    end

    context 'empty group' do
      let!(:group) { create(:attribute_group, company: company) }

      it 'can be destroyed when empty' do
        expect { group.destroy }.to change(AttributeGroup, :count).by(-1)
      end

      it 'has no product attributes' do
        expect(group.product_attributes).to be_empty
      end
    end

    context 'group with positioned attributes' do
      let(:group) { create(:attribute_group, company: company) }
      let!(:attr3) { create(:product_attribute, company: company, attribute_group: group, attribute_position: 3) }
      let!(:attr1) { create(:product_attribute, company: company, attribute_group: group, attribute_position: 1) }
      let!(:attr2) { create(:product_attribute, company: company, attribute_group: group, attribute_position: 2) }

      it 'returns attributes ordered by position' do
        attributes = group.product_attributes.to_a
        expect(attributes).to eq([attr1, attr2, attr3])
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:company) { create(:company) }

    it 'handles very long names' do
      long_name = 'A' * 255
      group = build(:attribute_group, company: company, name: long_name)
      expect(group).to be_valid
    end

    it 'handles very long codes' do
      long_code = 'a' * 100
      group = build(:attribute_group, company: company, code: long_code)
      expect(group).to be_valid
    end

    it 'handles groups with many attributes' do
      group = create(:attribute_group, company: company)
      50.times do |i|
        create(:product_attribute, company: company, attribute_group: group, code: "attr_#{i}")
      end

      expect(group.product_attributes.count).to eq(50)
    end

    it 'handles nil description' do
      group = build(:attribute_group, company: company, description: nil)
      expect(group).to be_valid
    end

    it 'handles empty description' do
      group = build(:attribute_group, company: company, description: '')
      expect(group).to be_valid
    end

    it 'handles special characters in name' do
      group = build(:attribute_group, company: company, name: 'Pricing & Cost (€)')
      expect(group).to be_valid
    end
  end
end
