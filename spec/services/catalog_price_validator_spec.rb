require 'rails_helper'

RSpec.describe CatalogPriceValidator do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  let(:price_attr) do
    create(:product_attribute,
          company: company,
          code: 'price',
          pa_type: :patype_number,
          view_format: :view_format_price,
          product_attribute_scope: :product_and_catalog_scope)
  end

  # Set up base EUR price on product
  before do
    create(:product_attribute_value, product: product, product_attribute: price_attr, value: '100')
  end

  describe '#validate for EUR catalog' do
    let(:catalog) { create(:catalog, company: company, currency_code: 'eur') }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    context 'without catalog price' do
      it 'validates successfully (no ratio check for EUR)' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'with catalog price' do
      before do
        catalog_item.write_catalog_attribute_value('price', '100')
      end

      it 'validates successfully (no ratio check for EUR)' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
        expect(validator.errors).to be_empty
      end
    end
  end

  describe '#validate for SEK catalog' do
    let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    context 'when catalog price meets minimum ratio (1.5x)' do
      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'validates successfully' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when catalog price exceeds minimum ratio' do
      before do
        catalog_item.write_catalog_attribute_value('price', '200')
      end

      it 'validates successfully' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when catalog price is below minimum ratio' do
      before do
        catalog_item.write_catalog_attribute_value('price', '140')
      end

      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error message with actual and minimum ratio' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/below minimum/)
        expect(validator.errors.first).to match(/1\.4/)  # Actual ratio
        expect(validator.errors.first).to match(/1\.5/)  # Minimum ratio
      end
    end

    context 'when base price is missing' do
      let(:product_without_price) { create(:product, company: company) }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product_without_price) }

      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error about missing base price' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/Base price \(EUR\) is missing/)
      end
    end

    context 'when catalog price is missing' do
      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error about missing catalog price' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/Catalog price \(SEK\) is missing/)
      end
    end

    context 'when base price is zero' do
      before do
        product.write_attribute_value('price', '0')
      end

      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error about missing base price' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/Base price \(EUR\) is missing/)
      end
    end

    context 'when catalog price is zero' do
      before do
        catalog_item.write_catalog_attribute_value('price', '0')
      end

      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error about missing catalog price' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/Catalog price \(SEK\) is missing/)
      end
    end
  end

  describe '#validate for NOK catalog' do
    let(:catalog) { create(:catalog, company: company, currency_code: 'nok') }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    context 'when catalog price meets minimum ratio (1.5x)' do
      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'validates successfully' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
        expect(validator.errors).to be_empty
      end
    end

    context 'when catalog price is below minimum ratio' do
      before do
        catalog_item.write_catalog_attribute_value('price', '130')
      end

      it 'fails validation' do
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'includes error message with NOK currency' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/below minimum/)
        expect(validator.errors.first).to match(/1\.3/)  # Actual ratio
        expect(validator.errors.first).to match(/1\.5/)  # Minimum ratio
      end
    end

    context 'when catalog price is missing' do
      it 'includes error about missing NOK price' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to include(/Catalog price \(NOK\) is missing/)
      end
    end
  end

  describe '#valid?' do
    let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    before do
      catalog_item.write_catalog_attribute_value('price', '150')
    end

    it 'is an alias for #validate' do
      validator = CatalogPriceValidator.new(catalog_item)
      expect(validator.valid?).to eq(validator.validate)
    end
  end

  describe '#errors' do
    let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
    let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

    context 'after successful validation' do
      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'returns empty array' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to be_empty
      end
    end

    context 'after failed validation' do
      before do
        catalog_item.write_catalog_attribute_value('price', '140')
      end

      it 'returns array of error messages' do
        validator = CatalogPriceValidator.new(catalog_item)
        validator.validate
        expect(validator.errors).to be_an(Array)
        expect(validator.errors.size).to be > 0
      end
    end
  end

  # Integration tests
  describe 'integration scenarios' do
    context 'multi-catalog pricing strategy' do
      let(:eur_catalog) { create(:catalog, company: company, currency_code: 'eur') }
      let(:sek_catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:nok_catalog) { create(:catalog, company: company, currency_code: 'nok') }

      let(:eur_item) { create(:catalog_item, catalog: eur_catalog, product: product) }
      let(:sek_item) { create(:catalog_item, catalog: sek_catalog, product: product) }
      let(:nok_item) { create(:catalog_item, catalog: nok_catalog, product: product) }

      before do
        # Base price: 100 EUR
        # SEK price: 150 (1.5x - minimum required)
        # NOK price: 160 (1.6x - above minimum)
        sek_item.write_catalog_attribute_value('price', '150')
        nok_item.write_catalog_attribute_value('price', '160')
      end

      it 'validates all catalogs correctly' do
        eur_validator = CatalogPriceValidator.new(eur_item)
        sek_validator = CatalogPriceValidator.new(sek_item)
        nok_validator = CatalogPriceValidator.new(nok_item)

        expect(eur_validator.validate).to be true
        expect(sek_validator.validate).to be true
        expect(nok_validator.validate).to be true
      end
    end

    context 'price update workflow' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      it 'validates after price changes' do
        # Initially invalid (no catalog price)
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false

        # Set valid catalog price
        catalog_item.write_catalog_attribute_value('price', '150')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true

        # Update to invalid price
        catalog_item.write_catalog_attribute_value('price', '140')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false

        # Update to valid price again
        catalog_item.write_catalog_attribute_value('price', '200')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
      end
    end

    context 'base price changes' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'reflects new base price in validation' do
        # Valid with base 100 / catalog 150 (ratio 1.5)
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true

        # Change base price to 110
        product.write_attribute_value('price', '110')

        # Now invalid (ratio 150/110 = 1.36 < 1.5)
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end
    end

    context 'edge cases' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      it 'handles exact minimum ratio' do
        catalog_item.write_catalog_attribute_value('price', '150')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
      end

      it 'handles very small price difference below minimum' do
        catalog_item.write_catalog_attribute_value('price', '149.99')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be false
      end

      it 'handles very small price difference above minimum' do
        catalog_item.write_catalog_attribute_value('price', '150.01')
        validator = CatalogPriceValidator.new(catalog_item)
        expect(validator.validate).to be true
      end
    end
  end
end
