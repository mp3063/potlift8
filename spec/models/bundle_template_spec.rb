require 'rails_helper'

RSpec.describe BundleTemplate, type: :model do
  let(:company) { create(:company) }
  let(:bundle_product) { create(:product, :bundle, company: company) }

  describe 'associations' do
    it { is_expected.to belong_to(:product) }
    it { is_expected.to belong_to(:company) }
  end

  describe 'validations' do
    subject { build(:bundle_template, product: bundle_product, company: company) }

    it { is_expected.to validate_presence_of(:product) }
    it { is_expected.to validate_presence_of(:company) }
    it { is_expected.to validate_uniqueness_of(:product_id) }

    it 'validates product is a bundle' do
      sellable = create(:product, :sellable, company: company)
      template = build(:bundle_template, product: sellable, company: company)

      expect(template).not_to be_valid
      expect(template.errors[:product]).to include('must be a bundle product')
    end
  end

  describe '#configuration' do
    it 'defaults to empty hash' do
      template = BundleTemplate.new
      expect(template.configuration).to eq({})
    end

    it 'stores component configuration as JSONB' do
      config = {
        'components' => [
          { 'product_id' => 1, 'product_type' => 'sellable', 'quantity' => 2 }
        ]
      }
      template = create(:bundle_template, product: bundle_product, company: company, configuration: config)
      template.reload

      expect(template.configuration).to eq(config)
    end
  end

  describe '#components' do
    it 'returns components array from configuration' do
      config = { 'components' => [ { 'product_id' => 1 } ] }
      template = build(:bundle_template, configuration: config)

      expect(template.components).to eq([ { 'product_id' => 1 } ])
    end

    it 'returns empty array when no components' do
      template = build(:bundle_template, configuration: {})
      expect(template.components).to eq([])
    end
  end
end
