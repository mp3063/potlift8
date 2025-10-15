require 'rails_helper'

RSpec.describe ConfigurationValue, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:configuration_value)).to be_valid
    end

    it 'creates valid configuration values with traits' do
      expect(create(:configuration_value, :small)).to be_valid
      expect(create(:configuration_value, :medium)).to be_valid
      expect(create(:configuration_value, :large)).to be_valid
      expect(create(:configuration_value, :red)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:configuration) }
    it { is_expected.to have_many(:variant_configuration_values) }
    it { is_expected.to have_many(:variants).through(:variant_configuration_values) }
  end

  # Test validations
  describe 'validations' do
    subject { build(:configuration_value) }

    it { is_expected.to validate_presence_of(:value) }

    it 'validates non-blank value' do
      config_value = build(:configuration_value, value: '   ')
      expect(config_value).not_to be_valid
    end
  end

  # Test acts_as_list
  describe 'acts_as_list' do
    let(:configuration) { create(:configuration) }

    it 'sets position on create' do
      value1 = create(:configuration_value, configuration: configuration)
      value2 = create(:configuration_value, configuration: configuration)
      value3 = create(:configuration_value, configuration: configuration)

      expect(value1.position).to eq(1)
      expect(value2.position).to eq(2)
      expect(value3.position).to eq(3)
    end

    it 'can reorder values' do
      value1 = create(:configuration_value, configuration: configuration, value: 'First')
      value2 = create(:configuration_value, configuration: configuration, value: 'Second')
      value3 = create(:configuration_value, configuration: configuration, value: 'Third')

      value3.move_to_top
      value1.reload
      value2.reload
      value3.reload

      expect(value3.position).to eq(1)
      expect(value1.position).to eq(2)
      expect(value2.position).to eq(3)
    end

    it 'scopes position to configuration' do
      other_configuration = create(:configuration)

      value1 = create(:configuration_value, configuration: configuration)
      value2 = create(:configuration_value, configuration: other_configuration)

      expect(value1.position).to eq(1)
      expect(value2.position).to eq(1) # Same position but different configuration
    end

    it 'reorders remaining values when deleted' do
      value1 = create(:configuration_value, configuration: configuration)
      value2 = create(:configuration_value, configuration: configuration)
      value3 = create(:configuration_value, configuration: configuration)

      value2.destroy

      value1.reload
      value3.reload

      expect(value1.position).to eq(1)
      expect(value3.position).to eq(2)
    end
  end

  # Test association with variants
  describe 'variant associations' do
    let(:configuration) { create(:configuration, :size) }
    let(:value_small) { configuration.configuration_values.find_by(value: 'Small') }
    let(:variant) { create(:variant) }

    it 'can be associated with variants' do
      create(:variant_configuration_value,
             variant: variant,
             configuration: configuration,
             configuration_value: value_small)

      expect(value_small.variants).to include(variant)
      expect(variant.configuration_values).to include(value_small)
    end

    it 'tracks multiple variants using same value' do
      variant1 = create(:variant)
      variant2 = create(:variant)

      create(:variant_configuration_value,
             variant: variant1,
             configuration: configuration,
             configuration_value: value_small)
      create(:variant_configuration_value,
             variant: variant2,
             configuration: configuration,
             configuration_value: value_small)

      expect(value_small.variants.count).to eq(2)
      expect(value_small.variants).to include(variant1, variant2)
    end
  end

  # Integration tests
  describe 'integration' do
    context 'size configuration with values' do
      let(:size_config) { create(:configuration, :size) }

      it 'has three size values in order' do
        values = size_config.configuration_values.order(:position)
        expect(values.count).to eq(3)
        expect(values.pluck(:value)).to eq(['Small', 'Medium', 'Large'])
      end

      it 'can add new value to existing configuration' do
        expect {
          create(:configuration_value, configuration: size_config, value: 'XL')
        }.to change { size_config.configuration_values.count }.by(1)

        expect(size_config.configuration_values.pluck(:value)).to include('XL')
      end
    end

    context 'configuration value deletion with variants' do
      let(:configuration) { create(:configuration, :size) }
      let(:value_small) { configuration.configuration_values.find_by(value: 'Small') }
      let(:variant) { create(:variant) }

      before do
        create(:variant_configuration_value,
               variant: variant,
               configuration: configuration,
               configuration_value: value_small)
      end

      it 'deleting value removes variant associations' do
        expect {
          value_small.destroy
        }.to change { VariantConfigurationValue.count }.by(-1)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    it 'handles long values' do
      long_value = 'A' * 255
      config_value = build(:configuration_value, value: long_value)
      expect(config_value).to be_valid
    end

    it 'handles special characters in value' do
      config_value = build(:configuration_value, value: 'Size: 32" x 40"')
      expect(config_value).to be_valid
    end

    it 'handles unicode characters' do
      config_value = build(:configuration_value, value: 'Größe XL')
      expect(config_value).to be_valid
    end

    it 'allows duplicate values in same configuration' do
      configuration = create(:configuration)
      value1 = create(:configuration_value, configuration: configuration, value: 'Medium')
      value2 = build(:configuration_value, configuration: configuration, value: 'Medium')

      # Duplicate values ARE allowed within same configuration
      expect(value2).to be_valid
    end

    it 'handles numeric values' do
      config_value = build(:configuration_value, value: '42')
      expect(config_value).to be_valid
    end

    it 'handles values with only spaces' do
      config_value = build(:configuration_value, value: '   ')
      expect(config_value).not_to be_valid
    end
  end

  # Multi-tenancy
  describe 'multi-tenancy' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company) }
    let(:configuration) { create(:configuration, product: product, company: company) }

    it 'configuration value inherits company context from configuration' do
      config_value = create(:configuration_value, configuration: configuration)
      expect(config_value.configuration.product.company).to eq(company)
    end
  end
end
