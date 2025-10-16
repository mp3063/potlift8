# Phase 17-19: Implementation Required Before Tests Can Run

## ⚠️ IMPORTANT: Models and Migrations Need to be Created

The comprehensive test suite has been created (230+ tests), but **the actual models, migrations, and implementations do not exist yet**.

The tests are waiting for you to implement the features according to the Phase 17-19 specification.

---

## 🚧 Required Implementation Steps

### Step 1: Create Database Migrations

You need to create 4 migrations:

#### 1. CreateVersions (PaperTrail)
```bash
bin/rails generate paper_trail:install
```

#### 2. CreateCustomerGroups
```bash
bin/rails generate migration CreateCustomerGroups
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_customer_groups.rb
class CreateCustomerGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :customer_groups do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.integer :discount_percent

      t.timestamps
    end

    add_index :customer_groups, [:company_id, :name], unique: true
    add_index :customer_groups, [:company_id, :code], unique: true
  end
end
```

#### 3. CreatePrices
```bash
bin/rails generate migration CreatePrices
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_prices.rb
class CreatePrices < ActiveRecord::Migration[8.0]
  def change
    create_table :prices do |t|
      t.references :product, null: false, foreign_key: true
      t.references :customer_group, null: true, foreign_key: true
      t.integer :value, null: false
      t.string :currency, null: false, default: 'EUR'
      t.string :price_type, null: false
      t.datetime :valid_from
      t.datetime :valid_to

      t.timestamps
    end

    add_index :prices, [:product_id, :customer_group_id, :price_type],
              unique: true,
              where: 'customer_group_id IS NOT NULL',
              name: 'index_prices_on_product_group_type'
  end
end
```

#### 4. CreateTranslations
```bash
bin/rails generate migration CreateTranslations
```

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_translations.rb
class CreateTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :translations do |t|
      t.references :translatable, polymorphic: true, null: false
      t.string :locale, null: false
      t.string :key, null: false
      t.text :value

      t.timestamps
    end

    add_index :translations, [:translatable_type, :translatable_id, :locale, :key],
              unique: true,
              name: 'index_translations_unique'
  end
end
```

**Then run migrations:**
```bash
bin/rails db:migrate
```

---

### Step 2: Create Models

#### 1. Price Model
```ruby
# app/models/price.rb
class Price < ApplicationRecord
  belongs_to :product
  belongs_to :customer_group, optional: true

  validates :value, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true
  validates :price_type, presence: true, inclusion: { in: PRICE_TYPES }
  validates :customer_group_id, uniqueness: { scope: [:product_id, :price_type] }, allow_nil: true

  PRICE_TYPES = ['base', 'special', 'group'].freeze

  scope :base_prices, -> { where(price_type: 'base', customer_group_id: nil) }
  scope :special_prices, -> { where(price_type: 'special') }
  scope :group_prices, -> { where(price_type: 'group') }

  validate :valid_date_range, if: -> { price_type == 'special' }

  def active?
    return true unless price_type == 'special'

    now = Time.current
    (valid_from.nil? || valid_from <= now) && (valid_to.nil? || valid_to >= now)
  end

  private

  def valid_date_range
    return if valid_from.blank? || valid_to.blank?

    if valid_from >= valid_to
      errors.add(:valid_from, "must be before valid_to")
    end
  end
end
```

#### 2. CustomerGroup Model
```ruby
# app/models/customer_group.rb
class CustomerGroup < ApplicationRecord
  belongs_to :company
  has_many :prices, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :company_id }
  validates :code, presence: true, uniqueness: { scope: :company_id }

  def discount_percentage
    discount_percent || 0
  end
end
```

#### 3. Translation Model
```ruby
# app/models/translation.rb
class Translation < ApplicationRecord
  belongs_to :translatable, polymorphic: true

  validates :locale, presence: true
  validates :key, presence: true
  validates :locale, uniqueness: { scope: [:translatable_type, :translatable_id, :key] }

  SUPPORTED_LOCALES = ['en', 'es', 'fr', 'de', 'it', 'pt'].freeze

  validates :locale, inclusion: { in: SUPPORTED_LOCALES }

  scope :for_locale, ->(locale) { where(locale: locale) }
end
```

#### 4. Update Product Model
```ruby
# app/models/product.rb
class Product < ApplicationRecord
  # Add PaperTrail
  has_paper_trail on: [:update, :destroy],
                  ignore: [:updated_at],
                  meta: {
                    company_id: :company_id,
                    user_id: -> (product) { PaperTrail.request.whodunnit }
                  }

  # Add translations association
  has_many :translations, as: :translatable, dependent: :destroy

  # Add prices association
  has_many :prices, dependent: :destroy

  # Translation methods
  def translated_name(locale = I18n.locale)
    translations.find_by(locale: locale, key: 'name')&.value || name
  end

  def translated_description(locale = I18n.locale)
    translations.find_by(locale: locale, key: 'description')&.value || description
  end
