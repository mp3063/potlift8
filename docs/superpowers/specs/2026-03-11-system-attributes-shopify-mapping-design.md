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

**New method required:** `CatalogItem#effective_product_attribute_values` returns the merged set of attribute values with catalog overrides, preserving the `product_attribute` association for mapping lookup. Add to `app/models/catalog_item.rb`:

```ruby
# Returns product attribute values with catalog overrides merged in.
# Unlike effective_attribute_values_hash (which returns flat {code => value}),
# this returns an array of duck-typed objects with .product_attribute, .value, .info
# so build_attribute_entry can access the ProductAttribute record for mapping.
#
# Catalog-level overrides take precedence over product-level values.
# Only attributes with product_and_catalog_scope or catalog_scope can be overridden.
def effective_product_attribute_values
  product_values = product.product_attribute_values.includes(:product_attribute).index_by { |pav| pav.product_attribute_id }
  catalog_overrides = catalog_item_attribute_values.includes(:product_attribute).index_by { |ciav| ciav.product_attribute_id }

  # Merge: catalog overrides replace product values for matching attribute IDs
  merged = product_values.merge(catalog_overrides)
  merged.values
end
```

#### Subproduct (variant) attribute enrichment

The `build_subproducts_payload` (line 295-325 in `app/services/product_sync_service.rb`) currently calls `subproduct.attribute_values_hash` which returns a flat hash. Replace with enriched version. Change line 316 from:

```ruby
# BEFORE (line 316):
attributes: subproduct.attribute_values_hash,

# AFTER:
attributes: build_subproduct_attributes(subproduct),
```

Add this private method to ProductSyncService:

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

All changes in `/Users/sin/RubymineProjects/Ozz-Rails-8/Shopify8/app/services/shopify/product_schema/build.rb`.

#### Phase 1: Dual-format attribute accessor (deploy first)

Add a helper that reads attribute values from both old (flat string) and new (enriched hash) payload formats. This makes Shopify8 backward-compatible during the transition.

```ruby
# Reads an attribute value regardless of payload format.
# Old format: attrs["price"] => "1999"
# New format: attrs["price"] => { "value" => "1999", "shopify_field" => "price" }
def attr_value(attrs, code)
  val = attrs[code]
  return nil if val.nil?
  val.is_a?(Hash) ? val["value"] : val
end

# Find attribute entry by shopify_field mapping (new format only)
def find_by_shopify_field(attrs, field_name)
  return nil unless attrs.is_a?(Hash)
  attrs.values.find { |v| v.is_a?(Hash) && v["shopify_field"] == field_name }
end

# Find attribute entry by custom_handler mapping (new format only)
def find_by_custom_handler(attrs, handler_name)
  return nil unless attrs.is_a?(Hash)
  attrs.values.find { |v| v.is_a?(Hash) && v["custom_handler"] == handler_name }
end
```

#### Phase 1: Update existing methods to use dual-format accessor

These changes make existing methods work with both old and new payload formats:

```ruby
# localized_attribute (line 73-76) — update to handle enriched format
def localized_attribute(code)
  localized = load.dig("attributes", "localized", code, "localized_value", @shop_language)
  return localized if localized.present?
  attrs = load.dig("attributes", "values") || load["attributes"] || {}
  attr_value(attrs, code)
end

# extract_vendor (line 80-86) — update to use attr_value
def extract_vendor
  labels = load["labels"] || []
  brand = labels.find { |l| l["label_type"] == "brand" }
  return localized_label_name(brand) if brand

  attrs = load.dig("attributes", "values") || load["attributes"] || {}
  attr_value(attrs, "brand")
end

# extract_compare_at_price (line 118-126) — update to use attr_value
def extract_compare_at_price(attributes)
  special_price = attr_value(attributes, "special_price")
  regular_price = attr_value(attributes, "price")
  return nil if special_price.blank? || special_price == regular_price
  price_from_cents(regular_price)
end

# build_single_variant (line 176-196) — update to use attr_value
def build_single_variant
  attrs = load.dig("attributes", "values") || load["attributes"] || {}
  existing = find_existing_variant(product_field("sku"))

  variant = {
    sku: product_field("sku"),
    price: price_from_cents(attr_value(attrs, "price")),
    compareAtPrice: extract_compare_at_price(attrs),
    barcode: attr_value(attrs, "ean") || product_field("ean"),
    taxable: true
  }

  # ... existing/new variant logic unchanged ...
  variant.compact
end

# build_variant_from_subproduct (line 140-174) — update to use attr_value
def build_variant_from_subproduct(subproduct, index)
  attrs = subproduct["attributes"] || {}
  # ... rest uses attr_value(attrs, "price"), attr_value(attrs, "ean"), etc.
end

# build_metafields (line 233-275) — update sizechart/description access
def build_metafields
  metafields = []
  attrs = load.dig("attributes", "values") || load["attributes"] || {}

  # Origin SKU (always)
  metafields << { namespace: "global", key: "origin_sku", value: product_field("sku"), type: "single_line_text_field" }

  # Detailed description — from localized_attribute (unchanged logic)
  if (desc = localized_attribute("description_html")).present?
    metafields << { namespace: "global", key: "detailed_description_html", value: desc, type: "multi_line_text_field" }
  end

  # Size chart — use attr_value for dual-format
  if (sizechart = attr_value(attrs, "sizechart")).present?
    metafields << { namespace: "global", key: "sizechart", value: sizechart, type: "single_line_text_field" }
  end

  # ... label, bundle composition unchanged ...
  metafields
end
```

