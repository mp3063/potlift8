# Accessibility Testing Documentation

This document describes the automated accessibility testing infrastructure for Potlift8, implemented as part of Phase 8 (Testing & Quality) of the frontend redesign plan.

## Overview

The accessibility testing suite uses **axe-core** via the `axe-core-rspec` gem to automatically test all UI components and pages for **WCAG 2.1 Level AA** compliance. This ensures that Potlift8 is accessible to all users, including those using assistive technologies like screen readers, keyboard-only navigation, and other accessibility tools.

## Tools and Technologies

- **axe-core**: Industry-standard accessibility testing engine from Deque Systems
- **axe-core-rspec**: RSpec integration for axe-core
- **Capybara + Selenium**: Browser automation for system tests
- **Chrome DevTools**: Used by axe-core for real-browser accessibility analysis

## Configuration

### Gem Installation

The `axe-core-rspec` gem is installed in the test group:

```ruby
# Gemfile
group :test do
  gem "axe-core-rspec"
end
```

### RSpec Configuration

Accessibility testing is configured in `/spec/support/axe.rb`:

- **WCAG Standards**: Tests for WCAG 2.1 Level A and AA compliance
- **Custom Helper Methods**: Keyboard navigation, focus management, ARIA testing
- **Shared Examples**: Reusable test patterns for components and pages

## Test Structure

### Test Files

```
spec/system/accessibility/
├── component_accessibility_spec.rb    # UI component accessibility tests
├── page_accessibility_spec.rb         # Full page accessibility tests
└── navigation_accessibility_spec.rb   # Keyboard navigation tests
```

### Test Categories

#### 1. Component Accessibility (`component_accessibility_spec.rb`)

Tests individual ViewComponents for accessibility:

- **Button Component**: All variants (primary, secondary, danger, ghost, link)
- **Badge Component**: Status badges with color contrast
- **Card Component**: Card structure and heading hierarchy
- **Modal Component**: Dialog ARIA attributes, focus trap, keyboard navigation
- **Flash Component**: Alert roles and dismissible messages
- **Navbar Component**: Semantic navigation, mobile menu, dropdowns
- **Form Components**: Empty states, form errors, pagination, breadcrumbs
- **Product Components**: Tables and forms with proper labels

**Key Tests:**
- WCAG 2.1 AA compliance
- Color contrast ratios (4.5:1 for normal text, 3:1 for large text)
- Keyboard accessibility
- ARIA attributes (roles, labels, states)
- Focus indicators
- Screen reader announcements

#### 2. Page Accessibility (`page_accessibility_spec.rb`)

Tests complete pages for accessibility:

- **Dashboard Page**: Stats cards, widget accessibility
- **Products Index**: Table structure, search, pagination
- **Product Forms**: New/edit forms with label associations
- **Product Show**: Product details, images with alt text
- **Search Page**: Search input, results announcement

**Key Tests:**
- Page title and meta information
- Single H1 heading per page
- Proper heading hierarchy (no skipped levels)
- Main landmark region
- All images have alt text
- Form inputs have associated labels
- Required fields are marked
- Error messages have alert roles
- Responsive design (mobile/tablet)

#### 3. Navigation Accessibility (`navigation_accessibility_spec.rb`)

Tests keyboard navigation and focus management:

- **Navbar Navigation**: Tab through links, focus indicators
- **Dropdown Menus**: Keyboard open/close, menu item navigation
- **Mobile Menu**: Mobile button, menu accessibility, focus trap
- **Modal Dialogs**: Focus trap, Escape to close, focus return
- **Skip Links**: Skip to main content functionality
- **Form Navigation**: Tab order, Shift+Tab backward navigation
- **Table Navigation**: Keyboard accessible action buttons
- **Focus Management**: Visible focus indicators, no hidden focus

**Key Tests:**
- Tab key navigation
- Shift+Tab backward navigation
- Enter/Space to activate buttons
- Escape to close dialogs/dropdowns
- Arrow keys for menu navigation (where implemented)
- Focus trap in modals and mobile menus
- Visible focus indicators on all interactive elements

## Running Accessibility Tests

### Run All Accessibility Tests

```bash
bundle exec rspec spec/system/accessibility/
```

### Run Specific Test File

```bash
bundle exec rspec spec/system/accessibility/component_accessibility_spec.rb
bundle exec rspec spec/system/accessibility/page_accessibility_spec.rb
bundle exec rspec spec/system/accessibility/navigation_accessibility_spec.rb
```

### Run Tests with Specific Tag

```bash
# Run only tests tagged with :accessibility
bundle exec rspec --tag accessibility

# Run specific component tests
bundle exec rspec spec/system/accessibility/component_accessibility_spec.rb:20
```

