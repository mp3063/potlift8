# Accessibility Testing Checklist
## Quick Reference for Developers

Use this checklist when creating new components or reviewing existing ones for WCAG 2.1 AA compliance.

---

## Pre-Deployment Checklist

### Perceivable

#### Images & Icons
- [ ] All images have appropriate alt text or aria-label
- [ ] Decorative images/icons use `aria-hidden="true"`
- [ ] Icon-only buttons have `aria-label` or visible text with `.sr-only`
- [ ] SVG icons use `<title>` or `aria-label` when functional

#### Color & Contrast
- [ ] Text color contrast ratio ≥ 4.5:1 for normal text
- [ ] Text color contrast ratio ≥ 3:1 for large text (18pt+ or 14pt+ bold)
- [ ] UI components have ≥ 3:1 contrast against adjacent colors
- [ ] Information not conveyed by color alone
- [ ] Links distinguishable from surrounding text (underline, weight, etc.)

#### Text & Content
- [ ] Text can be resized to 200% without loss of content
- [ ] Content readable without horizontal scrolling at 320px width
- [ ] Font size minimum 14px (0.875rem)
- [ ] Line height minimum 1.5x font size
- [ ] Paragraph spacing minimum 1.5x line height

### Operable

#### Keyboard Navigation
- [ ] All interactive elements keyboard accessible (Tab, Enter, Space)
- [ ] Focus order follows logical sequence
- [ ] Focus never trapped (or intentionally trapped in modals)
- [ ] No keyboard-only actions (no mouse-only operations)
- [ ] Keyboard shortcuts don't override browser/AT shortcuts

#### Focus Indicators
- [ ] All interactive elements have visible focus indicator
- [ ] Focus indicator has ≥ 3:1 contrast ratio with background
- [ ] Focus indicator not removed with `outline: none` without replacement
- [ ] Focus indicator visible in all states (default, hover, active)

#### Navigation
- [ ] Skip navigation link present and functional
- [ ] Page structure uses landmarks (nav, main, aside, footer)
- [ ] Current page indicated in navigation (aria-current="page")
- [ ] Breadcrumbs use proper markup (<nav><ol>)

#### Interactive Components
- [ ] Buttons use `<button>` or `role="button"`
- [ ] Links use `<a href="">` (not `<a onclick="">`)
- [ ] Dropdown menus support Arrow keys, Escape, Home, End
- [ ] Modal dialogs trap focus within dialog
- [ ] Modal dialogs close with Escape key
- [ ] Modal dialogs return focus to trigger element on close

### Understandable

#### Forms
- [ ] All inputs have associated `<label>` (visible or `.sr-only`)
- [ ] Required fields indicated (not only by color)
- [ ] Error messages associated with fields (aria-describedby)
- [ ] Error messages identify what's wrong and how to fix
- [ ] Form instructions provided before form, not after
- [ ] Autocomplete attributes used where appropriate

#### Navigation & Interaction
- [ ] Navigation consistent across pages
- [ ] Page title describes page content and is unique
- [ ] Headings describe page structure (H1 → H2 → H3, no skips)
- [ ] Link text describes destination (not "click here")
- [ ] Button text describes action (not generic "submit")

#### Content
- [ ] Language specified in HTML tag (`<html lang="en">`)
- [ ] Complex language explained or simplified
- [ ] Abbreviations/acronyms explained on first use
- [ ] Reading level appropriate for audience

### Robust

#### ARIA Usage
- [ ] ARIA only used when native HTML insufficient
- [ ] ARIA roles match element function
- [ ] ARIA states kept up to date (aria-expanded, aria-selected)
- [ ] ARIA relationships properly set (aria-labelledby, aria-describedby)
- [ ] ARIA landmark labels provided (aria-label on multiple navs)

#### HTML Validity
- [ ] HTML validates (no unclosed tags, proper nesting)
- [ ] IDs unique within page
- [ ] Attributes properly quoted
- [ ] Proper DOCTYPE declared

---

## Component-Specific Checklists

### Dropdown Menu

