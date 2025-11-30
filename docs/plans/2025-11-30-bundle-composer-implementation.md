# Bundle Product Composer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable automatic generation of all variant combinations when creating bundle products containing configurable and sellable products.

**Architecture:** Bundle composer UI appears when user selects "bundle" product type. User adds products, configures per-variant quantities, and on save the system generates all variant combinations as individual sellable products. Inventory is virtual (calculated from components).

**Note:** Shopify integration is OUT OF SCOPE for this implementation. Will be handled in a separate phase.

**Tech Stack:** Rails 8, PostgreSQL (JSONB), Hotwire (Turbo + Stimulus), ViewComponents, RSpec

**Design Document:** `docs/plans/2025-11-30-bundle-product-composer-design.md`

---

## Phase 1: Database & Models

### Task 1: Create bundle_templates migration

**Files:**
- Create: `db/migrate/XXXXXX_create_bundle_templates.rb`

**Step 1: Generate migration**

Run: `bin/rails generate migration CreateBundleTemplates`

**Step 2: Write migration code**

```ruby
# db/migrate/XXXXXX_create_bundle_templates.rb
class CreateBundleTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :bundle_templates do |t|
      t.references :product, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true
      t.jsonb :configuration, default: {}, null: false
      t.integer :generated_variants_count, default: 0, null: false
      t.datetime :last_generated_at

      t.timestamps
    end

    add_index :bundle_templates, :product_id, unique: true
  end
end
```

**Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration successful, bundle_templates table created

**Step 4: Commit**

```bash
git add db/migrate/*_create_bundle_templates.rb db/schema.rb
git commit -m "db: create bundle_templates table"
```

---

### Task 2: Add bundle fields to products migration

**Files:**
- Create: `db/migrate/XXXXXX_add_bundle_fields_to_products.rb`

**Step 1: Generate migration**

Run: `bin/rails generate migration AddBundleFieldsToProducts`

**Step 2: Write migration code**

```ruby
# db/migrate/XXXXXX_add_bundle_fields_to_products.rb
class AddBundleFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_reference :products, :parent_bundle, foreign_key: { to_table: :products }, null: true
    add_column :products, :bundle_variant, :boolean, default: false, null: false

    add_index :products, :parent_bundle_id
    add_index :products, :bundle_variant
  end
end
```

**Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration successful, columns added to products table

**Step 4: Commit**

```bash
git add db/migrate/*_add_bundle_fields_to_products.rb db/schema.rb
git commit -m "db: add parent_bundle_id and bundle_variant to products"
```

---

### Task 3: Create BundleTemplate model with specs

**Files:**
- Create: `app/models/bundle_template.rb`
- Create: `spec/models/bundle_template_spec.rb`

**Step 1: Write the failing test**

```ruby
# spec/models/bundle_template_spec.rb
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
      config = { 'components' => [{ 'product_id' => 1 }] }
      template = build(:bundle_template, configuration: config)

      expect(template.components).to eq([{ 'product_id' => 1 }])
    end

    it 'returns empty array when no components' do
      template = build(:bundle_template, configuration: {})
      expect(template.components).to eq([])
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/models/bundle_template_spec.rb`
Expected: FAIL with "uninitialized constant BundleTemplate"

**Step 3: Write minimal implementation**

```ruby
# app/models/bundle_template.rb
class BundleTemplate < ApplicationRecord
  belongs_to :product
  belongs_to :company

  validates :product, presence: true
  validates :company, presence: true
  validates :product_id, uniqueness: true
  validate :product_must_be_bundle

  def components
    configuration['components'] || []
  end

  private

  def product_must_be_bundle
    return if product.blank?

    unless product.product_type_bundle?
      errors.add(:product, 'must be a bundle product')
    end
  end
end
```

**Step 4: Create factory**

```ruby
# spec/factories/bundle_templates.rb
FactoryBot.define do
  factory :bundle_template do
    association :product, factory: [:product, :bundle]
    company { product.company }
    configuration { {} }
    generated_variants_count { 0 }
    last_generated_at { nil }

    trait :with_configuration do
      transient do
        sellable_product { nil }
      end

      after(:build) do |template, evaluator|
        if evaluator.sellable_product
          template.configuration = {
            'components' => [
              {
                'product_id' => evaluator.sellable_product.id,
                'product_type' => 'sellable',
                'quantity' => 1
              }
            ]
          }
        end
      end
    end
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rspec spec/models/bundle_template_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/models/bundle_template.rb spec/models/bundle_template_spec.rb spec/factories/bundle_templates.rb
git commit -m "feat: add BundleTemplate model with validations"
```

---

### Task 4: Update Product model with bundle associations

**Files:**
- Modify: `app/models/product.rb`
- Modify: `spec/models/product_spec.rb`

**Step 1: Write the failing tests**

Add to existing product spec:

```ruby
# spec/models/product_spec.rb (add to existing file)
describe 'bundle associations' do
  describe '#bundle_template' do
    it 'has one bundle_template' do
      bundle = create(:product, :bundle)
      template = create(:bundle_template, product: bundle, company: bundle.company)

      expect(bundle.bundle_template).to eq(template)
    end

    it 'destroys bundle_template when product is destroyed' do
      bundle = create(:product, :bundle)
      create(:bundle_template, product: bundle, company: bundle.company)

      expect { bundle.destroy }.to change(BundleTemplate, :count).by(-1)
    end
  end

  describe '#bundle_variants' do
    let(:company) { create(:company) }
    let(:bundle) { create(:product, :bundle, company: company) }

    it 'has many bundle_variants' do
      variant1 = create(:product, :sellable, company: company, parent_bundle: bundle, bundle_variant: true)
      variant2 = create(:product, :sellable, company: company, parent_bundle: bundle, bundle_variant: true)

      expect(bundle.bundle_variants).to contain_exactly(variant1, variant2)
    end

    it 'destroys bundle_variants when bundle is destroyed' do
      create(:product, :sellable, company: company, parent_bundle: bundle, bundle_variant: true)
      create(:product, :sellable, company: company, parent_bundle: bundle, bundle_variant: true)

      expect { bundle.destroy }.to change(Product, :count).by(-3) # bundle + 2 variants
    end
  end

  describe '#parent_bundle' do
    it 'belongs to parent_bundle' do
      bundle = create(:product, :bundle)
      variant = create(:product, :sellable, company: bundle.company, parent_bundle: bundle, bundle_variant: true)

      expect(variant.parent_bundle).to eq(bundle)
    end
  end

  describe 'scopes' do
    let(:company) { create(:company) }
    let!(:bundle) { create(:product, :bundle, company: company) }
    let!(:sellable) { create(:product, :sellable, company: company) }
    let!(:bundle_variant) { create(:product, :sellable, company: company, parent_bundle: bundle, bundle_variant: true) }

    describe '.bundle_variants' do
      it 'returns only bundle variant products' do
        expect(company.products.bundle_variants).to contain_exactly(bundle_variant)
      end
    end

    describe '.not_bundle_variants' do
      it 'returns products that are not bundle variants' do
        expect(company.products.not_bundle_variants).to contain_exactly(bundle, sellable)
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/models/product_spec.rb -e "bundle associations"`
Expected: FAIL (associations not defined)

**Step 3: Add associations to Product model**

```ruby
# app/models/product.rb (add to existing associations section)

# Bundle template relationship
has_one :bundle_template, dependent: :destroy

# Generated variants relationship (this bundle is the parent)
has_many :bundle_variants,
         class_name: 'Product',
         foreign_key: 'parent_bundle_id',
         dependent: :destroy

# Parent bundle relationship (this product is a generated variant)
belongs_to :parent_bundle,
           class_name: 'Product',
           optional: true

# Scopes for bundle variants
scope :bundle_variants, -> { where(bundle_variant: true) }
scope :not_bundle_variants, -> { where(bundle_variant: false) }
```

**Step 4: Run test to verify it passes**

Run: `bin/rspec spec/models/product_spec.rb -e "bundle associations"`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/models/product.rb spec/models/product_spec.rb
git commit -m "feat: add bundle associations and scopes to Product"
```

---

## Phase 2: Services

### Task 5: Create BundleValidationService

**Files:**
- Create: `app/services/bundle_validation_service.rb`
- Create: `spec/services/bundle_validation_service_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/services/bundle_validation_service_spec.rb
require 'rails_helper'

