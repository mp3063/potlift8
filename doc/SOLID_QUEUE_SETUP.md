# Solid Queue Setup Documentation

This document describes the Solid Queue configuration for Potlift8, a Rails 8 application using database-backed background job processing.

## Overview

Solid Queue is a database-backed Active Job adapter for Rails 8+ that provides reliable, persistent job queuing without requiring Redis or other external dependencies. It uses PostgreSQL for job storage and processing.

## Architecture

### Queue Priorities

The application uses three priority levels:

1. **high_priority** - Time-sensitive operations
   - Inventory synchronization
   - Critical catalog updates
   - Real-time operations
   - 5 threads, 0.1s polling interval

2. **default** - Standard operations
   - Product updates
   - Notifications
   - Routine tasks
   - 3 threads, 0.5s polling interval

3. **low_priority** - Background maintenance
   - Cleanup tasks
   - Reports
   - Analytics
   - Bulk operations
   - 2 threads, 1s polling interval

### Database Configuration

Solid Queue uses a separate database connection defined in `config/database.yml`:

```yaml
production:
  primary:
    database: potlift8_production
  queue:
    database: potlift8_production_queue
    migrations_paths: db/queue_migrate
```

## Configuration Files

### /config/queue.yml

Defines dispatcher and worker configurations for each environment:

- **Dispatchers**: Pick up scheduled jobs and enqueue them
- **Workers**: Process jobs from queues
- **Polling intervals**: Control how frequently workers check for new jobs
- **Thread counts**: Determine concurrent job processing capacity

### /config/initializers/solid_queue.rb

Initializes Solid Queue with:
- Logging configuration
- Error handling
- Queue name prefixes
- Performance instrumentation
- Health check monitoring (production only)

### /app/jobs/application_job.rb

Base job class with:
- Retry strategies (exponential backoff, 5 attempts)
- Error handling for common failures
- Performance monitoring
- Job lifecycle logging
- Helper methods for queue assignment

## Usage

### Creating Jobs

#### High Priority Job
```ruby
class InventorySyncJob < ApplicationJob
  queue_as :high_priority

  def perform(product_id)
    product = Product.find(product_id)
    product.sync_inventory_with_external_system
  end
end

# Enqueue the job
InventorySyncJob.perform_later(product.id)
```

#### Default Priority Job
```ruby
class ProductUpdateJob < ApplicationJob
  queue_as :default  # or omit for default

  def perform(product_id, attributes)
    product = Product.find(product_id)
    product.update(attributes)
  end
end
```

#### Low Priority Job
```ruby
class DailyReportJob < ApplicationJob
  queue_as :low_priority

  def perform(date)
    Reports::Generator.new(date).generate
  end
end
```

### Using Helper Methods

ApplicationJob provides convenience methods:

```ruby
class MyJob < ApplicationJob
  high_priority  # Same as queue_as :high_priority
end

class AnotherJob < ApplicationJob
  default_priority  # Same as queue_as :default
end

class BackgroundJob < ApplicationJob
  low_priority  # Same as queue_as :low_priority
end
```

### Scheduled Jobs

```ruby
# Run in 1 hour
MyJob.set(wait: 1.hour).perform_later(args)

# Run at specific time
MyJob.set(wait_until: Date.tomorrow.noon).perform_later(args)
```

## Monitoring

### Rake Tasks

Monitor queue health:
```bash
rake solid_queue:health
```

Check specific queue statistics:
```bash
rake solid_queue:queue_stats[high_priority]
```

List recent failed jobs:
```bash
rake solid_queue:failed_jobs
```

Retry all failed jobs:
```bash
rake solid_queue:retry_failed
```

Monitor queue depth:
```bash
rake solid_queue:monitor
```

View performance statistics:
```bash
rake solid_queue:performance
```

Clean up old jobs:
```bash
rake solid_queue:clear_completed[7]  # Clear jobs older than 7 days
```

Discard old failed jobs:
```bash
rake solid_queue:discard_old_failed[30]  # Discard failures older than 30 days
```

### Health Monitoring Service

Use the `JobMonitoring::QueueHealthService` for programmatic health checks:

```ruby
# Get comprehensive health report
report = JobMonitoring::QueueHealthService.health_report

# Check if queues are healthy
if JobMonitoring::QueueHealthService.healthy?
  puts "All systems operational"
else
  puts "Queue issues detected"
end

# Alert on queue depth
if JobMonitoring::QueueHealthService.queue_depth_alert?("high_priority", threshold: 100)
  # Send alert notification
end
```