#### Phase 3: Generic metafield builder (after Potlift8 deploys enriched format)

Once all payloads use the new format, add generic metafield building from attribute mapping:

```ruby
# Builds metafields from any attributes that have shopify_metafield mapping.
# This handles both system metafield attributes AND user-opted custom attributes.
def build_metafields_from_attributes(attrs)
  return [] unless attrs.is_a?(Hash)

  attrs.select { |_code, v| v.is_a?(Hash) && v["shopify_metafield"].present? }
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

Then update `build_metafields` to use it:
```ruby
# Replace hardcoded detailed_description and sizechart blocks with:
metafields.concat(build_metafields_from_attributes(attrs))
```

**Special cases that remain hardcoded (all phases):**
- `special_price` — date-range logic (check from/until before setting compareAtPrice)
- `vat_group` — maps to Shopify tags via `build_tags`, not a field or metafield
- `secondary_sku` — barcode fallback logic (try ean first, fall back to secondary_sku)
- `description_html` vs `detailed_description` — currently `localized_attribute("description_html")` populates BOTH the product body (`descriptionHtml`) and the metafield (`detailed_description_html`). After migration: `description_html` attribute (with `shopify_field: :descriptionHtml`) feeds the product body. `detailed_description` attribute (with `shopify_metafield`) feeds the metafield. These are two separate attributes.

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

### 8. Controller Changes

**File:** `app/controllers/product_attributes_controller.rb`

#### Strong params defense-in-depth

Add system field stripping in `product_attribute_params` (line 140-177). Even though model validations prevent system field changes, the controller should strip them as defense-in-depth:

```ruby
def product_attribute_params
  permitted = params.require(:product_attribute).permit(
    :name, :code, :view_format, :attribute_group_id, :mandatory,
    :help_text, :default_value, :pa_type, :description,
    :product_attribute_scope, :options,
    # New Shopify sync fields (custom attributes only)
    :shopify_metafield_namespace, :shopify_metafield_key, :shopify_metafield_type,
    options: []
  )

  # Strip immutable fields for system attributes
  if @product_attribute&.system?
    permitted.delete(:code)
    permitted.delete(:pa_type)
    permitted.delete(:view_format)
    permitted.delete(:shopify_metafield_namespace)
    permitted.delete(:shopify_metafield_key)
    permitted.delete(:shopify_metafield_type)
  end

  # ... existing options JSON parsing logic unchanged ...
end
```

#### Destroy action (line 79-88)

Add system check before the existing "has values?" check:

```ruby
def destroy
  authorize @product_attribute

  if @product_attribute.system?
    redirect_to product_attributes_path, alert: "System attributes cannot be deleted."
    return
  end

  if @product_attribute.product_attribute_values.any?
    redirect_to product_attributes_path, alert: "Cannot delete attribute with existing values."
  else
    @product_attribute.destroy
    redirect_to product_attributes_path, notice: "Attribute deleted successfully."
  end
end
```

### 9. UI Changes

#### Product Attributes Index (`app/views/product_attributes/index.html.erb`)

- System attributes show a `Ui::BadgeComponent.new(variant: :info) { "System" }` badge next to name
- System attributes: hide delete button (line ~69 in attribute row)
- System attributes still draggable for reordering within groups

#### Product Attribute Form (`app/views/product_attributes/_form.html.erb`)

**System attribute locked fields (lines 62-141):**

Wrap code, pa_type, view_format fields with conditional `disabled`:

```erb
<%# Code field (line ~40) %>
<%= form.text_field :code, disabled: @product_attribute.system?, ... %>

