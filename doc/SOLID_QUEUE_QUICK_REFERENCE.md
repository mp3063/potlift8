# Solid Queue Quick Reference

## Queue Priorities

| Queue | Use For | Response Time |
|-------|---------|---------------|
| `high_priority` | Urgent operations, inventory sync | ~0.1s |
| `default` | Standard operations, notifications | ~0.5s |
| `low_priority` | Background tasks, reports | ~1.0s |

## Creating Jobs

### Basic Job
```ruby
class MyJob < ApplicationJob
  queue_as :default  # or omit for default

  def perform(arg)
    # Job logic
  end
end
```

### Using Helpers
```ruby
class UrgentJob < ApplicationJob
  high_priority  # Shortcut for queue_as :high_priority
end

class BackgroundJob < ApplicationJob
  low_priority  # Shortcut for queue_as :low_priority
end
```

## Enqueuing Jobs

```ruby
# Immediate
MyJob.perform_later(args)

# Delayed
MyJob.set(wait: 1.hour).perform_later(args)

# Scheduled
MyJob.set(wait_until: tomorrow).perform_later(args)
```

## Monitoring Commands

```bash
# Health status
rake solid_queue:health

# Queue stats
rake solid_queue:queue_stats[high_priority]

# Failed jobs
rake solid_queue:failed_jobs

# Retry failures
rake solid_queue:retry_failed

# Performance
rake solid_queue:performance

# Monitor depth
rake solid_queue:monitor

# Cleanup
rake solid_queue:clear_completed[7]
rake solid_queue:discard_old_failed[30]
```

## Common Patterns

### Retry on Custom Error
```ruby
class MyJob < ApplicationJob
  retry_on MyCustomError, wait: 5.seconds, attempts: 3
end
```

### Discard on Specific Error
```ruby
class MyJob < ApplicationJob
  discard_on UnrecoverableError do |job, error|
    # Cleanup logic
  end
end
```

### Performance Tracking
```ruby
class MyJob < ApplicationJob
  include JobMonitoring  # For enhanced metrics

  def perform
    log_job_metric("records_processed", count)
  end
end
```

## Configuration

### Environment Variables (Production)
```bash
HIGH_PRIORITY_CONCURRENCY=2
DEFAULT_CONCURRENCY=2
LOW_PRIORITY_CONCURRENCY=1
```

### Files
- Configuration: `/config/queue.yml`
- Database: `/config/database.yml` (queue section)
- Base Job: `/app/jobs/application_job.rb`
- Initializer: `/config/initializers/solid_queue.rb`

## Running Workers

### Development
```bash
bin/jobs  # or starts with rails server
```

### Production
```bash
bundle exec rake solid_queue:start
```

## Health Check API

```ruby
# In code
report = JobMonitoring::QueueHealthService.health_report
is_healthy = JobMonitoring::QueueHealthService.healthy?
alert = JobMonitoring::QueueHealthService.queue_depth_alert?("high_priority")
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Jobs not processing | Check workers: `ps aux \| grep solid_queue` |
| High queue depth | Increase concurrency or optimize jobs |
| Failed jobs | Check logs: `rake solid_queue:failed_jobs` |
| Slow processing | Review performance: `rake solid_queue:performance` |

## Log Output

```
# Enqueue
Job enqueued: MyJob (ID: abc-123, Queue: default, Scheduled at: immediately)

# Start
Job started: MyJob (ID: abc-123, Queue: default) with arguments: [456]

# Complete
Job completed: MyJob (ID: abc-123) Duration: 2.35s

# Error
Job failed: MyJob (ID: abc-123) Duration: 1.2s, Error: StandardError - Something went wrong
```

## Important Notes

- Test environment uses inline adapter (synchronous)
- Queue names have environment prefix (e.g., `test__high_priority`)
- Jobs auto-retry up to 5 times with exponential backoff
- Failed jobs older than 30 days should be discarded
- Completed jobs older than 7 days should be cleaned up
- Monitor queue depth; alert if > 100 pending jobs

## Documentation

Full documentation: `/doc/SOLID_QUEUE_SETUP.md`
