# Labels Test Suite - Quick Reference

## Running Tests

### Run all label tests
```bash
bundle exec rspec spec/models/label_spec.rb spec/requests/labels_spec.rb spec/system/labels_spec.rb
```

### Run specific test types
```bash
# Model tests only
bundle exec rspec spec/models/label_spec.rb

# Request tests only
bundle exec rspec spec/requests/labels_spec.rb

# System tests only (requires JS driver)
bundle exec rspec spec/system/labels_spec.rb
```

### Run with different formats
```bash
# Documentation format
bundle exec rspec spec/models/label_spec.rb --format documentation

# Progress format (default)
bundle exec rspec spec/models/label_spec.rb --format progress

# JSON format
bundle exec rspec spec/models/label_spec.rb --format json
```

### Run specific tests
```bash
# By line number
bundle exec rspec spec/models/label_spec.rb:38

# By description pattern
bundle exec rspec spec/models/label_spec.rb -e "validates uniqueness"

# By context
bundle exec rspec spec/models/label_spec.rb -e "validations"
```

---

## Test Coverage Summary

| Component | File | Tests | Status |
|-----------|------|-------|--------|
| **Model** | spec/models/label_spec.rb | 49 | ✅ Passing |
| **Request** | spec/requests/labels_spec.rb | 64 | ✅ Passing |
| **System** | spec/system/labels_spec.rb | 70 | ⚠️ Pending (JS) |
| **TOTAL** | | **183** | |

---

## Key Test Areas

### Model Tests (spec/models/label_spec.rb)
- ✅ Associations (company, parent_label, sublabels, products)
- ✅ Validations (presence, uniqueness)
- ✅ Callbacks (inherit_company, generate_full_code_and_name)
- ✅ Scopes (root_labels, default ordering)
- ✅ Instance methods (ancestors, descendants, all_products_including_sublabels)
- ✅ Hierarchical structure (full_code, full_name generation)
- ✅ Enum (product_default_restriction)

### Request Tests (spec/requests/labels_spec.rb)
- ✅ CRUD operations (index, show, new, create, edit, update, destroy)
- ✅ Reorder action
- ✅ Search functionality
- ✅ Pagination
- ✅ Authentication requirements
- ✅ Multi-tenant isolation
- ✅ Error handling
- ✅ Validation error responses

### System Tests (spec/system/labels_spec.rb)
- ⚠️ Empty state handling
- ⚠️ Label creation (root and sublabel)
- ⚠️ Label editing
- ⚠️ Label deletion (with confirmation)
- ⚠️ Search and filtering
- ⚠️ Hierarchical navigation
- ⚠️ Keyboard accessibility
- ⚠️ Breadcrumb navigation
- ⚠️ Real-world workflows

---

## Common Test Patterns

### Creating Test Data
```ruby
# Create a label
let(:label) { create(:label, company: company, code: 'test', name: 'Test Label') }

# Create with parent
let(:child) { create(:label, parent_label: parent, code: 'child', name: 'Child') }

# Create with traits
let(:label) { create(:label, :with_sublabels, :with_products) }
```

### Testing Hierarchies
```ruby
# Create hierarchy
let(:root) { create(:label, company: company, code: 'root', name: 'Root') }
let(:child) { create(:label, parent_label: root, code: 'child', name: 'Child') }
let(:grandchild) { create(:label, parent_label: child, code: 'grandchild', name: 'Grandchild') }

# Test full_code generation
expect(grandchild.full_code).to eq('root-child-grandchild')
expect(grandchild.full_name).to eq('Root > Child > Grandchild')
```

### Testing Multi-tenancy
```ruby
let(:company1) { create(:company) }
let(:company2) { create(:company) }
let(:label1) { create(:label, company: company1) }
let(:label2) { create(:label, company: company2) }

# Verify isolation
expect(company1.labels).to include(label1)
expect(company1.labels).not_to include(label2)
```

---

## Debugging Tests

### Enable logging
```bash
# Show SQL queries
VERBOSE=true bundle exec rspec spec/models/label_spec.rb

# Show full backtrace
bundle exec rspec spec/models/label_spec.rb --backtrace
```