<%# Attribute Type select (line ~62) %>
<%= form.select :pa_type, ..., {}, { disabled: @product_attribute.system? } %>

<%# View Format select (line ~88) %>
<%= form.select :view_format, ..., {}, { disabled: @product_attribute.system? } %>
```

Add system info banner at top of form when editing system attribute:

```erb
<% if @product_attribute.system? %>
  <div class="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
    <p class="text-sm text-blue-800">
      This is a system attribute required for Shopify sync. Code, type, and format cannot be changed.
    </p>
  </div>
<% end %>
```

**Shopify Sync section (add after line ~214, end of form):**

Only shown for NON-system attributes:

```erb
<% unless @product_attribute.system? %>
  <div class="border-t pt-6 mt-6" data-controller="shopify-sync-toggle">
    <h3 class="text-lg font-medium mb-4">Shopify Sync</h3>

    <label class="flex items-center gap-2 mb-4">
      <%= check_box_tag :sync_to_shopify,
            "1",
            @product_attribute.shopify_metafield_namespace.present?,
            data: { action: "shopify-sync-toggle#toggle", shopify_sync_toggle_target: "checkbox" } %>
      <span class="text-sm font-medium">Sync to Shopify as metafield</span>
    </label>

    <div data-shopify-sync-toggle-target="fields"
         class="<%= 'hidden' unless @product_attribute.shopify_metafield_namespace.present? %> space-y-4 ml-6">

      <div>
        <label class="block text-sm font-medium mb-1">Namespace</label>
        <%= form.text_field :shopify_metafield_namespace,
              value: @product_attribute.shopify_metafield_namespace || "custom",
              class: "form-input w-full" %>
        <p class="text-xs text-gray-500 mt-1">Default: "custom". Use "global" for store-wide fields.</p>
      </div>

      <div>
        <label class="block text-sm font-medium mb-1">Key</label>
        <%= form.text_field :shopify_metafield_key,
              value: @product_attribute.shopify_metafield_key || @product_attribute.code,
              class: "form-input w-full" %>
      </div>

      <div>
        <label class="block text-sm font-medium mb-1">Metafield Type</label>
        <%= form.select :shopify_metafield_type,
              ProductAttribute::SHOPIFY_METAFIELD_TYPE_MAP.values.uniq,
              { selected: @product_attribute.shopify_metafield_type ||
                          ProductAttribute::SHOPIFY_METAFIELD_TYPE_MAP[@product_attribute.pa_type] },
              { class: "form-select w-full" } %>
      </div>
    </div>
  </div>
<% end %>
```

**Stimulus controller** (`app/javascript/controllers/shopify_sync_toggle_controller.js`):

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "fields"]

  toggle() {
    this.fieldsTarget.classList.toggle("hidden", !this.checkboxTarget.checked)
    if (!this.checkboxTarget.checked) {
      // Clear metafield fields when unchecked
      this.fieldsTarget.querySelectorAll("input, select").forEach(el => {
        if (el.type !== "checkbox") el.value = ""
      })
    }
  }
}
```

**Metafield type map constant** (add to `app/models/product_attribute.rb`):

```ruby
SHOPIFY_METAFIELD_TYPE_MAP = {
  "patype_text" => "single_line_text_field",
  "patype_number" => "number_decimal",
  "patype_boolean" => "boolean",
  "patype_select" => "single_line_text_field",
  "patype_multiselect" => "list.single_line_text_field",
  "patype_date" => "date",
  "patype_rich_text" => "multi_line_text_field",
  "patype_custom" => "json"
}.freeze
```

## Files to Modify

### Potlift8

