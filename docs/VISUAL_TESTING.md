# Visual Regression Testing Guide

## Overview

Visual regression testing ensures that UI changes don't introduce unintended visual bugs by capturing and comparing screenshots of components across different states, variants, and viewport sizes.

## Tool Selection

### Recommendation: **Capybara Screenshot with VCS**

After evaluating Percy, Chromatic, BackstopJS, and Capybara Screenshot, we recommend **Capybara Screenshot** with version-controlled baselines for this project.

### Decision Rationale

**Why Capybara Screenshot:**
1. **Zero cost** - Completely free and open-source
2. **Simple integration** - Works seamlessly with existing RSpec + Capybara setup
3. **Full control** - Baselines stored in Git, no external dependencies
4. **CI/CD friendly** - No API keys or external services required
5. **Rails-native** - Built for Rails applications with ViewComponent support
6. **Privacy** - Screenshots never leave your infrastructure
7. **Lightweight** - No additional build tools or services needed

**Why NOT Percy:**
- Cost: $349/month for small teams (5 users, 25k snapshots)
- External dependency on SaaS platform
- Requires API keys and authentication setup
- Overkill for a single-team internal project

**Why NOT Chromatic:**
- Cost: $149/month (5k snapshots)
- Requires Storybook setup (additional complexity)
- Best suited for design system teams sharing components
- External service dependency

**Why NOT BackstopJS:**
- Node.js dependency in Ruby project
- More complex configuration
- Less integration with RSpec workflow
- No ViewComponent-specific support

## Installation

### 1. Add Gems

Add to your `Gemfile` in the test group:

```ruby
group :test do
  # ... existing gems ...

  # Visual regression testing
  gem 'capybara-screenshot', '~> 1.0'
  gem 'capybara-screenshot-diff', '~> 1.8'
end
```

Then install:

```bash
bundle install
```

### 2. Configure RSpec

Create `spec/support/capybara_screenshot.rb`:

```ruby
# frozen_string_literal: true

require 'capybara-screenshot/diff'

# Configure capybara-screenshot-diff
Capybara::Screenshot.enabled = true
Capybara::Screenshot.add_os_path = true
Capybara::Screenshot.add_driver_path = true

Capybara::Screenshot::Diff.enabled = true
Capybara::Screenshot::Diff.color_distance_limit = 50
Capybara::Screenshot::Diff.shift_distance_limit = 1
Capybara::Screenshot::Diff.area_size_limit = 100
Capybara::Screenshot::Diff.tolerance = 0.01

# Store screenshots in organized directory structure
Capybara::Screenshot.save_path = Rails.root.join('spec/visual')

# Configure diff storage
Capybara::Screenshot::Diff.screenshot_area = :full

RSpec.configure do |config|
  # Add screenshot comparison to component specs
  config.include Capybara::Screenshot::Diff::TestMethods, type: :component
  config.include Capybara::Screenshot::Diff::TestMethods, type: :system

  # Clean up failed screenshots after successful re-runs
  config.after(:each, type: :component) do |example|
    if example.exception.nil?
      # Test passed, clean up any old failure artifacts
      screenshot_name = example.metadata[:full_description].gsub(/\s+/, '_')
      failure_path = Rails.root.join("spec/visual/#{screenshot_name}.diff.png")
      File.delete(failure_path) if File.exist?(failure_path)
    end
  end
end
```

### 3. Update .gitignore

Add to `.gitignore`:

```gitignore
# Visual regression artifacts (keep baselines, ignore diffs)
spec/visual/**/*.diff.png
spec/visual/**/*.new.png
spec/visual/tmp/
```

Add to version control (commit baselines):

```bash
git add spec/visual/**/*.png
git add '!spec/visual/**/*.diff.png'
git add '!spec/visual/**/*.new.png'
```

### 4. Configure Viewports

Create `spec/support/viewports.rb`:

```ruby
# frozen_string_literal: true

module VisualTestHelpers
  # Standard breakpoints matching Tailwind CSS defaults
  VIEWPORTS = {
    mobile: [375, 667],    # iPhone SE
    tablet: [768, 1024],   # iPad
    desktop: [1440, 900]   # Standard desktop
  }.freeze

  def screenshot_component(component, name:, viewports: [:desktop])
    Array(viewports).each do |viewport|
      width, height = VIEWPORTS[viewport]

      resize_to(width, height) if respond_to?(:resize_to)

      render_inline(component)

      screenshot_name = "#{name}_#{viewport}_#{width}x#{height}"
      screenshot_and_compare(screenshot_name)
    end
  end

  def screenshot_and_compare(name)
    screenshot(name)

    # Automatically compare with baseline
    expect(page).to match_screenshot(name)
  end

  private

  def resize_to(width, height)
    page.driver.browser.manage.window.resize_to(width, height)
  end
end

RSpec.configure do |config|
  config.include VisualTestHelpers, type: :component
  config.include VisualTestHelpers, type: :system
end
```

## Writing Visual Tests

### Basic Component Test

```ruby
require "rails_helper"

RSpec.describe Ui::ButtonComponent, type: :component do
  describe "visual regression" do
    it "matches baseline for primary variant" do
      render_inline(described_class.new(variant: :primary)) { "Click me" }

      expect(page).to match_screenshot("button_primary")
    end

    it "matches baseline for all variants at multiple viewports", :visual do
      [:primary, :secondary, :danger, :ghost, :link].each do |variant|
        render_inline(described_class.new(variant: variant)) { "Button" }

        expect(page).to match_screenshot("button_#{variant}")
      end
    end
  end
end
```

### Multi-Viewport Test

```ruby
RSpec.describe Shared::NavbarComponent, type: :component do
  let(:user) { { email: "user@example.com", name: "John Doe" } }

  describe "visual regression across viewports" do
    it "matches baseline at all breakpoints", :visual do
      [:mobile, :tablet, :desktop].each do |viewport|
        render_inline(described_class.new(user: user))

        screenshot_component(
          described_class.new(user: user),
          name: "navbar",
          viewports: [viewport]
        )
      end
    end
  end
end
```

### Component States Test

```ruby
RSpec.describe Ui::ButtonComponent, type: :component do
  describe "visual regression for states" do
    it "matches baseline for all states", :visual do
      [
        { state: "default", props: {} },
        { state: "disabled", props: { disabled: true } },
        { state: "loading", props: { loading: true } },
        { state: "with_icon", props: { icon: '<svg class="w-4 h-4">...</svg>' } }
      ].each do |config|
        render_inline(described_class.new(**config[:props])) { "Button" }

        expect(page).to match_screenshot("button_state_#{config[:state]}")
      end
    end
  end
end
```

### Complex Component Test

```ruby
RSpec.describe Products::TableComponent, type: :component do
  let(:company) { create(:company) }
  let(:products) { create_list(:product, 5, company: company) }

  describe "visual regression" do
    it "matches baseline for table with products", :visual do
      render_inline(described_class.new(products: products))

      expect(page).to match_screenshot("products_table_full")
    end

    it "matches baseline for empty state", :visual do
      render_inline(described_class.new(products: []))

      expect(page).to match_screenshot("products_table_empty")
    end

    it "matches baseline at mobile viewport", :visual do
      screenshot_component(
        described_class.new(products: products),
        name: "products_table",
        viewports: [:mobile]
      )
    end
  end
end
```

## Running Visual Tests

### Run All Visual Tests

```bash
# Run all specs tagged with :visual
bundle exec rspec --tag visual

# Run all component visual tests
bundle exec rspec spec/components --tag visual
```

### Run Specific Component Tests

```bash
# Test specific component
bundle exec rspec spec/components/ui/button_component_spec.rb

# Test with documentation format
bundle exec rspec spec/components/ui/button_component_spec.rb --format documentation
```

### Generate Initial Baselines

```bash
# First time: generate baseline screenshots
SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual

# Or for specific component
SCREENSHOT_BASELINE=1 bundle exec rspec spec/components/ui/button_component_spec.rb
```

## Reviewing and Approving Changes

### When Tests Fail

When a visual test fails, you'll see:

```
Failure/Error: expect(page).to match_screenshot("button_primary")
  Screenshot does not match baseline:
    - Baseline: spec/visual/button_primary.png
    - New:      spec/visual/button_primary.new.png
    - Diff:     spec/visual/button_primary.diff.png

  Changes detected:
    - Color distance: 15.2 (limit: 50)
    - Shift distance: 0 (limit: 1)
    - Changed area: 45px (limit: 100px)
```

### Review Process

1. **Open the diff image:**
   ```bash
   open spec/visual/button_primary.diff.png
   ```