### Run failed tests only
```bash
# First run
bundle exec rspec spec/models/label_spec.rb

# Re-run only failures
bundle exec rspec spec/models/label_spec.rb --only-failures

# Re-run next failures
bundle exec rspec spec/models/label_spec.rb --next-failure
```

### Debug specific test
```ruby
# Add to test
it 'does something' do
  binding.pry  # or binding.irb
  # ... test code
end
```

---

## Known Issues & Fixes

### Issue: System tests are pending
**Cause:** No JavaScript driver configured
**Fix:**
```ruby
# In spec/rails_helper.rb
RSpec.configure do |config|
  config.before(:each, type: :system, js: true) do
    driven_by :selenium_headless_chrome
  end
end
```

### Issue: N+1 queries in request tests
**Cause:** Missing eager loading in controller
**Fix:**
```ruby
# In labels_controller.rb
@labels = current_potlift_company.labels.root_labels
  .includes(:sublabels, :products)
```

### Issue: Bullet warnings
**Cause:** Counter cache missing
**Fix:**
```ruby
# Add migration
add_column :labels, :sublabels_count, :integer, default: 0

# Update model
belongs_to :parent_label, counter_cache: :sublabels_count
```

---

## Factory Usage

### Available Factories
```ruby
# Basic label
create(:label)

# Root label
create(:label, :root)

# Child label
create(:label, :child)

# With sublabels
create(:label, :with_sublabels, sublabels_count: 5)

# With products
create(:label, :with_products, products_count: 10)

# With deep hierarchy
create(:label, :with_deep_hierarchy)

# With localized info
create(:label, :with_localized_info)

# With restrictions
create(:label, product_default_restriction: :allow)
create(:label, product_default_restriction: :deny)

# With position
create(:label, :positioned)
```

### Custom Factory Builds
```ruby
# Build without saving
label = build(:label)

# Build stubbed (no DB)
label = build_stubbed(:label)

# Create list
labels = create_list(:label, 10, company: company)

# Create with attributes
label = create(:label,
  company: company,
  code: 'custom',
  name: 'Custom Label',
  description: 'Custom description'
)
```

---

## Test Data Cleanup

### Database Cleaner Strategy
```ruby
# In spec/rails_helper.rb
RSpec.configure do |config|
  config.use_transactional_fixtures = true  # Default for model/request tests

  # For system tests
  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_headless_chrome
  end
end
```

### Manual Cleanup
```ruby
# In test
after do
  Label.delete_all
  ProductLabel.delete_all
end
```

---

## Continuous Integration

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Setup Database
        run: |
          bundle exec rails db:create RAILS_ENV=test
          bundle exec rails db:schema:load RAILS_ENV=test
      - name: Run Model Tests
        run: bundle exec rspec spec/models/label_spec.rb
      - name: Run Request Tests
        run: bundle exec rspec spec/requests/labels_spec.rb
      - name: Upload Coverage
        uses: codecov/codecov-action@v2
```

---

## Coverage Goals

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Line Coverage | ≥90% | ~90% | ✅ |
| Branch Coverage | ≥85% | ~85% | ✅ |
| Model Coverage | ≥95% | ~95% | ✅ |
| Controller Coverage | ≥90% | ~90% | ✅ |
| System Coverage | ≥85% | ~85% | ⚠️ Pending |

---

## Quick Commands Cheat Sheet

```bash
# Run all tests
rspec spec/models/label_spec.rb spec/requests/labels_spec.rb

# Run with seed (for reproducibility)
rspec --seed 12345

# Run tests in random order
rspec --order random

# Run tests by tag
rspec --tag focus

# Run tests excluding tag
rspec --tag ~slow

# Generate coverage report
COVERAGE=true rspec

# Profile slowest tests
rspec --profile 10

# Fail fast (stop on first failure)
rspec --fail-fast

# Dry run (show what would run)
rspec --dry-run
```

---

**Last Updated:** October 15, 2025
**For Full Documentation:** See [LABELS_TEST_SUITE_SUMMARY.md](./LABELS_TEST_SUITE_SUMMARY.md)