### Logging

All jobs automatically log:
- Job enqueue events
- Job start events
- Job completion with duration
- Job failures with errors
- Performance metrics

Example log output:
```
Job enqueued: ProductUpdateJob (ID: 123, Queue: default, Scheduled at: immediately)
Job started: ProductUpdateJob (ID: 123, Queue: default) with arguments: [456]
Job completed: ProductUpdateJob (ID: 123) Duration: 2.35s
```

## Error Handling

### Automatic Retries

Jobs automatically retry on:
- Database deadlocks (5 attempts)
- Connection errors (5 attempts)
- Lock wait timeouts (5 attempts)
- Network failures (3-5 attempts)

All retries use exponential backoff.

### Discarded Jobs

Jobs are automatically discarded for:
- Deserialization errors (record deleted before job runs)
- Record not found errors
- Other non-retryable errors

### Custom Error Handling

Override in specific jobs:

```ruby
class MyJob < ApplicationJob
  retry_on CustomError, wait: 5.seconds, attempts: 3

  discard_on AnotherError do |job, error|
    # Custom cleanup logic
  end

  def perform
    # Job logic
  end
end
```

## Running Workers

### Development

Workers start automatically with `rails server` in development mode.

Or start manually:
```bash
bin/jobs
```

### Production

Use the provided systemd service or run:
```bash
bundle exec rake solid_queue:start
```

Configure worker concurrency with environment variables:
```bash
HIGH_PRIORITY_CONCURRENCY=2
DEFAULT_CONCURRENCY=2
LOW_PRIORITY_CONCURRENCY=1
```

## Performance Tuning

### Adjusting Worker Threads

Edit `config/queue.yml` to adjust thread counts per queue:

```yaml
workers:
  - queues: high_priority
    threads: 5  # Increase for more concurrent jobs
    processes: 2
```

### Polling Intervals

Shorter intervals = faster job pickup but more database load:
- High priority: 0.1s (responsive)
- Default: 0.5s (balanced)
- Low priority: 1s (efficient)

### Database Connections

Ensure your database pool size accommodates workers:
```yaml
# config/database.yml
pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
```

Total connections needed ≈ (threads × processes) per queue

## Troubleshooting

### Jobs not processing

1. Check workers are running:
   ```bash
   ps aux | grep solid_queue
   ```

2. Check queue health:
   ```bash
   rake solid_queue:health
   ```

3. Check database connection:
   ```bash
   rails dbconsole -p queue
   ```

### High queue depth

1. Increase worker concurrency
2. Optimize job performance
3. Check for failing jobs blocking the queue

### Failed jobs accumulating

1. Review failed job errors:
   ```bash
   rake solid_queue:failed_jobs
   ```

2. Fix underlying issues
3. Retry failed jobs:
   ```bash
   rake solid_queue:retry_failed
   ```

## Migration from Other Adapters

If migrating from Sidekiq, Resque, or Delayed Job:

1. Update `Gemfile` to include `solid_queue`
2. Run migrations: `rails solid_queue:install:migrations && rails db:migrate`
3. Update job classes to inherit from `ApplicationJob`
4. Remove old adapter configurations
5. Test job processing in development
6. Deploy to production

## Best Practices

1. **Use appropriate queues**: Match job priority to business importance
2. **Keep jobs small**: Break large tasks into smaller jobs
3. **Make jobs idempotent**: Jobs should be safe to run multiple times
4. **Handle missing records**: Use `discard_on ActiveRecord::RecordNotFound`
5. **Monitor regularly**: Check queue health and performance metrics
6. **Clean up old jobs**: Schedule regular cleanup of completed jobs
7. **Log important events**: Use structured logging for debugging
8. **Test job logic**: Write tests for job behavior

## Security Considerations

1. **Validate job arguments**: Don't trust deserialized data
2. **Limit job execution time**: Use timeouts for long-running jobs
3. **Protect sensitive data**: Don't log passwords or tokens
4. **Use database permissions**: Restrict queue database access
5. **Monitor for abuse**: Watch for unusual job patterns

## Resources

- [Solid Queue GitHub](https://github.com/basecamp/solid_queue)
- [Rails Active Job Guide](https://guides.rubyonrails.org/active_job_basics.html)
- [Rails 8 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)
