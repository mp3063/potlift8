# Inline Editor Components

Quick reference for using inline editor partials in Potlift8.

## Overview

Inline editor components provide seamless in-place editing with:
- Display/edit mode toggle
- Keyboard navigation (Escape to cancel, Enter to submit)
- Visual feedback on save/error
- Full accessibility support
- Turbo-powered updates (no page reload)

## Components

### 1. Priority Editor (CatalogItem)

**File:** `app/views/catalog_items/_priority_editor.html.erb`

**Usage:**
```erb
<%= render "catalog_items/priority_editor",
           catalog: @catalog,
           catalog_item: @catalog_item %>
```

**Parameters:**
- `catalog_item` (required) - The CatalogItem instance
- `catalog` (optional) - The Catalog instance (defaults to `catalog_item.catalog`)

**Field:**
- Edits: `catalog_item.priority` (integer)
- Input: Number field (w-20)
- Submits to: `PATCH /catalogs/:catalog_id/catalog_items/:id`

**Example in Table:**
```erb
<td class="px-6 py-4 whitespace-nowrap">
  <%= render "catalog_items/priority_editor",
             catalog: catalog,
             catalog_item: item %>
</td>
```

---

### 2. ETA Quantity Editor (Inventory)

**File:** `app/views/inventories/_eta_quantity_editor.html.erb`

**Usage:**
```erb
<%= render "inventories/eta_quantity_editor",
           storage: @storage,
           inventory: @inventory %>
```

**Parameters:**
- `inventory` (required) - The Inventory instance
- `storage` (optional) - The Storage instance (defaults to `inventory.storage`)

**Field:**
- Edits: `inventory.value` (integer, quantity)
- Input: Number field (w-24, min: 0)
- Submits to: `PATCH /storages/:storage_id/inventories/:id`

**Note:** Field is named `value` in database for pot3 compatibility, but represents quantity.

**Example in Table:**
```erb
<td class="px-6 py-4 whitespace-nowrap">
  <%= render "inventories/eta_quantity_editor",
             storage: storage,
             inventory: inventory %>
</td>
```

---

### 3. ETA Date Editor (Inventory)

**File:** `app/views/inventories/_eta_date_editor.html.erb`

**Usage:**
```erb
<%= render "inventories/eta_date_editor",
           storage: @storage,
           inventory: @inventory %>
```

**Parameters:**
- `inventory` (required) - The Inventory instance
- `storage` (optional) - The Storage instance (defaults to `inventory.storage`)

**Field:**
- Edits: `inventory.eta` (date)
- Input: Date field (w-40)
- Display: Formatted as "MMM DD, YYYY" (e.g., "Jan 15, 2025")
- Submits to: `PATCH /storages/:storage_id/inventories/:id`

**Example in Table:**
```erb
<td class="px-6 py-4 whitespace-nowrap">
  <%= render "inventories/eta_date_editor",
             storage: storage,
             inventory: inventory %>
</td>
```

---

## Features

### Display Mode
- Shows current value or "—" if null/empty
- Pencil icon appears on hover (opacity transition)
- Icon has `aria-label` for accessibility
- Group hover effect

### Edit Mode
- Auto-focuses input field
- Selects existing value for easy replacement
- Blue-600 Save button
- Gray Cancel button
- Proper labels (screen-reader only)
- Error messages displayed inline

### Keyboard Support
- **Escape** - Cancel editing and return to display mode
- **Enter** - Submit form (single input fields)
- **Tab** - Navigate between input, Save, and Cancel buttons
- Focus returns to edit icon after save/cancel

### Visual Feedback
- **Success:** Green highlight ring for 1 second
- **Error:** Red ring on editor, stays for 3 seconds
- Screen reader announcements for status changes

---

## Controller Integration

All editors use the `inline_editor_controller.js` Stimulus controller.

**Required Controller Actions:**
```ruby
# app/controllers/catalog_items_controller.rb
def update
  if @catalog_item.update(catalog_item_params)
    respond_to do |format|
      format.html { redirect_to @catalog_item }
      format.turbo_stream  # For Turbo Frame updates
    end
  else
    render :edit, status: :unprocessable_entity
  end
end
```

**Required Routes:**
```ruby
# config/routes.rb
resources :catalogs do
  resources :catalog_items, only: [:update]
end

resources :storages do
  resources :inventories, only: [:update]
end
```

---

## Accessibility

All inline editors are WCAG 2.1 AA compliant:

✓ Keyboard navigation (Tab, Enter, Escape)
✓ ARIA labels on icon-only buttons
✓ Screen-reader only labels on form fields
✓ Focus management (returns to trigger)
✓ Error announcements (role="alert")
✓ Status announcements (role="status")
✓ Visible focus indicators (blue-500 ring)

---

## Styling

All components use Tailwind CSS with consistent styling:

**Inputs:**
- Border: `border-gray-300`
- Focus: `focus:border-blue-500 focus:ring-blue-500`
- Size: `sm:text-sm`
- Rounded: `rounded-lg`

**Buttons:**
- Primary (Save): `bg-blue-600 hover:bg-blue-700`
- Secondary (Cancel): `bg-white hover:bg-gray-50 border-gray-300`
- Size: `text-xs px-3 py-1.5`

**Icons:**
- Size: `h-4 w-4`
- Color: `text-gray-400 hover:text-gray-600`
- Visibility: `opacity-0 group-hover:opacity-100`

---

## Example Usage in Views

### Catalog Items Table
```erb
<table class="min-w-full divide-y divide-gray-300">
  <thead>
    <tr>
      <th>Product</th>
      <th>Priority</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-gray-200">
    <% @catalog.catalog_items.each do |item| %>
      <tr>
        <td><%= item.product.name %></td>
        <td>
          <%= render "catalog_items/priority_editor",
                     catalog: @catalog,
                     catalog_item: item %>
        </td>
        <td><%= item.catalog_item_state %></td>
      </tr>
    <% end %>
  </tbody>
</table>
```

### Inventory Management Table
```erb
<table class="min-w-full divide-y divide-gray-300">
  <thead>
    <tr>
      <th>Storage</th>
      <th>Quantity</th>
      <th>ETA Date</th>
    </tr>
  </thead>
  <tbody class="divide-y divide-gray-200">
    <% @product.inventories.each do |inventory| %>
      <tr>
        <td><%= inventory.storage.name %></td>
        <td>
          <%= render "inventories/eta_quantity_editor",
                     storage: inventory.storage,
                     inventory: inventory %>
        </td>
        <td>
          <%= render "inventories/eta_date_editor",
                     storage: inventory.storage,
                     inventory: inventory %>
        </td>
      </tr>
    <% end %>
  </tbody>
</table>
```

---

## Testing

Example RSpec tests for inline editor partials:

```ruby
# spec/views/catalog_items/_priority_editor.html.erb_spec.rb
require "rails_helper"

RSpec.describe "catalog_items/priority_editor", type: :view do
  let(:company) { create(:company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:product) { create(:product, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product, priority: 10) }

  it "displays priority value" do
    render partial: "catalog_items/priority_editor",
           locals: { catalog: catalog, catalog_item: catalog_item }

    expect(rendered).to have_text("10")
    expect(rendered).to have_css('[aria-label="Edit priority"]')
  end

  it "displays dash when priority is nil" do
    catalog_item.update!(priority: nil)

    render partial: "catalog_items/priority_editor",
           locals: { catalog: catalog, catalog_item: catalog_item }

    expect(rendered).to have_text("—")
  end

  it "includes edit form with correct action" do
    render partial: "catalog_items/priority_editor",
           locals: { catalog: catalog, catalog_item: catalog_item }

    expect(rendered).to have_css('form[action*="catalog_items"]')
    expect(rendered).to have_css('input[type="number"][name="catalog_item[priority]"]')
  end
end
```

---

## Troubleshooting

### Editor doesn't open
- Verify `inline_editor_controller.js` is imported in `application.js`
- Check browser console for Stimulus errors
- Ensure `data-controller="inline-editor"` is present

### Form doesn't submit
- Verify routes are configured correctly
- Check controller has `update` action
- Ensure Turbo is enabled (not disabled on form)

### Success feedback not showing
- Verify `turbo:submit-end` event is firing
- Check controller responds with Turbo Stream or redirects
- Ensure no JavaScript errors in console

### Focus not returning
- Verify edit button has proper `data-action` attribute
- Check `previousActiveElement` is being stored in controller
- Ensure edit button is not removed from DOM on update

---

## Related Files

- **Controller:** `app/javascript/controllers/inline_editor_controller.js`
- **Routes:** `config/routes.rb`
- **Models:**
  - `app/models/catalog_item.rb`
  - `app/models/inventory.rb`
- **Controllers:**
  - `app/controllers/catalog_items_controller.rb`
  - `app/controllers/inventories_controller.rb`
