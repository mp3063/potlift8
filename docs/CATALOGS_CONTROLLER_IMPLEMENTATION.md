# Catalogs Controller Implementation

## Overview

Implemented the CatalogsController for managing product catalogs in the Potlift8 inventory management system. The controller follows Rails 8 conventions and multi-tenant architecture patterns established in the project.

## Files Created/Modified

### Created:
- `app/controllers/catalogs_controller.rb` - Main controller implementation

### Modified:
- `config/routes.rb` - Added catalog routes with custom member actions

---

## Controller Actions

### Standard CRUD Actions

#### `index` - GET /catalogs
Lists all catalogs for the current company.

**Features:**
- Eager loads `catalog_items` and `products` associations
- Orders by `created_at DESC`
- Supports Turbo Stream format

**Response Formats:**
- `html` - Default HTML view
- `turbo_stream` - For dynamic updates

---

#### `show` - GET /catalogs/:code
Shows catalog details.

**Behavior:**
- Redirects to `items_catalog_path(@catalog)` to display catalog items
- Uses catalog `code` as URL parameter (not `id`)

---

#### `new` - GET /catalogs/new
Renders form for creating a new catalog.

**Features:**
- Builds new catalog scoped to `current_potlift_company`

---

#### `edit` - GET /catalogs/:code/edit
Renders form for editing an existing catalog.

---

#### `create` - POST /catalogs
Creates a new catalog.

**Features:**
- Scoped to `current_potlift_company`
- Strong parameters validation
- Turbo Stream support
- Success: Redirects to `catalogs_path` with notice
- Failure: Renders `:new` with 422 status

**Strong Parameters:**
- `name` - Catalog display name
- `code` - Unique catalog identifier (URL-safe)
- `catalog_type` - Type of catalog (webshop, supply)
- `currency_code` - ISO currency code (eur, sek, nok)
- `description` - Optional catalog description
- `active` - Boolean flag for catalog status

---

#### `update` - PATCH /catalogs/:code
Updates an existing catalog.

**Features:**
- Same as `create` but updates existing record
- Turbo Stream support
- Success: Redirects to `catalogs_path` with notice
- Failure: Renders `:edit` with 422 status

---

#### `destroy` - DELETE /catalogs/:code
Destroys a catalog and all associated catalog items.

**Features:**
- Cascade deletes via `dependent: :destroy` on associations
- Turbo Stream support
- Redirects to `catalogs_path` with notice

---

### Custom Member Actions

#### `items` - GET /catalogs/:code/items
Lists catalog items (products in this catalog) with pagination.

**Features:**
- Eager loads product associations (labels, inventories, attribute values)
- Ordered by priority (DESC)
- Search filter by product name or SKU (case-insensitive)
- Pagination (25 items per page default)
- Turbo Stream support

**Query Parameters:**
- `page` - Page number (default: 1)
- `per_page` - Items per page (default: 25)
- `q` - Search query (matches product name or SKU)

**Response Formats:**
- `html` - Default HTML view with pagination
- `turbo_stream` - For dynamic updates

---

#### `reorder_items` - PATCH /catalogs/:code/reorder_items
Reorders catalog items by updating their priority values.

**Use Case:**
- Drag-and-drop interfaces via AJAX
- Batch priority updates

**Parameters:**
- `order` - Array of `catalog_item_id` values in desired order

**Priority Logic:**
- Priority is 1-based, higher numbers appear first (default scope: `DESC`)
- First item in array gets highest priority: `order.length`
- Last item in array gets lowest priority: `1`
- Example: `[100, 200, 300]` → priorities: `3, 2, 1`

**Response:**
- `200 OK` with no body on success
- `422 Unprocessable Entity` if order parameter is missing/invalid or if catalog items not found

**Transaction Safety:**
- Wrapped in `ActiveRecord::Base.transaction` for atomicity
- Rolls back all changes if any update fails

---

#### `export` - GET /catalogs/:code/export
Exports catalog data in JSON or CSV format.

**Response Formats:**

##### JSON Format (`format.json`)
Returns structured JSON with catalog metadata and all items:

```json
{
  "catalog": {
    "code": "webshop-eu",
    "name": "European Webshop",
    "catalog_type": "webshop",
    "currency_code": "eur",
    "products_count": 150
  },
  "items": [
    {
      "id": 1,
      "priority": 100,
      "catalog_item_state": "active",
      "product": {
        "id": 42,
        "sku": "ABC-123",
        "name": "Product Name",
        "product_type": "sellable",
        "product_status": "active",
        "ean": "1234567890123",
        "labels": [
          { "id": 1, "name": "Electronics" }
        ],
        "attributes": {
          "price": "1999",
          "weight": "500"
        }
      }
    }
  ]
}
```

**Features:**
- Includes all catalog metadata
- Full product details for each item
- Effective attribute values (catalog overrides + product fallbacks)
- All labels associated with product

