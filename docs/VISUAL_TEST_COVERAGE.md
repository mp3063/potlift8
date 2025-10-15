# Visual Test Coverage Plan

## Overview

This document tracks visual regression test coverage for all ViewComponents in the Potlift8 application.

**Goal:** 80%+ coverage of UI components with visual regression tests
**Current Status:** 36 tests implemented (Core UI components complete)

---

## Coverage Summary

| Priority | Components | Tests Planned | Tests Implemented | Status |
|----------|-----------|--------------|-------------------|---------|
| P1: Core UI | 3 | 36 | 36 | ✅ Complete |
| P2: Complex | 4 | 22 | 0 | 🟡 Not Started |
| P3: Supporting | 5 | 30 | 0 | 🟡 Not Started |
| P4: Pages | 3 | 14 | 0 | 🟡 Not Started |
| **Total** | **15** | **102** | **36** | **35% Complete** |

---

## Priority 1: Core UI Components ✅ COMPLETE

These foundational components are used throughout the application and require comprehensive visual coverage.

### Ui::ButtonComponent ✅ COMPLETE (14 tests)

**File:** `spec/components/ui/button_component_spec.rb`

**Coverage:**
- ✅ Variants: primary, secondary, danger, ghost, link (5 tests)
- ✅ Sizes: sm, md, lg (3 tests)
- ✅ States: disabled, loading (2 tests)
- ✅ Icons: left, right (2 tests)
- ✅ Focus states: all variants (integrated in variant tests)

**Test Names:**
```ruby
button_primary, button_secondary, button_danger, button_ghost, button_link
button_size_sm, button_size_md, button_size_lg
button_state_disabled, button_state_loading
button_icon_left, button_icon_right
```

**Viewports:** Desktop (1440px) only
**Total Screenshots:** 14

---

### Ui::CardComponent ✅ COMPLETE (11 tests)

**File:** `spec/components/ui/card_component_spec.rb`

**Coverage:**
- ✅ Basic variations: default, no border, hover (3 tests)
- ✅ Padding: none, sm, md, lg (4 tests)
- ✅ Slots: header, footer, header+footer, actions (4 tests)

**Test Names:**
```ruby
card_default, card_no_border, card_hover
card_padding_none, card_padding_sm, card_padding_md, card_padding_lg
card_with_header, card_with_footer, card_header_footer, card_with_actions
card_rich_content
```

**Viewports:** Desktop (1440px) only
**Total Screenshots:** 11

---

### Ui::ModalComponent ✅ COMPLETE (11 tests)

**File:** `spec/components/ui/modal_component_spec.rb`

**Coverage:**
- ✅ Sizes: sm, md, lg, xl (4 tests)
- ✅ Slots: header+body, footer, trigger (3 tests)
- ✅ Closable: true, false (2 tests)
- ✅ Complex: full-featured, form modal (2 tests)

**Test Names:**
```ruby
modal_size_sm, modal_size_md, modal_size_lg, modal_size_xl
modal_header_body, modal_with_footer, modal_with_trigger
modal_closable, modal_not_closable
modal_full_featured, modal_form
```

**Viewports:** Desktop (1440px) only
**Total Screenshots:** 11

---

## Priority 2: Complex Components (22 tests planned)

These components have significant logic and responsive behavior.

### Shared::NavbarComponent 🟡 NOT STARTED (6 tests)

**File:** `spec/components/shared/navbar_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Authentication states: authenticated, unauthenticated (2 tests)
- [ ] Dropdown: closed, open (2 tests)
- [ ] Responsive: mobile (375px), desktop (1440px) (2 tests)

**Test Names:**
```ruby
navbar_authenticated_desktop_1440x900
navbar_authenticated_mobile_375x667
navbar_unauthenticated_desktop_1440x900
navbar_dropdown_open
navbar_dropdown_closed
navbar_with_notifications
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 6

**Implementation Notes:**
```ruby
describe "visual regression", :visual do
  let(:user) { { email: "user@example.com", name: "John Doe" } }

  it "matches baseline for authenticated state at desktop" do
    screenshot_component(
      Shared::NavbarComponent.new(user: user),
      name: "navbar_authenticated",
      viewports: [:desktop]
    )
  end

  it "matches baseline for authenticated state at mobile" do
    screenshot_component(
      Shared::NavbarComponent.new(user: user),
      name: "navbar_authenticated",
      viewports: [:mobile]
    )
  end

  # ... more tests
end
```

---

### Shared::MobileSidebarComponent 🟡 NOT STARTED (4 tests)

**File:** `spec/components/shared/mobile_sidebar_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] States: closed, open (2 tests)
- [ ] Active items: none, selected (2 tests)

**Test Names:**
```ruby
mobile_sidebar_closed_mobile_375x667
mobile_sidebar_open_mobile_375x667
mobile_sidebar_active_item
mobile_sidebar_nested_navigation
```

**Viewports:** Mobile (375px) only
**Estimated Screenshots:** 4

---

### Products::TableComponent 🟡 NOT STARTED (6 tests)

**File:** `spec/components/products/table_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Data states: full (5 rows), empty, loading (3 tests)
- [ ] Responsive: mobile, tablet, desktop (3 tests)

