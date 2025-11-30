# Bundle Product Composer Design

**Date:** 2025-11-30
**Status:** Approved
**Author:** Claude + User collaborative brainstorm

## Overview

Redesign bundle product creation to support automatic generation of all variant combinations when bundles contain configurable products. This enables Shopify-compatible bundle products where each variant combination is a distinct SKU.

## Problem Statement

Current bundle creation acts like sellable product creation - a two-step disconnected process. Bundles should allow composing multiple configurable and sellable products with automatic variant combination generation.

## Design Goals

1. Single-page bundle composition experience
2. Automatic generation of all variant combinations
3. Per-variant quantity configuration
4. Shopify-compatible output (individual SKUs per combination)
5. Virtual inventory calculation from components

---

## Core Concepts

### Bundle Composition Example

```
Bundle: "Summer Starter Kit" (SKU: SUMKIT)

Components:
- T-Shirt (configurable: S, M, L) - varying quantities per size
- Hoodie (configurable: S, M, L) - qty 1 each
- Sticker Pack (sellable) - qty 3

Generated Variants: 9 (3 x 3)
- SUMKIT-S-S: 2x T-Shirt S + 1x Hoodie S + 3x Stickers
- SUMKIT-S-M: 2x T-Shirt S + 1x Hoodie M + 3x Stickers
- SUMKIT-S-L: 2x T-Shirt S + 1x Hoodie L + 3x Stickers
- SUMKIT-M-S: 1x T-Shirt M + 1x Hoodie S + 3x Stickers
- ... etc
```

### Inventory Model: Virtual (Calculated)

Bundle variants have no physical inventory. Availability is calculated from component stock:

```
Bundle "SUMKIT-S-S" availability:
  T-Shirt S:    50 in stock / 2 needed = 25 possible
  Hoodie S:     20 in stock / 1 needed = 20 possible
  Stickers:     250 in stock / 3 needed = 83 possible

  Bundle availability = min(25, 20, 83) = 20 bundles
```

---

## Limits & Constraints

| Constraint | Limit | Reasoning |
|------------|-------|-----------|
| Configurable products | 3 max | Prevents combinatorial explosion |
| Sellable products | 10 max | Keeps bundles manageable |
| Total products | 12 max | 3 configurable + 9 sellable |
| Generated variants | 200 max | Hard limit with error |
| Quantity per component | 1-99 | Reasonable range |
| Minimum products | 2 | Bundle must have 2+ items |

### Product Status Rules

| Condition | Behavior |
|-----------|----------|
| 0 inventory | Include (stock can be replenished) |
| Variant discontinued | Exclude from generation, show warning |
| Product discontinued | Exclude from picker entirely |
| All variants discontinued | Block addition with error |

---

## Data Model

### New Table: bundle_templates

Stores the bundle "recipe" for regeneration.

```ruby
create_table :bundle_templates do |t|
  t.references :product, null: false, foreign_key: true
  t.references :company, null: false, foreign_key: true
  t.jsonb :configuration, default: {}
  t.integer :generated_variants_count, default: 0
  t.datetime :last_generated_at
  t.timestamps
end
```

### Configuration JSONB Structure

```json
{
  "components": [
    {
      "product_id": 123,
      "product_type": "configurable",
      "variants": [
        { "variant_id": 456, "included": true, "quantity": 2 },
        { "variant_id": 457, "included": true, "quantity": 1 },
        { "variant_id": 458, "included": false, "quantity": 0 }
      ]
    },
    {
      "product_id": 789,
      "product_type": "sellable",
      "quantity": 3
    }
  ]
}
```

### Products Table Changes

```ruby
add_reference :products, :parent_bundle, foreign_key: { to_table: :products }, null: true
add_column :products, :bundle_variant, :boolean, default: false
```

### Model Associations