##### CSV Format (`format.csv`)
Returns CSV file with flattened data:

**CSV Headers:**
- Priority
- State
- Product SKU
- Product Name
- Product Type
- Product Status
- EAN
- Labels (comma-separated)
- Price
- Weight
- Stock (sum of all inventory quantities)

**Filename Format:**
`catalog_{code}_{timestamp}.csv`

Example: `catalog_webshop-eu_20250115_143022.csv`

---

## Routes Configuration

### Resource Routes
```ruby
resources :catalogs, param: :code do
  member do
    get :items
    patch :reorder_items
    get :export
  end
end
```

**Key Feature:**
- Uses `param: :code` to use catalog code in URLs instead of ID
- Example: `/catalogs/webshop-eu` instead of `/catalogs/1`

### Generated Routes

| HTTP Method | Path | Action | Name |
|-------------|------|--------|------|
| GET | /catalogs | index | catalogs_path |
| POST | /catalogs | create | catalogs_path |
| GET | /catalogs/new | new | new_catalog_path |
| GET | /catalogs/:code | show | catalog_path(code) |
| GET | /catalogs/:code/edit | edit | edit_catalog_path(code) |
| PATCH/PUT | /catalogs/:code | update | catalog_path(code) |
| DELETE | /catalogs/:code | destroy | catalog_path(code) |
| GET | /catalogs/:code/items | items | items_catalog_path(code) |
| PATCH | /catalogs/:code/reorder_items | reorder_items | reorder_items_catalog_path(code) |
| GET | /catalogs/:code/export | export | export_catalog_path(code) |

---

## Multi-Tenancy Implementation

### Company Scoping
All queries are automatically scoped to `current_potlift_company`:

```ruby
# Index action
@catalogs = current_potlift_company.catalogs

# Set catalog (before_action)
@catalog = current_potlift_company.catalogs.find_by!(code: params[:id])
```

**Security:**
- Ensures users can only access catalogs belonging to their company
- Raises `ActiveRecord::RecordNotFound` if catalog doesn't belong to company
- No cross-company data leakage

### URL Parameter Strategy
Uses catalog `code` instead of `id` for:
- Cleaner, more readable URLs
- Better SEO (if applicable)
- Matches catalog model's unique identifier

**Implementation:**
```ruby
# In routes
resources :catalogs, param: :code

# In controller
def set_catalog
  @catalog = current_potlift_company.catalogs.find_by!(code: params[:id])
end
```

---

## Key Implementation Details

### 1. Eager Loading
Prevents N+1 queries by preloading associations:

```ruby
# Index
.includes(:catalog_items, :products)

# Items
.includes(product: [:labels, :inventories, :product_attribute_values])
```

### 2. Priority Ordering
Catalog items are ordered by priority (highest first):

```ruby
@catalog_items = @catalog.catalog_items.by_priority
# Uses scope: order(Arel.sql('catalog_items.priority DESC NULLS LAST'))
```

### 3. Search Implementation
Case-insensitive search across product name and SKU:

```ruby
if params[:q].present?
  search_term = "%#{params[:q]}%"
  @catalog_items = @catalog_items.joins(:product)
                                 .where("products.name ILIKE ? OR products.sku ILIKE ?",
                                        search_term, search_term)
end
```

### 4. Turbo Stream Support
All CRUD actions support Turbo Stream for dynamic updates without full page reloads:

```ruby
respond_to do |format|
  format.html { redirect_to catalogs_path, notice: 'Catalog created successfully.' }
  format.turbo_stream { flash.now[:notice] = 'Catalog created successfully.' }
end
```

### 5. CSV Export
Built-in CSV generation without external service (for now):

```ruby
require 'csv'

csv_data = CSV.generate(headers: true) do |csv|
  csv << ['Priority', 'State', 'Product SKU', ...]
  catalog_items.each do |item|
    csv << [item.priority, item.catalog_item_state, ...]
  end
end
```

### 6. Effective Attribute Values
Uses `CatalogItem#effective_attribute_value` to get catalog overrides:

```ruby
# Returns catalog-specific value if exists, otherwise product value
item.effective_attribute_value('price')
```

---

## Usage Examples

### Creating a Catalog

```ruby
# Form params
catalog_params = {
  name: "European Webshop",
  code: "webshop-eu",
  catalog_type: "webshop",
  currency_code: "eur",
  description: "Main webshop for EU market",
  active: true
}

# Controller creates catalog scoped to company
@catalog = current_potlift_company.catalogs.build(catalog_params)
@catalog.save
```

### Reordering Catalog Items

```javascript
// Frontend AJAX request
fetch('/catalogs/webshop-eu/reorder_items', {
  method: 'PATCH',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': csrfToken
  },
  body: JSON.stringify({
    order: [100, 200, 300] // Catalog item IDs in desired order
  })
})
```