end
```

---

### Step 3: Create Services

#### 1. ProductImportService
Create the service as specified in `.claude/implementation_phases_tailwind/phase_17_19_import_history_pricing.md`

```bash
touch app/services/product_import_service.rb
```

See implementation spec in Phase 17-19 docs.

#### 2. ProductExportService
This already exists in the codebase.

---

### Step 4: Create Jobs

#### 1. ProductImportJob
```bash
bin/rails generate job ProductImport
```

See implementation spec in Phase 17-19 docs.

---

### Step 5: Create Controllers

#### 1. ImportsController
```bash
bin/rails generate controller Imports new create progress
```

#### 2. PricesController
```bash
bin/rails generate controller Prices index new create edit update destroy
```

#### 3. ProductVersionsController
```bash
bin/rails generate controller ProductVersions index show compare revert
```

---

### Step 6: Create Components

#### 1. DiffViewComponent
```bash
bin/rails generate component DiffView old_value new_value attribute_name
```

#### 2. TranslationsFormComponent
```bash
bin/rails generate component TranslationsForm translatable
```

---

### Step 7: Configure PaperTrail

```ruby
# config/initializers/paper_trail.rb
PaperTrail.config.track_associations = false
PaperTrail.config.version_limit = 50 # Keep last 50 versions per record
```

---

### Step 8: Add Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Imports
  resources :imports, only: [:new, :create] do
    member do
      get :progress
    end
  end

  # Products with nested resources
  resources :products do
    # Prices
    resources :prices

    # Version history
    resources :versions, controller: 'product_versions', only: [:index, :show] do
      collection do
        get :compare
      end
      member do
        post :revert
      end
    end
  end

  # Customer Groups
  resources :customer_groups
end
```

---

## ✅ Once Implementation is Complete

After implementing all the above, you can run the tests:

```bash
# Run migrations
bin/rails db:migrate
bin/rails db:test:prepare

# Run tests
bin/test spec/models/{price,customer_group,translation}_spec.rb
bin/test spec/services/product_import_service_spec.rb
bin/test spec/jobs/product_import_job_spec.rb

# Expected: 230+ passing tests
```

---

## 📋 Implementation Checklist

- [ ] Run `bin/rails generate paper_trail:install`
- [ ] Create CreateCustomerGroups migration
- [ ] Create CreatePrices migration
- [ ] Create CreateTranslations migration
- [ ] Run `bin/rails db:migrate`
- [ ] Create Price model (`app/models/price.rb`)
- [ ] Create CustomerGroup model (`app/models/customer_group.rb`)
- [ ] Create Translation model (`app/models/translation.rb`)
- [ ] Update Product model (add PaperTrail + translations)
- [ ] Create ProductImportService (`app/services/product_import_service.rb`)
- [ ] Create ProductImportJob (`app/jobs/product_import_job.rb`)
- [ ] Create ImportsController (`app/controllers/imports_controller.rb`)
- [ ] Create PricesController (`app/controllers/prices_controller.rb`)
- [ ] Create ProductVersionsController (`app/controllers/product_versions_controller.rb`)
- [ ] Create DiffViewComponent (`app/components/diff_view_component.rb`)
- [ ] Create TranslationsFormComponent (`app/components/translations_form_component.rb`)
- [ ] Configure PaperTrail initializer
- [ ] Add routes
- [ ] Run tests to verify implementation
- [ ] Fix any failing tests
- [ ] Generate coverage report

---

## 📚 Reference Documents

All implementation details are in:
- `.claude/implementation_phases_tailwind/phase_17_19_import_history_pricing.md`
- `spec/TEST_COVERAGE_PHASE_17_19.md`
- `spec/PHASE_17_19_TEST_SUITE_SUMMARY.md`

The test specs provide **executable documentation** of how each component should behave.

---

## 🎯 Current Status

- ✅ Test Suite Created: 230+ tests
- ✅ Factories Created: 3 factories
- ✅ Documentation Created: Comprehensive specs
- ⚠️ Models: **NOT CREATED YET**
- ⚠️ Migrations: **NOT CREATED YET**
- ⚠️ Services: **PARTIALLY CREATED** (export exists)
- ⚠️ Jobs: **NOT CREATED YET**
- ⚠️ Controllers: **NOT CREATED YET**
- ⚠️ Components: **NOT CREATED YET**

**You must complete the implementation before the tests can run.**
