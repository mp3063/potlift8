# Label-Based Filtering Implementation

## Overview

This document describes the implementation of hierarchical label-based filtering for the products index page in Potlift8.

## Features Implemented

### 1. Hierarchical Label Filtering

- **Parent Label Filtering**: When filtering by a parent label, products with child and grandchild labels are automatically included
- **Sublabel Filtering**: Filtering by a child label includes all products with that label and any descendant labels
- **Multi-Tenancy**: All label filtering respects company boundaries for security

### 2. User Interface Components

#### Filter Dropdown
- Accessible dropdown button with keyboard navigation
- Lists root labels with sublabels indented
- Shows product counts for each label (including descendants)
- Preserves existing filters (search query, product type)
- Gracefully handles empty label lists

#### Active Filter Display
- Blue filter chip showing the selected label's full hierarchical name
- Remove button (X) to clear the label filter
- Positioned below the search/filter controls
- Only displays when a label filter is active

#### Clear Filters Button
- Appears when any filter is active (search, type, or label)
- Removes all filters and returns to unfiltered view

### 3. Controller Implementation

**File**: `/app/controllers/products_controller.rb`

#### Key Changes:

1. **`load_filter_labels` Method** (lines 456-486):
   - Loads root labels with eager-loaded sublabels and products
   - Calculates product counts including descendants
   - Prevents N+1 queries with proper includes
   - Respects company scoping

2. **Enhanced `apply_filters` Method** (lines 397-417):
   - Finds the selected label with company scoping
   - Gets all descendant label IDs using `Label#descendants`
   - Filters products by label ID array (includes sublabels)
   - Handles invalid label IDs gracefully (ignores filter)
   - Sets `@current_label` for display in view
   - Qualifies column names (`products.name`) to avoid ambiguity when joining labels

3. **Updated `index` Action** (line 40):
   - Calls `load_filter_labels` before applying filters
   - Makes `@available_labels` and `@label_product_counts` available to view

### 4. View Implementation

**File**: `/app/views/products/index.html.erb`

#### Filter Dropdown (lines 55-101):
```erb
<div class="mt-4 sm:mt-0 relative" data-controller="dropdown">
  <button data-action="click->dropdown#toggle">
    Filter by Label
  </button>

  <div data-dropdown-target="menu" class="hidden">
    <% @available_labels.each do |label| %>
      <%= link_to products_path(label_id: label.id, ...) %>
        <%= label.name %> (<%= @label_product_counts[label.id] %>)
      <% end %>

      <!-- Sublabels with indentation -->
      <% label.sublabels.each do |sublabel| %>
        <%= link_to products_path(label_id: sublabel.id, ...) %>
      <% end %>
    <% end %>
  </div>
</div>
```

#### Active Filter Chip (lines 112-129):
```erb
<% if @current_label.present? %>
  <div class="flex flex-wrap gap-2 items-center">
    <span>Active filters:</span>
    <span class="inline-flex items-center bg-blue-100 text-blue-800 rounded-full px-3 py-1">
      <%= @current_label.full_name %>
      <%= link_to products_path(...) do %>
        <!-- X icon -->
      <% end %>
    </span>
  </div>
<% end %>
```

## Database Queries

### Label Hierarchy Traversal

The implementation uses `Label#descendants` method which recursively collects all descendant labels:

```ruby
def descendants
  sublabels.flat_map { |sublabel| [sublabel] + sublabel.descendants }
end
```

### Product Filtering Query

```sql
SELECT DISTINCT "products".*
FROM "products"
INNER JOIN "product_labels" ON "product_labels"."product_id" = "products"."id"
INNER JOIN "labels" ON "labels"."id" = "product_labels"."label_id"
WHERE "products"."company_id" = ?
  AND "labels"."id" IN (?, ?, ?, ...)  -- Parent + all descendants
ORDER BY "products"."created_at" DESC
```

### Product Count Calculation

For each label in the dropdown, we calculate:

```ruby
label_ids = [label.id] + label.descendants.pluck(:id)
count = current_potlift_company.products
                               .joins(:labels)
                               .where(labels: { id: label_ids })
                               .distinct
                               .count
```

## Performance Considerations

### Optimizations Applied:

1. **Eager Loading**: Labels are loaded with `includes(sublabels: :products)` to prevent N+1 queries
2. **Distinct Products**: `.distinct` ensures products with multiple labels are counted once
3. **Company Scoping**: All queries filter by `company_id` using indexes
4. **Qualified Column Names**: Using `products.name` prevents ambiguity and allows proper index usage

### Potential Improvements:

1. **Caching**: Product counts could be cached in Redis with cache invalidation on product/label changes
2. **Pagination**: For companies with many labels (>100), implement pagination in the dropdown
3. **Search**: Add search functionality within the label dropdown for large label hierarchies
4. **Recursive CTE**: For very deep label hierarchies (>5 levels), consider using PostgreSQL recursive CTEs instead of Ruby recursion

## Accessibility

