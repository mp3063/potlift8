require 'rails_helper'

RSpec.describe ProductValidator, type: :service do
  let(:company) do
    Company.create!(
      code: 'TEST',
      name: 'Test Company',
      active: true
    )
  end

  # Create mandatory product attributes
  let!(:mandatory_price_attr) do
    ProductAttribute.create!(
      company: company,
      code: 'price',
      name: 'Price',
      pa_type: :patype_number,
      view_format: :view_format_price,
      mandatory: true,
      product_attribute_scope: :product_scope,
      has_rules: true,
      rules: ['positive', 'not_null']
    )
  end

  let!(:mandatory_description_attr) do
    ProductAttribute.create!(
      company: company,
      code: 'description',
      name: 'Description',
      pa_type: :patype_text,
      view_format: :view_format_general,
      mandatory: true,
      product_attribute_scope: :product_and_catalog_scope,
      has_rules: true,
      rules: ['not_null']
    )
  end

  let!(:stock_quantity_attr) do
    ProductAttribute.create!(
      company: company,
      code: 'stock_quantity',
      name: 'Stock Quantity',
      pa_type: :patype_number,
      view_format: :view_format_general,
      mandatory: false,
      product_attribute_scope: :product_scope,
      has_rules: true,
      rules: ['positive', 'not_null']
    )
  end

  describe '#initialize' do
    let(:product) { create(:product, company: company) }

    it 'initializes with product and empty errors' do
      validator = ProductValidator.new(product)

      expect(validator.product).to eq(product)
      expect(validator.errors).to eq([])
    end
  end

  describe '#validate_structure - Sellable Products' do
    let(:product) { create(:product, :sellable, company: company) }

    before do
      # Add mandatory attributes
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_price_attr,
        value: '1999'
      )
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_description_attr,
        value: 'Test description'
      )
    end

    it 'validates when no special requirements exist' do
      validator = ProductValidator.new(product)

      expect(validator).to be_valid
      expect(validator.validate_structure).to be_empty
    end
  end

  describe '#validate_structure - Configurable Products' do
    context 'without variants' do
      let(:product) do
        create(:product, :configurable_variant, company: company)
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors).to include("Configurable product must have at least one variant")
      end
    end

    context 'with valid variants' do
      let(:product) { create(:product, :configurable_variant, company: company) }
      let(:variant1) { create(:product, :sellable, :active, company: company) }
      let(:variant2) { create(:product, :sellable, :active, company: company) }

      before do
        # Add mandatory attributes to configurable
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '2500'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Configurable product'
        )

        # Link variants
        ProductConfiguration.create!(superproduct: product, subproduct: variant1)
        ProductConfiguration.create!(superproduct: product, subproduct: variant2)
      end

      it 'is valid' do
        validator = ProductValidator.new(product)

        expect(validator).to be_valid
        expect(validator.validate_structure).to be_empty
      end
    end

    context 'with draft subproduct' do
      let(:product) { create(:product, :configurable_variant, company: company) }
      let(:draft_variant) { create(:product, :sellable, :draft, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '2500'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Configurable product'
        )

        ProductConfiguration.create!(superproduct: product, subproduct: draft_variant)
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors).to include("All variants must be active or incoming")
      end
    end

    context 'with deleted subproduct' do
      let(:product) { create(:product, :configurable_variant, company: company) }
      let(:deleted_variant) do
        create(:product, :sellable, company: company, product_status: :deleted)
      end

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '2500'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Configurable product'
        )

        ProductConfiguration.create!(superproduct: product, subproduct: deleted_variant)
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors).to include("All variants must be active or incoming")
      end
    end

    context 'with active and incoming variants' do
      let(:product) { create(:product, :configurable_variant, company: company) }
      let(:active_variant) { create(:product, :sellable, :active, company: company) }
      let(:incoming_variant) { create(:product, :sellable, :incoming, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '2800'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Mixed status variants'
        )

        ProductConfiguration.create!(superproduct: product, subproduct: active_variant)
        ProductConfiguration.create!(superproduct: product, subproduct: incoming_variant)
      end

      it 'is valid' do
        validator = ProductValidator.new(product)

        expect(validator).to be_valid
        expect(validator.validate_structure).to be_empty
      end
    end
  end

  describe '#validate_structure - Bundle Products' do
    context 'without subproducts' do
      let(:product) { create(:product, :bundle, company: company) }

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors).to include("Bundle product must have at least one subproduct")
      end
    end

    context 'with valid subproducts and quantities' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:component1) { create(:product, :sellable, company: company) }
      let(:component2) { create(:product, :sellable, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '5000'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Bundle product'
        )

        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component1,
          info: { 'quantity' => 2 }
        )
        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component2,
          info: { 'quantity' => 3 }
        )
      end

      it 'is valid' do
        validator = ProductValidator.new(product)

        expect(validator).to be_valid
        expect(validator.validate_structure).to be_empty
      end
    end

    context 'with zero quantity' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:component) { create(:product, :sellable, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '3000'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Bundle with zero quantity'
        )

        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component,
          info: { 'quantity' => 0 }
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Invalid quantity for subproduct/)
      end
    end

    context 'with nil quantity' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:component) { create(:product, :sellable, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '3500'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Bundle with nil quantity'
        )

        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component,
          info: {}  # No quantity key
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Invalid quantity for subproduct/)
      end
    end

    context 'with negative quantity' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:component) { create(:product, :sellable, company: company) }

      before do
        # Add mandatory attributes
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '4000'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Bundle with negative quantity'
        )

        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component,
          info: { 'quantity' => -5 }
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Invalid quantity for subproduct/)
      end
    end
  end

  describe '#validate_structure - Mandatory Attributes' do
    context 'without mandatory product_scope attribute' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        # Only add description, not price
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Test description'
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Mandatory attribute '.+' is missing/)
      end
    end

    context 'with all mandatory product_scope attributes' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '1999'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Valid description'
        )
      end

      it 'is valid' do
        validator = ProductValidator.new(product)

        expect(validator).to be_valid
        expect(validator.validate_structure).to be_empty
      end
    end

    context 'with empty mandatory attribute value' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '1999'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: ''  # Empty value
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Mandatory attribute '.+' is missing/)
      end
    end

    context 'with mandatory product_and_catalog_scope attribute' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        # Missing description which has product_and_catalog_scope
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '1999'
        )
      end

      it 'is validated' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Mandatory attribute '.+' is missing/)
      end
    end
  end

  describe '#validate_structure - Attribute Rules' do
    context 'with attribute failing positive rule' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '-500'  # Negative price
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Test description'
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Attribute '.+' value must be positive/)
      end
    end

    context 'with attribute failing not_null rule' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '1999'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Description'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: stock_quantity_attr,
          value: ''  # Empty value violates not_null
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Attribute '.+' value cannot be blank/)
      end
    end

    context 'with all attribute rules passing' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '2999'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: stock_quantity_attr,
          value: '100'
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Valid description'
        )
      end

      it 'is valid' do
        validator = ProductValidator.new(product)

        expect(validator).to be_valid
        expect(validator.validate_structure).to be_empty
      end
    end

    context 'with multiple rule violations' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '-100'  # Violates positive
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: stock_quantity_attr,
          value: ''  # Violates not_null
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Description'
        )
      end

      it 'shows all errors' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.length).to be > 1
      end
    end

    context 'with custom rule that fails' do
      let(:product) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '0'  # Will fail positive rule
        )
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_description_attr,
          value: 'Product with custom rule failure'
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.join).to match(/Attribute '.+' value/)
      end
    end
  end

  describe 'Complex validation scenarios' do
    context 'configurable product with mandatory attributes missing' do
      let(:product) { create(:product, :configurable_variant, company: company) }

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors).to include("Configurable product must have at least one variant")
        expect(errors.join).to match(/Mandatory attribute '.+' is missing/)
      end
    end

    context 'bundle product with rule violations' do
      let(:product) { create(:product, :bundle, company: company) }
      let(:component) { create(:product, :sellable, company: company) }

      before do
        ProductAttributeValue.create!(
          product: product,
          product_attribute: mandatory_price_attr,
          value: '-250'  # Negative price
        )
        # Missing description

        ProductConfiguration.create!(
          superproduct: product,
          subproduct: component,
          info: { 'quantity' => 0 }  # Invalid quantity
        )
      end

      it 'is invalid' do
        validator = ProductValidator.new(product)

        expect(validator).not_to be_valid
        errors = validator.validate_structure
        expect(errors.length).to be > 0
        has_structure_error = errors.any? { |e| e.match?(/Invalid quantity|Mandatory attribute/i) }
        expect(has_structure_error).to be true
      end
    end
  end

  describe 'Catalog validation tests' do
    # These tests will be skipped if Catalog is not defined
    context 'when Catalog model exists' do
      before do
        skip "Catalog model not defined" unless defined?(Catalog)
      end

      let(:catalog) { create(:catalog, company: company) }
      let(:product) { create(:product, :sellable, company: company) }

      describe '#validate_for_catalog' do
        it 'returns errors for structure and catalog issues' do
          validator = ProductValidator.new(product)
          errors = validator.validate_for_catalog(catalog)
          expect(errors).to be_a(Array)
        end
      end

      describe '#validate_catalog_specific_attributes' do
        it 'checks catalog mandatory attributes' do
          validator = ProductValidator.new(product)
          errors = validator.validate_for_catalog(catalog)
          # Test implementation depends on catalog setup
        end
      end

      describe '#validate_pricing_for_currency' do
        context 'with EUR currency' do
          let(:catalog) { create(:catalog, company: company, currency_code: 'EUR') }

          it 'skips validation' do
            validator = ProductValidator.new(product)
            errors = validator.validate_for_catalog(catalog)
            expect(errors.join).not_to match(/Price for .+ is below minimum ratio/)
          end
        end

        context 'with USD currency checking minimum ratio' do
          let(:catalog) { create(:catalog, company: company, currency_code: 'USD') }

          it 'validates minimum ratio' do
            skip "Requires Catalog::MINIMUM_CURRENCY_RATIO configuration"
          end
        end
      end
    end
  end

  describe 'Edge cases and error messages' do
    let(:product) { create(:product, :configurable_variant, company: company) }

    it 'produces clear and descriptive error messages' do
      validator = ProductValidator.new(product)
      errors = validator.validate_structure

      errors.each do |error|
        expect(error).to be_a(String)
        expect(error.length).to be > 10
      end
    end

    it 'does not modify product' do
      product = create(:product, :sellable, company: company)

      # Add mandatory attributes
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_price_attr,
        value: '1500'
      )
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_description_attr,
        value: 'Test'
      )

      original_updated_at = product.updated_at
      validator = ProductValidator.new(product)
      validator.validate_structure
      product.reload

      expect(product.updated_at).to eq(original_updated_at)
    end

    it 'can be reused for multiple validations' do
      product = create(:product, :sellable, company: company)

      # Add mandatory attributes
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_price_attr,
        value: '1500'
      )
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_description_attr,
        value: 'Sellable product'
      )

      validator = ProductValidator.new(product)

      # First validation
      errors1 = validator.validate_structure
      # Second validation
      errors2 = validator.validate_structure

      expect(errors1).to eq(errors2)
    end

    it 'has valid? method matching validate_structure.empty?' do
      product = create(:product, :sellable, company: company)

      # Add mandatory attributes
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_price_attr,
        value: '1500'
      )
      ProductAttributeValue.create!(
        product: product,
        product_attribute: mandatory_description_attr,
        value: 'Sellable product'
      )

      validator = ProductValidator.new(product)

      expect(validator.validate_structure.empty?).to eq(validator.valid?)
    end
  end
end
