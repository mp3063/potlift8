# Search API Reference

Quick reference guide for the Potlift8 global search system.

---

## Endpoints

### 1. Search (Multi-Scope)

**Endpoint:** `GET /search`

**Parameters:**
| Parameter | Type   | Required | Default | Description |
|-----------|--------|----------|---------|-------------|
| `q`       | String | Yes      | -       | Search query string |
| `scope`   | String | No       | `all`   | Search scope: `all`, `products`, `storage`, `attributes`, `labels`, `catalogs` |

**Response Formats:**
- `text/html` - Search results page
- `application/json` - JSON response with results

**Examples:**

```bash
# Search all scopes
GET /search?q=iPhone

# Search products only
GET /search?q=iPhone&scope=products

# JSON response
curl -H "Accept: application/json" \
  "http://localhost:3246/search?q=iPhone&scope=products"
```

**JSON Response Structure:**
```json
{
  "products": [
    {
      "id": 123,
      "sku": "IP-15",
      "name": "iPhone 15",
      "product_type": "sellable",
      "product_status": "active",
      "url": "/products/123"
    }
  ],
  "storage": [...],
  "attributes": [...],
  "labels": [...],
  "catalogs": [...]
}
```

---

### 2. Recent Searches

**Endpoint:** `GET /search/recent`

**Parameters:** None

**Response Format:** `application/json`

**Response Structure:**
```json
["iPhone", "Samsung", "Google Pixel"]
```

**Example:**
```bash
curl -H "Accept: application/json" \
  "http://localhost:3246/search/recent"
```

---

## Search Scopes

### `all` (Default)
- Searches all scopes
- Returns up to 5 results per scope
- Total: Up to 25 results (5 × 5 scopes)

### `products`
- Searches: name, sku, description
- Sorting: product_status ASC, name ASC
- Limit: 50 results

### `storage`
- Searches: name, code, address
- Filter: Active storages only
- Sorting: name ASC
- Limit: 50 results

### `attributes`
- Searches: name, code
- Sorting: attribute_position ASC
- Limit: 50 results

### `labels`
- Searches: name, full_name
- Sorting: label_positions ASC
- Limit: 50 results

### `catalogs`
- Searches: name, code
- Sorting: name ASC
- Limit: 50 results

---

## JSON Response Fields

### Products
| Field            | Type   | Description |
|------------------|--------|-------------|
| `id`             | Integer | Product ID |
| `sku`            | String  | Product SKU |
| `name`           | String  | Product name |
| `product_type`   | String  | Type: `sellable`, `configurable`, `bundle` |
| `product_status` | String  | Status: `active`, `draft`, etc. |
| `url`            | String  | Product detail URL |

### Storage
| Field          | Type   | Description |
|----------------|--------|-------------|
| `id`           | Integer | Storage ID |
| `code`         | String  | Storage code |
| `name`         | String  | Storage name |
| `storage_type` | String  | Type: `regular`, `temporary`, `incoming` |
| `url`          | String  | Storage detail URL |

### Attributes
| Field    | Type   | Description |
|----------|--------|-------------|
| `id`     | Integer | Attribute ID |
| `code`   | String  | Attribute code |
| `name`   | String  | Attribute name |
| `pa_type`| String  | Type: `patype_text`, `patype_number`, etc. |
| `url`    | String  | Attribute detail URL |

### Labels
| Field       | Type   | Description |
|-------------|--------|-------------|
| `id`        | Integer | Label ID |
| `code`      | String  | Label code |
| `name`      | String  | Label name |
| `full_name` | String  | Full hierarchical name |
| `label_type`| String  | Type: `category`, `tag`, etc. |
| `url`       | String  | Label detail URL |

### Catalogs
| Field           | Type   | Description |
|-----------------|--------|-------------|
| `id`            | Integer | Catalog ID |
| `code`          | String  | Catalog code |
| `name`          | String  | Catalog name |
| `catalog_type`  | String  | Type: `webshop`, `supply` |
| `currency_code` | String  | Currency: `eur`, `sek`, `nok` |
| `url`           | String  | Catalog detail URL |