RSpec.describe BundleValidationService do
  let(:company) { create(:company) }
  let(:sellable1) { create(:product, :sellable, company: company) }
  let(:sellable2) { create(:product, :sellable, company: company) }
  let(:configurable) { create(:product, :configurable, :with_variants, company: company, variant_count: 3) }

  describe '#valid?' do
    context 'with valid configuration' do
      it 'returns true for 2 sellable products' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 2 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be true
        expect(service.errors).to be_empty
      end

      it 'returns true for configurable with included variants' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => configurable.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
            }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be true
      end
    end

    context 'with invalid configuration' do
      it 'returns false when fewer than 2 products' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include('Bundle must contain at least 2 products')
      end

      it 'returns false when more than 3 configurables' do
        configurables = create_list(:product, 4, :configurable, :with_variants, company: company, variant_count: 2)
        config = {
          'components' => configurables.map do |c|
            {
              'product_id' => c.id,
              'product_type' => 'configurable',
              'variants' => c.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
            }
          end
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/Maximum 3 configurable products/))
      end

      it 'returns false when more than 10 sellables' do
        sellables = create_list(:product, 11, :sellable, company: company)
        config = {
          'components' => sellables.map do |s|
            { 'product_id' => s.id, 'product_type' => 'sellable', 'quantity' => 1 }
          end
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/Maximum 10 sellable products/))
      end

      it 'returns false when quantity is 0' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 0 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/Quantity must be at least 1/))
      end

      it 'returns false when quantity exceeds 99' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 100 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/Quantity cannot exceed 99/))
      end

      it 'returns false when combinations exceed 200' do
        # 3 configurables with 6 variants each = 216 combinations
        configurables = create_list(:product, 3, :configurable, :with_variants, company: company, variant_count: 6)
        config = {
          'components' => configurables.map do |c|
            {
              'product_id' => c.id,
              'product_type' => 'configurable',
              'variants' => c.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
            }
          end
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/would generate .* variants.*maximum: 200/))
      end

      it 'returns false for duplicate products' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include('Duplicate products not allowed. Use quantity instead.')
      end

      it 'returns false for discontinued product' do
        discontinued = create(:product, :sellable, company: company, product_status: :discontinued)
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => discontinued.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/is discontinued/))
      end

      it 'returns false when configurable has no included variants' do
        config = {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => configurable.subproducts.map { |v| { 'variant_id' => v.id, 'included' => false, 'quantity' => 0 } }
            }
          ]
        }
        service = described_class.new(config, company: company)

        expect(service.valid?).to be false
        expect(service.errors).to include(match(/At least one variant must be selected/))
      end
    end
  end

  describe '#warnings' do
    it 'warns when combinations exceed 100' do
      # 3 configurables with 5 variants each = 125 combinations
      configurables = create_list(:product, 3, :configurable, :with_variants, company: company, variant_count: 5)
      config = {
        'components' => configurables.map do |c|
          {
            'product_id' => c.id,
            'product_type' => 'configurable',
            'variants' => c.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
          end
        end
      }
      service = described_class.new(config, company: company)
      service.valid?

      expect(service.warnings).to include(match(/will generate 125 bundle variants/))
    end
  end

  describe '#combination_count' do
    it 'calculates correct combination count' do
      # 2 configurables with 3 variants each = 9 combinations
      config1 = create(:product, :configurable, :with_variants, company: company, variant_count: 3)
      config2 = create(:product, :configurable, :with_variants, company: company, variant_count: 3)
      config = {
        'components' => [
          {
            'product_id' => config1.id,
            'product_type' => 'configurable',
            'variants' => config1.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
          },
          {
            'product_id' => config2.id,
            'product_type' => 'configurable',
            'variants' => config2.subproducts.map { |v| { 'variant_id' => v.id, 'included' => true, 'quantity' => 1 } }
          },
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
      service = described_class.new(config, company: company)

      expect(service.combination_count).to eq(9)
    end

    it 'returns 1 when only sellables' do
      config = {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
          { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
      service = described_class.new(config, company: company)

      expect(service.combination_count).to eq(1)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/services/bundle_validation_service_spec.rb`
Expected: FAIL with "uninitialized constant BundleValidationService"

**Step 3: Write implementation**

```ruby
# app/services/bundle_validation_service.rb
class BundleValidationService
  LIMITS = {
    max_configurables: 3,
    max_sellables: 10,
    max_total_products: 12,
    max_combinations: 200,
    max_quantity: 99,
    min_quantity: 1
  }.freeze

  attr_reader :errors, :warnings

  def initialize(configuration, company:)
    @config = configuration || {}
    @company = company
    @errors = []
    @warnings = []
  end

  def valid?
    validate!
    @errors.empty?
  end

  def validate!
    @errors = []
    @warnings = []

    validate_has_components
    return if @errors.any?

    validate_minimum_products
    validate_component_counts
    validate_no_duplicate_products
    validate_products_exist_and_available
    validate_quantities
    validate_configurable_variants
    validate_combination_count
  end

  def combination_count
    @combination_count ||= calculate_combination_count
  end

  private

  def components
    @config['components'] || []
  end

  def validate_has_components
    if components.empty?
      @errors << 'Bundle configuration is empty'
    end
  end

  def validate_minimum_products
    if components.size < 2
      @errors << 'Bundle must contain at least 2 products'
    end
  end

  def validate_component_counts
    configurables = components.count { |c| c['product_type'] == 'configurable' }
    sellables = components.count { |c| c['product_type'] == 'sellable' }
    total = configurables + sellables

    if configurables > LIMITS[:max_configurables]
      @errors << "Maximum #{LIMITS[:max_configurables]} configurable products allowed (you have #{configurables})"
    end

    if sellables > LIMITS[:max_sellables]
      @errors << "Maximum #{LIMITS[:max_sellables]} sellable products allowed (you have #{sellables})"
    end

    if total > LIMITS[:max_total_products]
      @errors << "Maximum #{LIMITS[:max_total_products]} total products allowed (you have #{total})"
    end
  end

  def validate_no_duplicate_products
    product_ids = components.map { |c| c['product_id'] }
    duplicates = product_ids.select { |id| product_ids.count(id) > 1 }.uniq

    if duplicates.any?
      @errors << 'Duplicate products not allowed. Use quantity instead.'
    end
  end

  def validate_products_exist_and_available
    components.each do |component|
      product = @company.products.find_by(id: component['product_id'])

      if product.nil?
        @errors << "Product not found: #{component['product_id']}"
      elsif product.discontinued?
        @errors << "#{product.name} is discontinued and cannot be added to bundles"
      end
    end
  end

  def validate_quantities
    components.each do |component|
      if component['product_type'] == 'sellable'
        validate_quantity(component['quantity'])
      elsif component['product_type'] == 'configurable'
        component['variants']&.each do |variant|
          next unless variant['included']
          validate_quantity(variant['quantity'])
        end
      end
    end
  end

  def validate_quantity(qty)
    qty = qty.to_i
    if qty < LIMITS[:min_quantity]
      @errors << "Quantity must be at least #{LIMITS[:min_quantity]}"
    elsif qty > LIMITS[:max_quantity]
      @errors << "Quantity cannot exceed #{LIMITS[:max_quantity]}"
    end
  end

  def validate_configurable_variants
    components.select { |c| c['product_type'] == 'configurable' }.each do |component|
      product = @company.products.find_by(id: component['product_id'])
      next unless product

      included_variants = component['variants']&.select { |v| v['included'] } || []

      if included_variants.empty?
        @errors << "#{product.name}: At least one variant must be selected"
        next
      end

      included_variants.each do |variant_config|
        variant = product.subproducts.find_by(id: variant_config['variant_id'])
        if variant&.discontinued?
          @warnings << "#{product.name}: #{variant.name} is discontinued and will be skipped"
        end
      end
    end
  end

  def validate_combination_count
    count = combination_count

    if count > LIMITS[:max_combinations]
      @errors << "This configuration would generate #{count} variants (maximum: #{LIMITS[:max_combinations]}). Please reduce variant selections."
    elsif count > 100
      @warnings << "This will generate #{count} bundle variants"
    end
  end

  def calculate_combination_count
    configurable_counts = components
      .select { |c| c['product_type'] == 'configurable' }
      .map { |c| c['variants']&.count { |v| v['included'] } || 0 }

    return 1 if configurable_counts.empty?
    return 0 if configurable_counts.any?(&:zero?)

    configurable_counts.reduce(1, :*)
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rspec spec/services/bundle_validation_service_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/bundle_validation_service.rb spec/services/bundle_validation_service_spec.rb
git commit -m "feat: add BundleValidationService with comprehensive validation"
```

---

### Task 6: Create BundleSkuGeneratorService

**Files:**
- Create: `app/services/bundle_sku_generator_service.rb`
- Create: `spec/services/bundle_sku_generator_service_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/services/bundle_sku_generator_service_spec.rb
require 'rails_helper'

RSpec.describe BundleSkuGeneratorService do
  let(:company) { create(:company) }

  describe '#generate' do
    it 'generates SKU from base SKU and variant codes' do
      service = described_class.new('SUMKIT', ['S', 'M'])
      expect(service.generate).to eq('SUMKIT-S-M')
    end

    it 'handles single variant code' do
      service = described_class.new('BUNDLE', ['L'])
      expect(service.generate).to eq('BUNDLE-L')
    end

    it 'handles no variant codes (sellables only)' do
      service = described_class.new('KIT', [])
      expect(service.generate).to eq('KIT')
    end

    it 'sanitizes codes with special characters' do
      service = described_class.new('TEST', ['X/L', 'Red Color'])
      expect(service.generate).to eq('TEST-XL-RED-COLOR')
    end

    it 'truncates long SKUs' do
      long_codes = ['VERYLONGVARIANTNAME', 'ANOTHERLONGNAME', 'YETANOTHERLONGONE']
      service = described_class.new('BUNDLEPRODUCTSKU', long_codes)
      result = service.generate

      expect(result.length).to be <= 50
    end
  end

  describe '.generate' do
    it 'provides class method shortcut' do
      result = described_class.generate('BASE', ['A', 'B'])
      expect(result).to eq('BASE-A-B')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/services/bundle_sku_generator_service_spec.rb`
Expected: FAIL with "uninitialized constant BundleSkuGeneratorService"

**Step 3: Write implementation**

```ruby
# app/services/bundle_sku_generator_service.rb
class BundleSkuGeneratorService
  MAX_SKU_LENGTH = 50

  def initialize(base_sku, variant_codes)
    @base_sku = base_sku.to_s.strip
    @variant_codes = Array(variant_codes)
  end

  def generate
    return @base_sku if @variant_codes.empty?

    sanitized_codes = @variant_codes.map { |code| sanitize_code(code) }
    full_sku = [@base_sku, *sanitized_codes].join('-')

    truncate_sku(full_sku)
  end

  def self.generate(base_sku, variant_codes)
    new(base_sku, variant_codes).generate
  end

  private

  def sanitize_code(code)
    code.to_s
        .upcase
        .gsub(/[^A-Z0-9]+/, '-')
        .gsub(/-+/, '-')
        .gsub(/^-|-$/, '')
  end

  def truncate_sku(sku)
    return sku if sku.length <= MAX_SKU_LENGTH

    # Keep base SKU intact, truncate variant part
    base_length = @base_sku.length
    remaining = MAX_SKU_LENGTH - base_length - 1 # -1 for separator

    variant_part = sku[(base_length + 1)..]
    truncated_variant = truncate_variant_part(variant_part, remaining)

    "#{@base_sku}-#{truncated_variant}"
  end

  def truncate_variant_part(variant_part, max_length)
    return variant_part if variant_part.length <= max_length

    # Truncate each code proportionally
    codes = variant_part.split('-')
    per_code_length = (max_length - codes.length + 1) / codes.length

    codes.map { |code| code[0, [per_code_length, 3].max] }.join('-')
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rspec spec/services/bundle_sku_generator_service_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/bundle_sku_generator_service.rb spec/services/bundle_sku_generator_service_spec.rb
git commit -m "feat: add BundleSkuGeneratorService for variant SKU generation"
```

---

### Task 7: Create BundleVariantGeneratorService

**Files:**
- Create: `app/services/bundle_variant_generator_service.rb`
- Create: `spec/services/bundle_variant_generator_service_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/services/bundle_variant_generator_service_spec.rb
require 'rails_helper'

RSpec.describe BundleVariantGeneratorService do
  let(:company) { create(:company) }
  let(:bundle) { create(:product, :bundle, company: company, name: 'Test Bundle', sku: 'TESTBUNDLE') }

  describe '#call' do
    context 'with sellable products only' do
      let(:sellable1) { create(:product, :sellable, company: company) }
      let(:sellable2) { create(:product, :sellable, company: company) }
      let(:config) do
        {
          'components' => [
            { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
            { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'generates single variant' do
        result = described_class.new(bundle, config).call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(1)
      end

      it 'creates variant as sellable product' do
        result = described_class.new(bundle, config).call
        variant = result.variants.first

        expect(variant.product_type).to eq('sellable')
        expect(variant.bundle_variant).to be true
        expect(variant.parent_bundle).to eq(bundle)
      end

      it 'creates product configurations for variant' do
        result = described_class.new(bundle, config).call
        variant = result.variants.first

        configs = variant.product_configurations_as_super
        expect(configs.count).to eq(2)
        expect(configs.map(&:subproduct_id)).to contain_exactly(sellable1.id, sellable2.id)
        expect(configs.find_by(subproduct_id: sellable1.id).quantity).to eq(2)
      end
    end

    context 'with configurable products' do
      let(:configurable) { create(:product, :configurable, company: company) }
      let(:variant_s) { create(:product, :sellable, company: company, name: 'Variant S') }
      let(:variant_m) { create(:product, :sellable, company: company, name: 'Variant M') }
      let(:sellable) { create(:product, :sellable, company: company) }

      before do
        # Set up configurable with variants
        create(:product_configuration, superproduct: configurable, subproduct: variant_s,
               info: { 'variant_config' => { 'size' => 'S' } })
        create(:product_configuration, superproduct: configurable, subproduct: variant_m,
               info: { 'variant_config' => { 'size' => 'M' } })
      end

      let(:config) do
        {
          'components' => [
            {
              'product_id' => configurable.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => variant_s.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => variant_m.id, 'included' => true, 'quantity' => 2, 'code' => 'M' }
              ]
            },
            { 'product_id' => sellable.id, 'product_type' => 'sellable', 'quantity' => 3 }
          ]
        }
      end

      it 'generates variant per included configurable variant' do
        result = described_class.new(bundle, config).call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(2) # S and M
      end

      it 'generates correct SKUs' do
        result = described_class.new(bundle, config).call
        skus = result.variants.map(&:sku)

        expect(skus).to contain_exactly('TESTBUNDLE-S', 'TESTBUNDLE-M')
      end

      it 'sets correct quantities per variant' do
        result = described_class.new(bundle, config).call

        variant_s_product = result.variants.find { |v| v.sku == 'TESTBUNDLE-S' }
        variant_m_product = result.variants.find { |v| v.sku == 'TESTBUNDLE-M' }

        # Check configurable component quantity
        expect(variant_s_product.product_configurations_as_super.find_by(subproduct_id: variant_s.id).quantity).to eq(1)
        expect(variant_m_product.product_configurations_as_super.find_by(subproduct_id: variant_m.id).quantity).to eq(2)

        # Check sellable component quantity (same for all)
        expect(variant_s_product.product_configurations_as_super.find_by(subproduct_id: sellable.id).quantity).to eq(3)
      end

      it 'excludes non-included variants' do
        config_with_exclusion = config.deep_dup
        config_with_exclusion['components'][0]['variants'][1]['included'] = false

        result = described_class.new(bundle, config_with_exclusion).call

        expect(result.variants.count).to eq(1)
        expect(result.variants.first.sku).to eq('TESTBUNDLE-S')
      end
    end

    context 'with multiple configurable products' do
      let(:config1) { create(:product, :configurable, company: company) }
      let(:config2) { create(:product, :configurable, company: company) }
      let(:v1_s) { create(:product, :sellable, company: company) }
      let(:v1_m) { create(:product, :sellable, company: company) }
      let(:v2_red) { create(:product, :sellable, company: company) }
      let(:v2_blue) { create(:product, :sellable, company: company) }

      before do
        create(:product_configuration, superproduct: config1, subproduct: v1_s)
        create(:product_configuration, superproduct: config1, subproduct: v1_m)
        create(:product_configuration, superproduct: config2, subproduct: v2_red)
        create(:product_configuration, superproduct: config2, subproduct: v2_blue)
      end

      let(:config) do
        {
          'components' => [
            {
              'product_id' => config1.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => v1_s.id, 'included' => true, 'quantity' => 1, 'code' => 'S' },
                { 'variant_id' => v1_m.id, 'included' => true, 'quantity' => 1, 'code' => 'M' }
              ]
            },
            {
              'product_id' => config2.id,
              'product_type' => 'configurable',
              'variants' => [
                { 'variant_id' => v2_red.id, 'included' => true, 'quantity' => 1, 'code' => 'RED' },
                { 'variant_id' => v2_blue.id, 'included' => true, 'quantity' => 1, 'code' => 'BLUE' }
              ]
            }
          ]
        }
      end

      it 'generates cartesian product of variants' do
        result = described_class.new(bundle, config).call

        expect(result.success?).to be true
        expect(result.variants.count).to eq(4) # 2 x 2
      end

      it 'generates all combination SKUs' do
        result = described_class.new(bundle, config).call
        skus = result.variants.map(&:sku).sort

        expect(skus).to eq(['TESTBUNDLE-M-BLUE', 'TESTBUNDLE-M-RED', 'TESTBUNDLE-S-BLUE', 'TESTBUNDLE-S-RED'])
      end
    end

    context 'with validation errors' do
      it 'returns failure for non-bundle product' do
        sellable = create(:product, :sellable, company: company)
        result = described_class.new(sellable, {}).call

        expect(result.success?).to be false
        expect(result.errors).to include('Product is not a bundle')
      end

      it 'returns failure for empty configuration' do
        result = described_class.new(bundle, { 'components' => [] }).call

        expect(result.success?).to be false
      end
    end

    context 'bundle template' do
      let(:config) do
        {
          'components' => [
            { 'product_id' => create(:product, :sellable, company: company).id, 'product_type' => 'sellable', 'quantity' => 1 },
            { 'product_id' => create(:product, :sellable, company: company).id, 'product_type' => 'sellable', 'quantity' => 1 }
          ]
        }
      end

      it 'creates bundle template' do
        expect {
          described_class.new(bundle, config).call
        }.to change(BundleTemplate, :count).by(1)
      end

      it 'stores configuration in template' do
        described_class.new(bundle, config).call

        template = bundle.reload.bundle_template
        expect(template.configuration).to eq(config)
        expect(template.generated_variants_count).to eq(1)
        expect(template.last_generated_at).to be_within(1.second).of(Time.current)
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/services/bundle_variant_generator_service_spec.rb`
Expected: FAIL with "uninitialized constant BundleVariantGeneratorService"

**Step 3: Write implementation**

```ruby
# app/services/bundle_variant_generator_service.rb
class BundleVariantGeneratorService
  Result = Struct.new(:success?, :variants, :errors, keyword_init: true)

  def initialize(bundle_product, configuration)
    @bundle = bundle_product
    @config = configuration || {}
    @company = bundle_product.company
    @errors = []
  end

  def call
    return failure('Product is not a bundle') unless @bundle.product_type_bundle?

    validation = BundleValidationService.new(@config, company: @company)
    return failure(validation.errors.join(', ')) unless validation.valid?

    combinations = generate_combinations
    return failure('No valid combinations to generate') if combinations.empty?

    variants = []
    ActiveRecord::Base.transaction do
      variants = create_variants(combinations)
      create_or_update_bundle_template(variants)
    end

    Result.new(success?: true, variants: variants, errors: [])
  rescue StandardError => e
    Result.new(success?: false, variants: [], errors: [e.message])
  end

  private

  def failure(message)
    Result.new(success?: false, variants: [], errors: Array(message))
  end

  def components
    @config['components'] || []
  end

  def generate_combinations
    configurable_components = components.select { |c| c['product_type'] == 'configurable' }
    sellable_components = components.select { |c| c['product_type'] == 'sellable' }

    if configurable_components.empty?
      # Only sellables - single combination
      return [{ variant_codes: [], configurable_items: [], sellable_items: sellable_components }]
    end

    # Get included variants for each configurable
    variant_sets = configurable_components.map do |component|
      component['variants']
        &.select { |v| v['included'] }
        &.map { |v| v.merge('parent_product_id' => component['product_id']) } || []
    end

    # Cartesian product
    variant_sets.first.product(*variant_sets[1..]).map do |combo|
      combo = [combo].flatten # Handle single configurable case
      {
        variant_codes: combo.map { |v| v['code'] },
        configurable_items: combo,
        sellable_items: sellable_components
      }
    end
  end

  def create_variants(combinations)
    combinations.map do |combo|
      variant = create_variant_product(combo)
      create_product_configurations(variant, combo)
      variant
    end
  end

  def create_variant_product(combo)
    sku = BundleSkuGeneratorService.generate(@bundle.sku, combo[:variant_codes])
    name = generate_variant_name(combo)

    @company.products.create!(
      name: name,
      sku: sku,
      product_type: :sellable,
      product_status: :draft,
      parent_bundle: @bundle,
      bundle_variant: true
    )
  end

  def generate_variant_name(combo)
    if combo[:variant_codes].empty?
      @bundle.name
    else
      "#{@bundle.name} - #{combo[:variant_codes].join('/')}"
    end
  end

  def create_product_configurations(variant, combo)
    # Add configurable items (specific variants)
    combo[:configurable_items].each do |item|
      variant.product_configurations_as_super.create!(
        subproduct_id: item['variant_id'],
        info: { 'quantity' => item['quantity'].to_i }
      )
    end

    # Add sellable items
    combo[:sellable_items].each do |item|
      variant.product_configurations_as_super.create!(
        subproduct_id: item['product_id'],
        info: { 'quantity' => item['quantity'].to_i }
      )
    end
  end

  def create_or_update_bundle_template(variants)
    template = @bundle.bundle_template || @bundle.build_bundle_template(company: @company)
    template.update!(
      configuration: @config,
      generated_variants_count: variants.count,
      last_generated_at: Time.current
    )
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rspec spec/services/bundle_variant_generator_service_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/services/bundle_variant_generator_service.rb spec/services/bundle_variant_generator_service_spec.rb
git commit -m "feat: add BundleVariantGeneratorService for variant generation"
```

---

### Task 8: Create BundleRegeneratorService

**Files:**
- Create: `app/services/bundle_regenerator_service.rb`
- Create: `spec/services/bundle_regenerator_service_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/services/bundle_regenerator_service_spec.rb
require 'rails_helper'

RSpec.describe BundleRegeneratorService do
  let(:company) { create(:company) }
  let(:bundle) { create(:product, :bundle, company: company, sku: 'BUNDLE') }
  let(:sellable1) { create(:product, :sellable, company: company) }
  let(:sellable2) { create(:product, :sellable, company: company) }
  let(:sellable3) { create(:product, :sellable, company: company) }

  let(:original_config) do
    {
      'components' => [
        { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
        { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
      ]
    }
  end

  let(:new_config) do
    {
      'components' => [
        { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 2 },
        { 'product_id' => sellable3.id, 'product_type' => 'sellable', 'quantity' => 1 }
      ]
    }
  end

  before do
    # Generate original variants
    BundleVariantGeneratorService.new(bundle, original_config).call
  end

  describe '#call' do
    it 'soft deletes old variants' do
      old_variant = bundle.bundle_variants.first

      described_class.new(bundle, new_config).call

      old_variant.reload
      expect(old_variant.product_status).to eq('deleted')
      expect(old_variant.deleted_at).to be_present
    end

    it 'generates new variants' do
      result = described_class.new(bundle, new_config).call

      expect(result.success?).to be true
      expect(result.created_count).to eq(1)
    end

    it 'returns deleted and created counts' do
      result = described_class.new(bundle, new_config).call

      expect(result.deleted_count).to eq(1)
      expect(result.created_count).to eq(1)
    end

    it 'updates bundle template' do
      described_class.new(bundle, new_config).call

      template = bundle.reload.bundle_template
      expect(template.configuration).to eq(new_config)
    end

    it 'keeps old variants linked to bundle' do
      old_variant_id = bundle.bundle_variants.first.id

      described_class.new(bundle, new_config).call

      old_variant = Product.find(old_variant_id)
      expect(old_variant.parent_bundle_id).to eq(bundle.id)
    end

    context 'when validation fails' do
      let(:invalid_config) do
        { 'components' => [] }
      end

      it 'does not delete old variants' do
        expect {
          described_class.new(bundle, invalid_config).call
        }.not_to change { bundle.bundle_variants.where.not(product_status: :deleted).count }
      end

      it 'returns failure' do
        result = described_class.new(bundle, invalid_config).call
        expect(result.success?).to be false
      end
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/services/bundle_regenerator_service_spec.rb`
Expected: FAIL with "uninitialized constant BundleRegeneratorService"

**Step 3: Write implementation**

```ruby
# app/services/bundle_regenerator_service.rb
class BundleRegeneratorService
  Result = Struct.new(:success?, :deleted_count, :created_count, :errors, keyword_init: true)

  def initialize(bundle_product, new_configuration)
    @bundle = bundle_product
    @new_config = new_configuration
    @company = bundle_product.company
  end

  def call
    validation = BundleValidationService.new(@new_config, company: @company)
    return failure(validation.errors) unless validation.valid?

    deleted_variants = []
    new_variants = []

    ActiveRecord::Base.transaction do
      deleted_variants = soft_delete_old_variants
      result = generate_new_variants

      raise ActiveRecord::Rollback unless result.success?

      new_variants = result.variants
      # TODO: Add Shopify sync jobs here in future phase
    end

    if new_variants.any?
      Result.new(
        success?: true,
        deleted_count: deleted_variants.count,
        created_count: new_variants.count,
        errors: []
      )
    else
      failure(['Failed to generate new variants'])
    end
  rescue StandardError => e
    failure([e.message])
  end

  private

  def failure(errors)
    Result.new(success?: false, deleted_count: 0, created_count: 0, errors: Array(errors))
  end

  def soft_delete_old_variants
    old_variants = @bundle.bundle_variants.where.not(product_status: :deleted)

    old_variants.find_each do |variant|
      variant.update!(
        product_status: :deleted,
        deleted_at: Time.current,
        info: (variant.info || {}).merge('replaced_by_regeneration' => true, 'replaced_at' => Time.current.iso8601)
      )
    end

    old_variants.to_a
  end

  def generate_new_variants
    BundleVariantGeneratorService.new(@bundle, @new_config).call
  end
end
```

**Step 4: Add deleted_at column if not exists**

Check if `deleted_at` exists on products table. If not, create migration:

Run: `bin/rails generate migration AddDeletedAtToProducts deleted_at:datetime`

```ruby
# db/migrate/XXXXXX_add_deleted_at_to_products.rb
class AddDeletedAtToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :deleted_at, :datetime unless column_exists?(:products, :deleted_at)
    add_index :products, :deleted_at unless index_exists?(:products, :deleted_at)
  end
end
```

Run: `bin/rails db:migrate`

**Step 5: Run test to verify it passes**

Run: `bin/rspec spec/services/bundle_regenerator_service_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/services/bundle_regenerator_service.rb spec/services/bundle_regenerator_service_spec.rb db/migrate/*
git commit -m "feat: add BundleRegeneratorService for bundle regeneration"
```

---

## Phase 3: Controllers

### Task 9: Create BundleComposerController

**Files:**
- Create: `app/controllers/bundle_composer_controller.rb`
- Create: `spec/controllers/bundle_composer_controller_spec.rb`
- Create: `config/routes.rb` (add routes)

**Step 1: Add routes**

```ruby
# config/routes.rb (add inside the main routes block)
namespace :bundle_composer do
  get :search
  get 'product/:id', action: :product_details, as: :product_details
  post :preview
end
```

**Step 2: Write the failing tests**

```ruby
# spec/controllers/bundle_composer_controller_spec.rb
require 'rails_helper'

RSpec.describe BundleComposerController, type: :controller do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }

  before do
    sign_in(user)
    allow(controller).to receive(:current_potlift_company).and_return(company)
  end

  describe 'GET #search' do
    let!(:sellable) { create(:product, :sellable, company: company, name: 'Test Shirt', sku: 'SHIRT001') }
    let!(:configurable) { create(:product, :configurable, company: company, name: 'Test Hoodie') }
    let!(:bundle) { create(:product, :bundle, company: company, name: 'Test Bundle') }
    let!(:discontinued) { create(:product, :sellable, company: company, name: 'Old Shirt', product_status: :discontinued) }
    let!(:other_company_product) { create(:product, :sellable, name: 'Other Product') }

    it 'returns sellable and configurable products matching query' do
      get :search, params: { q: 'Test' }, format: :turbo_stream

      expect(assigns(:products)).to include(sellable, configurable)
    end

    it 'excludes bundle products' do
      get :search, params: { q: 'Test' }, format: :turbo_stream

      expect(assigns(:products)).not_to include(bundle)
    end

    it 'excludes discontinued products' do
      get :search, params: { q: 'Shirt' }, format: :turbo_stream

      expect(assigns(:products)).not_to include(discontinued)
    end

    it 'excludes other company products' do
      get :search, params: { q: 'Product' }, format: :turbo_stream

      expect(assigns(:products)).not_to include(other_company_product)
    end

    it 'searches by SKU' do
      get :search, params: { q: 'SHIRT001' }, format: :turbo_stream

      expect(assigns(:products)).to include(sellable)
    end

    it 'limits results to 20' do
      create_list(:product, 25, :sellable, company: company, name: 'Bulk Product')

      get :search, params: { q: 'Bulk' }, format: :turbo_stream

      expect(assigns(:products).count).to eq(20)
    end
  end

  describe 'GET #product_details' do
    let(:product) { create(:product, :sellable, company: company) }

    it 'returns product details' do
      get :product_details, params: { id: product.id }, format: :turbo_stream

      expect(assigns(:product)).to eq(product)
    end

    context 'with configurable product' do
      let(:configurable) { create(:product, :configurable, company: company) }
      let!(:variant1) { create(:product, :sellable, company: company) }
      let!(:variant2) { create(:product, :sellable, company: company, product_status: :discontinued) }

      before do
        create(:product_configuration, superproduct: configurable, subproduct: variant1)
        create(:product_configuration, superproduct: configurable, subproduct: variant2)
      end

      it 'includes variants' do
        get :product_details, params: { id: configurable.id }, format: :turbo_stream

        expect(assigns(:variants)).to include(variant1, variant2)
      end

      it 'identifies discontinued variants' do
        get :product_details, params: { id: configurable.id }, format: :turbo_stream

        expect(assigns(:discontinued_variants)).to include(variant2)
        expect(assigns(:discontinued_variants)).not_to include(variant1)
      end
    end
  end

  describe 'POST #preview' do
    let(:sellable1) { create(:product, :sellable, company: company) }
    let(:sellable2) { create(:product, :sellable, company: company) }

    let(:valid_config) do
      {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
          { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
    end

    it 'returns validation result' do
      post :preview, params: { configuration: valid_config.to_json }, format: :json

      json = JSON.parse(response.body)
      expect(json['valid']).to be true
      expect(json['combination_count']).to eq(1)
    end

    it 'returns errors for invalid config' do
      invalid_config = { 'components' => [] }

      post :preview, params: { configuration: invalid_config.to_json }, format: :json

      json = JSON.parse(response.body)
      expect(json['valid']).to be false
      expect(json['errors']).to be_present
    end
  end
end
```

**Step 3: Run test to verify it fails**

Run: `bin/rspec spec/controllers/bundle_composer_controller_spec.rb`
Expected: FAIL with routing or controller errors

**Step 4: Write implementation**

```ruby
# app/controllers/bundle_composer_controller.rb
class BundleComposerController < ApplicationController
  before_action :authenticate_user!

  def search
    query = params[:q].to_s.strip

    @products = current_potlift_company.products
      .not_bundle_variants
      .where(product_type: [:sellable, :configurable])
      .where.not(product_status: :discontinued)
      .where('name ILIKE :q OR sku ILIKE :q', q: "%#{query}%")
      .includes(product_configurations_as_super: :subproduct)
      .limit(20)

    respond_to do |format|
      format.turbo_stream
      format.html { render partial: 'bundle_composer/search_results', locals: { products: @products } }
    end
  end

  def product_details
    @product = current_potlift_company.products.find(params[:id])

    if @product.product_type_configurable?
      @variants = @product.subproducts.includes(:inventories)
      @discontinued_variants = @variants.select { |v| v.product_status == 'discontinued' }
    end

    respond_to do |format|
      format.turbo_stream
      format.html { render partial: 'bundle_composer/product_card', locals: { product: @product, variants: @variants, discontinued_variants: @discontinued_variants } }
    end
  end

  def preview
    config = JSON.parse(params[:configuration] || '{}')
    validator = BundleValidationService.new(config, company: current_potlift_company)
    validator.valid?

    render json: {
      valid: validator.errors.empty?,
      errors: validator.errors,
      warnings: validator.warnings,
      combination_count: validator.combination_count
    }
  rescue JSON::ParserError => e
    render json: { valid: false, errors: ['Invalid configuration format'], combination_count: 0 }
  end
end
```

**Step 5: Run test to verify it passes**

Run: `bin/rspec spec/controllers/bundle_composer_controller_spec.rb`
Expected: All tests PASS

**Step 6: Commit**

```bash
git add app/controllers/bundle_composer_controller.rb spec/controllers/bundle_composer_controller_spec.rb config/routes.rb
git commit -m "feat: add BundleComposerController for AJAX operations"
```

---

### Task 10: Update ProductsController for bundle generation

**Files:**
- Modify: `app/controllers/products_controller.rb`
- Modify: `spec/controllers/products_controller_spec.rb` or `spec/requests/products_spec.rb`

**Step 1: Write the failing tests**

```ruby
# spec/requests/products_bundle_spec.rb
require 'rails_helper'

RSpec.describe 'Products Bundle Creation', type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:sellable1) { create(:product, :sellable, company: company) }
  let(:sellable2) { create(:product, :sellable, company: company) }

  before do
    sign_in(user)
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
  end

  describe 'POST /products (bundle creation)' do
    let(:bundle_config) do
      {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
          { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 2 }
        ]
      }
    end

    let(:valid_params) do
      {
        product: {
          name: 'Test Bundle',
          sku: 'TESTBUNDLE',
          product_type: 'bundle'
        },
        bundle_configuration: bundle_config.to_json
      }
    end

    it 'creates bundle product with variants' do
      expect {
        post products_path, params: valid_params
      }.to change(Product, :count).by(2) # bundle + 1 variant

      bundle = Product.find_by(sku: 'TESTBUNDLE')
      expect(bundle.product_type).to eq('bundle')
      expect(bundle.bundle_variants.count).to eq(1)
    end

    it 'creates bundle template' do
      post products_path, params: valid_params

      bundle = Product.find_by(sku: 'TESTBUNDLE')
      expect(bundle.bundle_template).to be_present
      expect(bundle.bundle_template.configuration).to eq(bundle_config)
    end

    it 'redirects to bundle show page on success' do
      post products_path, params: valid_params

      bundle = Product.find_by(sku: 'TESTBUNDLE')
      expect(response).to redirect_to(product_path(bundle))
    end

    context 'with invalid bundle configuration' do
      let(:invalid_config) { { 'components' => [] } }

      it 'does not create bundle' do
        expect {
          post products_path, params: valid_params.merge(bundle_configuration: invalid_config.to_json)
        }.not_to change(Product, :count)
      end

      it 'renders form with errors' do
        post products_path, params: valid_params.merge(bundle_configuration: invalid_config.to_json)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'PATCH /products/:id (bundle regeneration)' do
    let(:bundle) { create(:product, :bundle, company: company, sku: 'EXISTINGBUNDLE') }
    let(:original_config) do
      {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 1 },
          { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
    end

    before do
      BundleVariantGeneratorService.new(bundle, original_config).call
    end

    let(:new_config) do
      {
        'components' => [
          { 'product_id' => sellable1.id, 'product_type' => 'sellable', 'quantity' => 3 },
          { 'product_id' => sellable2.id, 'product_type' => 'sellable', 'quantity' => 1 }
        ]
      }
    end

    it 'regenerates variants when regenerate flag is true' do
      old_variant_id = bundle.bundle_variants.first.id

      patch product_path(bundle), params: {
        product: { name: 'Updated Bundle' },
        bundle_configuration: new_config.to_json,
        regenerate: 'true'
      }

      expect(Product.find(old_variant_id).product_status).to eq('deleted')
      expect(bundle.reload.bundle_variants.where.not(product_status: :deleted).count).to eq(1)
    end

    it 'does not regenerate without flag' do
      old_variant_id = bundle.bundle_variants.first.id

      patch product_path(bundle), params: {
        product: { name: 'Updated Bundle' },
        bundle_configuration: new_config.to_json
      }

      expect(Product.find(old_variant_id).product_status).not_to eq('deleted')
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `bin/rspec spec/requests/products_bundle_spec.rb`
Expected: FAIL (bundle generation not implemented)

**Step 3: Update ProductsController**

```ruby
# app/controllers/products_controller.rb
# Add to existing create action:

def create
  @product = current_potlift_company.products.new(product_params)

  ActiveRecord::Base.transaction do
    @product.save!

    if @product.product_type_bundle? && bundle_config_present?
      result = generate_bundle_variants!
      unless result.success?
        @product.errors.add(:base, result.errors.join(', '))
        raise ActiveRecord::Rollback
      end
      @generated_count = result.variants.count
    end
  end

  if @product.persisted? && @product.errors.empty?
    redirect_to @product, notice: create_success_message
  else
    render :new, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordInvalid => e
  render :new, status: :unprocessable_entity
end

def update
  @product = current_potlift_company.products.find(params[:id])

  ActiveRecord::Base.transaction do
    @product.update!(product_params)

    if @product.product_type_bundle? && should_regenerate?
      result = regenerate_bundle_variants!
      unless result.success?
        @product.errors.add(:base, result.errors.join(', '))
        raise ActiveRecord::Rollback
      end
      @regeneration_result = result
    end
  end

  if @product.errors.empty?
    redirect_to @product, notice: update_success_message
  else
    render :edit, status: :unprocessable_entity
  end
rescue ActiveRecord::RecordInvalid => e
  render :edit, status: :unprocessable_entity
end

private

def generate_bundle_variants!
  BundleVariantGeneratorService.new(@product, bundle_configuration).call
end

def regenerate_bundle_variants!
  BundleRegeneratorService.new(@product, bundle_configuration).call
end

def bundle_configuration
  @bundle_configuration ||= JSON.parse(params[:bundle_configuration] || '{}')
rescue JSON::ParserError
  {}
end

def bundle_config_present?
  params[:bundle_configuration].present? && bundle_configuration['components'].present?
end

def should_regenerate?
  params[:regenerate] == 'true' && bundle_config_present?
end

def create_success_message
  if @generated_count
    "Bundle created with #{@generated_count} variants"
  else
    'Product created successfully'
  end
end

def update_success_message
  if @regeneration_result
    "Bundle updated. Deleted #{@regeneration_result.deleted_count}, created #{@regeneration_result.created_count} variants."
  else
    'Product updated successfully'
  end
end
```

**Step 4: Run test to verify it passes**

Run: `bin/rspec spec/requests/products_bundle_spec.rb`
Expected: All tests PASS

**Step 5: Commit**

```bash
git add app/controllers/products_controller.rb spec/requests/products_bundle_spec.rb
git commit -m "feat: add bundle variant generation to ProductsController"
```

---

## Phase 4: Frontend (Stimulus + Views)

### Task 11: Create bundle_composer Stimulus controller

**Files:**
- Create: `app/javascript/controllers/bundle_composer_controller.js`

**Step 1: Write the Stimulus controller**

```javascript
// app/javascript/controllers/bundle_composer_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "composer",
    "searchInput",
    "searchResults",
    "selectedProducts",
    "preview",
    "previewCount",
    "previewCombinations",
    "configuration",
    "productCount",
    "errorContainer",
    "warningContainer",
    "submitButton"
  ]

  static values = {
    maxConfigurables: { type: Number, default: 3 },
    maxSellables: { type: Number, default: 10 },
    maxCombinations: { type: Number, default: 200 }
  }

  connect() {
    this.selectedProducts = new Map()
    this.updateUI()
  }

  // Called when product type dropdown changes
  productTypeChanged(event) {
    const isBundle = event.target.value === "bundle"

    if (this.hasComposerTarget) {
      this.composerTarget.classList.toggle("hidden", !isBundle)
    }
  }

  // Search products with debounce
  search() {
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  async performSearch() {
    const query = this.searchInputTarget.value.trim()
    if (query.length < 2) {
      this.searchResultsTarget.innerHTML = ""
      return
    }

    try {
      const response = await fetch(`/bundle_composer/search?q=${encodeURIComponent(query)}`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      this.searchResultsTarget.innerHTML = await response.text()
    } catch (error) {
      console.error("Search failed:", error)
    }
  }

  clearSearch() {
    this.searchInputTarget.value = ""
    this.searchResultsTarget.innerHTML = ""
  }

  // Add product to bundle
  async addProduct(event) {
    const button = event.currentTarget
    const productId = button.dataset.productId
    const productType = button.dataset.productType
    const productName = button.dataset.productName

    if (this.selectedProducts.has(productId)) {
      return // Already added
    }

    // Check limits
    const currentConfigurables = this.countByType("configurable")
    const currentSellables = this.countByType("sellable")

    if (productType === "configurable" && currentConfigurables >= this.maxConfigurablesValue) {
      this.showError(`Maximum ${this.maxConfigurablesValue} configurable products allowed`)
      return
    }

    if (productType === "sellable" && currentSellables >= this.maxSellablesValue) {
      this.showError(`Maximum ${this.maxSellablesValue} sellable products allowed`)
      return
    }

    try {
      const response = await fetch(`/bundle_composer/product/${productId}`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })
      const html = await response.text()

      this.selectedProductsTarget.insertAdjacentHTML("beforeend", html)
      this.selectedProducts.set(productId, { type: productType, name: productName })

      this.clearSearch()
      this.updateUI()
      this.updatePreview()
    } catch (error) {
      console.error("Failed to add product:", error)
    }
  }

  // Remove product from bundle
  removeProduct(event) {
    const card = event.currentTarget.closest("[data-product-id]")
    const productId = card.dataset.productId

    card.remove()
    this.selectedProducts.delete(productId)

    this.updateUI()
    this.updatePreview()
  }

  // Toggle variant inclusion
  toggleVariant(event) {
    this.updatePreview()
  }

  // Update quantity
  quantityChanged(event) {
    this.updatePreview()
  }

  // Build configuration from UI
  buildConfiguration() {
    const components = []

    this.selectedProductsTarget.querySelectorAll("[data-product-card]").forEach(card => {
      const productId = parseInt(card.dataset.productId)
      const productType = card.dataset.productType

      if (productType === "sellable") {
        const quantityInput = card.querySelector("[data-quantity-input]")
        components.push({
          product_id: productId,
          product_type: "sellable",
          quantity: parseInt(quantityInput?.value || 1)
        })
      } else if (productType === "configurable") {
        const variants = []
        card.querySelectorAll("[data-variant-row]").forEach(row => {
          const checkbox = row.querySelector("[data-variant-checkbox]")
          const quantityInput = row.querySelector("[data-variant-quantity]")
          const code = row.dataset.variantCode

          variants.push({
            variant_id: parseInt(row.dataset.variantId),
            included: checkbox?.checked || false,
            quantity: parseInt(quantityInput?.value || 1),
            code: code
          })
        })

        components.push({
          product_id: productId,
          product_type: "configurable",
          variants: variants
        })
      }
    })

    return { components }
  }

  // Update preview with debounce
  updatePreview() {
    clearTimeout(this.previewTimeout)
    this.previewTimeout = setTimeout(() => {
      this.performPreview()
    }, 500)
  }

  async performPreview() {
    const config = this.buildConfiguration()

    // Update hidden field
    if (this.hasConfigurationTarget) {
      this.configurationTarget.value = JSON.stringify(config)
    }

    if (config.components.length < 2) {
      this.renderPreview({ valid: false, combination_count: 0, errors: [], warnings: [] })
      return
    }

    try {
      const response = await fetch("/bundle_composer/preview", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({ configuration: JSON.stringify(config) })
      })

      const data = await response.json()
      this.renderPreview(data)
    } catch (error) {
      console.error("Preview failed:", error)
    }
  }

  renderPreview(data) {
    // Update combination count
    if (this.hasPreviewCountTarget) {
      this.previewCountTarget.textContent = data.combination_count || 0
    }

    // Update errors
    if (this.hasErrorContainerTarget) {
      if (data.errors && data.errors.length > 0) {
        this.errorContainerTarget.innerHTML = data.errors.map(e =>
          `<div class="text-red-600 text-sm">• ${e}</div>`
        ).join("")
        this.errorContainerTarget.classList.remove("hidden")
      } else {
        this.errorContainerTarget.classList.add("hidden")
      }
    }

    // Update warnings
    if (this.hasWarningContainerTarget) {
      if (data.warnings && data.warnings.length > 0) {
        this.warningContainerTarget.innerHTML = data.warnings.map(w =>
          `<div class="text-yellow-600 text-sm">• ${w}</div>`
        ).join("")
        this.warningContainerTarget.classList.remove("hidden")
      } else {
        this.warningContainerTarget.classList.add("hidden")
      }
    }

    // Enable/disable submit
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !data.valid || data.combination_count === 0
    }
  }

  updateUI() {
    const count = this.selectedProducts.size

    if (this.hasProductCountTarget) {
      const configurables = this.countByType("configurable")
      const sellables = this.countByType("sellable")
      this.productCountTarget.textContent = `${count} products (${configurables} configurable, ${sellables} sellable)`
    }
  }

  countByType(type) {
    let count = 0
    this.selectedProducts.forEach(product => {
      if (product.type === type) count++
    })
    return count
  }

  showError(message) {
    if (this.hasErrorContainerTarget) {
      this.errorContainerTarget.innerHTML = `<div class="text-red-600 text-sm">• ${message}</div>`
      this.errorContainerTarget.classList.remove("hidden")

      setTimeout(() => {
        this.errorContainerTarget.classList.add("hidden")
      }, 5000)
    }
  }
}
```

**Step 2: Commit**

```bash
git add app/javascript/controllers/bundle_composer_controller.js
git commit -m "feat: add bundle_composer Stimulus controller"
```

---

### Task 12: Create bundle composer view partials

**Files:**
- Create: `app/views/bundle_composer/_composer.html.erb`
- Create: `app/views/bundle_composer/_search_results.html.erb`
- Create: `app/views/bundle_composer/_product_card.html.erb`
- Create: `app/views/bundle_composer/search.turbo_stream.erb`
- Create: `app/views/bundle_composer/product_details.turbo_stream.erb`

**Step 1: Create composer partial**

```erb
<%# app/views/bundle_composer/_composer.html.erb %>
<div id="bundle-composer"
     class="hidden mt-6 border rounded-lg p-4 bg-gray-50"
     data-controller="bundle-composer"
     data-bundle-composer-max-configurables-value="3"
     data-bundle-composer-max-sellables-value="10"
     data-bundle-composer-max-combinations-value="200">

  <h3 class="text-lg font-semibold mb-4 flex items-center gap-2">
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"/>
    </svg>
    Bundle Composer
  </h3>

  <%# Search Section %>
  <div class="mb-4">
    <label class="block text-sm font-medium text-gray-700 mb-1">Add Products</label>
    <div class="flex gap-2">
      <input type="text"
             data-bundle-composer-target="searchInput"
             data-action="input->bundle-composer#search"
             placeholder="Search products by name or SKU..."
             class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500">
      <button type="button"
              data-action="click->bundle-composer#clearSearch"
              class="px-3 py-2 text-sm text-gray-600 hover:text-gray-900">
        Clear
      </button>
    </div>

    <%# Search Results %>
    <div data-bundle-composer-target="searchResults"
         class="mt-2 border rounded-md bg-white shadow-sm max-h-60 overflow-y-auto">
    </div>
  </div>

  <%# Selected Products %>
  <div class="mb-4">
    <div class="flex justify-between items-center mb-2">
      <h4 class="text-sm font-medium text-gray-700">Selected Products</h4>
      <span data-bundle-composer-target="productCount" class="text-sm text-gray-500">0 products</span>
    </div>

    <div data-bundle-composer-target="selectedProducts"
         class="space-y-3 min-h-[100px] border-2 border-dashed border-gray-300 rounded-lg p-3">
      <p class="text-gray-400 text-sm text-center py-4" data-empty-state>
        Search and add products to your bundle
      </p>
    </div>
  </div>

  <%# Errors & Warnings %>
  <div data-bundle-composer-target="errorContainer" class="hidden mb-4 p-3 bg-red-50 border border-red-200 rounded-md">
  </div>

  <div data-bundle-composer-target="warningContainer" class="hidden mb-4 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
  </div>

  <%# Preview Section %>
  <div class="border-t pt-4">
    <h4 class="text-sm font-medium text-gray-700 mb-2">Generation Preview</h4>
    <div class="flex items-center gap-4 text-sm">
      <span>Will generate:</span>
      <span class="font-semibold text-lg" data-bundle-composer-target="previewCount">0</span>
      <span>bundle variants</span>
    </div>
  </div>

  <%# Hidden configuration field %>
  <%= hidden_field_tag :bundle_configuration, '{}', data: { bundle_composer_target: 'configuration' } %>
</div>
```

**Step 2: Create search results partial**

```erb
<%# app/views/bundle_composer/_search_results.html.erb %>
<% if products.any? %>
  <ul class="divide-y divide-gray-200">
    <% products.each do |product| %>
      <li class="p-3 hover:bg-gray-50 cursor-pointer flex justify-between items-center"
          data-action="click->bundle-composer#addProduct"
          data-product-id="<%= product.id %>"
          data-product-type="<%= product.product_type %>"
          data-product-name="<%= product.name %>">
        <div>
          <p class="font-medium text-gray-900"><%= product.name %></p>
          <p class="text-sm text-gray-500">
            SKU: <%= product.sku %> •
            <%= product.product_type.titleize %>
            <% if product.product_type_configurable? %>
              (<%= product.subproducts.count %> variants)
            <% end %>
          </p>
        </div>
        <span class="text-blue-600 text-sm">+ Add</span>
      </li>
    <% end %>
  </ul>
<% else %>
  <p class="p-3 text-gray-500 text-sm">No products found</p>
<% end %>
```

**Step 3: Create product card partial**

```erb
<%# app/views/bundle_composer/_product_card.html.erb %>
<div data-product-card
     data-product-id="<%= product.id %>"
     data-product-type="<%= product.product_type %>"
     class="border rounded-lg p-4 bg-white">

  <div class="flex justify-between items-start mb-3">
    <div>
      <h5 class="font-medium text-gray-900"><%= product.name %></h5>
      <p class="text-sm text-gray-500">SKU: <%= product.sku %> • <%= product.product_type.titleize %></p>
    </div>
    <button type="button"
            data-action="click->bundle-composer#removeProduct"
            class="text-red-600 hover:text-red-800 text-sm">
      Remove
    </button>
  </div>

  <% if product.product_type_sellable? %>
    <%# Sellable: single quantity input %>
    <div class="flex items-center gap-3">
      <label class="text-sm text-gray-600">Quantity:</label>
      <input type="number"
             min="1"
             max="99"
             value="1"
             data-quantity-input
             data-action="change->bundle-composer#quantityChanged"
             class="w-20 rounded-md border-gray-300 text-sm">
      <span class="text-sm text-gray-500">
        (<%= product.total_inventory || 0 %> in stock)
      </span>
    </div>
  <% else %>
    <%# Configurable: variant list with checkboxes and quantities %>
    <div class="space-y-2">
      <p class="text-sm text-gray-600 mb-2">Select variants to include:</p>

      <% (variants || product.subproducts).each do |variant| %>
        <% is_discontinued = discontinued_variants&.include?(variant) || variant.product_status == 'discontinued' %>

        <div data-variant-row
             data-variant-id="<%= variant.id %>"
             data-variant-code="<%= variant.info&.dig('variant_config')&.values&.first || variant.sku %>"
             class="flex items-center gap-3 p-2 rounded <%= is_discontinued ? 'bg-gray-100 opacity-60' : 'bg-gray-50' %>">

          <input type="checkbox"
                 data-variant-checkbox
                 data-action="change->bundle-composer#toggleVariant"
                 <%= 'disabled' if is_discontinued %>
                 <%= 'checked' unless is_discontinued %>
                 class="rounded border-gray-300 text-blue-600">

          <span class="flex-1 text-sm">
            <%= variant.name || variant.sku %>
            <% if is_discontinued %>
              <span class="text-red-500 text-xs ml-1">(discontinued)</span>
            <% end %>
          </span>

          <% unless is_discontinued %>
            <input type="number"
                   min="1"
                   max="99"
                   value="1"
                   data-variant-quantity
                   data-action="change->bundle-composer#quantityChanged"
                   class="w-16 rounded-md border-gray-300 text-sm">
          <% end %>

          <span class="text-xs text-gray-500 w-20 text-right">
            <%= variant.total_inventory || 0 %> in stock
          </span>
        </div>
      <% end %>
    </div>
  <% end %>
</div>
```

**Step 4: Create turbo stream responses**

```erb
<%# app/views/bundle_composer/search.turbo_stream.erb %>
<%= turbo_stream.update "search-results" do %>
  <%= render 'bundle_composer/search_results', products: @products %>
<% end %>
```

```erb
<%# app/views/bundle_composer/product_details.turbo_stream.erb %>
<%= turbo_stream.append "selected-products" do %>
  <%= render 'bundle_composer/product_card', product: @product, variants: @variants, discontinued_variants: @discontinued_variants %>
<% end %>
```

**Step 5: Commit**

```bash
git add app/views/bundle_composer/
git commit -m "feat: add bundle composer view partials"
```

---

### Task 13: Update product form to include bundle composer

**Files:**
- Modify: `app/views/products/_form.html.erb`

**Step 1: Update product form**

Add to the product form, after the product_type select field:

```erb
<%# Add this after the product_type field in app/views/products/_form.html.erb %>

<%# Product Type field - add data-action %>
<%= form.select :product_type,
    Product.product_types.keys.map { |t| [t.titleize, t] },
    {},
    { class: "...", data: { action: "change->bundle-composer#productTypeChanged" } } %>

<%# Bundle Composer - add after product_type field %>
<%= render 'bundle_composer/composer' %>
```

**Step 2: Commit**

```bash
git add app/views/products/_form.html.erb
git commit -m "feat: integrate bundle composer into product form"
```

---

## Phase 5: Testing

### Task 14: Add system specs for bundle creation flow

**Files:**
- Create: `spec/system/bundle_creation_spec.rb`

**Step 1: Write system specs**

```ruby
# spec/system/bundle_creation_spec.rb
require 'rails_helper'

RSpec.describe 'Bundle Creation', type: :system, js: true do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let!(:sellable1) { create(:product, :sellable, company: company, name: 'Test Shirt', sku: 'SHIRT001') }
  let!(:sellable2) { create(:product, :sellable, company: company, name: 'Test Pants', sku: 'PANTS001') }

  before do
    sign_in(user)
  end

  it 'creates a bundle with sellable products' do
    visit new_product_path

    fill_in 'Name', with: 'Summer Bundle'
    fill_in 'SKU', with: 'SUMBUNDLE'
    select 'Bundle', from: 'Product type'

    # Composer should appear
    expect(page).to have_css('#bundle-composer:not(.hidden)')

    # Search and add first product
    fill_in 'Search products', with: 'Shirt'
    expect(page).to have_content('Test Shirt')
    click_on 'Test Shirt'

    # Search and add second product
    fill_in 'Search products', with: 'Pants'
    expect(page).to have_content('Test Pants')
    click_on 'Test Pants'

    # Should show 2 products selected
    expect(page).to have_content('2 products')

    # Should show preview
    expect(page).to have_content('Will generate: 1 bundle variants')

    click_on 'Save'

    # Should redirect to bundle show page
    expect(page).to have_content('Bundle created with 1 variants')
    expect(page).to have_content('Summer Bundle')
  end

  context 'with configurable products' do
    let!(:configurable) { create(:product, :configurable, company: company, name: 'Size Shirt') }
    let!(:variant_s) { create(:product, :sellable, company: company, name: 'Size Shirt - S') }
    let!(:variant_m) { create(:product, :sellable, company: company, name: 'Size Shirt - M') }

    before do
      create(:product_configuration, superproduct: configurable, subproduct: variant_s,
             info: { 'variant_config' => { 'size' => 'S' } })
      create(:product_configuration, superproduct: configurable, subproduct: variant_m,
             info: { 'variant_config' => { 'size' => 'M' } })
    end

    it 'creates bundle with configurable product variants' do
      visit new_product_path

      fill_in 'Name', with: 'Sized Bundle'
      fill_in 'SKU', with: 'SIZEDBUNDLE'
      select 'Bundle', from: 'Product type'

      # Add configurable
      fill_in 'Search products', with: 'Size Shirt'
      find('[data-product-type="configurable"]', text: 'Size Shirt').click

      # Add sellable
      fill_in 'Search products', with: 'Pants'
      click_on 'Test Pants'

      # Should show 2 variants will be generated
      expect(page).to have_content('Will generate: 2 bundle variants')

      click_on 'Save'

      expect(page).to have_content('Bundle created with 2 variants')
    end
  end

  it 'shows validation errors' do
    visit new_product_path

    fill_in 'Name', with: 'Invalid Bundle'
    fill_in 'SKU', with: 'INVALID'
    select 'Bundle', from: 'Product type'

    # Add only one product
    fill_in 'Search products', with: 'Shirt'
    click_on 'Test Shirt'

    # Should show error
    expect(page).to have_content('Bundle must contain at least 2 products')
  end
end
```

**Step 2: Run system specs**

Run: `bin/rspec spec/system/bundle_creation_spec.rb`

**Step 3: Commit**

```bash
git add spec/system/bundle_creation_spec.rb
git commit -m "test: add system specs for bundle creation flow"
```

---

### Task 15: Final integration test and cleanup

**Step 1: Run full test suite**

Run: `bin/rspec`
Expected: All tests PASS

**Step 2: Run linter**

Run: `bin/rubocop -a`
Expected: No major issues

**Step 3: Manual testing checklist**

- [ ] Create bundle with 2 sellable products
- [ ] Create bundle with configurable + sellable
- [ ] Create bundle with 2 configurables (verify combinations)
- [ ] Verify validation limits work (3 configurable max)
- [ ] Verify 200 combination limit
- [ ] Edit bundle and regenerate
- [ ] Verify discontinued variants are excluded
- [ ] Verify inventory calculation works

**Step 4: Final commit**

```bash
git add .
git commit -m "feat: complete bundle product composer implementation"
```

---

## Summary

This implementation plan covers:

1. **Database & Models** (Tasks 1-4)
   - `bundle_templates` table
   - Product associations for bundle variants
   - BundleTemplate model

2. **Services** (Tasks 5-8)
   - BundleValidationService
   - BundleSkuGeneratorService
   - BundleVariantGeneratorService
   - BundleRegeneratorService

3. **Controllers** (Tasks 9-10)
   - BundleComposerController (search, preview)
   - ProductsController (create/update with generation)

4. **Frontend** (Tasks 11-13)
   - bundle_composer Stimulus controller
   - View partials for composer UI
   - Product form integration

5. **Testing** (Tasks 14-15)
   - System specs
   - Integration testing

**Future Phase (OUT OF SCOPE):**
   - Shopify sync for bundle variants
   - External system integration

**Total estimated tasks:** 15
**Each task follows TDD:** Write test → Verify fail → Implement → Verify pass → Commit