```erb
<div data-controller="dropdown">
  <!-- Trigger Button -->
  <button
    type="button"
    aria-expanded="false"
    aria-haspopup="true"
    aria-controls="menu-id"
    id="menu-button">
    Menu
  </button>

  <!-- Menu -->
  <div
    id="menu-id"
    role="menu"
    aria-orientation="vertical"
    aria-labelledby="menu-button"
    class="hidden">
    <a href="#" role="menuitem" tabindex="-1">Item 1</a>
    <a href="#" role="menuitem" tabindex="-1">Item 2</a>
  </div>
</div>
```

**Testing:**
- [ ] Button toggles with Enter/Space
- [ ] Menu opens on activation
- [ ] First item focused when menu opens
- [ ] Arrow Down/Up navigate menu items
- [ ] Home/End jump to first/last item
- [ ] Escape closes menu and returns focus
- [ ] Enter/Space activates current menu item
- [ ] Clicking outside closes menu
- [ ] `aria-expanded` updates when menu opens/closes
- [ ] Menu items have `tabindex="-1"` until menu opens

### Modal Dialog

```erb
<div
  data-controller="modal"
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  class="hidden">
  <div class="modal-backdrop"></div>
  <div class="modal-content">
    <h2 id="modal-title">Modal Title</h2>
    <button data-action="modal#close" aria-label="Close dialog">×</button>
    <!-- Content -->
  </div>
</div>
```

**Testing:**
- [ ] Opens with button/link activation
- [ ] Focus moves to modal when opened
- [ ] Focus trapped within modal (Tab cycles through modal only)
- [ ] Escape closes modal
- [ ] Close button keyboard accessible
- [ ] Focus returns to trigger element on close
- [ ] Background content not focusable when modal open
- [ ] Background scroll disabled when modal open
- [ ] `aria-modal="true"` present
- [ ] Modal has accessible name (aria-labelledby or aria-label)

### Form Field

```erb
<div>
  <label for="email-input">
    Email Address
    <span aria-hidden="true">*</span>
    <span class="sr-only">(required)</span>
  </label>
  <input
    type="email"
    id="email-input"
    name="email"
    required
    aria-required="true"
    aria-describedby="email-hint email-error"
    aria-invalid="false"
  >
  <p id="email-hint" class="hint">We'll never share your email</p>
  <p id="email-error" class="error hidden">Please enter a valid email</p>
</div>
```

**Testing:**
- [ ] Label associated with input (for attribute matches id)
- [ ] Required state communicated (not just asterisk)
- [ ] Hint text associated (aria-describedby)
- [ ] Error messages associated (aria-describedby)
- [ ] `aria-invalid` updated when validation fails
- [ ] Error message visible when invalid
- [ ] Error message describes problem and solution
- [ ] Field receives focus when error shown

### Button

```erb
<!-- Text Button (Best) -->
<button type="button">Save Changes</button>

<!-- Icon + Text (Good) -->
<button type="button">
  <svg aria-hidden="true">...</svg>
  Save
</button>

<!-- Icon Only (Needs Label) -->
<button type="button" aria-label="Save changes">
  <svg aria-hidden="true">...</svg>
</button>
```

**Testing:**
- [ ] Uses `<button>` element (not `<div>` with `role="button"`)
- [ ] Has visible text OR `aria-label`
- [ ] Icon marked `aria-hidden="true"` if text present
- [ ] `type` attribute specified (button, submit, reset)
- [ ] Keyboard accessible (Enter/Space activate)
- [ ] Focus indicator visible
- [ ] States communicated (disabled, loading, pressed)

### Link

```erb
<!-- Internal Link -->
<a href="/products">View Products</a>

<!-- External Link -->
<a href="https://example.com" target="_blank" rel="noopener noreferrer">
  External Site
  <span class="sr-only">(opens in new window)</span>
</a>

<!-- Download Link -->
<a href="/doc.pdf" download>
  Download PDF
  <span class="sr-only">(PDF, 2.5 MB)</span>
</a>
```