| File | Change | Lines Affected |
|------|--------|----------------|
| `app/models/concerns/system_attributes.rb` | **New** — Registry constant, groups, `ensure_system_attributes!`, helpers | — |
| `app/models/product_attribute.rb` | Include SystemAttributes, add `SHOPIFY_METAFIELD_TYPE_MAP`, system validations, destroy prevention | After existing validations |
| `app/models/company.rb` | Add `after_create :provision_system_attributes` | After existing callbacks |
| `app/models/catalog_item.rb` | Add `effective_product_attribute_values` method | After line 126 |
| `db/migrate/XXXX_add_system_and_shopify_metafield_to_product_attributes.rb` | **New** — 4 columns + index | — |
| `db/seeds.rb` | Replace cannabis attributes (lines ~209-387) with `ensure_system_attributes!` call | Lines 209-387 |
| `lib/tasks/product_attributes.rake` | **New** — Backfill rake task | — |
| `app/services/product_sync_service.rb` | Rewrite `build_attributes_payload` (lines 167-195), add `build_attribute_entry`, `build_subproduct_attributes`, update line 316 | Lines 167-195, 316 |
| `app/controllers/product_attributes_controller.rb` | Add metafield params, system field stripping, system destroy check | Lines 79-88, 140-177 |
| `app/views/product_attributes/_form.html.erb` | Disabled fields for system, system info banner, Shopify sync section | Lines 40, 62, 88, after 214 |
| `app/views/product_attributes/index.html.erb` | System badge, hide delete for system | Line ~69 |
| `app/javascript/controllers/shopify_sync_toggle_controller.js` | **New** — Toggle Shopify sync fields visibility | — |

### Shopify8

| File | Change | Lines Affected |
|------|--------|----------------|
| `app/services/shopify/product_schema/build.rb` | Add `attr_value`, `find_by_shopify_field`, `find_by_custom_handler` helpers; update `localized_attribute`, `extract_vendor`, `extract_compare_at_price`, `build_single_variant`, `build_variant_from_subproduct`, `build_metafields`; add `build_metafields_from_attributes` | Lines 62-86, 118-126, 140-196, 233-275 |

## Testing Strategy

> **Implementation status (2026-03-12):** All Potlift8 tests passing (68 tests across 4 spec files). Backfill run in dev.

- [x] **Unit tests:** `spec/models/concerns/system_attributes_spec.rb` — registry completeness (12 attrs, 4 groups, valid enums), `ensure_system_attributes!` idempotency, conflict resolution
- [x] **Model tests:** `spec/models/concerns/system_attributes_spec.rb` — system field immutability (code, pa_type, view_format), destroy prevention, allows name/description changes
- [x] **Service tests:** `spec/services/product_sync_service_enriched_payload_spec.rb` — enriched payload format with shopify_field, custom_handler, shopify_metafield, system flag; subproduct attributes; custom attribute with user-configured metafield
- [x] **Integration tests:** `spec/services/product_sync_service_integration_spec.rb` — full sync with system attrs (shopify_field + shopify_metafield), custom metafield opt-in, mixed attributes, catalog overrides, subproduct enrichment, HTTP payload verification via WebMock (19 tests)
- [x] **Controller tests:** `spec/requests/product_attributes_system_spec.rb` — system destroy prevention, immutable field stripping (code/pa_type/view_format/metafield columns), mutable fields (name/description/mandatory/default_value) update correctly (18 tests)
- [x] **Backfill test:** `spec/tasks/product_attributes_rake_spec.rb` — rake task runs, is idempotent, processes all companies

## Migration Plan

**Deployment order matters.** The payload format change (flat values → enriched objects) is a breaking change. Both services must be coordinated.

### Phase 1: Backward-compatible Shopify8 (deploy first) — DONE
1. ~~Deploy Shopify8 changes with **dual-format parsing**~~ — `attr_value` helper, `build_metafields_from_attributes`, all methods updated. 122 tests pass.

### Phase 2: Potlift8 schema + backfill — DONE
2. ~~Deploy Potlift8 migration (add 4 columns to `product_attributes`)~~ — Migration run in dev.
3. ~~Run `rake product_attributes:ensure_system` to backfill all companies~~ — Backfill run 2026-03-12. OZZ: 12 system attrs, TEST: 12 system attrs.
4. ~~Deploy Potlift8 code changes (model validations, enriched sync payload, UI)~~ — All code implemented.
5. ~~Verify sync works with enriched payload format~~ — Verified 2026-03-12. Enriched payload generates correctly with shopify_field, system flags, and metafield mappings.

### Phase 3: Cleanup — COMPLETE
6. ~~Remove old-format fallback from Shopify8 (once all payloads use new format)~~ — Done 2026-03-12. Removed dual-format `attr_value` fallback, `is_a?(Hash)` guards, and hardcoded `detailed_description_html`/`sizechart` metafield fallbacks. Updated `build_metafields_from_attributes` to use localized values. All 122 build_spec tests updated to enriched format and passing.
7. ~~Remove cannabis seed attributes from seeds.rb~~ — Seeds now use `ensure_system_attributes!` + company-specific custom attrs

### Rollback plan
- Phase 3 is a breaking change: Shopify8 now requires the enriched attribute format. If issues arise, revert Shopify8's `build.rb` to restore the dual-format `attr_value` fallback.
