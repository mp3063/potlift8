# Product Show Page — Dense Overview Design Spec

**Date:** 2026-09-03
**Status:** Approved
**Branch:** `feature/product-show-dense-overview`

## Problem

The product show page (`/products/:id`) is 3.25 viewports tall for a typical configurable product and about 4 viewports when the "Product" attribute tab is selected. Measured on product 206 at 1447×909:

| Section | Column | Height | Content |
|---|---|---|---|
| Catalog tab (European Webshop) | left | 975px | 7 attributes, each rendered as 3 stacked lines |
| Product tab (hidden) | left | 1677px | 17 attributes, 10 of them "Not set" |
| Configuration | left | 527px | 2 stat tiles, 2 chip rows, 2 stacked full-width buttons |
| Labels | left | 491px | Full label picker to display 1 selected chip |
| Basic Information | left | 365px | 6 fields in a 2-column grid |
| Images | left | 279px | Empty upload dropzone |
| Right column total | right | ~840px | Status, Inventory, Shopify, Activity, then ~1900px blank |

Root causes:

1. Attribute rows are vertical (label / value / "Inherited from product" as three lines).
2. Editors are embedded permanently in a show page (label picker, image dropzone).
3. Facts are repeated: status appears three times, product type twice, SKU three times, name twice.
4. Columns are unbalanced: the left column holds everything heavy, the right column ends after one screen.

## Solution

Keep the 2/3 + 1/3 grid and the existing drill-down pages. State every fact once, render attributes as one row each, collapse editors behind a button or a native `<details>`, move the Configuration summary to the sidebar, and make the sidebar sticky. Target: the full page for a typical product fits one 909px viewport.

Target layout:

```
Breadcrumb
Configurable 1   ● Active   Configurable · Variant         [Edit] [Deactivate] [More ▾]
SKU PRD_C8CF8A0E · EAN — · Restock level 0 · Updated 5 months ago
┌─ Images  3 ──────────────────────────[Upload]─┬─ Inventory ────────────────┐
│ ▢ ▢ ▢ ▢ ▢ ▢     ▸ Manage images               │ 481 units                  │
├─ [Product] [European Webshop] [+ Add to Catalog]  │ Incoming 240 · Main 241 │
│ European Webshop ● Active    View catalog · Remove │ Manage inventory →     │
│ Price           100                   inherited    ├─ Variants  12 ─────────┤
│ Short Descr.    Configurable blabla   inherited    │ Size   S · M · L       │
│ Weight          30                    inherited    │ Color  Red White Bl Ye │
│ Special Price   85            ● Override   ✎ ×     │ Manage variants →      │
│ …                                                  ├─ Shopify ──────────────┤
│                              [+ Add Attribute Override] │ European Webshop  │
├─ Labels ─────────────────────────────[+ Add]─┤     [Sync] Preview →        │
│ ● Flower ×                                   ├─ Activity ──────────────────┤
└──────────────────────────────────────────────┤ • Created by System · 6 mo  │
                                               │ View full history →         │
```

Height budget for product 206 against 845px of usable viewport (909 minus the 64px fixed nav):

| Block | Today | Target |
|---|---|---|
| Header + facts strip | 140 | ≤ 130 |
| Images (3 images) | 279 | ≤ 120 |
| Attributes, catalog tab (7 rows) | 975 | ≤ 400 |
| Labels (1 chip) | 491 | ≤ 70 |
| Left column total | 2925 | ≤ 770 |

## Design

### 1. Page structure (`app/views/products/show.html.erb`)

- Breadcrumb markup stays as is.
- The inline title/actions block and the `Products::BasicInfoComponent` and `Products::StatusCardComponent` renders are replaced by one render of `Products::HeaderComponent` inside `turbo_frame_tag "product-header-#{@product.id}"`.
- Left column (`lg:col-span-2 space-y-4`): `ImagesComponent`, the `catalog-tabs-<id>` frame with `CatalogTabsComponent`, `LabelsComponent`.
- Right column (`space-y-4 lg:sticky lg:top-20 lg:self-start`): `InventorySummaryComponent`, `ConfigurableCardComponent`, the existing Shopify Sync Preview markup unchanged, the `sync-preview-drawer` frame, `ActivityTimelineComponent`.
- Card gap shrinks from `gap-6` / `space-y-6` to `gap-4` / `space-y-4`.

### 2. `Products::HeaderComponent` (new)

Files: `app/components/products/header_component.rb`, `header_component.html.erb`.