### Exporting Catalog Data

```ruby
# JSON export
GET /catalogs/webshop-eu/export.json

# CSV export
GET /catalogs/webshop-eu/export.csv
```

---

## Testing Checklist

### Unit Tests (Controller)
- [ ] `index` - Lists catalogs for current company
- [ ] `show` - Redirects to items action
- [ ] `items` - Lists catalog items with pagination
- [ ] `items` - Search filter works (name and SKU)
- [ ] `new` - Renders new form
- [ ] `create` - Creates catalog with valid params
- [ ] `create` - Fails with invalid params
- [ ] `edit` - Renders edit form
- [ ] `update` - Updates catalog with valid params
- [ ] `update` - Fails with invalid params
- [ ] `destroy` - Deletes catalog
- [ ] `reorder_items` - Reorders with valid order array
- [ ] `reorder_items` - Fails with missing order param
- [ ] `reorder_items` - Fails with invalid catalog item IDs
- [ ] `export` - Returns JSON format
- [ ] `export` - Returns CSV format with correct headers
- [ ] Multi-tenancy - Cannot access catalogs from other companies

### Integration Tests (System/Request)
- [ ] Full CRUD workflow
- [ ] Turbo Stream responses
- [ ] CSV download with correct filename
- [ ] JSON structure matches specification
- [ ] Priority ordering works correctly
- [ ] Search filtering works
- [ ] Pagination works

---

## Future Enhancements

### Potential Additions (Not Implemented Yet)

1. **CatalogExportService**
   - Extract CSV/JSON export logic to dedicated service
   - Support additional export formats (Excel, PDF)
   - Custom field selection for exports

2. **Bulk Operations**
   - Bulk add/remove products from catalog
   - Bulk update catalog item states (activate/deactivate)
   - Bulk priority updates

3. **Advanced Filtering**
   - Filter by product type
   - Filter by product status
   - Filter by labels
   - Filter by catalog item state

4. **Sync Operations**
   - Trigger sync for single catalog
   - Trigger sync for specific catalog items
   - View sync status and history

5. **Analytics**
   - Product performance in catalog
   - Conversion rates per catalog item
   - Most/least popular products

---

## Architecture Decisions

### Why Use `code` Instead of `id`?
- **Readable URLs**: `/catalogs/webshop-eu` vs `/catalogs/1`
- **Stable URLs**: Code doesn't change, IDs might differ across environments
- **SEO-friendly**: Descriptive codes better for search engines
- **Consistency**: Matches catalog's natural identifier

### Why Redirect `show` to `items`?
- **UX**: Most common use case is viewing catalog items
- **Flexibility**: Can add dedicated show page later without breaking URLs
- **Simplicity**: Reduces redundant views

### Why Include CSV Generation in Controller?
- **Simplicity**: Straightforward CSV export doesn't warrant separate service yet
- **Performance**: Direct generation is fast for typical catalog sizes
- **Maintainability**: Easy to extract to service later if needed

### Why Transaction Wrapper for Reordering?
- **Data Integrity**: All-or-nothing update ensures consistency
- **Error Handling**: Rolls back partial updates on failure
- **Reliability**: Prevents orphaned priority values

---

## Related Files

### Models
- `app/models/catalog.rb` - Catalog model with associations and validations
- `app/models/catalog_item.rb` - Join table with priority ordering

### Services (Future)
- `app/services/catalog_export_service.rb` - Extract export logic (not implemented yet)

### Views (To Be Created)
- `app/views/catalogs/index.html.erb` - Catalog listing
- `app/views/catalogs/show.html.erb` - Catalog details (optional)
- `app/views/catalogs/items.html.erb` - Catalog items listing
- `app/views/catalogs/new.html.erb` - New catalog form
- `app/views/catalogs/edit.html.erb` - Edit catalog form
- `app/views/catalogs/_form.html.erb` - Shared form partial

### Components (Recommended)
- `app/components/catalogs/table_component.rb` - Catalog listing table
- `app/components/catalogs/form_component.rb` - Catalog form
- `app/components/catalogs/items_table_component.rb` - Catalog items table

---

## Summary

The CatalogsController provides a complete CRUD interface for managing product catalogs with the following key features:

- **Multi-tenant Architecture**: All operations scoped to current company
- **Code-based URLs**: Uses catalog code instead of ID for cleaner URLs
- **Catalog Items Management**: View, search, and reorder products in catalogs
- **Export Functionality**: JSON and CSV export with complete product data
- **Turbo Stream Support**: Dynamic updates without full page reloads
- **Eager Loading**: Optimized queries to prevent N+1 problems
- **Priority Ordering**: Drag-and-drop friendly reordering with transaction safety

**Implementation Status**: ✅ Complete and ready for view layer implementation.
