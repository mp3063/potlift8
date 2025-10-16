# Phase 20-21: Global Search Backend Implementation

## Overview

This document summarizes the implementation of the global search backend system for Phase 20-21 of the Potlift8 project.

**Implementation Date:** October 16, 2025
**Phase:** 20-21 (Search, Filters, Sorting & Performance Optimization)
**Scope:** Backend search functionality only (frontend global search modal with CMD/CTRL+K will be implemented separately)

---

## Implementation Summary

### 1. SearchController (`app/controllers/search_controller.rb`)

**Purpose:** Multi-scope search controller with Redis-based recent search caching.

**Features Implemented:**
- ✅ Multi-scope search (all, products, storage, attributes, labels, catalogs)
- ✅ Recent searches stored in Redis (last 10 per user, 30-day expiry)
- ✅ Company-scoped search using `current_potlift_company`
- ✅ HTML and JSON response formats
- ✅ SQL injection prevention with query sanitization
- ✅ Eager loading to prevent N+1 queries
- ✅ Proper multi-tenancy (company-scoped)

**Actions:**

#### `GET /search (index)`
- **Parameters:**
  - `q` (required): Search query string
  - `scope` (optional): Search scope (default: 'all')
    - `all` - Search all scopes (5 results per scope)
    - `products` - Products only (50 results max)
    - `storage` - Storages only (50 results max)
    - `attributes` - Product attributes only (50 results max)
    - `labels` - Labels only (50 results max)
    - `catalogs` - Catalogs only (50 results max)

- **Response Formats:**
  - HTML: Search results page with formatted results
  - JSON: Structured JSON with URLs for frontend consumption

#### `GET /search/recent`
- **Purpose:** Retrieve recent searches for current user
- **Response:** JSON array of last 10 unique searches
- **Cache:** Redis with 30-day expiration

---

### 2. Search Methods

#### Products Search (`search_products`)
- **Searches:** name, sku, description (JSONB field)
- **Query:** `ILIKE` pattern matching
- **Sorting:** product_status ASC, name ASC
- **Eager Loading:** product_labels (via includes)
- **Limit:** 5 (scope=all), 50 (scope=products)

#### Storage Search (`search_storage`)
- **Searches:** name, code, address (JSONB field)
- **Query:** `ILIKE` pattern matching
- **Filter:** Active storages only
- **Sorting:** name ASC
- **Limit:** 5 (scope=all), 50 (scope=storage)

#### Attributes Search (`search_attributes`)
- **Searches:** name, code
- **Query:** `ILIKE` pattern matching
- **Sorting:** attribute_position ASC
- **Limit:** 5 (scope=all), 50 (scope=attributes)

#### Labels Search (`search_labels`)
- **Searches:** name, full_name
- **Query:** `ILIKE` pattern matching
- **Sorting:** label_positions ASC
- **Limit:** 5 (scope=all), 50 (scope=labels)

#### Catalogs Search (`search_catalogs`)
- **Searches:** name, code
- **Query:** `ILIKE` pattern matching
- **Sorting:** name ASC
- **Limit:** 5 (scope=all), 50 (scope=catalogs)

---

### 3. Recent Searches (Redis Cache)

**Implementation:**
- Cache key: `recent_searches:#{current_user[:id]}`
- Storage: Array of search query strings
- Max items: 10 unique searches
- Expiration: 30 days
- Order: Most recent first (LIFO)
- Deduplication: Automatic (uniq)

**Storage Logic:**
```ruby
def store_recent_search(query)
  recent = Rails.cache.read(cache_key) || []
  recent.unshift(query)        # Add to beginning
  recent = recent.uniq.first(10) # Deduplicate and limit
  Rails.cache.write(cache_key, recent, expires_in: 30.days)
end
```

---

### 4. Security Features

#### SQL Injection Prevention
- Query sanitization escapes: `%`, `_`, `\`
- Safe parameterized queries using ActiveRecord
- No raw SQL concatenation

**Example:**
```ruby
def sanitize_query(query)
  query.to_s.gsub(/[%_\\]/) { |char| "\\#{char}" }
end

