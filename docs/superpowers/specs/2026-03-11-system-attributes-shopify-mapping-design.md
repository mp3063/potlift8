# System Attributes & Shopify Metafield Mapping

**Date:** 2026-03-11
**Status:** Draft
**Scope:** Potlift8 (primary), Shopify8 (sync changes)

## Problem

Potlift8's product attribute system has three issues:

1. **No protected system attributes.** Essential attributes (price, ean, weight, etc.) are user-created with no protection. Users can rename, retype, or delete them, breaking Shopify sync silently.
2. **No Shopify mapping for custom attributes.** Custom attributes (e.g., thc_percentage, cbd_percentage) have no path to Shopify. They exist only in Potlift8.
3. **Cannabis-specific seed data.** Current seeds include industry-specific attributes (thc, cbd, strain, terpene, package_size) as defaults, which don't belong as universal system attributes.

### Historical Context

The previous system (pot3 + Shopify3) had zero system attributes — everything was company-created. Shopify3 hardcoded expectations for these attribute codes: `price`, `ean`, `secondary_sku`, `brand`, `purchase_price`, `description_html`, `description_md`, `weight`, `special_price`, `vat_group`, `detailed_description_html`, `sizechart`. If a company didn't create those exact codes, sync would silently produce empty/broken Shopify fields.

## Design

### 1. System Attribute Registry

A `SystemAttributes` concern on `ProductAttribute` defines a `SYSTEM_ATTRIBUTES` constant — the single source of truth for all essential attributes.

```ruby
# app/models/concerns/system_attributes.rb
module SystemAttributes
  extend ActiveSupport::Concern

  SYSTEM_ATTRIBUTE_GROUPS = {
    pricing:     { name: "Pricing", position: 1 },
    identifiers: { name: "Identifiers", position: 2 },
    details:     { name: "Details", position: 3 },
    physical:    { name: "Physical", position: 4 }
  }.freeze

  SYSTEM_ATTRIBUTES = {
    # --- Pricing ---
    price: {
      pa_type: :patype_number,
      view_format: :view_format_price,
      mandatory: true,
      rules: { positive: true, not_null: true },
      group: :pricing,
      shopify_field: :price,
      scope: :product_and_catalog_scope,
      name: "Price",
      description: "Product selling price in cents"
    },
    purchase_price: {
      pa_type: :patype_number,
      view_format: :view_format_price,
      group: :pricing,
      shopify_field: :cost,
      scope: :product_scope,
      name: "Purchase Price",
      description: "Supplier/wholesale cost in cents"
    },
    special_price: {
      pa_type: :patype_custom,
      view_format: :view_format_special_price,
      group: :pricing,
      custom_handler: :special_price,  # Requires custom logic (date-range check), not a direct field mapping
      scope: :product_and_catalog_scope,
      name: "Special Price",
      description: "Sale price with date range (amount, from, until). Maps to Shopify compareAtPrice via custom handler."
    },
    vat_group: {
      pa_type: :patype_select,
      view_format: :view_format_selectable,
      group: :pricing,
      custom_handler: :vat_tag,  # Maps to Shopify tags (e.g., "vat14"), not a field or metafield
      scope: :product_scope,
      name: "VAT Group",
      description: "Tax classification for the product. Maps to Shopify tags via custom handler.",
      options: ["standard", "reduced 9", "reduced 14", "zero"]
    },

    # --- Identifiers ---
    ean: {
      pa_type: :patype_text,
      view_format: :view_format_ean,
      group: :identifiers,
      shopify_field: :barcode,
      scope: :product_scope,
      name: "EAN / Barcode",
      description: "EAN, UPC, or ISBN barcode"
    },
    secondary_sku: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :identifiers,
      custom_handler: :barcode_fallback,  # Not a Shopify field — used as fallback when EAN is empty
      scope: :product_scope,
      name: "Secondary SKU",
      description: "Alternative identifier, used as barcode fallback when EAN is empty"
    },

    # --- Details ---
    description_html: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      mandatory: true,
      group: :details,
      shopify_field: :descriptionHtml,
      scope: :product_and_catalog_scope,
      name: "Description",
      description: "Main product description (rich text/HTML). Code matches pot3 convention."
    },
    short_description: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :details,
      scope: :product_and_catalog_scope,
      name: "Short Description",
      description: "Brief product summary for listings. No Shopify mapping by default — users can opt-in via metafield sync if needed."
    },
    detailed_description: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      group: :details,
      scope: :product_and_catalog_scope,
      name: "Detailed Description",
      description: "Extended product details, synced as Shopify metafield",
      shopify_metafield: {
        namespace: "global",
        key: "detailed_description_html",
        type: "multi_line_text_field"
      }
    },
    brand: {
      pa_type: :patype_text,
      view_format: :view_format_general,
      group: :details,
      shopify_field: :vendor,
      scope: :product_scope,
      name: "Brand",
      description: "Product brand/manufacturer"
    },

    # --- Physical ---
    weight: {
      pa_type: :patype_number,
      view_format: :view_format_weight,
      group: :physical,
      shopify_field: :weight,
      shopify_weight_unit: "GRAMS",  # Shopify requires weightUnit alongside weight
      scope: :product_scope,
      name: "Weight",
      description: "Product weight in grams for shipping calculations"
    },
    sizechart: {
      pa_type: :patype_rich_text,
      view_format: :view_format_html,
      group: :physical,
      scope: :product_scope,
      name: "Size Chart",
      description: "Size chart information, synced as Shopify metafield",
      shopify_metafield: {
        namespace: "global",
        key: "sizechart",
        type: "multi_line_text_field"
      }
    }
  }.freeze
end
```

