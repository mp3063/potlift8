# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SystemAttributes, type: :model do
  describe 'SYSTEM_ATTRIBUTES registry' do
    it 'defines exactly 12 system attributes' do
      expect(SystemAttributes::SYSTEM_ATTRIBUTES.keys).to contain_exactly(
        :price, :purchase_price, :special_price, :vat_group,
        :ean, :secondary_sku,
        :description_html, :short_description, :detailed_description, :brand,
        :weight, :sizechart
      )
    end

    it 'every attribute has required keys' do
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        expect(config).to have_key(:pa_type), "#{code} missing pa_type"
        expect(config).to have_key(:view_format), "#{code} missing view_format"
        expect(config).to have_key(:group), "#{code} missing group"
        expect(config).to have_key(:scope), "#{code} missing scope"
        expect(config).to have_key(:name), "#{code} missing name"
        expect(config).to have_key(:description), "#{code} missing description"
      end
    end

    it 'all groups reference valid SYSTEM_ATTRIBUTE_GROUPS' do
      valid_groups = SystemAttributes::SYSTEM_ATTRIBUTE_GROUPS.keys
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        expect(valid_groups).to include(config[:group]),
          "#{code} references unknown group #{config[:group]}"
      end
    end

    it 'all pa_types are valid ProductAttribute enum values' do
      valid_types = ProductAttribute.pa_types.keys.map(&:to_sym)
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        expect(valid_types).to include(config[:pa_type]),
          "#{code} has invalid pa_type #{config[:pa_type]}"
      end
    end

    it 'all view_formats are valid ProductAttribute enum values' do
      valid_formats = ProductAttribute.view_formats.keys.map(&:to_sym)
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        expect(valid_formats).to include(config[:view_format]),
          "#{code} has invalid view_format #{config[:view_format]}"
      end
    end

    it 'all scopes are valid ProductAttribute enum values' do
      valid_scopes = ProductAttribute.product_attribute_scopes.keys.map(&:to_sym)
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        expect(valid_scopes).to include(config[:scope]),
          "#{code} has invalid scope #{config[:scope]}"
      end
    end
  end

  describe 'SYSTEM_ATTRIBUTE_GROUPS' do
    it 'defines exactly 4 groups' do
      expect(SystemAttributes::SYSTEM_ATTRIBUTE_GROUPS.keys).to contain_exactly(
        :pricing, :identifiers, :details, :physical
      )
    end

    it 'every group has name and position' do
      SystemAttributes::SYSTEM_ATTRIBUTE_GROUPS.each do |code, config|
        expect(config).to have_key(:name), "#{code} missing name"
        expect(config).to have_key(:position), "#{code} missing position"
        expect(config[:position]).to be_a(Integer)
      end
    end
  end

  describe '.ensure_system_attributes!' do
    let(:company) { create(:company) }

    it 'creates all 12 system attributes for a company' do
      system_attrs = company.product_attributes.where(system: true)
      expect(system_attrs.count).to eq(12)
    end

    it 'creates all 4 attribute groups' do
      groups = company.attribute_groups
      system_group_codes = SystemAttributes::SYSTEM_ATTRIBUTE_GROUPS.keys.map(&:to_s)
      expect(groups.where(code: system_group_codes).count).to eq(4)
    end

    it 'assigns correct types and formats to each attribute' do
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        attr = company.product_attributes.find_by(code: code.to_s)
        expect(attr).to be_present, "Missing system attribute: #{code}"
        expect(attr.pa_type).to eq(config[:pa_type].to_s), "#{code} pa_type mismatch"
        expect(attr.view_format).to eq(config[:view_format].to_s), "#{code} view_format mismatch"
      end
    end

    it 'assigns correct attribute groups' do
      SystemAttributes::SYSTEM_ATTRIBUTES.each do |code, config|
        attr = company.product_attributes.find_by(code: code.to_s)
        group = company.attribute_groups.find_by(code: config[:group].to_s)
        expect(attr.attribute_group).to eq(group), "#{code} should be in group #{config[:group]}"
      end
    end

    it 'sets mandatory flag correctly' do
      price = company.product_attributes.find_by(code: 'price')
      expect(price.mandatory).to be true

      brand = company.product_attributes.find_by(code: 'brand')
      expect(brand.mandatory).to be false
    end

    it 'sets rules correctly for price attribute' do
      price = company.product_attributes.find_by(code: 'price')
      expect(price.has_rules).to be true
      expect(price.rules).to contain_exactly('positive', 'not_null')
    end

    it 'sets shopify_metafield columns for attributes with metafield config' do
      detailed = company.product_attributes.find_by(code: 'detailed_description')
      expect(detailed.shopify_metafield_namespace).to eq('global')
      expect(detailed.shopify_metafield_key).to eq('detailed_description_html')
      expect(detailed.shopify_metafield_type).to eq('multi_line_text_field')

      sizechart = company.product_attributes.find_by(code: 'sizechart')
      expect(sizechart.shopify_metafield_namespace).to eq('global')
      expect(sizechart.shopify_metafield_key).to eq('sizechart')
    end

    it 'does not set shopify_metafield columns for attributes without metafield config' do
      price = company.product_attributes.find_by(code: 'price')
      expect(price.shopify_metafield_namespace).to be_nil
      expect(price.shopify_metafield_key).to be_nil
    end

    context 'idempotency' do
      it 'does not duplicate attributes when run twice' do
        expect {
          ProductAttribute.ensure_system_attributes!(company)
        }.not_to change { company.product_attributes.count }
      end

      it 'does not duplicate groups when run twice' do
        expect {
          ProductAttribute.ensure_system_attributes!(company)
        }.not_to change { company.attribute_groups.count }
      end

      it 'preserves system flag on repeated runs' do
        ProductAttribute.ensure_system_attributes!(company)
        company.product_attributes.where(system: true).each do |attr|
          expect(attr.system?).to be true
        end
      end
    end

    context 'existing attribute with mismatched type' do
      it 'forces type/format to match system definition on re-run' do
        # after_create already created the 'price' attribute correctly.
        # Simulate a pre-existing mismatch by updating the record directly.
        price = company.product_attributes.unscoped.find_by(code: 'price')
        price.update_columns(pa_type: ProductAttribute.pa_types[:patype_text],
                             view_format: ProductAttribute.view_formats[:view_format_general],
                             system: false)

        # Re-run should detect the conflict and force correct type/format
        ProductAttribute.ensure_system_attributes!(company)

        updated = company.product_attributes.unscoped.find_by(code: 'price')
        expect(updated.system?).to be true
        expect(updated.pa_type).to eq('patype_number')
        expect(updated.view_format).to eq('view_format_price')
      end
    end
  end

  describe 'system attribute protection' do
    let(:company) { create(:company) }

    describe 'immutable fields' do
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }

      it 'prevents changing code on system attribute' do
        price_attr.code = 'new_code'
        expect(price_attr).not_to be_valid
        expect(price_attr.errors[:code]).to include('cannot be changed for system attributes')
      end

      it 'prevents changing pa_type on system attribute' do
        price_attr.pa_type = :patype_text
        expect(price_attr).not_to be_valid
        expect(price_attr.errors[:pa_type]).to include('cannot be changed for system attributes')
      end

      it 'prevents changing view_format on system attribute' do
        price_attr.view_format = :view_format_general
        expect(price_attr).not_to be_valid
        expect(price_attr.errors[:view_format]).to include('cannot be changed for system attributes')
      end

      it 'allows changing name on system attribute' do
        price_attr.name = 'Updated Price Name'
        expect(price_attr).to be_valid
      end

      it 'allows changing description on system attribute' do
        price_attr.description = 'Updated description'
        expect(price_attr).to be_valid
      end
    end

    describe 'destroy prevention' do
      let(:price_attr) { company.product_attributes.find_by(code: 'price') }

      it 'prevents deleting a system attribute' do
        expect(price_attr.destroy).to be false
        expect(price_attr.errors[:base]).to include('System attributes cannot be deleted')
      end

      it 'does not remove the record from database' do
        price_attr.destroy
        expect(ProductAttribute.unscoped.find_by(id: price_attr.id)).to be_present
      end

      it 'allows deleting a non-system attribute' do
        custom = create(:product_attribute, company: company, code: 'custom_deletable')
        expect { custom.destroy }.to change { ProductAttribute.unscoped.count }.by(-1)
      end
    end
  end

  describe 'SHOPIFY_METAFIELD_TYPE_MAP' do
    it 'maps all pa_types to Shopify metafield types' do
      ProductAttribute.pa_types.keys.each do |pa_type|
        expect(ProductAttribute::SHOPIFY_METAFIELD_TYPE_MAP).to have_key(pa_type),
          "Missing Shopify metafield type mapping for #{pa_type}"
      end
    end
  end
end