# Usage
where("name ILIKE :query", query: "%#{sanitized_query}%")
```

#### Multi-Tenancy Security
- All queries scoped to `current_potlift_company`
- No cross-company data leakage
- User-specific cache keys for recent searches

---

### 5. JSON Response Format

#### Products
```json
{
  "products": [
    {
      "id": 123,
      "sku": "PRD-001",
      "name": "Product Name",
      "product_type": "sellable",
      "product_status": "active",
      "url": "/products/123"
    }
  ]
}
```

#### Storage
```json
{
  "storage": [
    {
      "id": 45,
      "code": "WH-01",
      "name": "Main Warehouse",
      "storage_type": "regular",
      "url": "/storages/45"
    }
  ]
}
```

#### Attributes
```json
{
  "attributes": [
    {
      "id": 67,
      "code": "price",
      "name": "Price",
      "pa_type": "patype_number",
      "url": "/product_attributes/67"
    }
  ]
}
```

#### Labels
```json
{
  "labels": [
    {
      "id": 89,
      "code": "electronics",
      "name": "Electronics",
      "full_name": "Categories > Electronics",
      "label_type": "category",
      "url": "/labels/89"
    }
  ]
}
```

#### Catalogs
```json
{
  "catalogs": [
    {
      "id": 12,
      "code": "web-eu",
      "name": "Webshop EU",
      "catalog_type": "webshop",
      "currency_code": "eur",
      "url": "/catalogs/web-eu"
    }
  ]
}
```

---

### 6. Routes Configuration

**Added routes in `config/routes.rb`:**
```ruby
# Global search
get 'search', to: 'search#index', as: :search
get 'search/recent', to: 'search#recent', as: :search_recent
```

**Available routes:**
- `GET /search?q=query&scope=all` - Search all scopes
- `GET /search?q=query&scope=products` - Search products only
- `GET /search/recent` - Get recent searches (JSON)

---

### 7. HTML View (`app/views/search/index.html.erb`)

**Features:**
- Search form with query input and scope selector
- Grouped results by scope
- Result count badges
- Clickable result cards
- Status and type badges for each result
- Empty state for no results
- Responsive design with Tailwind CSS

**UI Components:**
- Search form with scope dropdown
- Results grouped by type (Products, Storage, Attributes, Labels, Catalogs)
- Each result displays as a clickable card
- Badge indicators for status and type
- Empty state with icon and helpful message

---

### 8. Testing (`spec/controllers/search_controller_spec.rb`)

**Test Coverage:**
- ✅ Empty query handling
- ✅ Multi-scope search (all)
- ✅ Single-scope searches (products, storage, attributes, labels, catalogs)
- ✅ Result limiting (5 for 'all', 50 for specific scopes)
- ✅ Recent searches caching
- ✅ JSON response format
- ✅ SQL injection prevention
- ✅ Multi-tenancy isolation
- ✅ Query sanitization
- ✅ Private method testing

**Test Statistics:**
- Total tests: 30+
- Coverage areas: 8
- Edge cases covered: SQL injection, cross-tenant, empty queries

---

## File Summary

### New Files Created
1. ✅ `spec/controllers/search_controller_spec.rb` - Comprehensive controller tests

### Modified Files
1. ✅ `app/controllers/search_controller.rb` - Full implementation (was stub)
2. ✅ `config/routes.rb` - Added `/search/recent` route
3. ✅ `app/views/search/index.html.erb` - Updated with real results display

---

## Technical Architecture

### Data Flow
```
User Request
    ↓
SearchController
    ↓
Query Sanitization
    ↓
Scope Selection (all|products|storage|attributes|labels|catalogs)
    ↓
Database Query (company-scoped)
    ↓
Eager Loading (N+1 prevention)
    ↓
Format Response (HTML/JSON)
    ↓
Store Recent Search (Redis)
    ↓
Return Results
```

### Performance Optimizations
1. **Eager Loading:** Uses `includes()` to prevent N+1 queries
2. **Result Limiting:** Limits results per scope (5 or 50)
3. **Redis Caching:** Recent searches cached in Redis
4. **Indexed Queries:** Uses existing database indexes on name, code, sku columns
5. **Scoped Queries:** Company-scoped queries use composite indexes

### Multi-Tenancy Architecture
- All searches scoped to `current_potlift_company`
- User-specific cache keys: `recent_searches:#{user.id}`
- No cross-company data access
- Company association enforced at query level

---

## Usage Examples

### Basic Search (All Scopes)
```ruby
GET /search?q=iPhone

# Returns:
# - Up to 5 products matching "iPhone"
# - Up to 5 storages matching "iPhone"
# - Up to 5 attributes matching "iPhone"
# - Up to 5 labels matching "iPhone"
# - Up to 5 catalogs matching "iPhone"
```

### Scoped Search (Products Only)
```ruby
GET /search?q=iPhone&scope=products

# Returns:
# - Up to 50 products matching "iPhone"
```

### JSON Request
```ruby
GET /search?q=iPhone&scope=products
Accept: application/json

# Returns JSON:
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
  ]
}
```