```ruby
class Product < ApplicationRecord
  has_one :bundle_template, dependent: :destroy

  has_many :bundle_variants,
           class_name: 'Product',
           foreign_key: 'parent_bundle_id',
           dependent: :destroy

  belongs_to :parent_bundle,
             class_name: 'Product',
             optional: true

  scope :bundle_variants, -> { where(bundle_variant: true) }
  scope :not_bundle_variants, -> { where(bundle_variant: false) }
end
```

---

## UI Design

### Bundle Composer (appears when product_type = bundle)

```
┌─────────────────────────────────────────────────────────────────┐
│ 📦 BUNDLE COMPOSER                                              │
│─────────────────────────────────────────────────────────────────│
│                                                                 │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ 🔍 Search products...                            [Search]   │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│ SELECTED PRODUCTS (2 configurable, 1 sellable)                  │
│                                                                 │
│ ┌─ T-Shirt (configurable) ─────────────────────── [Remove] ──┐  │
│ │  ☑ Small    Qty: [2]    (48 in stock)                      │  │
│ │  ☑ Medium   Qty: [1]    (35 in stock)                      │  │
│ │  ☑ Large    Qty: [1]    (22 in stock)                      │  │
│ │  ☐ XL       ---         (0 in stock) ⚠️ discontinued       │  │
│ └────────────────────────────────────────────────────────────┘  │
│                                                                 │
│ ┌─ Hoodie (configurable) ──────────────────────── [Remove] ──┐  │
│ │  ☑ Small    Qty: [1]    (20 in stock)                      │  │
│ │  ☑ Medium   Qty: [1]    (15 in stock)                      │  │
│ │  ☑ Large    Qty: [1]    (18 in stock)                      │  │
│ └────────────────────────────────────────────────────────────┘  │
│                                                                 │
│ ┌─ Sticker Pack (sellable) ────────────────────── [Remove] ──┐  │
│ │  Quantity: [3]          (250 in stock)                     │  │
│ └────────────────────────────────────────────────────────────┘  │
│                                                                 │
│─────────────────────────────────────────────────────────────────│
│ 📊 GENERATION PREVIEW                                           │
│                                                                 │
│ Will generate: 9 bundle variants (3 × 3)                        │
│ Estimated availability: 7 - 20 bundles per variant              │
│                                                                 │
│ [Show all combinations ▼]                                       │
│                                                                 │
│  SKU              │ Components              │ Est. Available    │
│  SUMKIT-S-S       │ 2×TShirt-S, 1×Hood-S   │ 10 bundles        │
│  SUMKIT-S-M       │ 2×TShirt-S, 1×Hood-M   │ 15 bundles        │
│  SUMKIT-S-L       │ ...                    │ ...               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Validation Errors Display

```
┌─────────────────────────────────────────────────────────────────┐
│ ❌ VALIDATION ERRORS                                            │
│ • Maximum 3 configurable products allowed (you have 4)          │
│ • This configuration would generate 250 variants (max: 200)     │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ ⚠️ WARNINGS                                                      │
│ • T-Shirt: XL variant is discontinued and will be skipped       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Service Layer

### BundleVariantGeneratorService

Main service for generating variant combinations.

```ruby
class BundleVariantGeneratorService
  Result = Struct.new(:success?, :variants, :errors, keyword_init: true)

  def initialize(bundle_product, configuration)
    @bundle = bundle_product
    @config = configuration
    @company = bundle_product.company
  end

  def call
    return failure("Not a bundle") unless @bundle.product_type_bundle?
    return failure("Empty config") if @config["components"].blank?

    validate_limits!
    return failure(@errors.join(", ")) if @errors.any?

    combinations = generate_combinations
    return failure("Exceeds 200 limit") if combinations.size > 200

    variants = create_variants(combinations)
    update_bundle_template(variants)

    Result.new(success?: true, variants: variants, errors: [])
  end
end
```

### BundleValidationService

Validates configuration before generation.

```ruby
class BundleValidationService
  LIMITS = {
    max_configurables: 3,
    max_sellables: 10,
    max_total_products: 12,
    max_combinations: 200,
    max_quantity: 99,
    min_quantity: 1
  }.freeze

  def valid?
    validate!
    @errors.empty?
  end

  # Validates: counts, existence, availability, quantities,
  # combinations, duplicates
end
```

