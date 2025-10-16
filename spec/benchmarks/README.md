# Performance Benchmarks

This directory contains performance benchmarks for Phase 20-21 search and filtering features.

## Running Benchmarks

### Run All Benchmarks

```bash
bundle exec rspec spec/benchmarks/ --format documentation
```

### Run Specific Benchmark

```bash
bundle exec rspec spec/benchmarks/search_performance_benchmark.rb --format documentation
```

## Benchmark Categories

### 1. Search Performance Benchmark

**File:** `search_performance_benchmark.rb`

**Tests:**
- Single-scope product search performance
- Multi-scope search performance
- Query length impact on performance
- Result set size impact on performance
- Index effectiveness (indexed vs JSONB searches)
- Compound index usage
- Cache hit vs miss performance
- Eager loading effectiveness
- Select optimization
- Pagination performance
- Concurrent request handling
- Memory usage

**Expected Results:**
- Single-scope search: < 50ms per query
- Multi-scope search: < 100ms per query
- Cache hits: > 2x faster than cache misses
- Eager loading: > 2x faster than N+1 queries
- Memory: < 100MB for 500 records

## Performance Thresholds

### Search Queries

| Operation | Threshold | Target |
|-----------|-----------|--------|
| Product search (single scope) | < 50ms | < 20ms |
| Multi-scope search | < 100ms | < 50ms |
| Storage search | < 30ms | < 10ms |
| Label search | < 30ms | < 10ms |
| Catalog search | < 30ms | < 10ms |

### Database Queries

| Operation | Query Count | Target |
|-----------|-------------|--------|
| Product index | < 25 queries | < 10 queries |
| Product show | < 20 queries | < 8 queries |
| Search (all scopes) | < 30 queries | < 15 queries |
| Filtered list | < 25 queries | < 12 queries |

### Response Times

| Page | Threshold | Target |
|------|-----------|--------|
| Product index | < 1s | < 500ms |
| Product show | < 300ms | < 150ms |
| Search API | < 500ms | < 200ms |
| Filtered list | < 1s | < 500ms |

### Cache Performance

| Operation | Threshold | Target |
|-----------|-----------|--------|
| Cache read | < 1ms | < 0.5ms |
| Cache write | < 10ms | < 5ms |
| Recent searches | < 10ms | < 3ms |

## Interpreting Results

### Good Performance Indicators

- Query times consistently under thresholds
- Minimal variance between runs
- Cache hits significantly faster than misses
- Eager loading shows 2-5x improvement
- Concurrent requests show some parallelism benefit
- Memory usage scales linearly with result set size

### Warning Signs

- Query times exceeding thresholds
- High variance between runs (>50%)
- Cache hits not significantly faster
- No improvement from eager loading (N+1 queries still present)
- Memory usage growing super-linearly
- Sequential scans in EXPLAIN output

## Optimization Recommendations

### If Search is Slow

1. **Add/verify indexes:**
   ```sql
   CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);
   CREATE INDEX idx_products_sku_trgm ON products USING gin (sku gin_trgm_ops);
   ```

2. **Use compound indexes for filters:**
   ```sql
   CREATE INDEX idx_products_company_status_type
   ON products (company_id, product_status, product_type);
   ```

3. **Add eager loading:**
   ```ruby
   products.includes(:labels, :inventories)
   ```

### If Queries are High

1. **Use eager loading scopes:**
   ```ruby
   Product.with_search_associations
   Product.with_inventory
   Product.with_labels
   ```

2. **Add counter caches:**
   ```ruby
   add_column :products, :subproducts_count, :integer, default: 0
   Product.reset_column_information
   Product.find_each { |p| Product.reset_counters(p.id, :subproducts) }
   ```

3. **Optimize associations:**
   ```ruby
   has_many :labels, -> { select(:id, :name, :code) }
   ```

### If Cache is Not Helping

1. **Verify cache is enabled:**
   ```ruby
   Rails.cache.exist?(key)
   ```

2. **Check Redis connection:**
   ```bash
   redis-cli ping
   ```

3. **Verify cache keys:**
   ```ruby
   Rails.cache.read("recent_searches:#{user_id}")
   ```

### If Memory is High

1. **Limit result sets:**
   ```ruby
   products.limit(50)
   ```

2. **Use select to load only needed columns:**
   ```ruby
   products.select(:id, :name, :sku)
   ```

3. **Use find_each for batch processing:**
   ```ruby
   Product.find_each(batch_size: 100) { |product| ... }
   ```

## Continuous Monitoring

### Production Monitoring

Add APM tools to track performance in production:

- **New Relic** - Application performance monitoring
- **Scout APM** - Rails-specific monitoring
- **Skylight** - Performance insights
- **DataDog** - Infrastructure + APM

### Key Metrics to Monitor

1. **Response times:**
   - p50 (median)
   - p95 (95th percentile)
   - p99 (99th percentile)

2. **Database:**
   - Query count per request
   - Slow query log (>100ms)
   - Connection pool usage

3. **Cache:**
   - Hit rate (target: >80%)
   - Miss rate
   - Eviction rate

4. **Memory:**
   - Average per request
   - Peak usage
   - Garbage collection frequency

## Benchmark Development

### Adding New Benchmarks

1. Create new file in `spec/benchmarks/`
2. Use RSpec with `type: :benchmark`
3. Include performance thresholds
4. Document expected results
5. Add to this README

### Example Benchmark Template

```ruby
require 'rails_helper'
require 'benchmark'

RSpec.describe 'Feature Performance Benchmark', type: :benchmark do
  before(:all) do
    # Setup test data
  end

  after(:all) do
    # Cleanup
  end

  it "benchmarks feature operation" do
    puts "\n--- Feature Benchmark ---"

    results = Benchmark.measure do
      100.times { perform_operation }
    end

    avg_time = results.real / 100
    puts "Average time: #{(avg_time * 1000).round(2)}ms"

    expect(avg_time).to be < 0.05 # 50ms threshold
  end
end
```

## References

- [Rails Performance Best Practices](https://guides.rubyonrails.org/performance_testing.html)
- [PostgreSQL Performance Tips](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [Redis Performance Tuning](https://redis.io/topics/benchmarks)
- [N+1 Query Detection](https://github.com/flyerhzm/bullet)