- **Keyboard Navigation**: Full keyboard support via `dropdown_controller.js`
  - Tab to focus button
  - Enter/Space to open
  - Arrow keys to navigate
  - Escape to close
- **ARIA Attributes**:
  - `aria-expanded` on dropdown button
  - `aria-haspopup="true"` for dropdown
  - `role="menu"` and `role="menuitem"` for proper semantics
  - `aria-label` on remove filter button
- **Screen Reader Support**:
  - "Active filters:" label for context
  - Descriptive button text
  - Full label hierarchy read aloud

## Testing

### Test Coverage

**File**: `/spec/requests/products_spec.rb`

Added 9 comprehensive tests (lines 77-185):

1. ✅ Filters products by label
2. ✅ Displays active label filter chip
3. ✅ Preserves other filters when applying label filter
4. ✅ Filters by parent label includes products with child labels
5. ✅ Filters by child label includes products with grandchild labels
6. ✅ Filters by grandchild label only shows that level
7. ✅ Displays full hierarchical label name in filter chip
8. ✅ Handles invalid label_id gracefully
9. ✅ Prevents filtering by labels from other companies

### Test Results

```
88 examples, 0 failures
```

All existing tests continue to pass, ensuring backward compatibility.

## Security

### Multi-Tenancy Enforcement

1. **Label Lookup**: `current_potlift_company.labels.find(params[:label_id])`
   - Automatically scopes to current company
   - Raises `RecordNotFound` for labels from other companies

2. **Product Filtering**: `current_potlift_company.products.joins(:labels)`
   - All products pre-filtered by company_id
   - Even if label_id is compromised, only returns current company products

3. **Error Handling**: Invalid or unauthorized label IDs fail gracefully
   - Returns all products (no filter applied)
   - No error messages leak information about other companies

## UI/UX Design

### Design System Compliance

- **Color Scheme**: Blue-600 (#2563eb) for primary actions and selected state
- **Filter Chip**: Blue-100 background with blue-800 text (matches Authlift8 design)
- **Typography**: text-sm (14px) for filter UI, font-medium (500) for labels
- **Spacing**: Consistent with Potlift8 design system (px-4, py-2, gap-2)
- **Icons**: Heroicons SVG icons for dropdown chevron and remove X

### User Flow

1. User clicks "Filter by Label" button
2. Dropdown opens with keyboard focus on first label
3. User selects a label (click or Enter)
4. Page refreshes with filtered results
5. Active filter chip appears above product table
6. User can remove filter by clicking X on chip
7. User can clear all filters with "Clear" button

## Routes

No new routes required. Uses existing query parameter pattern:

```ruby
GET /products?label_id=123
GET /products?label_id=123&q=search&product_type=1
```

## Backward Compatibility

✅ **Fully Backward Compatible**

- No database migrations required
- No breaking changes to existing code
- All existing tests pass
- No changes to routes or URL structure
- Preserves existing filter behavior

## Future Enhancements

### Potential Features:

1. **Multi-Label Filtering**: Allow selecting multiple labels simultaneously
   - UI: Checkboxes instead of radio-style selection
   - Backend: Change `params[:label_id]` to `params[:label_ids]` array

2. **Label Search**: Add search input inside dropdown for large label lists
   - Filter labels client-side with JavaScript
   - Or implement server-side autocomplete

3. **Saved Filters**: Allow users to save common filter combinations
   - Store in user preferences or database
   - Quick access buttons for frequently used filters

4. **Filter Presets**: Admin-defined filter presets
   - "New Products" (last 7 days)
   - "Low Stock" (inventory < threshold)
   - "Needs Review" (specific label combinations)

5. **Export with Filters**: CSV export respects all active filters
   - ✅ Already implemented!
   - Downloads only filtered products

## Related Files

### Modified Files:
- `/app/controllers/products_controller.rb` - Controller logic
- `/app/views/products/index.html.erb` - Filter UI
- `/spec/requests/products_spec.rb` - Comprehensive tests

### Existing Files Used:
- `/app/models/label.rb` - Label hierarchy (`descendants` method)
- `/app/models/product.rb` - Product-label relationships
- `/app/javascript/controllers/dropdown_controller.js` - Dropdown interactions
- `/config/routes.rb` - No changes (uses query params)

## Summary

This implementation provides a robust, accessible, and performant label filtering system for the products index page. It leverages the existing label hierarchy to provide intuitive filtering that automatically includes products with descendant labels. The UI follows the Potlift8/Authlift8 design system and maintains full accessibility compliance.

**Key Achievements:**
- ✅ Hierarchical filtering with automatic sublabel inclusion
- ✅ Full multi-tenancy security
- ✅ Accessible UI with keyboard navigation
- ✅ Comprehensive test coverage (9 new tests)
- ✅ Backward compatible with zero breaking changes
- ✅ Performance optimized with eager loading
- ✅ Graceful error handling

---

**Implementation Date**: 2025-10-15
**Rails Version**: 8.0.3
**Ruby Version**: 3.4.7
**Test Status**: 88 examples, 0 failures ✅