### Run Tests with Documentation Format

```bash
bundle exec rspec spec/system/accessibility/ --format documentation
```

## Helper Methods

The `/spec/support/axe.rb` file provides custom helper methods for accessibility testing:

### Axe-core Matchers

```ruby
# Test for WCAG 2.1 AA compliance
expect_no_axe_violations

# Test specific element
expect_no_violations_in('#main-content')

# Exclude elements from testing (e.g., third-party widgets)
expect_no_violations_excluding('.external-widget')

# Test specific accessibility rule
expect_rule_passes('color-contrast')

# Skip specific rules (document why)
expect_no_violations_skipping('color-contrast')
```

### Keyboard Navigation Helpers

```ruby
# Test element is keyboard navigable
expect_keyboard_navigable('nav', expected_elements: 5)

# Test focus order
test_focus_order(['#first', '#second', '#third'])

# Test visible focus indicator
expect_visible_focus_indicator('button')

# Test focus trap (for modals)
expect_focus_trapped_in('[role="dialog"]')

# Test skip link
expect_skip_to_main_content
```

### Other Helpers

```ruby
# Test color contrast
expect_sufficient_contrast('button', level: 'AA')
```

## Shared Examples

Reusable test patterns for common accessibility requirements:

### `accessible component`

```ruby
it_behaves_like 'accessible component' do
  let(:component) { Ui::ButtonComponent.new { 'Click Me' } }
end
```

Tests:
- Passes axe accessibility checks
- Has proper ARIA attributes
- Is keyboard navigable

### `accessible page`

```ruby
describe 'Dashboard', type: :system do
  before { visit root_path }

  it_behaves_like 'accessible page'
end
```

Tests:
- Passes WCAG 2.1 AA compliance
- Has proper document title
- Has main landmark
- Has single H1 heading
- All images have alt text

### `keyboard navigable`

```ruby
it_behaves_like 'keyboard navigable', 'nav'
```

Tests:
- Can be navigated with Tab key
- Has visible focus indicators
- Supports Escape key (if applicable)

## WCAG 2.1 Level AA Requirements

The test suite validates compliance with these key WCAG 2.1 AA requirements:

### Perceivable

- **1.1.1 Non-text Content**: All images have alt text
- **1.3.1 Info and Relationships**: Semantic HTML, proper headings
- **1.3.2 Meaningful Sequence**: Logical tab order
- **1.4.3 Contrast (Minimum)**: 4.5:1 for normal text, 3:1 for large text
- **1.4.11 Non-text Contrast**: 3:1 for UI components and graphics

### Operable

- **2.1.1 Keyboard**: All functionality available via keyboard
- **2.1.2 No Keyboard Trap**: Focus can move away from all components
- **2.4.1 Bypass Blocks**: Skip to main content link
- **2.4.3 Focus Order**: Logical and sequential
- **2.4.6 Headings and Labels**: Descriptive headings and labels
- **2.4.7 Focus Visible**: Visible focus indicators

### Understandable

- **3.1.1 Language of Page**: HTML lang attribute
- **3.2.1 On Focus**: No unexpected context changes on focus
- **3.2.2 On Input**: No unexpected context changes on input
- **3.3.1 Error Identification**: Errors clearly identified
- **3.3.2 Labels or Instructions**: Form inputs have labels

### Robust

- **4.1.1 Parsing**: Valid HTML
- **4.1.2 Name, Role, Value**: ARIA attributes used correctly
- **4.1.3 Status Messages**: Status messages announced to screen readers

## Common Accessibility Issues

### Issues Found and Fixed

1. **Missing alt text on images**
   - Fixed: Added alt attributes to all image tags
   - Test: `spec/system/accessibility/page_accessibility_spec.rb`

2. **Insufficient color contrast**
   - Fixed: Updated color palette to meet WCAG AA ratios
   - Test: `spec/system/accessibility/component_accessibility_spec.rb`

3. **Missing form labels**
   - Fixed: Associated all form inputs with labels
   - Test: `spec/system/accessibility/page_accessibility_spec.rb`

4. **Missing ARIA attributes on modals**
   - Fixed: Added role="dialog", aria-modal, aria-labelledby
   - Test: `spec/system/accessibility/component_accessibility_spec.rb`

5. **No focus trap in modals**
   - Fixed: Implemented focus trap in modal controller
   - Test: `spec/system/accessibility/navigation_accessibility_spec.rb`

6. **Missing skip to main content link**
   - Status: Needs implementation
   - Test: `spec/system/accessibility/navigation_accessibility_spec.rb`

### Common Violations to Watch For

