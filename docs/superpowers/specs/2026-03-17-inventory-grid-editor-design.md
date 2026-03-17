# Inventory Grid Editor — Design Spec

**Date:** 2026-03-17
**Status:** Draft

## Problem

There is no efficient way to set or edit product inventory amounts. The current flow requires navigating to a storage or product inventory page and opening a modal for each individual inventory record. For a configurable product with 12 variants × 3 storages = 36 inventory records, this means 36 separate modal interactions. Initial setup of inventory for new products is especially painful.

## Solution

An inline editable spreadsheet grid for inventory management, with a setup wizard for new products.

## Design

### 1. Full Inventory Grid Page (`/products/:id/inventories`)

Replaces the current per-row modal approach with an inline editable grid.

**By product type:**

- **Sellable:** Storages as rows, columns = Storage Name, On Hand (editable), ETA Qty, ETA Date, Total. Simple vertical table.
- **Configurable:** Spreadsheet — variant subproducts as rows, storages as columns. Each cell is an editable number input. Row totals on right, column totals at bottom.
- **Bundle:** Read-only calculated view via `BundleInventoryCalculator.detailed_breakdown`. No editable cells.

**Toolbar:**
- **Fill All** — enter a number, fills all empty cells (value == 0 or blank)
- **Fill Column** — click a storage column header dropdown to fill that column
- **Save All** — single form submission, batch update in a transaction
- **Add Storage** — dropdown to add product to a new storage location

**Dirty state:** Changed cells get `bg-yellow-50 border-yellow-400` highlight. `beforeunload` guard prevents accidental navigation.

**Keyboard:** Tab moves right, Enter moves down, standard focus behavior.

### 2. Setup Wizard (Zero Inventory State)

When product has no inventory, the grid page shows a two-step wizard:

**Step 1 — Pick Storages:** Checkbox list of company's active storages. Default storage pre-checked. "Select All" shortcut.

**Step 2 — Fill Grid:** Shows the spreadsheet grid with only selected storages as columns. "Fill All" input pre-focused. For configurable products, variant rows are shown.

Both steps on the same page — Step 2 replaces Step 1 via Stimulus controller. Final save goes to the same `batch_update` endpoint.

### 3. Product Show Page Sidebar

Modify `Products::InventorySummaryComponent`:

- **No inventory:** Show "Set Up Inventory" button linking to `/products/:id/inventories` (triggers wizard)
- **Has inventory:** Keep existing read-only display (total + per-storage breakdown). Change "View Details" to "Manage Inventory →" link.

No inline editing in sidebar — keeps it simple.

### 4. Storage View Inline Editing

On `/storages/:code/inventory`, replace "Adjust" modal with click-to-edit cells:

- Click quantity cell → becomes editable input
- Enter/Tab → saves via Turbo PATCH to `StorageInventoriesController#update`
- Escape → cancels edit
- Turbo Stream replaces the cell frame on success
- Keep existing "Add Products" bulk modal as-is

## Technical Design

### Routes

```ruby
# Add to existing product inventories
resources :inventories, only: [:index, :update], controller: "product_inventories" do
  collection do
    patch :batch_update
  end
end

# Add update to storage inventories
resources :inventories, only: [:new, :create, :update, :destroy], controller: "storage_inventories"
```

### Batch Update Endpoint

`ProductInventoriesController#batch_update` — receives flat hash params:

```ruby
params[:inventories] = {
  "42_5" => { "value" => "100" },     # product_id_storage_id => { value }
  "42_7" => { "value" => "25" },
  "101_5" => { "value" => "50" },     # subproduct for configurable
}
```

Wrapped in `ActiveRecord::Base.transaction` — all-or-nothing. Uses `Inventory.find_or_initialize_by(product_id:, storage_id:)` per cell. Handles ETA fields in `info` JSONB. On failure, re-renders grid with `@failed_cells` for error highlighting.

### Eager Loading (Configurable Products)

```ruby
# 3 queries total, regardless of variant/storage count:
subproduct_ids = @product.product_configurations_as_super.order(:configuration_position).pluck(:subproduct_id)
all_inventories = Inventory.where(product_id: subproduct_ids).includes(:storage).index_by { |inv| [inv.product_id, inv.storage_id] }
@subproducts = Product.where(id: subproduct_ids).includes(product_configurations_as_sub: :superproduct)
@storages = current_potlift_company.storages.active.order_by_importance
```

### Stimulus Controllers

1. **`inventory_grid_controller.js`** — Main grid: dirty tracking, total calculations, fill operations, keyboard nav, beforeunload guard
2. **`inventory_setup_controller.js`** — Setup wizard: step transitions, storage selection, grid building
3. **`inline_cell_controller.js`** — Storage view: click-to-edit single cells, Turbo PATCH on save

### ViewComponents

1. **`Products::InventoryGridComponent`** — Renders the grid form (branches by product_type)
2. **`Products::InventoryGridToolbarComponent`** — Fill All, Save All, Add Storage buttons
3. **`Storages::InlineInventoryCellComponent`** — Wraps a single value in turbo_frame with click-to-edit

### Form Structure

Grid cells as inputs: `<input name="inventories[{product_id}_{storage_id}][value]">` with `data-cell-key`, `data-row-id`, `data-col-id` for Stimulus targeting.

## Files

### New Files
| File | Purpose |
|------|---------|
| `app/javascript/controllers/inventory_grid_controller.js` | Grid Stimulus controller |
| `app/javascript/controllers/inventory_setup_controller.js` | Setup wizard controller |
| `app/javascript/controllers/inline_cell_controller.js` | Storage inline edit controller |
| `app/components/products/inventory_grid_component.rb` + `.html.erb` | Grid ViewComponent |
| `app/components/products/inventory_grid_toolbar_component.rb` + `.html.erb` | Toolbar ViewComponent |
| `app/components/storages/inline_inventory_cell_component.rb` + `.html.erb` | Inline cell ViewComponent |
| `app/views/storage_inventories/update.turbo_stream.erb` | Turbo Stream for inline save |
| `spec/components/products/inventory_grid_component_spec.rb` | Component tests |
| `spec/requests/product_inventories_batch_update_spec.rb` | Request tests |

### Modified Files
| File | Changes |
|------|---------|
| `config/routes.rb` | Add `batch_update` collection route, add `update` to storage_inventories |
| `app/controllers/product_inventories_controller.rb` | Add `batch_update`, redesign `index` with product_type branching |
| `app/controllers/storage_inventories_controller.rb` | Add `update` action |
| `app/views/product_inventories/index.html.erb` | Replace with grid layout using ViewComponents |
| `app/views/storages/_inventory_row.html.erb` | Wrap value cell in InlineInventoryCellComponent |
| `app/components/products/inventory_summary_component.html.erb` | Add "Set Up Inventory" CTA, rename link |
| `app/policies/product_inventory_policy.rb` | Add `batch_update?` |
| `app/policies/storage_inventory_policy.rb` | Add `update?` |
