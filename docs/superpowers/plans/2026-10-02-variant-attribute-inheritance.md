# Variant Attribute Inheritance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new variant of a configurable product starts with its own copy of the parent's values for the attributes flagged `subproduct_mandatory`, as pot3 did. Existing variants can be backfilled. Shopify8 then syncs weight and cost per variant, falling back to the parent.

**Architecture:**
- One Potlift8 service, `VariantAttributeInheritance`, copies the flagged values.
- An `after_create` callback on `ProductConfiguration` runs it whenever a variant is linked to a configurable product. That covers the generator, the manual "add variant" form and imports.
- A rake task reuses the service for the backfill.
- Shopify8's `InventoryItemSync` reads weight and cost from the matching subproduct first, then the parent.

**Tech Stack:** Rails 8, RSpec, FactoryBot (Potlift8 and Shopify8).

**Spec:** The user's decisions on 2026-10-02:
- Copy-on-create like pot3 (`pot3/app/controllers/concerns/product_attributes_editor.rb:43-60`), driven by the existing, so far unused, `subproduct_mandatory` flag rather than `mandatory`.
- Flag `weight` and `purchase_price` for every company.
- Add the flag to the attribute form.
- Backfill existing variants with a rake task.

## Global Constraints

- **Copy rule (from pot3):** use the parent's value if present, else the attribute's `default_value`. Skip the attribute if both are blank. Copy `value` and `info`.
- **Never overwrite** a value the variant already has. Both the callback and the backfill are idempotent.
- **Configurable products only.** Bundle components are existing products and must never be changed (`superproduct.product_type_configurable?`).
- **Price is not flagged.** Price keeps falling back to the parent at sync time in Shopify8, so a parent price change still reaches every variant.
- **Baseline:** Potlift8 has 2 known failing specs (`catalog_price_validator_spec.rb:309`, `integration/api_workflow_spec.rb:316`), and its SimpleCov 80% gate trips on spec subsets. Run the full suite for the final check.

## Review Focus

1. **The variant already has a value:** it is kept, not overwritten. → Task 2 test.
2. **Bundle component linked to a bundle:** no values copied. → Task 2 test.
3. **Parent value blank but the attribute has a default:** the default is copied. → Task 2 test.
4. **The parent changes later:** the variant keeps its copy, by design, as in pot3. This is documented, not tested.
5. **Running the backfill twice:** the second run copies 0 values. → Task 3 test.

---

### Task 1: Flag weight and purchase_price; expose the flag in the attribute form (Potlift8)

**Files:**
- Create: `db/migrate/<ts>_flag_weight_and_purchase_price_subproduct_mandatory.rb`
- Modify: `app/controllers/product_attributes_controller.rb:122-137` (permit `:subproduct_mandatory`), `app/views/product_attributes/_form.html.erb:190-200` (checkbox after "mandatory", labelled "Copy to new variants", help text "New variants start with the parent's value")
- Test: `spec/requests/product_attributes_spec.rb`

- [ ] Write the failing request test: a PATCH with `subproduct_mandatory: "1"` saves `true`.
- [ ] Run it and see it fail, because the parameter is not permitted.
- [ ] Permit the parameter and add the checkbox. Run the test: it passes.
- [ ] Add the migration. `up` runs `ProductAttribute.where(code: %w[weight purchase_price]).update_all(subproduct_mandatory: true)` (SQL, no model callbacks). `down` sets it back to false.
- [ ] Run `bin/rails db:migrate`. Check that `ProductAttribute.where(subproduct_mandatory: true).pluck(:code).uniq.sort == ["purchase_price", "weight"]`.
- [ ] Commit with `feat(attributes): flag weight and purchase_price to copy into new variants`.

### Task 2: `VariantAttributeInheritance` + `ProductConfiguration` callback (Potlift8)

**Files:**
- Create: `app/services/variant_attribute_inheritance.rb`, `spec/services/variant_attribute_inheritance_spec.rb`
- Modify: `app/models/product_configuration.rb` (`after_create :inherit_variant_attributes, if: -> { superproduct.product_type_configurable? }`)

**Interfaces:**
- Produces: `VariantAttributeInheritance.new(superproduct:, subproduct:).call -> Integer`, the number of values created. Task 3 uses it.

- [ ] Write the failing service tests:
  - Copies a flagged attribute's value and `info`.
  - Skips unflagged attributes.
  - Copies `default_value` when the parent has no value.
  - Skips when the parent value and the default are both blank.
  - Keeps an existing variant value.
  - Returns the count.
- [ ] Write the failing callback tests:
  - Linking a variant to a configurable product copies the values.
  - Linking a component to a bundle copies nothing.
  - `VariantGeneratorService#generate!` gives each new variant the parent's weight.
- [ ] Run them and see them fail (`uninitialized constant`; nothing copied).
- [ ] Implement:
  - Loop over `company.product_attributes.where(subproduct_mandatory: true)`.
  - Skip when the subproduct already has a value for that attribute.
  - Otherwise create `product_attribute_values` with `value:` and `info:`.
- [ ] Run the new specs plus `variant_generator_service_spec`, `bundle_variant_generator_service_spec` and `spec/models/product_configuration_spec.rb`: all pass.
- [ ] Commit with `feat(variants): copy subproduct_mandatory attribute values into new variants`.

### Task 3: Backfill rake task (Potlift8)

**Files:**
- Create: `lib/tasks/variants.rake` (`variants:inherit_attributes`), `spec/tasks/variants_rake_spec.rb`

- [ ] Write the failing test: the first run on a configurable product with one empty variant copies its weight. A second run copies 0 values (it prints `0 values copied`).
- [ ] Run it and see `Don't know how to build task`.
- [ ] Implement: loop over every `ProductConfiguration` whose superproduct is configurable, call the service, and print `"<N> values copied into <M> variants"`.
- [ ] Run the test: it passes. Commit with `feat(variants): rake task to backfill inherited variant attributes`.
- [ ] Run the task on the dev database and record the counts.

### Task 4: Per-variant weight and cost in Shopify8

**Files:**
- Modify: `Shopify8/app/services/shopify/inventory_item_sync.rb` (`update_weights`, `update_costs`)
- Test: `Shopify8/spec/services/shopify/inventory_item_sync_spec.rb`

**Interfaces:**
- Consumes: Potlift8 subproduct entries `{"sku" or "product"=>{"sku"}, "attributes" => {code => {"value", ...}}}` (flat format), matched to a Shopify variant by SKU, as `set_stock` already does.

- [ ] Write the failing tests:
  - Two variants, where one subproduct has its own `weight` and `purchase_price` and the other has none. `update_inventory_item_measurement` gets the subproduct's weight for the first variant and the parent's for the second. `update_inventory_items` gets each variant's own cost.
  - When the parent and the subproduct both lack a weight, that item gets no measurement call.
- [ ] Run them and see them fail (both variants get the parent's values).
- [ ] Implement:
  - Add a private `subproduct_for(variant)`, shared with `set_stock`.
  - Read each value from the subproduct's `attributes`, falling back to the parent's.
  - Skip any item whose value resolves to blank.
- [ ] Run `bundle exec rspec`: all pass. Commit with `feat(sync): sync weight and cost per variant with parent fallback`.

### Final

- [ ] Run the full suites in both repos and compare them with the baseline.
- [ ] Run a final code review.
- [ ] Ask the user whether to merge and push.