**Total: 12 system attributes** across 4 groups.

### 2. Schema Changes

#### Migration: Add columns to `product_attributes`

```ruby
add_column :product_attributes, :system, :boolean, default: false, null: false
add_column :product_attributes, :shopify_metafield_namespace, :string
add_column :product_attributes, :shopify_metafield_key, :string
add_column :product_attributes, :shopify_metafield_type, :string

add_index :product_attributes, [:company_id, :system]
```

**Column purposes:**

| Column | Used by | Purpose |
|--------|---------|---------|
| `system` | System + custom | `true` = protected attribute, code/type/format immutable |
| `shopify_metafield_namespace` | System + custom | Shopify metafield namespace (e.g., `custom`, `global`) |
| `shopify_metafield_key` | System + custom | Shopify metafield key (e.g., `thc_percentage`) |
| `shopify_metafield_type` | System + custom | Shopify metafield value type (e.g., `number_decimal`) |

For system attributes with `shopify_field` (native Shopify mapping like price, barcode), the metafield columns stay null — the mapping is handled by the registry constant.

For system attributes with `shopify_metafield` (like detailed_description, sizechart), the metafield columns are populated from the registry.

For custom attributes, users populate the metafield columns via the UI to opt-in to Shopify sync.

### 3. Model Validations (Partial Locking)

When `system: true`, the following fields become immutable after creation:

- `code` — prevents breaking Shopify field mapping
- `pa_type` — prevents type mismatch with Shopify
- `view_format` — tied to pa_type behavior

What users CAN change on system attributes:
- `name` — display name customization
- `description` — documentation
- `attribute_group_id` — organizational grouping
- `attribute_position` — ordering within group
- `mandatory` — whether it's required on products
- `default_value` — default value for new products

System attributes cannot be destroyed.

```ruby
# ProductAttribute model additions
validate :immutable_system_fields, if: :system?

def immutable_system_fields
  if persisted?
    errors.add(:code, "cannot be changed for system attributes") if code_changed?
    errors.add(:pa_type, "cannot be changed for system attributes") if pa_type_changed?
    errors.add(:view_format, "cannot be changed for system attributes") if view_format_changed?
  end
end

before_destroy :prevent_system_destroy

def prevent_system_destroy
  if system?
    errors.add(:base, "System attributes cannot be deleted")
    throw(:abort)
  end
end
```

### 4. Custom Attribute Shopify Opt-in

Non-system attributes get an optional "Shopify Sync" section in the edit form:

- **Sync to Shopify** — checkbox toggle (off by default)
- When enabled:
  - **Namespace** — defaults to `custom`
  - **Key** — auto-populated from attribute code
  - **Metafield type** — auto-selected from pa_type:

| pa_type | Default Shopify metafield type |
|---------|-------------------------------|
| patype_text | `single_line_text_field` |
| patype_number | `number_decimal` |
| patype_boolean | `boolean` |
| patype_select | `single_line_text_field` |
| patype_multiselect | `list.single_line_text_field` |
| patype_date | `date` |
| patype_rich_text | `multi_line_text_field` |
| patype_custom | `json` |

Users can override the metafield type if needed. Clearing the toggle nullifies all three metafield columns.

### 5. Sync Payload Changes (Potlift8 → Shopify8)

#### Current payload format
```json
{
  "attributes": {
    "values": { "price": "1999", "ean": "123456" },
    "localized": {}
  }
}
```

#### New payload format
```json
{
  "attributes": {
    "values": {
      "price": {
        "value": "1999",
        "shopify_field": "price",
        "system": true
      },
      "ean": {
        "value": "123456",
        "shopify_field": "barcode",
        "system": true
      },
      "thc_percentage": {
        "value": "18.5",
        "shopify_metafield": {
          "namespace": "custom",
          "key": "thc_percentage",
          "type": "number_decimal"
        }
      },
      "detailed_description": {
        "value": "<p>Extended details...</p>",
        "shopify_metafield": {
          "namespace": "global",
          "key": "detailed_description_html",
          "type": "multi_line_text_field"
        },
        "system": true
      }
    },
    "localized": {}
  }
}
```

Each attribute value includes its mapping instructions. Attributes with no `shopify_field` or `shopify_metafield` are still sent (for Potlift8 record-keeping) but Shopify8 ignores them.

#### ProductSyncService changes

The current `build_attributes_payload` calls `product.attribute_values_hash` which returns a flat `{ code => value }` hash. This must be rewritten to iterate over `product_attribute_values` directly, so we can access the `ProductAttribute` record for mapping info.

```ruby
# Replaces the current build_attributes_payload method
def build_attributes_payload
  values = {}
  localized = {}

  # Use catalog overrides when available, fall back to product values
  attribute_values = if @catalog_item
    @catalog_item.effective_product_attribute_values
  else
    @product.product_attribute_values.includes(:product_attribute)
  end

  attribute_values.each do |pav|
    pa = pav.product_attribute
    code = pa.code
    values[code] = build_attribute_entry(pa, pav.value.presence || pav.info["value"])
    localized[code] = pav.info["localized_value"] if pav.localized_values?
  end

  { values: values, localized: localized }
end

def build_attribute_entry(product_attribute, value)
  entry = { value: value }
  code_sym = product_attribute.code.to_sym
  registry = SystemAttributes::SYSTEM_ATTRIBUTES[code_sym]

  # Native Shopify field mapping (from registry constant)
  if registry&.dig(:shopify_field)
    entry[:shopify_field] = registry[:shopify_field].to_s
  end

  # Custom handler mapping (special_price, vat_tag, barcode_fallback)
  if registry&.dig(:custom_handler)
    entry[:custom_handler] = registry[:custom_handler].to_s
  end

  # Metafield mapping (from registry or user-configured columns)
  if product_attribute.shopify_metafield_namespace.present?
    entry[:shopify_metafield] = {
      namespace: product_attribute.shopify_metafield_namespace,
      key: product_attribute.shopify_metafield_key,
      type: product_attribute.shopify_metafield_type
    }
  end

  entry[:system] = true if product_attribute.system?
  entry
end
```

**Note:** `CatalogItem#effective_product_attribute_values` is a new method that returns the merged set of ProductAttributeValue records with catalog overrides applied, preserving the `product_attribute` association for mapping lookup. This replaces the flat `effective_attribute_values_hash`.

#### Subproduct (variant) attribute enrichment

The `build_subproducts_payload` must also use `build_attribute_entry` for variant-level attributes (price, ean per variant). The same pattern applies:

```ruby
def build_subproduct_attributes(subproduct)
  values = {}
  subproduct.product_attribute_values.includes(:product_attribute).each do |pav|
    pa = pav.product_attribute
    values[pa.code] = build_attribute_entry(pa, pav.value.presence || pav.info["value"])
  end
  values
end
```

### 6. Shopify8 Sync Changes

#### ProductSchema::Build

Replace hardcoded `attribute_by_code` calls with mapping-driven logic:

```ruby
def price_value(attributes)
  find_by_shopify_field(attributes, "price")&.dig("value")
end

def barcode_value(attributes)
  find_by_shopify_field(attributes, "barcode")&.dig("value") ||
    find_by_custom_handler(attributes, "barcode_fallback")&.dig("value")
end

def vendor_value(attributes)
  find_by_shopify_field(attributes, "vendor")&.dig("value")
end

# Generic metafield builder
def build_metafields_from_attributes(attributes)
  attributes.select { |_code, attr| attr["shopify_metafield"].present? }
            .map do |_code, attr|
              meta = attr["shopify_metafield"]
              {
                namespace: meta["namespace"],
                key: meta["key"],
                value: attr["value"].to_s,
                type: meta["type"]
              }
            end
end
```

**Special cases that remain hardcoded:**
- `special_price` — date-range logic (check from/until before setting compareAtPrice)
- `vat_group` — maps to Shopify tags, not a field or metafield
- `secondary_sku` — barcode fallback logic (try ean first)

Everything else becomes generic mapping.

### 7. Seeds & Backfill

#### Seeds overhaul

Remove all cannabis-specific attributes. Replace with:

```ruby
# db/seeds.rb (attribute section)
Company.find_each do |company|
  ProductAttribute.ensure_system_attributes!(company)
end
```

#### `ensure_system_attributes!` class method

```ruby
def self.ensure_system_attributes!(company)
  # Create attribute groups
  SYSTEM_ATTRIBUTE_GROUPS.each do |code, config|
    company.attribute_groups.find_or_create_by!(code: code.to_s) do |group|
      group.name = config[:name]
      group.position = config[:position]
    end
  end

  # Create system attributes
  SYSTEM_ATTRIBUTES.each_with_index do |(code, config), index|
    group = company.attribute_groups.find_by(code: config[:group].to_s)

    attr = company.product_attributes.find_or_initialize_by(code: code.to_s)
    if attr.new_record?
      attr.assign_attributes(
        name: config[:name],
        description: config[:description],
        pa_type: config[:pa_type],
        view_format: config[:view_format],
        mandatory: config.fetch(:mandatory, false),
        product_attribute_scope: config.fetch(:scope, :product_scope),
        attribute_group: group,
        attribute_position: index + 1,
        rules: build_rules(config),
        has_rules: config[:rules].present?,
        info: build_info(config)
      )
    else
      # Existing attribute: validate type/format compatibility before promoting to system
      expected_type = config[:pa_type].to_s
      expected_format = config[:view_format].to_s
      if attr.pa_type != expected_type || attr.view_format != expected_format
        Rails.logger.warn(
          "SystemAttributes CONFLICT: Company #{company.code} has '#{code}' " \
          "with type=#{attr.pa_type}/format=#{attr.view_format}, " \
          "expected type=#{expected_type}/format=#{expected_format}. " \
          "Forcing type/format to match system definition."
        )
        attr.pa_type = config[:pa_type]
        attr.view_format = config[:view_format]
      end
    end

    # Always set system flag and metafield mapping
    attr.system = true
    if config[:shopify_metafield].present?
      attr.shopify_metafield_namespace = config[:shopify_metafield][:namespace]
      attr.shopify_metafield_key = config[:shopify_metafield][:key]
      attr.shopify_metafield_type = config[:shopify_metafield][:type]
    end

    attr.save!
  end
end

private

def self.build_rules(config)
  return [] unless config[:rules]
  config[:rules].keys.map(&:to_s)
end

def self.build_info(config)
  info = {}
  info["options"] = config[:options] if config[:options]
  info["unit"] = config[:unit] if config[:unit]
  info
end
```

