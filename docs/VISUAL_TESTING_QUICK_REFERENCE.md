# Visual Testing Quick Reference

## Quick Commands

### Setup (One Time)
```bash
bundle install
SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual
git add spec/visual/ && git commit -m "Add visual baselines"
```

### Daily Use
```bash
# Run all visual tests
bundle exec rspec --tag visual

# Run specific component
bundle exec rspec spec/components/ui/button_component_spec.rb --tag visual

# Run with details
bundle exec rspec --tag visual --format documentation
```

### Review Changes
```bash
# 1. Tests fail? Review diffs
open spec/visual/*.diff.png

# 2. Changes intentional? Accept
mv spec/visual/*.new.png spec/visual/*.png

# 3. Commit
git add spec/visual/
git commit -m "Update baselines: [reason]"
```

## Writing Tests

### Basic Test
```ruby
describe "visual regression", :visual do
  it "matches baseline" do
    render_inline(Ui::ButtonComponent.new(variant: :primary)) { "Click" }

    expect(page).to match_screenshot("button_primary")
  end
end
```

### Multi-Viewport Test
```ruby
it "matches at all breakpoints" do
  screenshot_component(
    MyComponent.new,
    name: "my_component",
    viewports: [:mobile, :tablet, :desktop]
  )
end
```

### Multiple States
```ruby
[
  { label: "default", props: {} },
  { label: "disabled", props: { disabled: true } },
  { label: "loading", props: { loading: true } }
].each do |state|
  it "matches baseline for #{state[:label]}" do
    render_inline(ButtonComponent.new(**state[:props])) { "Button" }
    expect(page).to match_screenshot("button_#{state[:label]}")
  end
end
```

## Available Viewports

```ruby
VIEWPORTS = {
  mobile: [375, 667],    # iPhone SE
  tablet: [768, 1024],   # iPad
  desktop: [1440, 900]   # Standard desktop
}
```

## Common Issues

### Tests failing inconsistently?
```ruby
# Increase tolerance in spec/support/capybara_screenshot.rb
Capybara::Screenshot::Diff.tolerance = 0.02
```

### Font rendering differences?
```ruby
# Enable font skip in spec/support/capybara_screenshot.rb
Capybara::Screenshot::Diff.skip_fonts = true
```

### Need to regenerate all baselines?
```bash
rm -rf spec/visual/*.png
SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual
```

## Best Practices

✅ **DO:**
- Tag tests with `:visual`
- Use descriptive screenshot names
- Test components in isolation
- Use stable test data
- Review diffs before accepting
- Commit baselines with clear messages

❌ **DON'T:**
- Use random test data (Faker)
- Test full pages (too broad)
- Accept changes without reviewing
- Commit .diff.png or .new.png files
- Run visual tests without tags

## File Locations

**Tests:** `spec/components/**/*_spec.rb`
**Baselines:** `spec/visual/*.png` (commit these)
**Diffs:** `spec/visual/*.diff.png` (gitignored)
**Config:** `spec/support/capybara_screenshot.rb`
**Helpers:** `spec/support/viewports.rb`

## Documentation

- **Full Guide:** `docs/VISUAL_TESTING.md`
- **Coverage Plan:** `docs/VISUAL_TEST_COVERAGE.md`
- **Tool Decision:** `docs/VISUAL_TESTING_RECOMMENDATION.md`
- **Summary:** `docs/VISUAL_TESTING_SUMMARY.md`

## CI/CD

Visual tests run automatically on PRs. If tests fail:

1. Check GitHub Actions artifacts
2. Download `visual-diffs.zip`
3. Review diff images
4. Update baselines if changes are intentional
5. Commit and push

## Help

Need help? Read `/docs/VISUAL_TESTING.md` or check:
- [Capybara Screenshot Diff](https://github.com/donv/capybara-screenshot-diff)
- [ViewComponent Testing](https://viewcomponent.org/guide/testing.html)