### BundleRegeneratorService

Handles editing/regenerating existing bundles.

```ruby
class BundleRegeneratorService
  def call
    validate_can_regenerate!  # Check no pending orders

    ActiveRecord::Base.transaction do
      deleted = soft_delete_old_variants
      result = generate_new_variants
      schedule_sync_jobs(deleted, result.variants)
    end
  end
end
```

### Service Summary

| Service | Responsibility |
|---------|----------------|
| `BundleVariantGeneratorService` | Generate variant combinations |
| `BundleSkuGeneratorService` | Generate unique SKUs |
| `BundleValidationService` | Validate configuration |
| `BundleRegeneratorService` | Delete old + generate new variants |
| `BundleInventoryCalculator` | Calculate availability (existing) |

---

## Controller Layer

### BundleComposerController

New controller for AJAX operations.

```ruby
class BundleComposerController < ApplicationController
  # GET /bundle_composer/search?q=shirt
  def search
    # Search products for picker
  end

  # GET /bundle_composer/product/:id
  def product_details
    # Get product with variants for display
  end

  # POST /bundle_composer/preview
  def preview
    # Validate and preview combinations
  end
end
```

### ProductsController Changes

```ruby
def create
  @product.save!

  if @product.product_type_bundle? && bundle_config_present?
    result = BundleVariantGeneratorService.new(@product, config).call
    raise BundleGenerationError unless result.success?
  end
end

def update
  @product.update!(product_params)

  if should_regenerate?
    result = BundleRegeneratorService.new(@product, config).call
    raise BundleRegenerationError unless result.success?
  end
end
```

---

## Stimulus Controller

### bundle_composer_controller.js

```javascript
export default class extends Controller {
  static targets = [
    "composer", "searchInput", "searchResults",
    "selectedProducts", "preview", "configuration"
  ]

  static values = {
    maxConfigurables: { type: Number, default: 3 },
    maxSellables: { type: Number, default: 10 },
    maxCombinations: { type: Number, default: 200 }
  }

  // Key methods:
  productTypeChanged(event)  // Show/hide composer
  search()                   // Search products (debounced)
  addProduct(event)          // Add to selection
  removeProduct(event)       // Remove from selection
  toggleVariant(event)       // Include/exclude variant
  quantityChanged(event)     // Update quantity
  updatePreview()            // Recalculate preview (debounced)
  buildConfiguration()       // Build JSON for submission
}
```

---

## Routes

```ruby
# config/routes.rb

resources :products do
  resources :bundle_products, only: [:index, :create, :update, :destroy]
end

namespace :bundle_composer do
  get :search
  get 'product/:id', action: :product_details
  post :preview
end
```

---

## Validation Rules Summary

| Rule | Type | Message |
|------|------|---------|
| Max 3 configurables | Error | "Maximum 3 configurable products allowed" |
| Max 10 sellables | Error | "Maximum 10 sellable products allowed" |
| Max 12 total | Error | "Maximum 12 total products allowed" |
| Min 2 products | Error | "Bundle must contain at least 2 products" |
| Max 200 combinations | Error | "Would generate X variants (max: 200)" |
| Quantity 1-99 | Error | "Quantity must be between 1 and 99" |
| No duplicates | Error | "Duplicate products not allowed" |
| Product discontinued | Error | "X is discontinued" |
| Variant discontinued | Warning | "X will be skipped" |
| High count (100+) | Warning | "Will generate X variants" |

---

## Edit & Regeneration Flow

1. User edits bundle configuration
2. System shows comparison: "Current: 9 variants → New: 12 variants"
3. User clicks "Save & Regenerate"
4. Confirmation: "Delete 9 existing, create 12 new?"
5. Service soft-deletes old variants
6. Service generates new variants
7. Shopify sync jobs queued

### Regeneration Blocked When

