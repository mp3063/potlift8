# Labels Controller - Quick Reference Guide

## Routes

```ruby
# List labels
GET /labels                          # Root labels
GET /labels?parent_id=5              # Sublabels of parent ID 5
GET /labels?q=electronics            # Search labels

# Show label
GET /labels/electronics-phones       # Show label by full_code

# New label
GET /labels/new                      # New root label
GET /labels/new?parent_id=5          # New sublabel of parent ID 5

# Edit label
GET /labels/electronics-phones/edit  # Edit label

# Create label
POST /labels
# params: { label: { name:, code:, label_type:, parent_label_id: } }

# Update label
PATCH /labels/electronics-phones
# params: { label: { name:, description: } }

# Delete label
DELETE /labels/electronics-phones

# Reorder labels
PATCH /labels/reorder
# params: { order: [3, 1, 2], parent_id: 5 }
```

## Controller Actions

| Action | Purpose | Parameters | Returns |
|--------|---------|------------|---------|
| `index` | List labels | `parent_id`, `q`, `page`, `per_page` | HTML/Turbo |
| `show` | Display label details | `id` (full_code) | HTML |
| `new` | New label form | `parent_id` | HTML |
| `edit` | Edit label form | `id` (full_code) | HTML |
| `create` | Create new label | `label: {...}` | Redirect + flash |
| `update` | Update existing label | `id`, `label: {...}` | Redirect + flash |
| `destroy` | Delete label | `id` (full_code) | Redirect + flash |
| `reorder` | Reorder labels | `order: [], parent_id:` | JSON |

## Strong Parameters

Permitted attributes in forms:

```ruby
:name
:code
:description
:label_type
:parent_label_id
:product_default_restriction
```

## Deletion Rules

A label can only be deleted if:
- ❌ Has NO sublabels
- ❌ Has NO associated products

Error messages will indicate:
- "Cannot delete label 'Name' because it has N sublabel(s)"
- "Cannot delete label 'Name' because it is assigned to N product(s)"

## Common Patterns

### Creating Labels

```ruby
# Root label
Label.create!(
  company: current_potlift_company,
  code: 'electronics',
  name: 'Electronics',
  label_type: 'category'
)

# Child label
Label.create!(
  company: current_potlift_company,
  code: 'phones',
  name: 'Phones',
  label_type: 'category',
  parent_label_id: parent.id
)
```

### Querying Labels

```ruby
# Root labels
current_potlift_company.labels.root_labels

# Sublabels
parent_label.sublabels

# Search
current_potlift_company.labels.where("name ILIKE ?", "%search%")
```

### Reordering via AJAX

```javascript
fetch('/labels/reorder', {
  method: 'PATCH',
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
  },
  body: JSON.stringify({
    order: [3, 1, 2],
    parent_id: null  // or specific parent ID
  })
})
.then(response => response.json())
.then(data => {
  if (data.success) {
    console.log('Reordered successfully');
  }
});
```

## Testing

Run tests:
```bash
# All label tests
bundle exec rspec spec/requests/labels_spec.rb

# Specific test
bundle exec rspec spec/requests/labels_spec.rb:30

# With documentation
bundle exec rspec spec/requests/labels_spec.rb --format documentation
```

## Security

All actions are:
- ✅ Protected by OAuth2 authentication
- ✅ Scoped to `current_potlift_company`
- ✅ Using strong parameters
- ✅ Preventing cross-company access

## Multi-Tenancy

Every query is automatically scoped:
```ruby
current_potlift_company.labels.find(...)
current_potlift_company.labels.root_labels
current_potlift_company.labels.where(...)
```

## Error Handling

| Scenario | HTTP Status | Message |
|----------|-------------|---------|
| Not authenticated | 302 (Redirect) | Redirects to login |
| Label not found | 404 | ActiveRecord::RecordNotFound |
| Other company's label | 404 | ActiveRecord::RecordNotFound |
| Invalid form data | 422 | Renders form with errors |
| Delete with sublabels | 302 (Redirect) | Alert message with count |
| Delete with products | 302 (Redirect) | Alert message with count |
| Invalid reorder params | 422 | JSON error response |

## Implementation Status

✅ **Complete:**
- LabelsController with all CRUD actions
- Reorder action with JSON API
- Multi-tenant security
- Routes configuration
- Comprehensive test suite (64 tests)

❌ **Pending:**
- View templates (index, show, new, edit, _form)
- ViewComponents (optional, recommended)
- Stimulus controllers (drag-and-drop, forms)
- System/integration tests (after views)

## Files

- **Controller:** `/app/controllers/labels_controller.rb`
- **Routes:** `/config/routes.rb` (lines 97-101)
- **Model:** `/app/models/label.rb` (already exists)
- **Tests:** `/spec/requests/labels_spec.rb`
- **Factories:** `/spec/factories/labels.rb` (already exists)

## Next Steps

1. Create view templates in `/app/views/labels/`
2. Test manually via browser
3. Implement drag-and-drop reordering UI
4. Add breadcrumb navigation for hierarchy
5. Create ViewComponents for reusability

## Support

For implementation details, see:
- **Full Documentation:** `/LABELS_CONTROLLER_IMPLEMENTATION_SUMMARY.md`
- **Controller Code:** `/app/controllers/labels_controller.rb`
- **Model Code:** `/app/models/label.rb`
- **Test Specs:** `/spec/requests/labels_spec.rb`
