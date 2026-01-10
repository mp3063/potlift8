require 'rails_helper'

RSpec.describe CatalogItemValidator do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company, currency_code: 'eur') }
  let(:product) { create(:product, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

  describe '#valid?' do
    context 'when all validations pass' do
      before do
        # Mock ProductValidator to always pass
        product_validator = instance_double(ProductValidator, validate_structure: [])
        allow(ProductValidator).to receive(:new).and_return(product_validator)
      end

      it 'returns true' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end
  end

  describe 'product structure validation' do
    context 'when product structure is valid' do
      before do
        product_validator = instance_double(ProductValidator, validate_structure: [])
        allow(ProductValidator).to receive(:new).with(product).and_return(product_validator)
      end

      it 'passes validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end
    end

    context 'when product structure is invalid' do
      before do
        product_validator = instance_double(ProductValidator,
                                          validate_structure: [ 'Structure error 1', 'Structure error 2' ])
        allow(ProductValidator).to receive(:new).with(product).and_return(product_validator)
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes structure errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include('Structure error 1', 'Structure error 2')
      end
    end
  end

  describe 'mandatory attribute validation' do
    let(:mandatory_catalog_attr) do
      create(:product_attribute,
            company: company,
            code: 'catalog_description',
            name: 'Catalog Description',
            mandatory: true,
            product_attribute_scope: :catalog_scope)
    end

    let(:mandatory_product_and_catalog_attr) do
      create(:product_attribute,
            company: company,
            code: 'price',
            name: 'Price',
            mandatory: true,
            product_attribute_scope: :product_and_catalog_scope)
    end

    let(:mandatory_product_only_attr) do
      create(:product_attribute,
            company: company,
            code: 'sku',
            name: 'SKU',
            mandatory: true,
            product_attribute_scope: :product_scope)
    end

    before do
      # Mock ProductValidator to pass structure validation
      product_validator = instance_double(ProductValidator, validate_structure: [])
      allow(ProductValidator).to receive(:new).and_return(product_validator)
    end

    context 'when all mandatory catalog attributes have values' do
      before do
        mandatory_catalog_attr
        mandatory_product_and_catalog_attr

        catalog_item.write_catalog_attribute_value('catalog_description', 'Test description')
        catalog_item.write_catalog_attribute_value('price', '1999')
      end

      it 'passes validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end
    end

    context 'when mandatory catalog_scope attribute is missing' do
      before do
        mandatory_catalog_attr
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes error about missing attribute' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include(/Mandatory catalog attribute 'Catalog Description' is missing/)
      end
    end

    context 'when mandatory product_and_catalog_scope attribute is missing' do
      before do
        mandatory_product_and_catalog_attr
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes error about missing attribute' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include(/Mandatory catalog attribute 'Price' is missing/)
      end
    end

    context 'when mandatory product_scope attribute is missing' do
      before do
        mandatory_product_only_attr
      end

      it 'passes validation (product_scope not checked at catalog level)' do
        validator = CatalogItemValidator.new(catalog_item)
        # Product-only mandatory attributes are not checked at catalog level
        # They should be checked by ProductValidator
        expect(validator.valid?).to be true
      end
    end

    context 'when attribute has product value but no catalog override' do
      before do
        mandatory_product_and_catalog_attr
        create(:product_attribute_value,
              product: product,
              product_attribute: mandatory_product_and_catalog_attr,
              value: '1999')
      end

      it 'passes validation (falls back to product value)' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end
    end

    context 'when attribute has blank catalog override' do
      before do
        mandatory_product_and_catalog_attr
        # Create with blank value (this shouldn't be possible due to model validation, but test the validator)
        ciav = catalog_item.catalog_item_attribute_values.build(
          product_attribute: mandatory_product_and_catalog_attr
        )
        ciav.save(validate: false)
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end
    end
  end

  describe 'price validation' do
    let(:price_attr) do
      create(:product_attribute,
            company: company,
            code: 'price',
            pa_type: :patype_number,
            view_format: :view_format_price,
            product_attribute_scope: :product_and_catalog_scope)
    end

    before do
      # Mock ProductValidator
      product_validator = instance_double(ProductValidator, validate_structure: [])
      allow(ProductValidator).to receive(:new).and_return(product_validator)

      # Set base price
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '100')
    end

    context 'for EUR catalog' do
      it 'passes validation regardless of price ratio' do
        catalog_item.write_catalog_attribute_value('price', '50')  # Even below 1.0 ratio
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end
    end

    context 'for SEK catalog with valid price ratio' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'passes validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end
    end

    context 'for SEK catalog with invalid price ratio' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      before do
        catalog_item.write_catalog_attribute_value('price', '140')
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes price validation errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include(/below minimum/)
      end
    end

    context 'when base price is missing' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:product_without_price) { create(:product, company: company) }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product_without_price) }

      before do
        catalog_item.write_catalog_attribute_value('price', '150')
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes error about missing base price' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include(/Base price \(EUR\) is missing/)
      end
    end

    context 'when catalog price is missing' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes error about missing catalog price' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include(/Catalog price \(SEK\) is missing/)
      end
    end
  end

  describe 'composite validation scenarios' do
    let(:price_attr) do
      create(:product_attribute,
            company: company,
            code: 'price',
            pa_type: :patype_number,
            mandatory: true,
            product_attribute_scope: :product_and_catalog_scope)
    end

    let(:description_attr) do
      create(:product_attribute,
            company: company,
            code: 'description',
            name: 'description',
            mandatory: true,
            product_attribute_scope: :catalog_scope)
    end

    before do
      price_attr
      description_attr

      # Mock ProductValidator
      product_validator = instance_double(ProductValidator, validate_structure: [])
      allow(ProductValidator).to receive(:new).and_return(product_validator)

      # Set base price
      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '100')
    end

    context 'when multiple validations fail' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      before do
        # Invalid price ratio (140 < 150)
        catalog_item.write_catalog_attribute_value('price', '140')
        # Missing mandatory description
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes all errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?

        # Should have both price ratio error and missing description error
        expect(validator.errors.size).to be >= 2
        expect(validator.errors).to include(/below minimum/)
        expect(validator.errors).to include(/Mandatory catalog attribute 'description' is missing/i)
      end
    end

    context 'when product structure, attributes, and pricing all valid' do
      before do
        catalog_item.write_catalog_attribute_value('price', '100')
        catalog_item.write_catalog_attribute_value('description', 'Valid description')
      end

      it 'passes validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be true
      end

      it 'has no errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end
  end

  describe '#errors' do
    before do
      product_validator = instance_double(ProductValidator, validate_structure: [])
      allow(ProductValidator).to receive(:new).and_return(product_validator)
    end

    context 'before validation' do
      it 'returns empty array' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.errors).to be_empty
      end
    end

    context 'after successful validation' do
      it 'returns empty array' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to be_empty
      end
    end

    context 'after failed validation' do
      let(:mandatory_attr) do
        create(:product_attribute,
              company: company,
              code: 'test',
              mandatory: true,
              product_attribute_scope: :catalog_scope)
      end

      before do
        mandatory_attr
      end

      it 'returns array of error messages' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to be_an(Array)
        expect(validator.errors.size).to be > 0
      end
    end
  end

  # Integration tests
  describe 'integration scenarios' do
    let(:price_attr) do
      create(:product_attribute,
            company: company,
            code: 'price',
            pa_type: :patype_number,
            mandatory: true,
            product_attribute_scope: :product_and_catalog_scope)
    end

    before do
      price_attr

      # Mock ProductValidator
      product_validator = instance_double(ProductValidator, validate_structure: [])
      allow(ProductValidator).to receive(:new).and_return(product_validator)

      create(:product_attribute_value, product: product, product_attribute: price_attr, value: '100')
    end

    context 'multi-catalog validation' do
      let(:eur_catalog) { create(:catalog, company: company, currency_code: 'eur') }
      let(:sek_catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:nok_catalog) { create(:catalog, company: company, currency_code: 'nok') }

      let(:eur_item) { create(:catalog_item, catalog: eur_catalog, product: product) }
      let(:sek_item) { create(:catalog_item, catalog: sek_catalog, product: product) }
      let(:nok_item) { create(:catalog_item, catalog: nok_catalog, product: product) }

      before do
        eur_item.write_catalog_attribute_value('price', '100')
        sek_item.write_catalog_attribute_value('price', '150')
        nok_item.write_catalog_attribute_value('price', '150')
      end

      it 'validates all catalog items correctly' do
        eur_validator = CatalogItemValidator.new(eur_item)
        sek_validator = CatalogItemValidator.new(sek_item)
        nok_validator = CatalogItemValidator.new(nok_item)

        expect(eur_validator.valid?).to be true
        expect(sek_validator.valid?).to be true
        expect(nok_validator.valid?).to be true
      end
    end

    context 'sales readiness workflow' do
      let(:catalog) { create(:catalog, company: company, currency_code: 'sek') }
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      it 'correctly reflects readiness state' do
        # Initially not ready (no catalog price)
        expect(catalog_item.sales_ready?).to be false

        # Add valid price
        catalog_item.write_catalog_attribute_value('price', '150')
        expect(catalog_item.sales_ready?).to be true

        # Invalid price
        catalog_item.write_catalog_attribute_value('price', '130')
        expect(catalog_item.sales_ready?).to be false

        # Fix price
        catalog_item.write_catalog_attribute_value('price', '200')
        expect(catalog_item.sales_ready?).to be true
      end
    end

    context 'validation with product structure errors' do
      let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }

      before do
        catalog_item.write_catalog_attribute_value('price', '100')

        # Mock product structure validation failure
        product_validator = instance_double(ProductValidator,
                                          validate_structure: [ 'Invalid product structure' ])
        allow(ProductValidator).to receive(:new).with(product).and_return(product_validator)
      end

      it 'fails validation' do
        validator = CatalogItemValidator.new(catalog_item)
        expect(validator.valid?).to be false
      end

      it 'includes product structure errors' do
        validator = CatalogItemValidator.new(catalog_item)
        validator.valid?
        expect(validator.errors).to include('Invalid product structure')
      end
    end
  end
end
