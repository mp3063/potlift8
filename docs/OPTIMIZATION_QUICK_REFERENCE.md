# Job Performance Optimization - Quick Reference Guide

## Quick Start

### 1. Batch Sync Products

```ruby
# Sync all products in a catalog (off-peak)
catalog = Catalog.find_by(code: 'SHOPIFY3')
catalog.schedule_full_sync(off_peak_hour: 2, batch_size: 500)

# Sync specific products immediately
product_ids = Product.active_products.limit(100).pluck(:id)
BatchProductSyncJob.perform_later(product_ids, catalog.id)

# Sync single product with deduplication
product = Product.find_by(sku: 'ABC123')
product.sync_to_catalog(catalog) # Returns true if enqueued, false if duplicate
```

### 2. Configure Rate Limiting

```ruby
# Set catalog rate limit
catalog = Catalog.find_by(code: 'SHOPIFY3')
catalog.update_rate_limit(limit: 150, period: 60)

# Check current config
catalog.rate_limit_config
# => { limit: 150, period: 60 }

# View rate limiter status
rate_limiter = RateLimiter.new("sync:#{catalog.code}", limit: 150, period: 60)
rate_limiter.info
# => { current_usage: 45, remaining: 105, percentage_used: 30.0, ... }
```

### 3. Monitor Performance

```ruby
# Get performance stats
stats = PerformanceMonitor.stats('batch_sync')
puts "Average: #{stats[:avg_duration]}s, Count: #{stats[:count]}"

# Track custom operation
PerformanceMonitor.track('my_operation', context: { user_id: 123 }) do
  # Your code here
end
```

## Common Operations

### Sync All Active Products

```ruby
catalog = Catalog.find_by(code: 'SHOPIFY3')
catalog.batch_sync_active_products
```

### Sync Product to All Catalogs

```ruby
product = Product.find_by(sku: 'ABC123')
jobs = product.sync_to_all_catalogs_batch
puts "Enqueued #{jobs.size} sync jobs"
```

### Force Sync (Bypass Deduplication)

```ruby
product.sync_to_catalog(catalog, force: true)
```

### Schedule Overnight Sync

```ruby
# All products, 2 AM, batches of 500, staggered by 5 minutes
catalog.schedule_full_sync(off_peak_hour: 2, batch_size: 500)
```

## Environment Variables

```bash
# Redis connection
REDIS_URL=redis://localhost:6379/1

# Job deduplication window (seconds)
JOB_DEDUP_WINDOW=30

# Catalog-specific rate limits
RATE_LIMIT_SHOPIFY3=150
RATE_LIMIT_PERIOD_SHOPIFY3=60

# Performance monitoring
TRACK_MEMORY=false  # Set to true to track memory usage
```

## Console Commands

### Check Rate Limit Status

```ruby
catalog = Catalog.find_by(code: 'SHOPIFY3')
rate_limiter = RateLimiter.new("sync:#{catalog.code}", **catalog.rate_limit_config)

info = rate_limiter.info
puts "Usage: #{info[:current_usage]}/#{info[:limit]} (#{info[:percentage_used]}%)"
puts "Reset in: #{info[:time_until_reset]}s"
```

### Reset Rate Limiter

```ruby
rate_limiter.reset!
```

### Clear Job Deduplication

```ruby
deduplicator = JobDeduplicator.new(
  job_name: 'ProductSyncJob',
  params: { product_id: 123, catalog_id: 456 },
  window: 30
)
deduplicator.clear!
```

### View Performance Stats

```ruby
# All tracked operations
['sync_product', 'batch_sync', 'api_call'].each do |op|
  stats = PerformanceMonitor.stats(op)
  next unless stats

  puts "#{op}:"
  puts "  Count: #{stats[:count]}"
  puts "  Avg: #{stats[:avg_duration]}s"
  puts "  Slow: #{stats[:slow_count]}"
end
```

## Troubleshooting

### Rate Limit Exceeded

```ruby
# Check current usage
rate_limiter.info

# Wait for reset
sleep rate_limiter.time_until_reset

# Or increase limit
catalog.update_rate_limit(limit: 200, period: 60)
```

### Too Many Duplicate Jobs

```ruby
# Check deduplication status
deduplicator = JobDeduplicator.new(
  job_name: 'ProductSyncJob',
  params: { product_id: 123, catalog_id: 456 },
  window: 30
)

if deduplicator.executed_recently?
  puts "Wait #{deduplicator.time_until_executable}s before retrying"
else
  puts "Job can be executed"
end
```

### Slow Operations

```ruby
# Find slow operations
stats = PerformanceMonitor.stats('sync_product')
if stats[:slow_count] > 0
  puts "#{stats[:slow_count]}/#{stats[:count]} operations were slow"
  puts "Max duration: #{stats[:max_duration]}s"
end
```

### Batch Failed Products

```ruby
# Re-sync failed products from logs
failed_product_ids = [123, 456, 789]
BatchProductSyncJob.set(queue: :high_priority).perform_later(failed_product_ids, catalog.id)
```

## Performance Tips

1. **Use batch operations for > 10 products**
2. **Schedule large syncs for off-peak hours (2-4 AM)**
3. **Monitor rate limit usage (alert at > 80%)**
4. **Set appropriate batch sizes (500 for overnight, 100 for urgent)**
5. **Check performance stats regularly**
6. **Increase rate limits only if needed**

## Monitoring Queries

```bash
# Recent rate limit events
grep "rate_limit_exceeded" logs/production.log | tail -10

# Slow operations
grep '"slow":true' logs/production.log | tail -10

# Duplicate jobs
grep "duplicate_job_skipped" logs/production.log | tail -10

# Batch summaries
grep "batch_sync_completed" logs/production.log | jq '.' | tail -5
```

## Key Classes

- `RateLimiter`: Rate limiting (app/services/rate_limiter.rb)
- `JobDeduplicator`: Deduplication (app/services/job_deduplicator.rb)
- `PerformanceMonitor`: Metrics (app/services/performance_monitor.rb)
- `BatchProductSyncJob`: Batch processing (app/jobs/batch_product_sync_job.rb)
- `ProductSyncJob`: Individual sync (app/jobs/product_sync_job.rb)
- `ProductSyncService`: Sync logic (app/services/product_sync_service.rb)