2. **Compare baseline vs new:**
   ```bash
   # View side-by-side
   open spec/visual/button_primary.png
   open spec/visual/button_primary.new.png
   ```

3. **Decision:**
   - If change is intentional: Update baseline
   - If change is a bug: Fix the code

### Update Baselines

**Accept specific change:**
```bash
# Replace baseline with new screenshot
mv spec/visual/button_primary.new.png spec/visual/button_primary.png

# Commit the update
git add spec/visual/button_primary.png
git commit -m "Update button primary visual baseline"
```

**Accept all changes:**
```bash
# Accept all new screenshots as baselines
find spec/visual -name "*.new.png" | while read f; do
  mv "$f" "${f%.new.png}.png"
done

git add spec/visual/
git commit -m "Update visual test baselines"
```

**Regenerate all baselines:**
```bash
# Delete old baselines and regenerate
rm -rf spec/visual/*.png
SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual

git add spec/visual/
git commit -m "Regenerate all visual baselines"
```

## CI/CD Integration

### GitHub Actions

Create `.github/workflows/visual_tests.yml`:

```yaml
name: Visual Regression Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  visual-tests:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

    steps:
      - uses: actions/checkout@v4

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.4.7
          bundler-cache: true

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libvips42 postgresql-client

      - name: Setup test database
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/potlift_test
          RAILS_ENV: test
        run: |
          bin/rails db:create
          bin/rails db:schema:load

      - name: Run visual tests
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/potlift_test
          RAILS_ENV: test
        run: |
          bundle exec rspec --tag visual

      - name: Upload diff images on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: visual-diffs
          path: spec/visual/**/*.diff.png
          retention-days: 7

      - name: Comment PR with diffs
        if: failure() && github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const path = require('path');

            const diffDir = 'spec/visual';
            const diffs = fs.readdirSync(diffDir)
              .filter(f => f.endsWith('.diff.png'));

            if (diffs.length > 0) {
              const comment = `## Visual Regression Test Failures\n\n` +
                `${diffs.length} visual difference(s) detected.\n\n` +
                `Download artifacts to review changes:\n` +
                `- Click "Details" next to this check\n` +
                `- Download "visual-diffs" artifact\n\n` +
                `If changes are intentional, update baselines:\n` +
                `\`\`\`bash\n` +
                `SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual\n` +
                `git add spec/visual/ && git commit -m "Update visual baselines"\n` +
                `\`\`\``;

              github.rest.issues.createComment({
                issue_number: context.issue.number,
                owner: context.repo.owner,
                repo: context.repo.repo,
                body: comment
              });
            }
```

### GitLab CI

Create `.gitlab-ci.yml` section:

```yaml
visual-tests:
  stage: test
  image: ruby:3.4.7

  services:
    - postgres:16

  variables:
    DATABASE_URL: postgresql://postgres:postgres@postgres:5432/potlift_test
    POSTGRES_PASSWORD: postgres
    RAILS_ENV: test

  before_script:
    - apt-get update -qq
    - apt-get install -y -qq postgresql-client libvips42
    - bundle install --jobs 4 --retry 3
    - bin/rails db:create
    - bin/rails db:schema:load

  script:
    - bundle exec rspec --tag visual

  artifacts:
    when: on_failure
    paths:
      - spec/visual/**/*.diff.png
      - spec/visual/**/*.new.png
    expire_in: 1 week

  only:
    - merge_requests
    - main