Replaces `BasicInfoComponent` and `StatusCardComponent`, which are deleted along with their specs. Their private helpers (status badge variant, type label, toggle button text/classes, inactive variant counts) move into the header component.

Content, top to bottom:

1. **Title row.** `<h1>` product name; `Ui::BadgeComponent` status badge with `dot: true` (variants: active → `:success`, draft/incoming → `:warning`, discontinued/deleted → `:danger`, else `:gray`; label = `product_status.humanize`); type badge `:info` reading `product_type.humanize`, and for configurables `"Configurable · #{configuration_type.humanize}"` when `configuration_type` is set.
2. **Actions** (right of title, `flex gap-x-2`):
   - Edit (`Ui::ButtonComponent` secondary, href `edit_product_path`).
   - Activate/Deactivate `button_to toggle_active_product_path`, method patch. Deactivate keeps `turbo_confirm`. Classes: gray when active (Deactivate), green when inactive (Activate), same as today's StatusCard.
   - More menu: `div.relative[data-controller="dropdown"]` with a secondary button (`data-dropdown-target="button"`, `aria-haspopup="menu"`, `aria-expanded`) and a hidden menu (`data-dropdown-target="menu"`, `role="menu"`) containing `role="menuitem"` entries: Assets (link to `product_product_assets_path`), Duplicate (`button_to duplicate_product_path`, post), Delete (`button_to product_path`, delete, red text, `turbo_confirm` as today).
3. **Facts strip.** One `<dl>` rendered inline as `flex flex-wrap gap-x-4 text-sm text-gray-500`, each item a `div` with a visually plain `dt` and `dd`: SKU (`font-mono`), EAN (`font-mono`, `—` when blank), Restock level (`product.info['restock_level'] || 0`), Updated (`time_ago_in_words(updated_at)` + " ago", `title` = full timestamp).
4. **Description.** When `product.description.present?`, a `<p class="mt-2 text-sm text-gray-600 line-clamp-2">`.
5. **Inactive variants notice.** Only when `!product.active?` and the product is configurable or bundle and has subproducts not in `active` state: a yellow bar (`bg-yellow-50 border border-yellow-200 rounded-md px-3 py-2 flex items-center justify-between`) with text "N of M variants not yet active" and a small `button_to "Activate all variants", activate_variants_product_path, method: :patch`.

The component renders for every product type. No `render?` guard.

### 3. Turbo streams for the header

`app/views/products/toggle_active.turbo_stream.erb` and `activate_variants.turbo_stream.erb` change their replace target from `product-status-<id>` to `product-header-<id>` and render `Products::HeaderComponent` inside `turbo_frame_tag "product-header-#{@product.id}"`. The flash update stays.

### 4. Attributes block (`Products::CatalogTabsComponent` and partials)

The component class is unchanged. The component template keeps the tab bar and only drops the `p-6` wrapper around the panels, so rows can carry their own horizontal padding. The two panel partials change layout, and row markup is consolidated.

**Row layout (both tabs).** Each row is one `div` that is both the inline-editor controller element and a CSS grid:

```
div#<row id>.group.grid.grid-cols-[minmax(9rem,1fr)_2fr_auto].items-start.gap-x-4.px-6.py-2.border-b.border-gray-100
  [data-controller="inline-editor" data-inline-editor-url-value=...]      (editable rows only)
  ├─ dl.contents [data-inline-editor-target="display"]
  │    ├─ dt   (column 1)
  │    ├─ dd   (column 2)
  │    └─ div  (column 3, actions)
  └─ div.hidden.col-span-3 [data-inline-editor-target="editor"]  (editable rows only; existing form markup)
```

The `display` wrapper uses `contents` so its three children become grid cells while the controller can still hide it as one element. The editor is a direct grid child spanning all three columns. Rows without an editor (inherited values on catalog tabs) omit the controller attributes and the editor block.

- Column 1 (`dt`, `text-sm font-medium text-gray-500`): attribute name. Suffixes: blue "Override" badge on catalog overrides; amber "Required" badge (`Ui::BadgeComponent` `:warning`, `size: :sm`) on mandatory attributes with no value. Attribute `description`, when present, becomes a `title` tooltip on the name instead of a third line.
- Column 2 (`dd`, `text-sm text-gray-900`): the value, `truncate` for single-line types, `line-clamp-2` for `patype_rich_text`; full value in `title`. Unset shows "Not set" in `text-gray-400 italic`, or `text-amber-700 italic` when mandatory.
- Column 3 (`flex items-center gap-1`): on catalog tabs, either a grey `inherited` tag (`text-xs text-gray-400`) or the override's edit and remove icon buttons (existing markup, hover-revealed). On the Product tab, the edit icon button (existing markup, hover-revealed).