---

## Recent Searches

**Cache Details:**
- Storage: Redis
- Cache key: `recent_searches:#{user_id}`
- Max items: 10 unique searches
- Expiration: 30 days
- Order: Most recent first

**Behavior:**
- Automatically stored on successful search (results found)
- Duplicates removed automatically
- Limited to last 10 searches per user
- User-specific (isolated per user ID)

---

## Multi-Tenancy

**Company Scoping:**
- All searches scoped to `current_potlift_company`
- No cross-company data access
- Recent searches isolated per user (not per company)

**Security:**
- Query sanitization prevents SQL injection
- ILIKE special characters escaped: `%`, `_`, `\`
- Parameterized queries only (no raw SQL)

---

## Usage in JavaScript

### Fetch Search Results
```javascript
async function search(query, scope = 'all') {
  const response = await fetch(
    `/search?q=${encodeURIComponent(query)}&scope=${scope}`,
    {
      headers: { 'Accept': 'application/json' }
    }
  );
  return await response.json();
}

// Usage
const results = await search('iPhone', 'products');
console.log(results.products); // Array of product results
```

### Fetch Recent Searches
```javascript
async function getRecentSearches() {
  const response = await fetch('/search/recent', {
    headers: { 'Accept': 'application/json' }
  });
  return await response.json();
}

// Usage
const recent = await getRecentSearches();
console.log(recent); // ["iPhone", "Samsung", ...]
```

---

## Error Handling

### Empty Query
```bash
GET /search?q=

# Response: Empty results
{ "products": [], "storage": [], ... }
```

### Invalid Scope
```bash
GET /search?q=iPhone&scope=invalid

# Response: Empty results
{}
```

### No Results Found
```bash
GET /search?q=nonexistent

# Response: Empty arrays per scope
{
  "products": [],
  "storage": [],
  "attributes": [],
  "labels": [],
  "catalogs": []
}
```

---

## Performance Considerations

### Query Performance
- Uses ILIKE for case-insensitive search
- Leverages existing database indexes
- Result limits prevent large data transfers
- Eager loading prevents N+1 queries

### Recommended Indexes
```sql
-- For better ILIKE performance
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_sku_trgm ON products USING gin (sku gin_trgm_ops);
```

### Caching
- Recent searches cached in Redis (30-day TTL)
- No result caching (always fresh data)
- Company-scoped queries use composite indexes

---

## Testing

### Run Tests
```bash
# All search controller tests
bin/test spec/controllers/search_controller_spec.rb

# Specific test
bin/test spec/controllers/search_controller_spec.rb:45
```

### Test Coverage
- 30+ test cases
- Multi-tenancy isolation
- SQL injection prevention
- Query sanitization
- JSON response format
- Recent searches caching

---

## Common Use Cases

### Search Products by SKU
```ruby
GET /search?q=PRD-001&scope=products
```

### Search Across All Resources
```ruby
GET /search?q=warehouse&scope=all
```

### Get User's Recent Searches
```ruby
GET /search/recent
```

### Frontend Integration
```javascript
// Debounced search
let debounceTimer;
searchInput.addEventListener('input', (e) => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(() => {
    search(e.target.value, 'all');
  }, 300);
});
```

---

## Related Documentation

- [Phase 20-21 Implementation](PHASE_20_21_SEARCH_BACKEND_IMPLEMENTATION.md)
- [SearchController](app/controllers/search_controller.rb)
- [Search Tests](spec/controllers/search_controller_spec.rb)
- [Search View](app/views/search/index.html.erb)

---

## Support

For issues or questions, refer to:
- Implementation documentation: `PHASE_20_21_SEARCH_BACKEND_IMPLEMENTATION.md`
- Controller source: `app/controllers/search_controller.rb`
- Test suite: `spec/controllers/search_controller_spec.rb`