```

## Visual Test Coverage Plan

### Priority 1: Core UI Components (Critical)

These components are used throughout the application and must be visually stable:

#### Ui::ButtonComponent
- All variants: primary, secondary, danger, ghost, link
- All sizes: sm, md, lg
- States: default, disabled, loading, hover, focus
- Icon positions: left, right, none
- Viewports: mobile, desktop

#### Ui::CardComponent
- Variants: default, bordered, elevated
- With/without header
- With/without footer
- Different content lengths
- Viewports: mobile, tablet, desktop

#### Ui::ModalComponent
- Open/closed states
- Different sizes: sm, md, lg, xl, full
- With/without footer
- Header variations
- Viewports: mobile, tablet, desktop

#### Ui::BadgeComponent
- All variants: default, success, warning, danger, info
- All sizes: sm, md, lg
- States: default, outline, soft

### Priority 2: Complex Components (High)

#### Shared::NavbarComponent
- Authenticated state
- Unauthenticated state
- With/without dropdown open
- Mobile responsive states
- Viewports: mobile, tablet, desktop

#### Shared::MobileSidebarComponent
- Open/closed states
- Active menu items
- Nested navigation
- Viewport: mobile only

#### Products::TableComponent
- Full table with data (5+ rows)
- Empty state
- Loading state
- Sorted columns
- Selected rows
- Viewports: mobile, tablet, desktop

#### Products::FormComponent
- Empty form
- Pre-filled form
- Validation errors
- Different product types
- Viewports: mobile, desktop

### Priority 3: Layout Components (Medium)

#### Shared::BreadcrumbComponent
- Single level
- Multiple levels (2-5 items)
- Long text truncation
- Viewports: mobile, desktop

#### Shared::PaginationComponent
- First page
- Middle page
- Last page
- Single page
- Many pages (ellipsis)
- Viewports: mobile, desktop

#### Shared::EmptyStateComponent
- With icon
- Without icon
- With action button
- Different messages
- Viewports: mobile, desktop

#### Shared::FormErrorsComponent
- Single error
- Multiple errors
- Long error messages
- Viewports: mobile, desktop

### Priority 4: Application Pages (Lower)

#### Dashboard
- Authenticated view
- Empty data state
- Full data state
- Viewports: mobile, tablet, desktop

#### Products Index
- List view with products
- Empty state
- Search active
- Filters applied
- Viewports: mobile, tablet, desktop

#### Search Results
- With results
- No results
- Loading state
- Viewports: mobile, desktop

### Test Organization

Structure visual tests in dedicated describe blocks:

```ruby
RSpec.describe Ui::ButtonComponent, type: :component do
  # ... existing functional tests ...

  describe "visual regression", :visual do
    # All visual tests grouped together
    # Tagged with :visual for selective running

    context "variants" do
      # Test each variant
    end

    context "sizes" do
      # Test each size
    end

    context "states" do
      # Test interactive states
    end

    context "responsive" do
      # Test at different viewports
    end
  end
end
```

## Best Practices

### 1. Use Descriptive Screenshot Names

```ruby
# Good
expect(page).to match_screenshot("button_primary_disabled_mobile")
expect(page).to match_screenshot("navbar_authenticated_dropdown_open")

# Bad
expect(page).to match_screenshot("test1")
expect(page).to match_screenshot("component")
```

### 2. Group Related Visual Tests

```ruby
describe "visual regression", :visual do
  context "button variants" do
    # All variant tests
  end

  context "button states" do
    # All state tests
  end
end
```

### 3. Test Component Isolation

```ruby
# Good: Test component in isolation
render_inline(described_class.new(variant: :primary)) { "Button" }
expect(page).to match_screenshot("button_primary")

# Avoid: Testing in full page context (unless testing layout)
visit products_path
expect(page).to match_screenshot("products_page") # Too broad
```

### 4. Set Explicit Viewports

```ruby
# Good: Explicit viewport control
screenshot_component(component, name: "navbar", viewports: [:mobile, :desktop])

# Avoid: Relying on default browser size
render_inline(component)
expect(page).to match_screenshot("navbar") # Size unclear
```

### 5. Stable Test Data

```ruby
# Good: Deterministic data
let(:product) { create(:product, name: "Test Product", sku: "TEST-001") }

# Avoid: Random data
let(:product) { create(:product) } # Name might be random via Faker
```

### 6. Wait for Async Content

```ruby
# Good: Wait for animations/transitions
render_inline(modal_component)
sleep 0.3 # Wait for fade-in animation
expect(page).to match_screenshot("modal_open")

# Avoid: Capturing mid-animation
render_inline(modal_component)
expect(page).to match_screenshot("modal_open") # Might capture transition
```

### 7. Tag Visual Tests

```ruby
# Tag for selective running
describe "visual regression", :visual do
  it "matches baseline", :visual do
    # ...
  end
end

# Run only visual tests
# bundle exec rspec --tag visual
```

### 8. Document Baseline Updates

```bash
# Good commit messages
git commit -m "Update button baselines after padding adjustment"
git commit -m "Regenerate navbar baselines for mobile breakpoint change"

