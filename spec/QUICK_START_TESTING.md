# Quick Start: Running Phase 20-21 Tests

## Prerequisites

```bash
# Ensure database is set up
RAILS_ENV=test bin/rails db:environment:set RAILS_ENV=test
bin/rails db:test:prepare

# Ensure Redis is running
redis-cli ping  # Should return PONG
```

## Run All Phase 20-21 Tests

```bash
# All tests (excluding benchmarks)
bundle exec rspec \
  spec/components/search/ \
  spec/components/filter_panel_component_spec.rb \
  spec/system/global_search_spec.rb \
  spec/system/product_filtering_spec.rb \
  spec/integration/caching_spec.rb \
  spec/integration/performance_spec.rb

# Expected: ~170 tests, all passing
```

## Run Individual Test Categories

### Component Tests (Fast, ~2 seconds)
```bash
# Search modal component
bundle exec rspec spec/components/search/modal_component_spec.rb

# Filter panel component
bundle exec rspec spec/components/filter_panel_component_spec.rb
```

### System Tests (Requires JS, ~30 seconds)
```bash
# Global search
bundle exec rspec spec/system/global_search_spec.rb

# Product filtering
bundle exec rspec spec/system/product_filtering_spec.rb
```

### Integration Tests (Medium speed, ~10 seconds)
```bash
# Caching
bundle exec rspec spec/integration/caching_spec.rb

# Performance
bundle exec rspec spec/integration/performance_spec.rb
```

### Performance Benchmarks (Slow, ~10 minutes)
```bash
# Search performance
bundle exec rspec spec/benchmarks/search_performance_benchmark.rb --format documentation
```

## Output Formats

### Progress (default)
```bash
bundle exec rspec spec/components/search/modal_component_spec.rb
# Output: ...............................
```

### Documentation (verbose)
```bash
bundle exec rspec spec/components/search/modal_component_spec.rb --format documentation
# Output:
# Search::ModalComponent
#   rendering
#     renders the modal container with global-search controller
#     renders modal backdrop with correct attributes
#     ...
```

### JSON (for CI/CD)
```bash
bundle exec rspec spec/components/search/modal_component_spec.rb --format json
```

## Troubleshooting

### Database Environment Error
```bash
# Error: "You are attempting to modify a database that was last run in `development` environment"
RAILS_ENV=test bin/rails db:environment:set RAILS_ENV=test
```

### Redis Connection Error
```bash
# Start Redis
redis-server

# Or start via Homebrew
brew services start redis
```

### JavaScript Driver Not Found
```bash
# Install Chrome/Chromium
brew install --cask google-chrome

# Or use headless mode (should work by default)
```

### System Tests Timing Out
```ruby
# Increase wait time in spec_helper.rb
Capybara.default_max_wait_time = 5
```

### N+1 Query Warnings (Bullet gem)
```bash
# Add to Gemfile (if not already)
gem 'bullet', group: [:development, :test]

# Run tests
BULLET=true bundle exec rspec
```

## Quick Verification

Run a single fast test to verify setup:

```bash
bundle exec rspec spec/components/search/modal_component_spec.rb:18
# Should pass in < 1 second
```

## Coverage Report

```bash
# Run tests with coverage
COVERAGE=true bundle exec rspec

# View report
open coverage/index.html
```

## Common Workflows

### Before Committing
```bash
# Run fast tests only
bundle exec rspec spec/components/ --tag ~js
```

### Before Pushing
```bash
# Run all tests except benchmarks
bundle exec rspec --tag ~benchmark
```

### Before Deploying
```bash
# Run everything including benchmarks
bundle exec rspec spec/benchmarks/

# Verify performance thresholds met
```

## Test Files Reference

```
spec/
├── components/
│   ├── search/
│   │   └── modal_component_spec.rb       # 31 tests
│   └── filter_panel_component_spec.rb    # 40 tests
├── system/
│   ├── global_search_spec.rb             # ~25 tests
│   └── product_filtering_spec.rb         # ~35 tests
├── integration/
│   ├── caching_spec.rb                   # ~30 tests
│   └── performance_spec.rb               # ~25 tests
├── benchmarks/
│   └── search_performance_benchmark.rb   # 15 benchmarks
└── controllers/
    └── search_controller_spec.rb         # ~55 tests (existing)
```

## Expected Results

### All Tests Passing
```
Search::ModalComponent         31 examples, 0 failures
FilterPanelComponent          40 examples, 0 failures
Global Search                ~25 examples, 0 failures
Product Filtering            ~35 examples, 0 failures
Caching Integration          ~30 examples, 0 failures
Performance Integration      ~25 examples, 0 failures
SearchController             ~55 examples, 0 failures (existing)
-----------------------------------------------------------
TOTAL:                      ~240 examples, 0 failures
```

### Benchmark Results
```
Search Performance Benchmark:
- Single-scope search:        < 50ms  ✅
- Multi-scope search:         < 100ms ✅
- Cache hit speedup:          > 2x    ✅
- Eager loading speedup:      > 2x    ✅
- Memory (500 records):       < 100MB ✅
```

## Documentation

- **Detailed Overview:** `spec/PHASE_20_21_TEST_SUITE_SUMMARY.md`
- **Completion Report:** `spec/PHASE_20_21_TESTING_COMPLETE.md`
- **Benchmark Guide:** `spec/benchmarks/README.md`
- **Quick Start:** `spec/QUICK_START_TESTING.md` (this file)

## Support

For issues or questions:
1. Check `spec/PHASE_20_21_TEST_SUITE_SUMMARY.md` for detailed documentation
2. Review `spec/benchmarks/README.md` for performance tuning
3. Refer to component source code for implementation details

---

Last Updated: 2025-10-16
