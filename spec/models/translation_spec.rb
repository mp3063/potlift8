require 'rails_helper'

RSpec.describe Translation, type: :model do
  # Test factories
  describe 'factories' do
    it 'has a valid factory' do
      expect(build(:translation)).to be_valid
    end

    it 'creates valid translations with different locales' do
      expect(create(:translation, :spanish)).to be_valid
      expect(create(:translation, :french)).to be_valid
      expect(create(:translation, :german)).to be_valid
      expect(create(:translation, :italian)).to be_valid
      expect(create(:translation, :portuguese)).to be_valid
    end

    it 'creates valid translations with different keys' do
      expect(create(:translation, :name_translation)).to be_valid
      expect(create(:translation, :description_translation)).to be_valid
    end
  end

  # Test associations
  describe 'associations' do
    it { is_expected.to belong_to(:translatable) }

    context 'polymorphic association' do
      let(:product) { create(:product) }
      let(:translation) { create(:translation, translatable: product) }

      it 'associates with different translatable types' do
        expect(translation.translatable).to eq(product)
        expect(translation.translatable_type).to eq('Product')
        expect(translation.translatable_id).to eq(product.id)
      end
    end
  end

  # Test validations
  describe 'validations' do
    subject { build(:translation) }

    it { is_expected.to validate_presence_of(:locale) }
    it { is_expected.to validate_presence_of(:key) }
    it { is_expected.to validate_inclusion_of(:locale).in_array(Translation::SUPPORTED_LOCALES) }

    context 'locale uniqueness' do
      let(:product) { create(:product) }

      before do
        create(:translation, translatable: product, locale: 'en', key: 'name', value: 'Product Name')
      end

      it 'validates uniqueness of locale scoped to translatable and key' do
        duplicate = build(:translation, translatable: product, locale: 'en', key: 'name', value: 'Another Name')
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:locale]).to include('has already been taken')
      end

      it 'allows same locale for different keys' do
        translation = build(:translation, translatable: product, locale: 'en', key: 'description')
        expect(translation).to be_valid
      end

      it 'allows same locale for different translatables' do
        other_product = create(:product, company: product.company)
        translation = build(:translation, translatable: other_product, locale: 'en', key: 'name')
        expect(translation).to be_valid
      end

      it 'allows different locale for same translatable and key' do
        translation = build(:translation, translatable: product, locale: 'es', key: 'name')
        expect(translation).to be_valid
      end
    end

    context 'locale validation' do
      it 'accepts valid locales' do
        Translation::SUPPORTED_LOCALES.each do |locale|
          translation = build(:translation, locale: locale)
          expect(translation).to be_valid
        end
      end

      it 'rejects invalid locales' do
        translation = build(:translation, locale: 'invalid')
        expect(translation).not_to be_valid
        expect(translation.errors[:locale]).to be_present
      end

      it 'rejects nil locale' do
        translation = build(:translation, locale: nil)
        expect(translation).not_to be_valid
        expect(translation.errors[:locale]).to include("can't be blank")
      end
    end
  end

  # Test SUPPORTED_LOCALES constant
  describe 'SUPPORTED_LOCALES constant' do
    it 'defines all 6 supported locales' do
      expect(Translation::SUPPORTED_LOCALES).to eq(['en', 'es', 'fr', 'de', 'it', 'pt'])
    end
  end

  # Test scopes
  describe 'scopes' do
    let(:product) { create(:product) }

    describe '.for_locale' do
      let!(:en_translation) { create(:translation, translatable: product, locale: 'en', key: 'name') }
      let!(:es_translation) { create(:translation, translatable: product, locale: 'es', key: 'name') }
      let!(:fr_translation) { create(:translation, translatable: product, locale: 'fr', key: 'name') }

      it 'returns translations for specified locale' do
        result = Translation.for_locale('es')
        expect(result).to contain_exactly(es_translation)
      end

      it 'returns empty for non-existent locale' do
        result = Translation.for_locale('de')
        expect(result).to be_empty
      end
    end
  end

  # Integration tests
  describe 'integration' do
    let(:company) { create(:company) }
    let(:product) { create(:product, company: company, name: 'Default Product Name') }

    context 'complete translation setup' do
      let!(:en_name) { create(:translation, translatable: product, locale: 'en', key: 'name', value: 'Product Name') }
      let!(:es_name) { create(:translation, translatable: product, locale: 'es', key: 'name', value: 'Nombre del Producto') }
      let!(:fr_name) { create(:translation, translatable: product, locale: 'fr', key: 'name', value: 'Nom du Produit') }
      let!(:en_desc) { create(:translation, translatable: product, locale: 'en', key: 'description', value: 'Product Description') }
      let!(:es_desc) { create(:translation, translatable: product, locale: 'es', key: 'description', value: 'Descripción del Producto') }

      it 'has all translations associated with product' do
        expect(product.translations.count).to eq(5)
      end

      it 'can query by locale' do
        en_translations = product.translations.for_locale('en')
        expect(en_translations.count).to eq(2)
        expect(en_translations.pluck(:key)).to contain_exactly('name', 'description')
      end

      it 'can query by key' do
        name_translations = product.translations.where(key: 'name')
        expect(name_translations.count).to eq(3)
        expect(name_translations.pluck(:locale)).to contain_exactly('en', 'es', 'fr')
      end
    end

    context 'translation deletion cascade' do
      let!(:translation) { create(:translation, translatable: product) }

      it 'is destroyed when translatable is destroyed' do
        expect { product.destroy }.to change { Translation.count }.by(-1)
      end
    end

    context 'multiple translatables with translations' do
      let(:product1) { create(:product, company: company) }
      let(:product2) { create(:product, company: company) }

      let!(:product1_en) { create(:translation, translatable: product1, locale: 'en', key: 'name') }
      let!(:product1_es) { create(:translation, translatable: product1, locale: 'es', key: 'name') }
      let!(:product2_en) { create(:translation, translatable: product2, locale: 'en', key: 'name') }
      let!(:product2_fr) { create(:translation, translatable: product2, locale: 'fr', key: 'name') }

      it 'scopes translations by translatable' do
        expect(product1.translations.count).to eq(2)
        expect(product2.translations.count).to eq(2)
      end

      it 'allows querying all translations for a locale' do
        en_translations = Translation.for_locale('en')
        expect(en_translations.count).to eq(2)
        expect(en_translations.map(&:translatable)).to contain_exactly(product1, product2)
      end
    end

    context 'translation with different polymorphic types' do
      let(:product) { create(:product, company: company) }
      # Note: Catalog is another potential translatable type
      # Add more polymorphic types here as needed

      let!(:product_translation) { create(:translation, translatable: product, locale: 'en', key: 'name') }

      it 'handles different translatable types' do
        expect(product_translation.translatable_type).to eq('Product')
        expect(product_translation.translatable).to eq(product)
      end
    end

    context 'bulk translation creation' do
      it 'creates multiple translations for all supported locales' do
        translations_data = Translation::SUPPORTED_LOCALES.map do |locale|
          { translatable: product, locale: locale, key: 'name', value: "Name in #{locale}" }
        end

        expect {
          translations_data.each { |data| create(:translation, **data) }
        }.to change { Translation.count }.by(6)

        expect(product.translations.count).to eq(6)
        expect(product.translations.pluck(:locale)).to match_array(Translation::SUPPORTED_LOCALES)
      end
    end
  end

  # Edge cases
  describe 'edge cases' do
    let(:product) { create(:product) }

    context 'with blank key' do
      it 'is invalid' do
        translation = build(:translation, translatable: product, key: '')
        expect(translation).not_to be_valid
        expect(translation.errors[:key]).to include("can't be blank")
      end
    end

    context 'with blank value' do
      it 'is valid (value can be blank)' do
        translation = build(:translation, translatable: product, value: '')
        expect(translation).to be_valid
      end
    end

    context 'with nil value' do
      it 'is valid (value can be nil)' do
        translation = build(:translation, translatable: product, value: nil)
        expect(translation).to be_valid
      end
    end

    context 'with very long value' do
      it 'is valid' do
        long_value = 'a' * 10000
        translation = build(:translation, translatable: product, value: long_value)
        expect(translation).to be_valid
      end
    end

    context 'with special characters in value' do
      it 'is valid' do
        translation = build(:translation, translatable: product, value: 'Café ñoño <>&"\'')
        expect(translation).to be_valid
        expect(translation.value).to include('Café')
      end
    end

    context 'with numeric value' do
      it 'is valid (stored as string)' do
        translation = build(:translation, translatable: product, value: '12345')
        expect(translation).to be_valid
      end
    end
  end
end