- Variants have pending orders
- Shows error: "Cannot regenerate: X variants have pending orders"

---

## Implementation Tasks

### Phase 1: Database & Models
- [ ] Create migration for `bundle_templates` table
- [ ] Add `parent_bundle_id` and `bundle_variant` to products
- [ ] Create `BundleTemplate` model
- [ ] Update `Product` model associations and scopes

### Phase 2: Services
- [ ] Create `BundleValidationService`
- [ ] Create `BundleSkuGeneratorService`
- [ ] Create `BundleVariantGeneratorService`
- [ ] Create `BundleRegeneratorService`
- [ ] Update `BundleInventoryCalculator` if needed

### Phase 3: Controllers
- [ ] Create `BundleComposerController`
- [ ] Update `ProductsController#create` for bundle generation
- [ ] Update `ProductsController#update` for regeneration

### Phase 4: Frontend
- [ ] Create `bundle_composer_controller.js` Stimulus controller
- [ ] Create bundle composer partial/ViewComponent
- [ ] Create product card partial for selected products
- [ ] Create search results partial
- [ ] Create preview section partial
- [ ] Update product form to show composer when bundle selected

### Phase 5: Views & UX
- [ ] Bundle composer UI on product new/edit
- [ ] Validation error display
- [ ] Warning display for discontinued variants
- [ ] Generation preview with combination list
- [ ] Regeneration confirmation modal
- [ ] Bundle variants list on product show page

### Phase 6: Testing
- [ ] Model specs for BundleTemplate
- [ ] Service specs for all new services
- [ ] Controller specs for BundleComposerController
- [ ] Request specs for bundle creation flow
- [ ] System specs for full UI flow

### Phase 7: Integration
- [ ] Update Shopify sync to handle bundle variants
- [ ] Update inventory sync for virtual inventory
- [ ] Add shared component warnings

---

## SKU Generation Strategy

Base bundle SKU + variant dimension codes:

```
Bundle SKU: SUMKIT
T-Shirt variants: S, M, L (code from ConfigurationValue)
Hoodie variants: S, M, L

Generated SKUs:
- SUMKIT-S-S (T-Shirt S + Hoodie S)
- SUMKIT-S-M (T-Shirt S + Hoodie M)
- SUMKIT-M-L (T-Shirt M + Hoodie L)
```

Sellable products don't affect SKU - tracked via ProductConfiguration quantity.

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| Inventory model? | Virtual (calculated from components) |
| Per-variant quantities? | Yes, each variant can have different qty |
| Exclude variants? | Yes, checkbox to include/exclude |
| Discontinued handling? | Exclude from generation, show warning |
| Max configurables? | 3 |
| Max combinations? | 200 (hard limit) |

---

## Files to Create/Modify

### New Files
- `db/migrate/XXXXXX_create_bundle_templates.rb`
- `db/migrate/XXXXXX_add_bundle_fields_to_products.rb`
- `app/models/bundle_template.rb`
- `app/services/bundle_validation_service.rb`
- `app/services/bundle_sku_generator_service.rb`
- `app/services/bundle_variant_generator_service.rb`
- `app/services/bundle_regenerator_service.rb`
- `app/controllers/bundle_composer_controller.rb`
- `app/javascript/controllers/bundle_composer_controller.js`
- `app/views/bundle_composer/_composer.html.erb`
- `app/views/bundle_composer/_product_card.html.erb`
- `app/views/bundle_composer/_search_results.html.erb`
- `app/views/bundle_composer/_preview.html.erb`
- `spec/models/bundle_template_spec.rb`
- `spec/services/bundle_variant_generator_service_spec.rb`
- `spec/services/bundle_validation_service_spec.rb`
- `spec/controllers/bundle_composer_controller_spec.rb`

### Modified Files
- `app/models/product.rb` - Add associations
- `app/controllers/products_controller.rb` - Add bundle logic
- `app/views/products/_form.html.erb` - Include composer
- `config/routes.rb` - Add bundle_composer routes