- **color-contrast**: Text doesn't meet contrast ratio requirements
- **label**: Form input missing associated label
- **button-name**: Button without accessible name
- **image-alt**: Image missing alt attribute
- **aria-required-parent**: ARIA role without required parent
- **heading-order**: Heading levels skipped (h1 → h3)
- **link-name**: Link without accessible name
- **list**: List items not in ul/ol
- **region**: Page content not in landmarks

## Best Practices

### Component Development

1. **Use Semantic HTML**: Use proper HTML5 elements (nav, main, article, etc.)
2. **Keyboard Support**: Ensure all interactive elements are keyboard accessible
3. **Focus Management**: Provide visible focus indicators (focus:ring classes)
4. **ARIA When Needed**: Use ARIA attributes only when semantic HTML isn't sufficient
5. **Test Early**: Run accessibility tests as you build components

### Form Design

1. **Label Association**: Use `<label for="id">` or nest inputs in labels
2. **Required Fields**: Mark with `required` attribute and aria-required
3. **Error Messages**: Use role="alert" for immediate announcement
4. **Field Instructions**: Provide clear instructions and examples
5. **Validation**: Provide clear, specific error messages

### Modal/Dialog Design

1. **ARIA Role**: Use role="dialog" and aria-modal="true"
2. **Labeling**: Use aria-labelledby to reference title
3. **Focus Trap**: Keep focus within modal while open
4. **Escape Key**: Close modal with Escape key
5. **Focus Return**: Return focus to trigger element on close

### Navigation Design

1. **Skip Links**: Provide skip to main content link (first focusable element)
2. **Landmarks**: Use semantic landmarks (nav, main, aside, footer)
3. **Current Page**: Indicate current page with aria-current="page"
4. **Dropdown Menus**: Use aria-haspopup, aria-expanded, role="menu"
5. **Mobile Menu**: Ensure mobile menu is keyboard accessible

## Continuous Integration

### CI/CD Integration

Add accessibility tests to your CI pipeline:

```yaml
# .github/workflows/test.yml
- name: Run Accessibility Tests
  run: bundle exec rspec spec/system/accessibility/ --format documentation
```

### Quality Gates

Consider setting up quality gates:
- All accessibility tests must pass before merge
- No critical or serious violations allowed
- Manual review required for moderate violations

## Manual Testing

Automated tests catch most issues, but manual testing is still important:

### Screen Readers

Test with popular screen readers:
- **macOS**: VoiceOver (Cmd+F5)
- **Windows**: NVDA (free) or JAWS
- **Linux**: Orca

### Browser Extensions

Use these browser extensions for additional testing:
- **axe DevTools**: Browser extension for axe-core
- **WAVE**: Web accessibility evaluation tool
- **Lighthouse**: Chrome DevTools accessibility audit

### Keyboard Testing

Manually test keyboard navigation:
1. Unplug your mouse
2. Use only Tab, Shift+Tab, Enter, Space, Escape, Arrow keys
3. Verify all functionality is accessible
4. Check for visible focus indicators

### Responsive Testing

Test accessibility at different viewport sizes:
- Mobile: 375px x 667px (iPhone)
- Tablet: 768px x 1024px (iPad)
- Desktop: 1440px x 900px

## Resources

### Documentation

- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [axe-core Rule Descriptions](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md)
- [MDN Accessibility Guide](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [A11y Project](https://www.a11yproject.com/)

### Tools

- [axe DevTools](https://www.deque.com/axe/devtools/)
- [WAVE](https://wave.webaim.org/)
- [Chrome Lighthouse](https://developers.google.com/web/tools/lighthouse)
- [Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Testing Guides

- [WebAIM Screen Reader Testing](https://webaim.org/articles/screenreader_testing/)
- [Keyboard Accessibility](https://webaim.org/articles/keyboard/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)

## Maintenance

### Regular Reviews

- Run accessibility tests before each release
- Review new components for accessibility
- Update tests as UI components change
- Keep axe-core gem updated for latest rules

### Accessibility Champions

- Designate accessibility champions on the team
- Conduct accessibility training for developers
- Include accessibility in code review checklist
- Share accessibility wins and learnings

## Support

For questions about accessibility testing:
1. Check this documentation
2. Review the helper methods in `/spec/support/axe.rb`
3. Consult the axe-core documentation
4. Ask in the team's accessibility channel

## Conclusion

The automated accessibility testing infrastructure ensures that Potlift8 maintains WCAG 2.1 AA compliance throughout development. By running these tests regularly and following accessibility best practices, we create an inclusive application that works for all users.

Remember: **Accessibility is not a feature, it's a requirement.**