**Product tab (`_product_attributes.html.erb`).**

- Loops `all_attributes` and renders `products/attribute_value` for each. That partial becomes the single source for the Product-tab row and now includes the outer row `div` with `id: dom_id(attribute, :value)`. The `turbo_frame_tag` wrapper in the loop is removed, since the id on the row div is what `ProductAttributeValuesController#update` replaces.
- Rows are partitioned: `visible = attributes with a value, plus mandatory attributes without a value`; `hidden = non-mandatory attributes without a value`. Visible rows render first. If `hidden` is non-empty, they render inside `<details class="group/unset">` with `<summary class="px-6 py-2 text-sm text-blue-600 cursor-pointer">Show N unset attributes</summary>` (N = `hidden.size`). No JS.
- The "No attributes defined" empty state stays.

**Catalog tab (`_catalog_attributes.html.erb`).**

- Header row compacts to one line: catalog name and state badge on the left; on the right a text link "View catalog" (`catalog_items_path`, `data-turbo-frame="_top"`) and a red text `button_to "Remove"` with the existing `turbo_confirm` and frame target. The large buttons are removed.
- Attribute rows use the shared row layout. The current skip rule stays: attributes with neither an override nor a product value are not rendered on catalog tabs.
- The override row markup is extracted to `products/catalog_tabs/_catalog_override_row.html.erb` (locals: `catalog_override`, `product_attribute`, `product_value`, `catalog_item`, `product`). It includes the outer row `div` with `id: dom_id(catalog_override, :value)`; the `turbo_frame_tag` is dropped for the same reason as above. The inherited row markup is inline in `_catalog_attributes` (no editor).
- "Product value: X" for an override that differs from the product value moves to a `title` tooltip on the value and a small `text-xs text-gray-400` line inside the editor form only.
- The "Add Attribute Override" modal and its trigger button stay, trigger rendered `size: :sm` right-aligned in a `px-6 py-3` footer row.

**Override update response.** `app/views/catalog_item_attribute_values/update.turbo_stream.erb` stops inlining row markup and instead replaces the whole panel exactly like `create.turbo_stream.erb` and `destroy.turbo_stream.erb` already do (panel replace plus tab badge update).

**Padding.** `CatalogTabsComponent` renders its panels without the outer `p-6` so rows can use their own `px-6`.

### 5. `Products::ImagesComponent`

Stays in the left column. The card uses `padding: :sm`.

- Header: "Images" with the count badge when images exist; header action: an "Upload" control rendered as a `<label for="file-upload">` styled with the secondary button classes, pointing at the existing hidden file input. A label works from outside the form.
- The existing `form_with ... data: { controller: "image-upload" }` stays the controller element, because the controller reads `this.element.action`. The form now wraps only the collapsed body: the thumbnail strip (or the empty-state line), the hidden file input, and the `progressContainer`. The strip wrapper carries `data-image-upload-target="dropzone"` and the existing drop / dragover / dragleave actions, so dropping files onto the strip uploads them. The dashed dropzone box is removed.
- Thumbnail strip (default view): `flex gap-2 overflow-x-auto`, each thumbnail `h-16 w-16 rounded object-cover`, primary first with the existing star marker scaled to `h-4 w-4` in the corner. When there are more than 8 images, the strip shows the first 7 followed by one `h-16 w-16` tile reading "+N" where N = total − 7. Alt text as today.
- After the form: `<details>` with `<summary class="text-sm text-blue-600 cursor-pointer">Manage images</summary>` wrapping the existing gallery block (main preview, select-all, sortable grid with reorder / set primary / metadata / delete, bulk toolbar, metadata modal) unchanged. The four Stimulus controllers stay on the same wrapper element they have today; the wrapper moves inside the `<details>`. The details sit outside the upload form so the metadata modal's form is not nested.
- Empty state: one line `text-sm text-gray-500` "No images yet. Upload or drop files here." inside the dropzone wrapper. No details toggle.

### 6. `Products::LabelsComponent`

- The `data-controller="product-label-manager"` wrapper moves outside the card so it encloses both the header action and the body.
- Header: "Labels"; header action: `Ui::ModalComponent` (`size: :md`, `modal_id: "add-label-modal-#{product.id}"`) with a trigger rendered as a small secondary "Add" button. The modal body holds the existing search input, `labelList`, `labelOption` buttons and `emptyState` markup unchanged. Modal footer: a Close button.
- Body (`padding: :sm`): the existing `selectedContainer` chips markup and `emptyMessage`, without the "Selected Labels" heading and without the surrounding bordered box.
- Controller JS is unchanged. Adding a label from the modal updates the chips behind it; the modal stays open until closed.