#### Rake task for backfill

```ruby
# lib/tasks/product_attributes.rake
namespace :product_attributes do
  desc "Ensure all companies have system attributes"
  task ensure_system: :environment do
    Company.find_each do |company|
      ProductAttribute.ensure_system_attributes!(company)
      puts "System attributes ensured for #{company.name} (#{company.code})"
    end
  end
end
```

#### Company after_create hook

```ruby
# app/models/company.rb
after_create :provision_system_attributes

private

def provision_system_attributes
  ProductAttribute.ensure_system_attributes!(self)
end
```

### 8. UI Changes

#### Product Attributes Index

- System attributes show a lock icon or "System" badge
- System attributes cannot be deleted (no delete button)
- System attributes still draggable for reordering

#### Product Attribute Edit Form

- System attributes: code, type, and format fields are disabled/read-only
- System attributes: show info text "This is a system attribute required for Shopify sync. Code, type, and format cannot be changed."
- Non-system attributes: new "Shopify Sync" section with toggle + metafield fields

#### Product Attribute New Form

- No changes to creation flow for custom attributes
- System attributes are never created via the form (only via registry)

## Files to Modify

### Potlift8

| File | Change |
|------|--------|
| `app/models/concerns/system_attributes.rb` | **New** — Registry constant and `ensure_system_attributes!` |
| `app/models/product_attribute.rb` | Add system validations, include SystemAttributes |
| `app/models/company.rb` | Add `after_create :provision_system_attributes` |
| `db/migrate/XXXX_add_system_and_shopify_metafield_to_product_attributes.rb` | **New** — 4 columns |
| `db/seeds.rb` | Replace cannabis attributes with `ensure_system_attributes!` call |
| `lib/tasks/product_attributes.rake` | **New** — Backfill rake task |
| `app/services/product_sync_service.rb` | Enrich attribute payload with mapping info |
| `app/controllers/product_attributes_controller.rb` | Disable fields for system attributes |
| `app/views/product_attributes/_form.html.erb` | Conditional disabled fields + Shopify sync section |
| `app/views/product_attributes/index.html.erb` | System badge, hide delete for system |

### Shopify8

| File | Change |
|------|--------|
| `app/services/shopify/product_schema/build.rb` | Replace hardcoded attribute lookups with mapping-driven logic |
| `app/services/executors/product_changed_executor.rb` | Use new metafield builder for custom attribute metafields |

## Testing Strategy

- **Unit tests:** SystemAttributes concern — registry completeness, `ensure_system_attributes!` idempotency
- **Model tests:** ProductAttribute — system field immutability, destroy prevention
- **Service tests:** ProductSyncService — enriched payload format with mapping info
- **Integration tests:** Full sync flow with system + custom metafield attributes
- **Controller tests:** System attributes can't be deleted or have type changed via form
- **Backfill test:** Rake task handles existing attributes correctly (sets system flag without changing user customizations)

## Migration Plan

**Deployment order matters.** The payload format change (flat values → enriched objects) is a breaking change. Both services must be coordinated.

### Phase 1: Backward-compatible Shopify8 (deploy first)
1. Deploy Shopify8 changes with **dual-format parsing**: check if attribute value is a Hash (new format) or String (old format). If String, fall back to current hardcoded `attribute_by_code` logic. This makes Shopify8 accept both formats safely.

### Phase 2: Potlift8 schema + backfill
2. Deploy Potlift8 migration (add 4 columns to `product_attributes`)
3. Run `rake product_attributes:ensure_system` to backfill all companies
4. Deploy Potlift8 code changes (model validations, enriched sync payload, UI)
5. Verify sync works with enriched payload format end-to-end

### Phase 3: Cleanup
6. Remove old-format fallback from Shopify8 (once all payloads use new format)
7. Remove cannabis seed attributes from seeds.rb

### Rollback plan
- If Phase 2 causes sync issues, revert Potlift8 code (schema + data can stay). Shopify8 dual-format parsing handles the old format gracefully.