**Test Names:**
```ruby
products_table_full_desktop_1440x900
products_table_full_mobile_375x667
products_table_empty
products_table_loading
products_table_sorted
products_table_selected_rows
```

**Viewports:** Mobile (375px), Tablet (768px), Desktop (1440px)
**Estimated Screenshots:** 6

**Implementation Notes:**
```ruby
describe "visual regression", :visual do
  let(:company) { create(:company) }
  let(:products) { create_list(:product, 5, company: company) }

  it "matches baseline for full table at desktop" do
    screenshot_component(
      Products::TableComponent.new(products: products),
      name: "products_table_full",
      viewports: [:desktop]
    )
  end

  it "matches baseline for empty state" do
    render_inline(Products::TableComponent.new(products: []))
    expect(page).to match_screenshot("products_table_empty")
  end
end
```

---

### Products::FormComponent 🟡 NOT STARTED (6 tests)

**File:** `spec/components/products/form_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] States: empty, filled, errors (3 tests)
- [ ] Product types: sellable, configurable, bundle (3 tests)

**Test Names:**
```ruby
products_form_empty
products_form_filled
products_form_errors
products_form_sellable_type
products_form_configurable_type
products_form_bundle_type
```

**Viewports:** Desktop (1440px) only
**Estimated Screenshots:** 6

---

## Priority 3: Supporting Components (30 tests planned)

These components provide supporting functionality and need visual stability.

### Ui::BadgeComponent 🟡 NOT STARTED (12 tests)

**File:** `spec/components/ui/badge_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Variants: default, success, warning, danger, info (5 tests)
- [ ] Styles: solid, outline, soft (3 tests)
- [ ] Sizes: sm, md, lg (3 tests)
- [ ] With icons (1 test)

**Test Names:**
```ruby
badge_default, badge_success, badge_warning, badge_danger, badge_info
badge_style_solid, badge_style_outline, badge_style_soft
badge_size_sm, badge_size_md, badge_size_lg
badge_with_icon
```

**Viewports:** Desktop (1440px) only
**Estimated Screenshots:** 12

---

### Shared::PaginationComponent 🟡 NOT STARTED (6 tests)

**File:** `spec/components/shared/pagination_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] States: first page, middle page, last page (3 tests)
- [ ] Edge cases: single page, many pages (ellipsis) (2 tests)
- [ ] Responsive: mobile, desktop (2 tests integrated)

**Test Names:**
```ruby
pagination_first_page
pagination_middle_page
pagination_last_page
pagination_single_page
pagination_many_pages
pagination_mobile_375x667
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 6

---

### Shared::BreadcrumbComponent 🟡 NOT STARTED (4 tests)

**File:** `spec/components/shared/breadcrumb_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Levels: single, multiple (2-5 items) (3 tests)
- [ ] Responsive: mobile (truncation), desktop (1 test)

**Test Names:**
```ruby
breadcrumb_single_level
breadcrumb_multiple_levels
breadcrumb_long_text
breadcrumb_mobile_375x667
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 4

---

### Shared::EmptyStateComponent 🟡 NOT STARTED (4 tests)

**File:** `spec/components/shared/empty_state_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Variants: with icon, without icon (2 tests)
- [ ] With/without action button (2 tests integrated)

**Test Names:**
```ruby
empty_state_with_icon
empty_state_without_icon
empty_state_with_action
empty_state_no_action
```

**Viewports:** Desktop (1440px) only
**Estimated Screenshots:** 4

---

### Shared::FormErrorsComponent 🟡 NOT STARTED (4 tests)

**File:** `spec/components/shared/form_errors_component_spec.rb` (to be updated)

**Planned Coverage:**
- [ ] Error counts: single, multiple (2 tests)
- [ ] Long messages (1 test)
- [ ] Responsive: mobile, desktop (1 test)

**Test Names:**
```ruby
form_errors_single
form_errors_multiple
form_errors_long_messages
form_errors_mobile_375x667
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 4

---

## Priority 4: Application Pages (14 tests planned)

Full page testing for critical user flows.

### Dashboard Page 🟡 NOT STARTED (4 tests)

**File:** `spec/system/dashboard_spec.rb` (new file)

**Planned Coverage:**
- [ ] States: empty data, full data (2 tests)
- [ ] Responsive: mobile, desktop (2 tests)

**Test Names:**
```ruby
dashboard_full_desktop_1440x900
dashboard_empty_desktop_1440x900
dashboard_full_mobile_375x667
dashboard_empty_mobile_375x667
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 4

---

### Products Index Page 🟡 NOT STARTED (6 tests)

**File:** `spec/system/products_spec.rb` (new file)

**Planned Coverage:**
- [ ] List views: with products, empty (2 tests)
- [ ] Search: active, inactive (2 tests)
- [ ] Responsive: mobile, desktop (2 tests integrated)

**Test Names:**
```ruby
products_index_list_desktop_1440x900
products_index_empty_desktop_1440x900
products_index_search_active
products_index_list_mobile_375x667
products_index_filters_applied
products_index_loading_state
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 6

