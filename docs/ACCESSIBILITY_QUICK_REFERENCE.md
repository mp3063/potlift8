# Accessibility Testing Quick Reference

Quick reference for developers working with accessibility tests in Potlift8.

## Run Tests

```bash
# All accessibility tests
bundle exec rspec spec/system/accessibility/

# Component tests only
bundle exec rspec spec/system/accessibility/component_accessibility_spec.rb

# Page tests only
bundle exec rspec spec/system/accessibility/page_accessibility_spec.rb

# Navigation tests only
bundle exec rspec spec/system/accessibility/navigation_accessibility_spec.rb

# Specific test
bundle exec rspec spec/system/accessibility/component_accessibility_spec.rb:20

# With documentation format
bundle exec rspec spec/system/accessibility/ --format documentation
```

## Common Helper Methods

```ruby
# Test WCAG 2.1 AA compliance
expect_no_axe_violations

# Test specific element
expect_no_violations_in('#main-content')

# Test specific rule
expect_rule_passes('color-contrast')

# Test keyboard navigation
expect_keyboard_navigable('nav')

# Test focus trap (modals)
expect_focus_trapped_in('[role="dialog"]')
```

## Shared Examples

```ruby
# For components
it_behaves_like 'accessible component'

# For pages
it_behaves_like 'accessible page'

# For keyboard navigation
it_behaves_like 'keyboard navigable', 'nav'
```

## Accessibility Checklist

### For Components

- [ ] Passes `expect_no_axe_violations`
- [ ] Keyboard accessible (Tab, Enter, Escape)
- [ ] Has visible focus indicators
- [ ] Uses proper ARIA attributes
- [ ] Color contrast meets WCAG AA (4.5:1)
- [ ] Interactive elements have accessible names

### For Buttons

```ruby
# ✅ Good: Button with text
<button>Save Product</button>

# ✅ Good: Icon button with aria-label
<button aria-label="Close">
  <svg>...</svg>
</button>

# ❌ Bad: Icon button without label
<button>
  <svg>...</svg>
</button>
```

### For Forms

```ruby
# ✅ Good: Input with label
<label for="product_sku">SKU</label>
<input type="text" id="product_sku" name="product[sku]">

# ✅ Good: Required field
<input type="text" required aria-required="true">

# ✅ Good: Error with alert role
<div role="alert" class="error">
  SKU cannot be blank
</div>

# ❌ Bad: Input without label
<input type="text" placeholder="SKU">
```

### For Images

```ruby
# ✅ Good: Informative image
<img src="product.jpg" alt="Blue cotton t-shirt, size M">

# ✅ Good: Decorative image
<img src="decoration.svg" alt="">

# ❌ Bad: No alt attribute
<img src="product.jpg">
```

### For Modals

```ruby
# ✅ Good: Modal with ARIA
<div role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <h3 id="modal-title">Confirm Deletion</h3>
  <p>Are you sure?</p>
  <button aria-label="Close">×</button>
</div>

# Required features:
# - role="dialog"
# - aria-modal="true"
# - aria-labelledby pointing to title
# - Focus trap
# - Escape to close
```

### For Navigation

```ruby
# ✅ Good: Semantic navigation
<nav aria-label="Main navigation">
  <a href="/" aria-current="page">Dashboard</a>
  <a href="/products">Products</a>
</nav>

# ✅ Good: Skip link
<a href="#main-content" class="sr-only focus:not-sr-only">
  Skip to main content
</a>
<main id="main-content">
  <!-- Page content -->
</main>
```

## Common WCAG Violations

### color-contrast
**Issue**: Text doesn't have enough contrast
**Fix**: Use colors that meet 4.5:1 ratio (3:1 for large text)
```css
/* ❌ Bad: Insufficient contrast */
color: #999; background: #fff; /* 2.8:1 */

/* ✅ Good: Sufficient contrast */
color: #666; background: #fff; /* 5.7:1 */
```

### label
**Issue**: Form input missing label
**Fix**: Add label element or aria-label
```ruby
# ✅ Fix: Add label
<label for="sku">SKU</label>
<input type="text" id="sku">
```