**Testing:**
- [ ] Uses `<a>` element with valid `href`
- [ ] Link text describes destination (not "click here")
- [ ] External links indicate they open new window
- [ ] Download links indicate file type and size
- [ ] Links distinguishable from surrounding text
- [ ] Focus indicator visible

### Alert/Flash Message

```erb
<div
  role="alert"
  aria-live="assertive"
  aria-atomic="true"
  class="flash-error">
  <svg aria-hidden="true">...</svg>
  <p>An error occurred. Please try again.</p>
  <button aria-label="Dismiss error message">×</button>
</div>

<div
  role="status"
  aria-live="polite"
  aria-atomic="true"
  class="flash-success">
  <svg aria-hidden="true">...</svg>
  <p>Changes saved successfully.</p>
  <button aria-label="Dismiss notification">×</button>
</div>
```

**Testing:**
- [ ] Error messages use `role="alert"` and `aria-live="assertive"`
- [ ] Success messages use `role="status"` and `aria-live="polite"`
- [ ] Icon marked `aria-hidden="true"`
- [ ] Dismiss button has `aria-label`
- [ ] Dismiss button keyboard accessible
- [ ] Auto-dismiss timer can be paused or disabled
- [ ] Error messages don't auto-dismiss
- [ ] Sufficient color contrast

---

## Testing Tools

### Browser DevTools

**Chrome DevTools Lighthouse:**
1. Open DevTools (F12)
2. Navigate to Lighthouse tab
3. Select "Accessibility" category
4. Click "Generate report"

**Chrome DevTools Contrast Checker:**
1. Inspect element
2. Click color square in Styles panel
3. View contrast ratio in color picker

**Firefox Accessibility Inspector:**
1. Open DevTools (F12)
2. Navigate to Accessibility tab
3. Enable "Check for issues"

### Browser Extensions

- **axe DevTools** (Chrome/Firefox) - Comprehensive WCAG testing
- **WAVE** (Chrome/Firefox) - Visual feedback on accessibility issues
- **Accessibility Insights** (Chrome/Edge) - Microsoft's testing tool

### Screen Readers

- **NVDA** (Windows) - Free, https://www.nvaccess.org/
- **JAWS** (Windows) - Industry standard (paid)
- **VoiceOver** (macOS) - Built-in, activate with Cmd+F5
- **TalkBack** (Android) - Built-in
- **VoiceOver** (iOS) - Built-in

### Keyboard Testing

**Essential Keys:**
- `Tab` - Move focus forward
- `Shift+Tab` - Move focus backward
- `Enter` - Activate button/link
- `Space` - Activate button, check checkbox
- `Escape` - Close dialog/menu
- `Arrow keys` - Navigate menu items, radio buttons
- `Home/End` - Jump to start/end

**Test Process:**
1. Unplug mouse (or hide it)
2. Tab through entire page
3. Verify focus always visible
4. Verify all interactive elements reachable
5. Verify logical tab order
6. Test all keyboard shortcuts

---

## Quick Color Contrast Reference

### WCAG Requirements

| Text Size | Contrast Ratio | Example |
|-----------|----------------|---------|
| Normal text (<18pt or <14pt bold) | 4.5:1 | Body copy, labels |
| Large text (≥18pt or ≥14pt bold) | 3:1 | Headings, hero text |
| UI components (borders, icons) | 3:1 | Buttons, form borders |
| Inactive/disabled | No requirement | Disabled buttons |

### Common Tailwind Combinations

| Combination | Ratio | Pass/Fail |
|-------------|-------|-----------|
| gray-900 on white | 17.5:1 | ✓✓✓ |
| gray-700 on white | 8.3:1 | ✓✓ |
| gray-600 on white | 5.4:1 | ✓ |
| gray-500 on white | 3.9:1 | ❌ (normal) ✓ (large) |
| gray-400 on white | 2.8:1 | ❌ |
| gray-400 on gray-900 | 4.1:1 | ❌ (needs 4.5:1) |
| gray-300 on gray-900 | 6.4:1 | ✓✓ |
| white on blue-600 | 4.5:1 | ✓ |
| white on blue-500 | 3.2:1 | ❌ (normal) ✓ (large) |