### Recent Searches
```ruby
GET /search/recent
Accept: application/json

# Returns:
["iPhone", "Samsung", "Google Pixel"]
```

---

## Integration Points

### Current User (from JWT)
```ruby
current_user[:id]     # User ID for cache keys
current_user[:email]  # User email
current_user[:name]   # User name
```

### Current Company (from JWT)
```ruby
current_company[:id]    # Company ID
current_company[:code]  # Company code
current_company[:name]  # Company name
```

### Current Potlift Company (Model)
```ruby
current_potlift_company        # Company model instance
current_potlift_company.products     # Company's products
current_potlift_company.storages     # Company's storages
current_potlift_company.labels       # Company's labels
current_potlift_company.catalogs     # Company's catalogs
current_potlift_company.product_attributes  # Company's attributes
```

---

## Next Steps (Phase 20-21 Continuation)

### Frontend Implementation (To Be Done)
1. **Global Search Modal:**
   - Keyboard shortcut: CMD/CTRL+K
   - Stimulus controller: `global_search_controller.js`
   - Debounced search (300ms)
   - Modal overlay with backdrop
   - Keyboard navigation support

2. **Search Input Component:**
   - Auto-focus on open
   - Clear button
   - Loading indicator
   - Recent searches display

3. **Results Display:**
   - Grouped by scope
   - Click to navigate
   - Highlight search terms
   - Keyboard navigation (Arrow keys, Enter)

4. **Performance:**
   - Debounced input (prevent excessive requests)
   - Request cancellation (abort previous requests)
   - Loading states

### Future Enhancements
1. **Advanced Search:**
   - Date range filters
   - Status filters
   - Type filters
   - Sorting options

2. **Search Analytics:**
   - Popular searches tracking
   - Search success rate
   - Zero-result queries

3. **Full-Text Search:**
   - PostgreSQL full-text search (tsvector)
   - Fuzzy matching for typo tolerance
   - Weighted results (name > sku > description)

4. **Performance Optimization:**
   - pg_trgm extension for LIKE performance
   - Search result caching
   - Materialized views for complex searches

---

## Success Criteria

### Backend Implementation (Completed)
- ✅ Multi-scope search (all, products, storage, attributes, labels, catalogs)
- ✅ Recent searches stored in Redis (10 per user, 30-day expiry)
- ✅ Scoped to current company (multi-tenant)
- ✅ HTML and JSON response formats
- ✅ SQL injection prevention
- ✅ N+1 query prevention (eager loading)
- ✅ Routes configured
- ✅ Comprehensive tests (30+ test cases)
- ✅ HTML view with grouped results

### Frontend Implementation (Not Started)
- ⏳ Global search modal with CMD/CTRL+K
- ⏳ Debounced search (300ms)
- ⏳ Stimulus controller
- ⏳ Keyboard navigation
- ⏳ Recent searches display

---

## Known Limitations

1. **Search Algorithm:**
   - Uses simple ILIKE pattern matching (case-insensitive)
   - No fuzzy matching or typo tolerance
   - No result ranking or relevance scoring
   - No full-text search features

2. **Performance:**
   - ILIKE queries can be slow on large datasets without pg_trgm
   - No search result caching
   - No query result pagination (hard limits only)

3. **Frontend:**
   - No global search modal yet (Phase 20-21 continuation)
   - No keyboard shortcuts (CMD/CTRL+K)
   - No search term highlighting in results
   - No autocomplete suggestions

---

## Database Requirements

### Required Indexes (Already Exist)
- `products.name` - For name search
- `products.sku` - For SKU search
- `storages.name` - For storage name search
- `storages.code` - For storage code search
- `labels.name` - For label name search
- `catalogs.name` - For catalog name search

### Recommended Indexes (Future)
```sql
-- For ILIKE performance
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
CREATE INDEX idx_products_sku_trgm ON products USING gin (sku gin_trgm_ops);
```

---

## Dependencies

### Required Gems
- Rails 8.0.3+
- Redis (for recent searches caching)
- RSpec (for testing)
- FactoryBot (for test fixtures)

### Redis Configuration
```ruby
# config/environments/development.rb
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

---

## Conclusion

The global search backend system has been successfully implemented with full multi-scope search, recent searches caching, and comprehensive test coverage. The system is production-ready and properly scoped to company context for multi-tenancy.

The next phase will focus on implementing the frontend global search modal with CMD/CTRL+K keyboard shortcut and Stimulus integration.

---

**Implementation Status:** ✅ Complete (Backend)
**Next Phase:** Frontend global search modal (Phase 20-21 continuation)
**Documentation:** Complete
**Test Coverage:** 30+ test cases