### button-name
**Issue**: Button without accessible name
**Fix**: Add text or aria-label
```ruby
# ✅ Fix: Add aria-label
<button aria-label="Close">×</button>
```

### image-alt
**Issue**: Image missing alt attribute
**Fix**: Add alt text (empty if decorative)
```ruby
# ✅ Fix: Add alt
<img src="logo.png" alt="Potlift8 Logo">
<img src="decoration.svg" alt="">
```

### heading-order
**Issue**: Heading levels skipped (h1 → h3)
**Fix**: Use sequential heading levels
```ruby
# ❌ Bad: Skipped h2
<h1>Page Title</h1>
<h3>Section Title</h3>

# ✅ Good: Sequential
<h1>Page Title</h1>
<h2>Section Title</h2>
```

## Keyboard Testing

### Essential Keys

- **Tab**: Move focus forward
- **Shift+Tab**: Move focus backward
- **Enter**: Activate links and buttons
- **Space**: Activate buttons, toggle checkboxes
- **Escape**: Close modals and dropdowns
- **Arrow Keys**: Navigate menus (if implemented)

### Manual Testing

1. Unplug your mouse
2. Tab through entire page
3. Verify all interactive elements can be reached
4. Check for visible focus indicators
5. Try activating elements with Enter/Space
6. Try closing dialogs with Escape

## Screen Reader Testing

### macOS VoiceOver

```bash
# Start VoiceOver
Cmd + F5

# Navigate
Ctrl + Option + Arrow keys

# Read current item
Ctrl + Option + Shift + Down

# Stop VoiceOver
Cmd + F5
```

### Windows NVDA (Free)

```bash
# Download from: https://www.nvaccess.org/

# Basic navigation
Insert + Down Arrow: Read next
Insert + Up Arrow: Read previous
Insert + Space: Toggle focus/browse mode
```

## Common Tailwind Classes

### Focus Indicators

```css
/* Always include focus styles */
focus:outline-none focus:ring-2 focus:ring-blue-500

/* For light backgrounds */
focus:ring-blue-500

/* For dark backgrounds */
focus:ring-white

/* With offset */
focus:ring-2 focus:ring-offset-2 focus:ring-blue-500
```

### Screen Reader Only Text

```css
/* Hide visually but keep for screen readers */
sr-only

/* Show when focused (for skip links) */
sr-only focus:not-sr-only
```

### ARIA Live Regions

```ruby
# Polite: Announced when convenient
<div aria-live="polite">Loading...</div>

# Assertive: Announced immediately
<div role="alert" aria-live="assertive">Error!</div>

# Status: For status messages
<div role="status" aria-live="polite">5 products found</div>
```

## Testing Workflow

### Before Committing

1. Run accessibility tests
   ```bash
   bundle exec rspec spec/system/accessibility/
   ```

2. Fix any violations

3. Do manual keyboard test (Tab through page)

4. Check with axe DevTools browser extension

### In Code Review

- [ ] All interactive elements keyboard accessible?
- [ ] Proper ARIA attributes?
- [ ] Color contrast sufficient?
- [ ] Form labels present?
- [ ] Images have alt text?
- [ ] Tests updated?

## Resources

- **Full Documentation**: `/docs/ACCESSIBILITY_TESTING.md`
- **Helper Methods**: `/spec/support/axe.rb`
- **Implementation Summary**: `/docs/ACCESSIBILITY_IMPLEMENTATION_SUMMARY.md`
- **WCAG Quick Reference**: https://www.w3.org/WAI/WCAG21/quickref/
- **axe-core Rules**: https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md

## Getting Help

1. Check this quick reference
2. Read `/docs/ACCESSIBILITY_TESTING.md`
3. Check helper methods in `/spec/support/axe.rb`
4. Review existing tests for examples
5. Consult WCAG documentation
6. Ask the team's accessibility champion

## Remember

- **Accessibility is not optional** - It's a requirement
- **Test early and often** - Don't wait until the end
- **Use semantic HTML** - It's accessible by default
- **Think keyboard-first** - Not everyone uses a mouse
- **Test with real users** - Automated tests catch most issues, but not all