**Tool:** Use https://webaim.org/resources/contrastchecker/ to verify custom colors

---

## RSpec Testing Helpers

### Install axe-core-rspec

```ruby
# Gemfile
group :test do
  gem 'axe-core-rspec'
end

# spec/rails_helper.rb
require 'axe-rspec'

RSpec.configure do |config|
  config.around(:each, :accessibility) do |example|
    Capybara.current_driver = :selenium_chrome_headless
    example.run
  end
end
```

### Example Tests

```ruby
# spec/features/accessibility_spec.rb
RSpec.describe "Accessibility", type: :feature, js: true do
  it "has no violations on homepage", :accessibility do
    visit root_path
    expect(page).to be_axe_clean
  end

  it "dropdown is keyboard accessible" do
    visit root_path

    # Focus dropdown button
    page.driver.browser.action.send_keys(:tab).perform
    # Open with Enter
    page.driver.browser.action.send_keys(:enter).perform

    expect(page).to have_css('[role="menu"]:not(.hidden)')

    # Navigate with Arrow Down
    page.driver.browser.action.send_keys(:arrow_down).perform
    expect(page).to have_css('[role="menuitem"]:focus')

    # Close with Escape
    page.driver.browser.action.send_keys(:escape).perform
    expect(page).to have_css('[role="menu"].hidden')
  end

  it "modal traps focus" do
    visit root_path

    click_button "Open Modal"

    # Focus should be in modal
    within('[role="dialog"]') do
      expect(page).to have_css(':focus')
    end

    # Tab through all focusable elements
    10.times { page.driver.browser.action.send_keys(:tab).perform }

    # Focus should still be in modal
    within('[role="dialog"]') do
      expect(page).to have_css(':focus')
    end
  end
end

# spec/system/keyboard_navigation_spec.rb
RSpec.describe "Keyboard Navigation", type: :system, js: true do
  it "skip link jumps to main content" do
    visit root_path

    # Tab to skip link
    page.driver.browser.action.send_keys(:tab).perform
    expect(page).to have_css(':focus', text: 'Skip to main content')

    # Activate skip link
    page.driver.browser.action.send_keys(:enter).perform

    # Main content should be focused
    expect(page).to have_css('#main-content:focus')
  end

  it "navigation is keyboard accessible" do
    visit root_path

    # Tab to first nav item
    within('nav[aria-label="Main navigation"]') do
      find('a', match: :first).send_keys(:tab)
      expect(page).to have_css('a:focus')
    end
  end
end
```

---

## Resources

### Official Documentation
- [WCAG 2.1](https://www.w3.org/TR/WCAG21/)
- [ARIA Authoring Practices Guide](https://www.w3.org/WAI/ARIA/apg/)
- [MDN Accessibility](https://developer.mozilla.org/en-US/docs/Web/Accessibility)

### Tools
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)
- [WAVE Web Accessibility Evaluation Tool](https://wave.webaim.org/)
- [axe DevTools](https://www.deque.com/axe/devtools/)

### Learning
- [A11y Project Checklist](https://www.a11yproject.com/checklist/)
- [WebAIM Articles](https://webaim.org/articles/)
- [Inclusive Components](https://inclusive-components.design/)

---

## Common Mistakes to Avoid

1. **Don't** remove focus outlines without providing alternative
2. **Don't** use `<div>` or `<span>` for buttons/links
3. **Don't** rely on color alone to convey information
4. **Don't** use placeholder text as labels
5. **Don't** use `title` attribute for important information
6. **Don't** use `tabindex` > 0 (disrupts natural tab order)
7. **Don't** create custom controls without ARIA patterns
8. **Don't** auto-play audio or video without controls
9. **Don't** use `target="_blank"` without warning
10. **Don't** forget to test with actual assistive technology

---

**Remember:** Accessibility is not a checklist, it's a practice. Test early, test often, and test with real users!