# Bad commit messages
git commit -m "Update screenshots"
git commit -m "Visual changes"
```

## Troubleshooting

### Tests Failing Inconsistently

**Problem:** Screenshots differ slightly between local and CI

**Solution:**
1. Increase tolerance in `spec/support/capybara_screenshot.rb`:
   ```ruby
   Capybara::Screenshot::Diff.tolerance = 0.02 # Increase from 0.01
   ```

2. Ensure consistent fonts between environments:
   ```ruby
   # spec/support/capybara_screenshot.rb
   Capybara::Screenshot::Diff.skip_fonts = true
   ```

### Large File Sizes

**Problem:** Baseline images consuming too much disk space

**Solution:**
1. Use PNG optimization:
   ```bash
   # Install pngquant
   brew install pngquant

   # Optimize images
   find spec/visual -name "*.png" -exec pngquant --force --ext .png {} \;
   ```

2. Configure screenshot dimensions:
   ```ruby
   # Only capture visible viewport, not full page
   Capybara::Screenshot::Diff.screenshot_area = :viewport
   ```

### Font Rendering Differences

**Problem:** Text looks different between macOS and Linux

**Solution:**
1. Use web fonts consistently:
   ```css
   /* application.css */
   @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
   ```

2. Disable font antialiasing differences:
   ```ruby
   Capybara::Screenshot::Diff.skip_fonts = true
   ```

### Animation Timing Issues

**Problem:** Animations not complete when screenshot taken

**Solution:**
1. Disable animations in tests:
   ```ruby
   # spec/support/capybara_screenshot.rb
   config.before(:each, type: :component) do
     # Disable CSS transitions/animations
     page.driver.browser.manage.add_cookie(name: 'prefers-reduced-motion', value: 'reduce')
   end
   ```

2. Add explicit waits:
   ```ruby
   render_inline(component)
   sleep 0.5 # Wait for animation
   expect(page).to match_screenshot("component")
   ```

## Cost Analysis

### Capybara Screenshot (Recommended)

**Setup Cost:** 1-2 hours
**Monthly Cost:** $0
**Maintenance:** 1-2 hours/month

**Pros:**
- Zero ongoing cost
- Complete control
- No external dependencies
- Privacy (screenshots stay in Git)

**Cons:**
- Manual baseline management
- Git repo size increases
- No built-in collaboration features

### Percy (Alternative)

**Setup Cost:** 4-6 hours
**Monthly Cost:** $349 (5 users, 25k snapshots)
**Maintenance:** 0.5 hours/month

**Pros:**
- Excellent UI for reviewing diffs
- Automatic baseline management
- Good CI/CD integration
- Team collaboration features

**Cons:**
- High cost for small teams
- External dependency
- Requires API key management
- Screenshots sent to external service

### Chromatic (Alternative)

**Setup Cost:** 6-8 hours (includes Storybook)
**Monthly Cost:** $149 (5k snapshots)
**Maintenance:** 1-2 hours/month

**Pros:**
- Excellent for design systems
- Good Storybook integration
- Visual test + documentation

**Cons:**
- Requires Storybook setup
- External dependency
- Monthly cost
- Overkill for internal project

## Migration Path

If you need to upgrade to a paid solution later:

### From Capybara Screenshot to Percy

1. Install Percy:
   ```bash
   gem install percy-capybara
   ```

2. Migrate tests:
   ```ruby
   # Replace
   expect(page).to match_screenshot("name")

   # With
   Percy.snapshot(page, name: "name")
   ```

3. Upload baselines to Percy
4. Update CI/CD configuration

### From Capybara Screenshot to Chromatic

1. Set up Storybook
2. Convert components to stories
3. Install Chromatic
4. Configure chromatic.yml
5. Upload baselines

## Summary

For the Potlift8 project, **Capybara Screenshot** is the optimal choice:

- Zero cost and maintenance overhead
- Simple integration with existing test suite
- Full control over baselines and process
- No external dependencies or API keys
- Perfect for internal project with single team
- Easy to upgrade to paid solution if needed

The recommended setup takes ~2 hours and provides comprehensive visual regression coverage for all 15+ ViewComponents across 3 responsive breakpoints.

## Additional Resources

- [capybara-screenshot-diff GitHub](https://github.com/donv/capybara-screenshot-diff)
- [ViewComponent Testing Guide](https://viewcomponent.org/guide/testing.html)
- [Capybara Documentation](https://rubydoc.info/github/teamcapybara/capybara)
- [RSpec Best Practices](https://rspec.info/features/3-12/rspec-core/)