### 7. `Products::ConfigurableCardComponent` (moved to sidebar, compacted)

Still `render?` only for configurables. Card `padding: :sm`.

- Header: "Variants" with a `:gray` count badge showing `variants_count`. The configuration type badge moves next to it, `size: :sm`.
- Body: one line per configuration: `dt` name (`text-xs font-medium text-gray-500 w-14 shrink-0`) and a `flex flex-wrap gap-1` of `size: :sm` value chips. The stat tiles are removed. The "generate up to N combinations" hint stays as one `text-xs text-blue-700` line, shown only when `can_generate_variants? && variants_count < possible_combinations`. The "No configurations" empty state stays, shortened to one line.
- Footer (`text-sm`): links "Manage variants →" (`product_variants_path`) and "Configurations →" (`product_configurations_path`), side by side.

### 8. Sidebar cards

- `InventorySummaryComponent`: card `padding: :sm`. Otherwise unchanged.
- Shopify Sync Preview markup in `show.html.erb`: unchanged.
- `ActivityTimelineComponent`: `limit(5)` becomes `limit(3)`; `pb-8` becomes `pb-4`. Otherwise unchanged.

### 9. Deleted files

- `app/components/products/basic_info_component.rb` and `.html.erb`
- `app/components/products/status_card_component.rb` and `.html.erb`
- `spec/components/products/basic_info_component_spec.rb`
- `spec/components/products/status_card_component_spec.rb`

`Products::AttributesComponent` is already unused before this change and is left alone.

### 10. Out of scope

- A Components card for bundle products (the show page has none today).
- Formatting price and weight attribute values through `ProductAttribute#avjson`. Raw stored values keep displaying as today.
- A matrix view with one column per catalog.
- Mobile layout changes beyond the existing single-column stacking.
- Any change to the edit page, variants, configurations, inventories, assets, or versions pages.

## Testing

Component specs (`bundle exec rspec spec/components/products`):

- `header_component_spec.rb` (new): status badge text and variant class for active, draft, discontinued, disabled; type label with and without configuration type; facts strip shows SKU, EAN dash when blank, restock level, "ago" text; Edit link; Deactivate button with confirm when active, Activate when inactive; More menu contains Assets, Duplicate, Delete; inactive variants notice appears only for an inactive configurable with inactive subproducts and shows the counts.
- `catalog_tabs_component_spec.rb` (new): Product tab renders one row per attribute with `id` = `dom_id(attribute, :value)`; non-mandatory unset attributes are inside `details` with a summary "Show N unset attributes"; mandatory unset attributes are outside the details with a Required badge; catalog tab shows the Override badge and edit/remove buttons for overrides and an `inherited` tag for inherited values; attributes with neither are absent; the catalog header has View catalog and Remove.
- `images_component_spec.rb` (update): thumbnail strip renders up to 8 thumbnails and a "+N" tile beyond that; primary image is first; the gallery is inside `details`; empty state is the one-line message with no `details`; the Upload label targets the file input.
- `labels_component_spec.rb` (update): chips render for assigned labels; the picker (search input and label options) is inside the modal; the controller wrapper encloses the modal trigger.
- `configurable_card_component_spec.rb` (new): does not render for sellable; renders "Variants" with count; one line per configuration with value chips; hint shown only when combinations exceed variants; both footer links present.
- `activity_timeline_component_spec.rb` (update): at most 3 entries.

Request specs: `spec/requests/products_spec.rb` show and toggle_active examples must still pass unchanged. `spec/requests/product_attribute_values_spec.rb` and `spec/requests/product_catalogs_spec.rb` must pass unchanged. Add one example to the catalog item attribute values request spec asserting the turbo_stream update response targets `panel-<catalog code>`.

System spec: `spec/system/accessibility/page_accessibility_spec.rb` product details examples must pass (axe, WCAG 2.1 AA).

Manual verification in the Orca browser tab on product 206 at 1447×909:

- `document.documentElement.scrollHeight` ≤ 1000 on the European Webshop tab and on the Product tab with unset attributes collapsed.
- Inline edit of a Product-tab attribute saves and re-renders the row twice in a row without a page reload.
- Editing an override on the catalog tab re-renders the panel and keeps the tab selected.
- Add label from the modal adds a chip; remove chip works.
- Upload button opens the file picker; Manage images reveals the gallery.
- Deactivate re-renders the header with the Activate button and the status badge.
