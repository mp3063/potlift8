require 'rails_helper'

RSpec.describe Configuration, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:configuration)).to be_valid
    end

    it 'creates valid configurations with traits' do
      expect(create(:configuration, :size)).to be_valid
      expect(create(:configuration, :color)).to be_valid
      expect(create(:configuration, :material)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:product) }
    it { is_expected.to have_many(:configuration_values).dependent(:destroy) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:configuration) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:code) }

    context 'code uniqueness' do
      let(:company) { create(:company) }
      let(:product) { create(:product, company: company) }

      before do
        create(:configuration, product: product, code: 'size')
      end

      it 'validates uniqueness of code scoped to product' do
        duplicate = build(:configuration, product: product, code: 'size')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:code]).to include('has already been taken')
      end

      it 'allows same code for different products' do
        other_product = create(:product, company: company)
        config = build(:configuration, product: other_product, code: 'size')
        expect(config).to be_valid
      end
    end
  end

  # Test acts_as_list
  describe 'acts_as_list' do
    let(:product) { create(:product) }

    it 'sets position on create' do
      config1 = create(:configuration, product: product)
      config2 = create(:configuration, product: product)
      config3 = create(:configuration, product: product)

      expect(config1.position).to eq(1)
      expect(config2.position).to eq(2)
      expect(config3.position).to eq(3)
    end

    it 'can move items up and down' do
      config1 = create(:configuration, product: product)
      config2 = create(:configuration, product: product)
      config3 = create(:configuration, product: product)

      config3.move_to_top
      config3.reload
      config1.reload

      expect(config3.position).to eq(1)
      expect(config1.position).to eq(2)
    end

    it 'scopes position to product' do
      other_product = create(:product)

      config1 = create(:configuration, product: product)
      config2 = create(:configuration, product: other_product)

      expect(config1.position).to eq(1)
      expect(config2.position).to eq(1) # Same position but different product
    end

    it 'reorders remaining items when deleted' do
      config1 = create(:configuration, product: product)
      config2 = create(:configuration, product: product)
      config3 = create(:configuration, product: product)

      config2.destroy

      config1.reload
      config3.reload

      expect(config1.position).to eq(1)
      expect(config3.position).to eq(2)
    end
  end

  # Test configuration with values
  describe 'configuration with values' do
    let(:configuration) { create(:configuration, :size) }

    it 'creates configuration with values using trait' do
      expect(configuration.configuration_values.count).to eq(3)
      expect(configuration.configuration_values.pluck(:value)).to include('Small', 'Medium', 'Large')
    end

    it 'destroys values when configuration is destroyed' do
      value_ids = configuration.configuration_values.pluck(:id)

      expect {
        configuration.destroy
      }.to change { ConfigurationValue.where(id: value_ids).count }.to(0)
    end
  end

  # Test multi-tenancy
  describe 'multi-tenancy' do
    let(:company) { create(:company) }
    let(:other_company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:other_product) { create(:product, company: other_company) }

    it 'configurations belong to company through product' do
      config = create(:configuration, product: product, company: company)
      expect(config.company).to eq(company)
    end

    it 'prevents cross-company associations' do
      expect {
        create(:configuration, product: other_product, company: company)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # Integration tests
  describe 'integration' do
    context 'size and color configurations' do
      let(:product) { create(:product, :configurable_variant) }
      let!(:size_config) { create(:configuration, :size, product: product) }
      let!(:color_config) { create(:configuration, :color, product: product) }

      it 'product has multiple configurations' do
        expect(product.configurations.count).to eq(2)
        expect(product.configurations).to include(size_config, color_config)
      end

      it 'each configuration has multiple values' do
        expect(size_config.configuration_values.count).to eq(3)
        expect(color_config.configuration_values.count).to eq(3)
      end

      it 'configurations are ordered by position' do
        configurations = product.configurations.order(:position)
        expect(configurations.first).to eq(size_config)
      end
    end

    context 'configuration without values' do
      let(:product) { create(:product, :configurable_variant) }
      let(:config) { create(:configuration, product: product, name: 'Empty', code: 'empty') }

      it 'can exist without values' do
        expect(config).to be_valid
        expect(config.configuration_values.count).to eq(0)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    it 'handles long names' do
      long_name = 'A' * 255
      config = build(:configuration, name: long_name)
      expect(config).to be_valid
    end

    it 'handles special characters in code' do
      config = build(:configuration, code: 'size_large-xl')
      expect(config).to be_valid
    end

    it 'requires non-blank name' do
      config = build(:configuration, name: '   ')
      expect(config).not_to be_valid
    end

    it 'requires non-blank code' do
      config = build(:configuration, code: '')
      expect(config).not_to be_valid
    end
  end
end