---

### Search Results Page 🟡 NOT STARTED (4 tests)

**File:** `spec/system/search_spec.rb` (new file)

**Planned Coverage:**
- [ ] States: with results, no results, loading (3 tests)
- [ ] Responsive: mobile, desktop (1 test)

**Test Names:**
```ruby
search_with_results_desktop_1440x900
search_no_results
search_loading
search_with_results_mobile_375x667
```

**Viewports:** Mobile (375px), Desktop (1440px)
**Estimated Screenshots:** 4

---

## Implementation Roadmap

### Phase 1: Core UI (Complete ✅)
**Timeline:** Completed
**Components:** Button, Card, Modal
**Tests:** 36 tests implemented
**Status:** ✅ Done

### Phase 2: Complex Components (Week 1-2)
**Timeline:** 2 weeks
**Components:** Navbar, MobileSidebar, Products Table, Products Form
**Tests:** 22 tests to implement
**Effort:** ~8-10 hours
**Priority:** HIGH

### Phase 3: Supporting Components (Week 3-4)
**Timeline:** 2 weeks
**Components:** Badge, Pagination, Breadcrumb, EmptyState, FormErrors
**Tests:** 30 tests to implement
**Effort:** ~10-12 hours
**Priority:** MEDIUM

### Phase 4: Application Pages (Week 5)
**Timeline:** 1 week
**Components:** Dashboard, Products Index, Search Results
**Tests:** 14 tests to implement
**Effort:** ~6-8 hours
**Priority:** LOW

**Total Timeline:** 5 weeks
**Total Effort:** ~24-30 hours
**Final Coverage:** 102 tests (80%+ of UI)

---

## Running Visual Tests

### Run All Visual Tests
```bash
bundle exec rspec --tag visual
```

### Run Specific Component
```bash
bundle exec rspec spec/components/ui/button_component_spec.rb --tag visual
```

### Run by Priority
```bash
# Priority 1 (Core UI)
bundle exec rspec spec/components/ui/ --tag visual

# Priority 2 (Complex)
bundle exec rspec spec/components/shared/navbar_component_spec.rb --tag visual
bundle exec rspec spec/components/products/ --tag visual

# Priority 3 (Supporting)
bundle exec rspec spec/components/shared/ --tag visual

# Priority 4 (Pages)
bundle exec rspec spec/system/ --tag visual
```

### Generate New Baselines
```bash
SCREENSHOT_BASELINE=1 bundle exec rspec --tag visual
```

---

## Maintenance Guidelines

### When to Update Baselines

1. **Intentional UI Changes:**
   - New design tokens applied
   - Component styling updated
   - Layout adjustments

2. **After Review:**
   - Verify diff images look correct
   - Confirm changes are intentional
   - Update baselines and commit

### How to Update Baselines

```bash
# 1. Run tests and review diffs
bundle exec rspec --tag visual

# 2. Review diff images
open spec/visual/*.diff.png

# 3. Accept changes
mv spec/visual/*.new.png spec/visual/*.png

# 4. Commit updates
git add spec/visual/
git commit -m "Update visual baselines for [reason]"
```

### Best Practices

1. **Group Updates:** Update baselines for related changes together
2. **Clear Messages:** Commit messages should explain why baselines changed
3. **Review Diffs:** Always review before accepting changes
4. **Test Coverage:** Add visual tests for new components immediately
5. **Regular Runs:** Run visual tests before each PR

---

## Success Metrics

Track these metrics monthly:

### Test Coverage
- **Target:** 80%+ of UI components
- **Current:** 35% (36/102 tests)
- **Next Milestone:** 50% (52/102 tests) - After Phase 2

### Bug Detection
- **Target:** 80%+ of visual regressions caught
- **Measure:** Visual bugs found in PR vs production
- **Goal:** Catch before merge

### False Positives
- **Target:** <10% false positive rate
- **Measure:** Tests failing for acceptable changes
- **Action:** Adjust tolerance if >10%

### Maintenance Time
- **Target:** <2 hours/month
- **Measure:** Time updating baselines
- **Action:** Optimize if >2 hours/month

---

## Resources

- [Visual Testing Documentation](/Users/sin/RubymineProjects/Ozz-Rails-8/Potlift8/docs/VISUAL_TESTING.md)
- [Tool Recommendation](/Users/sin/RubymineProjects/Ozz-Rails-8/Potlift8/docs/VISUAL_TESTING_RECOMMENDATION.md)
- [Capybara Screenshot Diff GitHub](https://github.com/donv/capybara-screenshot-diff)
- [ViewComponent Testing](https://viewcomponent.org/guide/testing.html)

---

**Last Updated:** 2025-10-14
**Next Review:** After Phase 2 completion (2 weeks)
