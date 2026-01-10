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

    # Note: The old Variant/VariantConfigurationValue models have been replaced
    # with ProductConfiguration which stores variant config in JSONB info field.
    # ConfigurationValue no longer has direct associations to variants.
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

  # Test relationship with ProductConfiguration (variants)
  # Note: The legacy Variant model has been replaced with ProductConfiguration.
  # Variant configurations are now stored in the info JSONB field of ProductConfiguration.
  describe 'integration with product configurations' do
    let(:configurable_product) { create(:product, :configurable_variant) }
    let(:configuration) { create(:configuration, :size, product: configurable_product) }
    let(:value_small) { configuration.configuration_values.find_by(value: 'Small') }

    it 'configuration values are linked through configuration to configurable product' do
      expect(value_small.configuration.product).to eq(configurable_product)
    end

    it 'can access product via delegation' do
      expect(value_small.product).to eq(configurable_product)
    end

    it 'configuration values represent options for variant generation' do
      # ConfigurationValues define the possible options for variants
      # Actual variant selection is stored in ProductConfiguration.info['variant_config']
      expect(configuration.configuration_values.pluck(:value)).to include('Small', 'Medium', 'Large')
    end
  end

  # Integration tests
  describe 'integration' do
    context 'size configuration with values' do
      let(:size_config) { create(:configuration, :size) }

      it 'has three size values in order' do
        values = size_config.configuration_values.order(:position)
        expect(values.count).to eq(3)
        expect(values.pluck(:value)).to eq([ 'Small', 'Medium', 'Large' ])
      end

      it 'can add new value to existing configuration' do
        expect {
          create(:configuration_value, configuration: size_config, value: 'XL')
        }.to change { size_config.configuration_values.count }.by(1)

        expect(size_config.configuration_values.pluck(:value)).to include('XL')
      end
    end

    context 'configuration value deletion' do
      let(:configuration) { create(:configuration, :size) }
      let(:value_small) { configuration.configuration_values.find_by(value: 'Small') }

      it 'can be destroyed independently' do
        # Ensure configuration is created first (which creates 3 values via :size trait)
        configuration
        initial_count = ConfigurationValue.count

        value_small.destroy

        expect(ConfigurationValue.count).to eq(initial_count - 1)
      end

      it 'does not affect other configuration values' do
        value_medium = configuration.configuration_values.find_by(value: 'Medium')
        value_large = configuration.configuration_values.find_by(value: 'Large')

        value_small.destroy

        expect(configuration.configuration_values.reload).to include(value_medium, value_large)
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

    it 'does not allow duplicate values in same configuration' do
      configuration = create(:configuration)
      create(:configuration_value, configuration: configuration, value: 'Medium')
      value2 = build(:configuration_value, configuration: configuration, value: 'Medium')

      # Duplicate values are NOT allowed within the same configuration
      expect(value2).not_to be_valid
      expect(value2.errors[:value]).to include('has already been taken')
    end

    it 'allows same value in different configurations' do
      configuration1 = create(:configuration)
      configuration2 = create(:configuration)

      create(:configuration_value, configuration: configuration1, value: 'Medium')
      value2 = build(:configuration_value, configuration: configuration2, value: 'Medium')

      # Same value IS allowed in different configurations
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
    let(:product) { create(:product, :configurable_variant, company: company) }
    let(:configuration) { create(:configuration, product: product, company: company) }

    it 'configuration value inherits company context from configuration' do
      config_value = create(:configuration_value, configuration: configuration)
      expect(config_value.configuration.product.company).to eq(company)
    end

    it 'can access company through delegation chain' do
      config_value = create(:configuration_value, configuration: configuration)
      # ConfigurationValue -> Configuration -> Product -> Company
      expect(config_value.product.company).to eq(company)
    end
  end
end
