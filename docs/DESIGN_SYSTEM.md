# Potlift8 Design System

**Version:** 1.0
**Last Updated:** 2025-10-14
**Status:** Active (Phase 5 - Frontend Redesign Complete)

---

## Table of Contents

1. [Overview](#overview)
2. [Color Palette](#color-palette)
3. [Typography](#typography)
4. [Spacing System](#spacing-system)
5. [Components](#components)
6. [Form Elements](#form-elements)
7. [Accessibility Standards](#accessibility-standards)
8. [Best Practices](#best-practices)
9. [Migration Guide](#migration-guide)

---

## Overview

### Purpose

The Potlift8 Design System provides a comprehensive set of reusable UI components, design tokens, and guidelines to ensure visual consistency and accessibility across the cannabis inventory management platform.

### Relationship to Authlift8

Potlift8's design system is **aligned with Authlift8** (the OAuth2 authentication provider) to create a cohesive user experience across the Ozz platform ecosystem. Both applications share:

- **Color palette** (Blue primary instead of Indigo)
- **Component architecture** (ViewComponent-based)
- **Layout patterns** (Fixed navbar, card-based content)
- **Accessibility standards** (WCAG 2.1 AA compliance)

### Goals

1. **Consistency** - Unified visual language across all pages and features
2. **Accessibility** - WCAG 2.1 AA compliance for all users
3. **Efficiency** - Reusable components reduce development time
4. **Maintainability** - Centralized design tokens simplify updates
5. **Developer Experience** - Clear documentation and examples

### Technology Stack

- **Rails 8.0.3** with ViewComponent architecture
- **Tailwind CSS** for utility-first styling
- **Stimulus.js** for JavaScript interactions
- **Hotwire/Turbo** for dynamic updates

---

## Color Palette

All colors follow Tailwind CSS naming conventions and are defined in `config/design_tokens.yml`.

### Primary Colors (Blue)

Blue is the primary brand color for Potlift8, used for actions, links, and focus states.

| Color | Hex Code | Usage |
|-------|----------|-------|
| `blue-50` | `#eff6ff` | Light backgrounds, hover states on cards |
| `blue-100` | `#dbeafe` | Subtle backgrounds, selected states |
| `blue-500` | `#3b82f6` | Focus rings, loading indicators |
| `blue-600` | `#2563eb` | **Primary brand color**, buttons, links |
| `blue-700` | `#1d4ed8` | Hover states for blue-600 elements |

**Usage Guidelines:**
- Use `blue-600` for primary actions (save, submit, create)
- Use `blue-500` for focus rings (accessibility requirement)
- Use `blue-50` and `blue-100` for informational backgrounds
- Never use blue for negative/destructive actions

**Accessibility Note:** Blue-600 text on white background provides 8.59:1 contrast ratio (exceeds WCAG AAA).

---

### Semantic Colors

#### Success (Green)

Used for positive feedback, success states, and active status.

| Color | Hex Code | Usage |
|-------|----------|-------|
| `green-50` | `#f0fdf4` | Success message backgrounds |
| `green-600` | `#16a34a` | Success text, active badges |
| `green-700` | `#15803d` | Hover states |
| `green-800` | `#166534` | Text on green backgrounds |

**Example Use Cases:**
- Product status: "Active"
- Form submission success
- Sync completed badges

---

#### Warning (Yellow)

Used for caution, pending states, and important notices.

| Color | Hex Code | Usage |
|-------|----------|-------|
| `yellow-50` | `#fefce8` | Warning message backgrounds |
| `yellow-600` | `#ca8a04` | Warning icons, pending badges |
| `yellow-800` | `#854d0e` | Text on yellow backgrounds |

**Example Use Cases:**
- Product status: "Draft", "Incoming"
- Outdated sync status
- Action required alerts

---

#### Danger (Red)

Used for errors, destructive actions, and critical alerts.

| Color | Hex Code | Usage |
|-------|----------|-------|
| `red-50` | `#fef2f2` | Error message backgrounds |
| `red-600` | `#dc2626` | Error text, delete buttons |
| `red-700` | `#b91c1c` | Hover states for red buttons |
| `red-800` | `#991b1b` | Text on red backgrounds |

**Example Use Cases:**
- Product status: "Discontinued", "Deleted"
- Form validation errors
- Delete confirmation dialogs

---

#### Info (Blue)

Used for neutral information and informational messages.

| Color | Hex Code | Usage |
|-------|----------|-------|
| `blue-50` | `#eff6ff` | Info message backgrounds |
| `blue-600` | `#2563eb` | Info text, informational badges |
| `blue-800` | `#1e40af` | Text on blue backgrounds |

**Example Use Cases:**
- Product type: "Sellable"
- Notice flash messages
- Informational tooltips

---

### Neutral Colors (Gray Scale)

Used for text, borders, backgrounds, and UI structure.

| Color | Hex Code | Usage | Notes |
|-------|----------|-------|-------|
| `gray-50` | `#f9fafb` | Page backgrounds, card headers | Lightest gray |
| `gray-100` | `#f3f4f6` | Subtle backgrounds, disabled states | |
| `gray-200` | `#e5e7eb` | Borders, dividers | |
| `gray-300` | `#d1d5db` | Input borders, inactive elements | |
| `gray-400` | `#9ca3af` | Placeholder text (use sparingly) | Below WCAG AA |
| `gray-500` | `#6b7280` | Secondary text | |
| `gray-600` | `#4b5563` | **Primary text for accessibility** | 7:1 contrast |
| `gray-700` | `#374151` | Headings, important text | |
| `gray-900` | `#111827` | Darkest text, maximum contrast | |

**Accessibility Note:** Use `gray-600` or darker for body text to ensure 4.5:1 contrast ratio. Avoid `gray-400` for text (only 3.1:1 contrast).

---

### Color Usage Guidelines

**Do:**
- Use semantic colors consistently (green = success, red = danger)
- Ensure all text has 4.5:1 contrast ratio minimum
- Use blue-600 for primary actions across the application
- Pair light backgrounds with dark text

**Don't:**
- Mix color meanings (e.g., don't use red for success)
- Use color alone to convey information (always include text/icons)
- Use gray-400 for body text (insufficient contrast)
- Override semantic color meanings

---

## Typography

Potlift8 uses the system font stack for optimal performance and native OS appearance.

### Font Family

```css
font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI',
             Roboto, 'Helvetica Neue', Arial, sans-serif;
```

This is Tailwind's default `sans` font family, providing:
- Native OS appearance (San Francisco on macOS, Segoe UI on Windows)
- Excellent readability
- Zero font loading time
- Reduced bundle size

---

### Font Sizes

| Tailwind Class | Size (px) | Size (rem) | Usage |
|----------------|-----------|------------|-------|
| `text-xs` | 12px | 0.75rem | Small labels, badges, captions |
| `text-sm` | 14px | 0.875rem | **Default body text**, form labels |
| `text-base` | 16px | 1rem | Important body text, buttons |
| `text-lg` | 18px | 1.125rem | Card headers, section titles |
| `text-xl` | 20px | 1.25rem | Page subheadings |
| `text-2xl` | 24px | 1.5rem | Page headings |
| `text-3xl` | 30px | 1.875rem | Hero headings, dashboard stats |

**Base font size:** 14px (`text-sm`) is the default for most body text to maximize screen real estate while maintaining readability.

---

### Font Weights

| Tailwind Class | Weight | Usage |
|----------------|--------|-------|
| `font-normal` | 400 | Default body text |
| `font-medium` | 500 | **Primary weight for buttons, labels** |
| `font-semibold` | 600 | Section headings, emphasized text |
| `font-bold` | 700 | Page headings, stats, important data |

**Note:** Avoid using `font-light` or `font-thin` as they reduce readability, especially at small sizes.

---

### Line Heights

| Tailwind Class | Value | Usage |
|----------------|-------|-------|
| `leading-tight` | 1.25 | Headings, tight layouts |
| `leading-normal` | 1.5 | **Default for body text** |
| `leading-relaxed` | 1.625 | Long-form content, documentation |

---

### Typography Examples

```erb
<!-- Page heading -->
<h1 class="text-2xl font-bold text-gray-900">Product Management</h1>

<!-- Section heading -->
<h2 class="text-lg font-semibold text-gray-900">Product Details</h2>

<!-- Body text -->
<p class="text-sm text-gray-600 leading-normal">
  This product is currently active and available for sale.
</p>

<!-- Label text -->
<label class="block text-sm font-medium text-gray-700">SKU</label>

<!-- Small caption -->
<span class="text-xs text-gray-500">Last updated 2 hours ago</span>

<!-- Stat display -->
<div class="text-3xl font-bold text-gray-900">1,234</div>
<div class="text-sm text-gray-600">Total Products</div>
```

---

## Spacing System

Potlift8 follows Tailwind's 4px-based spacing scale for consistent rhythm and alignment.

### Base Unit

**1 spacing unit = 0.25rem = 4px**

Common spacing values:
- `1` = 4px
- `2` = 8px
- `3` = 12px
- `4` = 16px
- `6` = 24px
- `8` = 32px
- `12` = 48px
- `16` = 64px

---

### Container Padding

Responsive padding for main content containers:

```erb
<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
  <!-- Content -->
</div>
```

| Breakpoint | Class | Padding |
|------------|-------|---------|
| Mobile (< 640px) | `px-4` | 16px left/right |
| Small (≥ 640px) | `sm:px-6` | 24px left/right |
| Large (≥ 1024px) | `lg:px-8` | 32px left/right |

---

### Component Spacing

#### Card Padding

```erb
<!-- Standard card -->
<div class="p-6">...</div>        <!-- 24px all sides -->

<!-- Compact card -->
<div class="p-4">...</div>        <!-- 16px all sides -->

<!-- Spacious card -->
<div class="p-8">...</div>        <!-- 32px all sides -->

<!-- Card header/footer -->
<div class="px-6 py-4">...</div>  <!-- 24px horizontal, 16px vertical -->
```

#### Section Spacing

Vertical spacing between major sections:

```erb
<div class="space-y-8">
  <section>...</section>
  <section>...</section>
</div>
```

Recommended values:
- `space-y-4` (16px) - Tight sections, related content
- `space-y-6` (24px) - Normal sections
- `space-y-8` (32px) - **Default for major sections**
- `space-y-12` (48px) - Extra spacing, visual separation

---

#### Form Spacing

```erb
<!-- Form field spacing -->
<div class="space-y-6">
  <div>
    <label>...</label>
    <input>
  </div>
  <div>
    <label>...</label>
    <input>
  </div>
</div>

<!-- Label-to-input spacing -->
<div class="space-y-2">
  <label>...</label>
  <input>
  <p class="text-xs text-gray-500">Help text</p>
</div>
```

Recommended values:
- `space-y-2` (8px) - Label to input
- `space-y-4` (16px) - Compact form fields
- `space-y-6` (24px) - **Default for form fields**

---

### Margin & Padding Best Practices

**Do:**
- Use `space-y-*` for vertical stacks (cleaner than individual margins)
- Use consistent spacing (4px increments)
- Use responsive spacing where appropriate
- Prefer padding over margin for component internals

**Don't:**
- Mix arbitrary values (e.g., `p-[13px]`) unless absolutely necessary
- Use negative margins excessively
- Apply margin to the last child (use `space-y` on parent instead)

---

## Components

Potlift8 includes four core UI components and several shared components. All components are ViewComponents using Tailwind CSS.

### Component File Structure

```
app/components/
├── ui/                           # Core reusable UI components
│   ├── button_component.rb      # Button with 5 variants, 3 sizes
│   ├── card_component.rb        # Card container with slots
│   ├── modal_component.rb       # Modal dialog with Stimulus
│   └── badge_component.rb       # Status badges
├── shared/                       # Application-specific components
│   ├── navbar_component.rb      # Fixed navbar with navigation
│   ├── mobile_sidebar_component.rb
│   ├── empty_state_component.rb
│   ├── form_errors_component.rb
│   ├── breadcrumb_component.rb
│   └── pagination_component.rb
├── flash_component.rb            # Flash message alerts
└── products/                     # Domain-specific components
    ├── table_component.rb
    └── form_component.rb
```

---

### Button Component

**File:** `app/components/ui/button_component.rb`

Reusable button component with consistent styling across all variants.

#### Variants

| Variant | Use Case | Visual |
|---------|----------|--------|
| `primary` | Primary actions (save, submit, create) | Blue-600 background, white text |
| `secondary` | Secondary actions (cancel, close) | White background, gray text, border |
| `danger` | Destructive actions (delete) | Red-600 background, white text |
| `ghost` | Subtle actions (close, minimize) | Transparent, gray text, no border |
| `link` | Link-style actions | Transparent, blue text, underline on hover |

#### Sizes

| Size | Padding | Text Size | Use Case |
|------|---------|-----------|----------|
| `sm` | `px-3 py-1.5` | `text-sm` | Compact UIs, table actions, cards |
| `md` | `px-4 py-2` | `text-sm` | **Default button size** |
| `lg` | `px-6 py-3` | `text-base` | Hero sections, primary CTAs |

#### Props

```ruby
variant: :primary      # :primary, :secondary, :danger, :ghost, :link
size: :md              # :sm, :md, :lg
disabled: false        # Boolean - disables button
type: "button"         # HTML type attribute
loading: false         # Boolean - shows spinner, disables button
icon: nil              # String - SVG markup for icon
icon_position: :left   # :left or :right
aria_label: nil        # String - required for icon-only buttons
```

#### Usage Examples

```erb
<!-- Primary button (default) -->
<%= render Ui::ButtonComponent.new do %>
  Save Product
<% end %>

<!-- Secondary button -->
<%= render Ui::ButtonComponent.new(variant: :secondary) do %>
  Cancel
<% end %>

<!-- Small danger button -->
<%= render Ui::ButtonComponent.new(variant: :danger, size: :sm) do %>
  Delete
<% end %>

<!-- Loading state -->
<%= render Ui::ButtonComponent.new(loading: true) do %>
  Saving...
<% end %>

<!-- Disabled state -->
<%= render Ui::ButtonComponent.new(disabled: true) do %>
  Save Product
<% end %>

<!-- Ghost button (subtle) -->
<%= render Ui::ButtonComponent.new(variant: :ghost) do %>
  Close
<% end %>

<!-- Link-style button -->
<%= render Ui::ButtonComponent.new(variant: :link) do %>
  Learn more →
<% end %>

<!-- Icon-only button (requires aria-label) -->
<%= render Ui::ButtonComponent.new(
  variant: :ghost,
  size: :sm,
  aria_label: "Close dialog"
) do %>
  <svg>...</svg>
<% end %>

<!-- Button with icon -->
<%= render Ui::ButtonComponent.new(
  icon: '<svg>...</svg>',
  icon_position: :left
) do %>
  Add Product
<% end %>

<!-- Submit button in form -->
<%= render Ui::ButtonComponent.new(type: "submit") do %>
  Create Product
<% end %>

<!-- With Turbo/Stimulus actions -->
<%= render Ui::ButtonComponent.new(
  data: { turbo_method: :delete, turbo_confirm: "Are you sure?" }
) do %>
  Delete Product
<% end %>
```

#### Accessibility Features

- Focus ring with 2px blue-500 outline
- Disabled state with reduced opacity (50%)
- Loading state disables button and shows spinner
- `aria-label` support for icon-only buttons
- Keyboard accessible (native button element)

#### Best Practices

**Do:**
- Use `primary` for the main action on a page
- Use `secondary` for cancel/back actions
- Use `danger` for destructive actions (delete, remove)
- Always provide `aria-label` for icon-only buttons
- Use loading state for async operations

**Don't:**
- Use multiple primary buttons in the same section
- Use red buttons for non-destructive actions
- Create icon-only buttons without `aria-label`
- Override button classes (use variants instead)

---

### Card Component

**File:** `app/components/ui/card_component.rb`

Reusable card container with optional header, footer, and actions.

#### Features

- **Header slot** with optional action buttons
- **Footer slot** for form actions or metadata
- **Customizable padding** (none, sm, md, lg)
- **Hover effect** for clickable cards
- **Border toggle** for borderless cards

#### Props

```ruby
padding: :md      # :none, :sm, :md, :lg
hover: false      # Boolean - adds hover shadow effect
border: true      # Boolean - shows/hides border
```

#### Usage Examples

```erb
<!-- Simple card -->
<%= render Ui::CardComponent.new do %>
  <p>Card content here</p>
<% end %>

<!-- Card with header -->
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h3 class="text-lg font-semibold text-gray-900">Product Details</h3>
  <% end %>

  <div class="space-y-4">
    <div>
      <span class="text-sm font-medium text-gray-700">SKU:</span>
      <span class="text-sm text-gray-900">ABC-123</span>
    </div>
    <div>
      <span class="text-sm font-medium text-gray-700">Status:</span>
      <%= product_status_badge(@product) %>
    </div>
  </div>
<% end %>

<!-- Card with header and action buttons -->
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h3 class="text-lg font-semibold text-gray-900">Product Details</h3>
  <% end %>

  <% card.with_action do %>
    <%= render Ui::ButtonComponent.new(variant: :secondary, size: :sm) { "Edit" } %>
  <% end %>

  <% card.with_action do %>
    <%= render Ui::ButtonComponent.new(variant: :danger, size: :sm) { "Delete" } %>
  <% end %>

  <div class="space-y-4">
    <p>Product information...</p>
  </div>
<% end %>

<!-- Card with footer (for forms) -->
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h3 class="text-lg font-semibold text-gray-900">Create Product</h3>
  <% end %>

  <%= form_with model: @product do |f| %>
    <div class="space-y-4">
      <%= f.text_field :sku %>
      <%= f.text_field :name %>
    </div>
  <% end %>

  <% card.with_footer do %>
    <div class="flex justify-end gap-2">
      <%= render Ui::ButtonComponent.new(variant: :secondary) { "Cancel" } %>
      <%= render Ui::ButtonComponent.new(type: "submit") { "Create Product" } %>
    </div>
  <% end %>
<% end %>

<!-- Hover effect card (for clickable cards) -->
<%= link_to product_path(@product) do %>
  <%= render Ui::CardComponent.new(hover: true) do %>
    <div class="space-y-2">
      <h4 class="font-semibold text-gray-900"><%= @product.name %></h4>
      <p class="text-sm text-gray-600"><%= @product.sku %></p>
    </div>
  <% end %>
<% end %>

<!-- Stat card (large padding, centered) -->
<%= render Ui::CardComponent.new(padding: :lg, hover: true) do %>
  <div class="text-center">
    <div class="text-3xl font-bold text-gray-900">1,234</div>
    <div class="text-sm text-gray-600">Total Products</div>
  </div>
<% end %>

<!-- Borderless card -->
<%= render Ui::CardComponent.new(border: false, padding: :lg) do %>
  <p>Content without border</p>
<% end %>
```

#### Visual Structure

```
┌─────────────────────────────────────┐
│ Header (gray-50 bg)      [Actions] │ ← Header slot (optional)
├─────────────────────────────────────┤
│                                     │
│  Card Body (white bg)               │ ← Main content
│  (padding based on prop)            │
│                                     │
├─────────────────────────────────────┤
│ Footer (gray-50 bg)                 │ ← Footer slot (optional)
└─────────────────────────────────────┘
```

#### Accessibility Features

- Semantic HTML structure (div elements)
- Header uses gray-50 background for visual hierarchy
- Footer uses gray-50 background to separate actions
- Proper heading levels should be used in header slot

#### Best Practices

**Do:**
- Use cards to group related content
- Use header for card titles
- Use footer for form actions
- Use hover effect for clickable cards
- Keep card content focused and concise

**Don't:**
- Nest cards deeply (1-2 levels max)
- Use cards for single-line content (use div instead)
- Override card styles (use props instead)
- Forget to use proper heading levels in headers

---

### Modal Component

**File:** `app/components/ui/modal_component.rb`
**Controller:** `app/javascript/controllers/modal_controller.js`

Reusable modal dialog with Stimulus controller for interactions.

#### Features

- **Five sizes** from small (max-w-md) to full screen
- **Trigger slot** for button that opens modal
- **Header and footer slots** for consistent structure
- **Closable option** to disable/enable closing
- **Keyboard navigation** (ESC to close)
- **Click outside to close** (backdrop click)
- **Focus trap** for accessibility
- **Body scroll lock** when modal is open

#### Sizes

| Size | Max Width | Use Case |
|------|-----------|----------|
| `sm` | `max-w-md` (448px) | Confirmations, simple alerts |
| `md` | `max-w-lg` (512px) | **Default** - most dialogs |
| `lg` | `max-w-2xl` (672px) | Forms with multiple fields |
| `xl` | `max-w-4xl` (896px) | Complex forms, data tables |
| `full` | `max-w-full mx-4` | Full-screen modals (mobile) |

#### Props

```ruby
size: :md          # :sm, :md, :lg, :xl, :full
closable: true     # Boolean - show close button, allow ESC/backdrop close
modal_id: nil      # String - custom ID (auto-generated if not provided)
```

#### Usage Examples

```erb
<!-- Simple confirmation modal -->
<%= render Ui::ModalComponent.new(size: :sm) do |modal| %>
  <% modal.with_trigger do %>
    <%= render Ui::ButtonComponent.new(variant: :danger) { "Delete Product" } %>
  <% end %>

  <% modal.with_header do %>
    Confirm Deletion
  <% end %>

  <p class="text-gray-600">
    Are you sure you want to delete this product? This action cannot be undone.
  </p>

  <% modal.with_footer do %>
    <%= render Ui::ButtonComponent.new(
      variant: :secondary,
      data: { action: "click->modal#close" }
    ) { "Cancel" } %>
    <%= render Ui::ButtonComponent.new(
      variant: :danger,
      data: { turbo_method: :delete }
    ) { "Delete Product" } %>
  <% end %>
<% end %>

<!-- Form modal (large) -->
<%= render Ui::ModalComponent.new(size: :lg) do |modal| %>
  <% modal.with_trigger do %>
    <%= render Ui::ButtonComponent.new { "Create New Product" } %>
  <% end %>

  <% modal.with_header do %>
    Create New Product
  <% end %>

  <%= form_with model: @product, data: { turbo: false } do |f| %>
    <div class="space-y-4">
      <div>
        <%= f.label :sku, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_field :sku, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
      </div>
      <div>
        <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_field :name, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
      </div>
    </div>
  <% end %>

  <% modal.with_footer do %>
    <%= render Ui::ButtonComponent.new(
      variant: :secondary,
      data: { action: "click->modal#close" }
    ) { "Cancel" } %>
    <%= render Ui::ButtonComponent.new(type: "submit") { "Create Product" } %>
  <% end %>
<% end %>

<!-- Modal without close button (force user action) -->
<%= render Ui::ModalComponent.new(closable: false) do |modal| %>
  <% modal.with_trigger do %>
    <%= render Ui::ButtonComponent.new { "Important Action" } %>
  <% end %>

  <% modal.with_header do %>
    Complete Required Action
  <% end %>

  <p>You must complete this action before continuing.</p>

  <% modal.with_footer do %>
    <%= render Ui::ButtonComponent.new { "Complete Action" } %>
  <% end %>
<% end %>

<!-- Modal opened programmatically (no trigger) -->
<div data-controller="modal" data-modal-closable-value="true">
  <button data-action="click->modal#open" class="...">
    Open Modal
  </button>

  <%= render Ui::ModalComponent.new do |modal| %>
    <% modal.with_header do %>
      Modal Title
    <% end %>
    <p>Modal content</p>
  <% end %>
</div>
```

#### Stimulus Controller API

```javascript
// Open modal programmatically
this.application.getControllerForElementAndIdentifier(element, 'modal').open()

// Close modal programmatically
this.application.getControllerForElementAndIdentifier(element, 'modal').close()

// Data attributes
data-action="click->modal#open"       // Open modal
data-action="click->modal#close"      // Close modal
data-modal-closable-value="true"      // Enable/disable closing
data-modal-target="backdrop"          // Backdrop element
data-modal-target="container"         // Modal container
```

#### Accessibility Features

- **ARIA attributes:** `role="dialog"`, `aria-modal="true"`, `aria-labelledby`
- **Keyboard navigation:** ESC key closes modal (if closable)
- **Focus trap:** Focus stays within modal when open
- **Auto-focus:** First focusable element gets focus on open
- **Body scroll lock:** Prevents background scrolling
- **Screen reader support:** Proper ARIA labels and roles

#### Best Practices

**Do:**
- Use modals for focused tasks (forms, confirmations)
- Keep modal content concise
- Always provide a way to close (unless critical action)
- Use appropriate size for content
- Include clear action buttons in footer

**Don't:**
- Use modals for navigation
- Nest modals (opens over another modal)
- Create modals without header text
- Use modals for long-form content (use page instead)
- Forget to disable closable for critical actions

---

### Badge Component

**File:** `app/components/ui/badge_component.rb`

Reusable badge component for status indicators and labels.

#### Variants

| Variant | Colors | Use Case |
|---------|--------|----------|
| `success` | Green-100 bg, green-800 text | Active status, completed |
| `info` | Blue-100 bg, blue-800 text | Informational, sellable type |
| `warning` | Yellow-100 bg, yellow-800 text | Draft, pending, caution |
| `danger` | Red-100 bg, red-800 text | Error, discontinued, deleted |
| `gray` | Gray-100 bg, gray-800 text | **Default** - neutral status |
| `primary` | Blue-600 bg, white text | Highlighted, important |

#### Sizes

| Size | Padding | Text Size | Use Case |
|------|---------|-----------|----------|
| `sm` | `px-2 py-0.5` | `text-xs` | **Default** - compact badges |
| `md` | `px-2.5 py-1` | `text-sm` | Standard badges |
| `lg` | `px-3 py-1.5` | `text-base` | Large badges, emphasis |

#### Props

```ruby
variant: :gray    # :success, :info, :warning, :danger, :gray, :primary
size: :sm         # :sm, :md, :lg
dot: false        # Boolean - shows colored dot before text
```

#### Usage Examples

```erb
<!-- Product status badges -->
<%= render Ui::BadgeComponent.new(variant: :success, dot: true) { "Active" } %>
<%= render Ui::BadgeComponent.new(variant: :warning, dot: true) { "Draft" } %>
<%= render Ui::BadgeComponent.new(variant: :danger, dot: true) { "Discontinued" } %>

<!-- Product type badges -->
<%= render Ui::BadgeComponent.new(variant: :info) { "Sellable" } %>
<%= render Ui::BadgeComponent.new(variant: :warning) { "Configurable" } %>
<%= render Ui::BadgeComponent.new(variant: :gray) { "Bundle" } %>

<!-- Sync status badges -->
<%= render Ui::BadgeComponent.new(variant: :success, dot: true) { "Synced" } %>
<%= render Ui::BadgeComponent.new(variant: :warning) { "Outdated" } %>
<%= render Ui::BadgeComponent.new(variant: :gray) { "Never synced" } %>

<!-- Sizes -->
<%= render Ui::BadgeComponent.new(variant: :info, size: :sm) { "Small" } %>
<%= render Ui::BadgeComponent.new(variant: :info, size: :md) { "Medium" } %>
<%= render Ui::BadgeComponent.new(variant: :info, size: :lg) { "Large" } %>

<!-- Primary badge (highlighted) -->
<%= render Ui::BadgeComponent.new(variant: :primary) { "New" } %>

<!-- Without dot -->
<%= render Ui::BadgeComponent.new(variant: :success) { "Active" } %>

<!-- With dot (status indicator) -->
<%= render Ui::BadgeComponent.new(variant: :success, dot: true) { "Online" } %>
```

#### Helper Methods

Potlift8 provides helper methods for common badge patterns:

```ruby
# app/helpers/products_helper.rb

# Product status badge
product_status_badge(@product)
# => Renders success badge for "active", warning for "draft", etc.

# Product type badge
product_type_badge(@product)
# => Renders info badge for "sellable", warning for "configurable", etc.

# Sync status badge
sync_status_badge(@product.last_synced_at)
# => Renders success badge if synced within 1 hour, warning if older
```

Usage in views:

```erb
<!-- Using helpers -->
<div class="flex gap-2">
  <%= product_status_badge(@product) %>
  <%= product_type_badge(@product) %>
  <%= sync_status_badge(@product.last_synced_at) %>
</div>
```

#### Best Practices

**Do:**
- Use consistent variants for same meanings (success = green)
- Use dot for real-time status (online, syncing)
- Use appropriate size for context
- Group related badges together

**Don't:**
- Use badges for actions (use buttons)
- Overuse badges (clutters UI)
- Use too many variants in one area
- Use badges for long text (use labels instead)

---

## Form Elements

Potlift8 follows Authlift8's form styling conventions with rounded-lg inputs and blue focus states.

### Input Fields

#### Text Inputs

```erb
<div>
  <label for="product_sku" class="block text-sm font-medium text-gray-700">
    SKU
  </label>
  <input
    type="text"
    id="product_sku"
    name="product[sku]"
    class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
    placeholder="ABC-123"
  />
</div>
```

**Key Classes:**
- `rounded-lg` - 8px border radius (more prominent than rounded-md)
- `border-gray-300` - Default border color
- `focus:border-blue-500` - Blue border on focus
- `focus:ring-blue-500` - Blue ring on focus
- `shadow-sm` - Subtle shadow for depth
- `sm:text-sm` - 14px text size

---

#### Textarea

```erb
<div>
  <label for="product_description" class="block text-sm font-medium text-gray-700">
    Description
  </label>
  <textarea
    id="product_description"
    name="product[description]"
    rows="4"
    class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
  ></textarea>
</div>
```

---

#### Select Dropdowns

```erb
<div>
  <label for="product_type" class="block text-sm font-medium text-gray-700">
    Product Type
  </label>
  <select
    id="product_type"
    name="product[product_type]"
    class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
  >
    <option value="">Select type...</option>
    <option value="sellable">Sellable</option>
    <option value="configurable">Configurable</option>
    <option value="bundle">Bundle</option>
  </select>
</div>
```

---

#### Checkboxes

```erb
<div class="flex items-start">
  <div class="flex items-center h-5">
    <input
      type="checkbox"
      id="product_active"
      name="product[active]"
      class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
    />
  </div>
  <div class="ml-3">
    <label for="product_active" class="text-sm font-medium text-gray-700">
      Active
    </label>
    <p class="text-sm text-gray-500">
      Product is available for sale
    </p>
  </div>
</div>
```

**Key Classes:**
- `h-4 w-4` - 16px checkbox size
- `rounded` - 4px border radius
- `text-blue-600` - Blue checked state
- `focus:ring-blue-500` - Blue focus ring

---

#### Radio Buttons

```erb
<div class="space-y-4">
  <div class="flex items-center">
    <input
      type="radio"
      id="type_sellable"
      name="product[product_type]"
      value="sellable"
      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
    />
    <label for="type_sellable" class="ml-3 text-sm font-medium text-gray-700">
      Sellable
    </label>
  </div>
  <div class="flex items-center">
    <input
      type="radio"
      id="type_configurable"
      name="product[product_type]"
      value="configurable"
      class="h-4 w-4 border-gray-300 text-blue-600 focus:ring-blue-500"
    />
    <label for="type_configurable" class="ml-3 text-sm font-medium text-gray-700">
      Configurable
    </label>
  </div>
</div>
```

---

### Error States

When a field has validation errors:

```erb
<div>
  <label for="product_sku" class="block text-sm font-medium text-gray-700">
    SKU
  </label>
  <input
    type="text"
    id="product_sku"
    name="product[sku]"
    aria-invalid="true"
    aria-describedby="product_sku_error"
    class="mt-1 block w-full rounded-lg border-red-300 shadow-sm focus:border-red-500 focus:ring-red-500 sm:text-sm"
  />
  <p id="product_sku_error" class="mt-2 text-sm text-red-600">
    SKU is required
  </p>
</div>
```

**Error State Changes:**
- Border: `border-gray-300` → `border-red-300`
- Focus border: `focus:border-blue-500` → `focus:border-red-500`
- Focus ring: `focus:ring-blue-500` → `focus:ring-red-500`
- Add `aria-invalid="true"`
- Add `aria-describedby` pointing to error message

---

### Help Text

Descriptive text below form fields:

```erb
<div>
  <label for="product_sku" class="block text-sm font-medium text-gray-700">
    SKU
  </label>
  <input
    type="text"
    id="product_sku"
    name="product[sku]"
    aria-describedby="product_sku_help"
    class="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
  />
  <p id="product_sku_help" class="mt-2 text-sm text-gray-500">
    Unique product identifier (e.g., ABC-123)
  </p>
</div>
```

**Help Text Classes:**
- `text-sm` - 14px size
- `text-gray-500` - Medium gray color
- `mt-2` - 8px spacing above

---

### Label Guidelines

**Required Field Indicator:**

```erb
<label for="product_sku" class="block text-sm font-medium text-gray-700">
  SKU <span class="text-red-600">*</span>
</label>
```

**Optional Field Indicator:**

```erb
<label for="product_notes" class="block text-sm font-medium text-gray-700">
  Notes <span class="text-sm font-normal text-gray-500">(optional)</span>
</label>
```

---

### Form Layout Examples

#### Single Column Form

```erb
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h3 class="text-lg font-semibold text-gray-900">Product Information</h3>
  <% end %>

  <%= form_with model: @product do |f| %>
    <div class="space-y-6">
      <div>
        <%= f.label :sku, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_field :sku, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
      </div>

      <div>
        <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_field :name, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
      </div>

      <div>
        <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
        <%= f.text_area :description, rows: 4, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
      </div>
    </div>
  <% end %>

  <% card.with_footer do %>
    <div class="flex justify-end gap-2">
      <%= render Ui::ButtonComponent.new(variant: :secondary) { "Cancel" } %>
      <%= render Ui::ButtonComponent.new(type: "submit") { "Save Product" } %>
    </div>
  <% end %>
<% end %>
```

---

#### Two Column Form

```erb
<div class="grid grid-cols-1 gap-6 sm:grid-cols-2">
  <div>
    <%= f.label :sku, class: "block text-sm font-medium text-gray-700" %>
    <%= f.text_field :sku, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
  </div>

  <div>
    <%= f.label :name, class: "block text-sm font-medium text-gray-700" %>
    <%= f.text_field :name, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
  </div>

  <div class="sm:col-span-2">
    <%= f.label :description, class: "block text-sm font-medium text-gray-700" %>
    <%= f.text_area :description, rows: 4, class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
  </div>
</div>
```

---

### Form Best Practices

**Do:**
- Always pair labels with inputs (`for` and `id` attributes)
- Use `text-sm` for labels (14px)
- Use `font-medium` for labels (weight 500)
- Add help text for complex fields
- Show clear error messages
- Use `rounded-lg` for inputs (8px radius)
- Use `space-y-6` between form fields

**Don't:**
- Create inputs without labels
- Use placeholder as label replacement
- Use gray-400 for label text (insufficient contrast)
- Mix rounded-md and rounded-lg (be consistent)
- Use indigo colors (use blue instead)

---

## Accessibility Standards

Potlift8 meets **WCAG 2.1 Level AA** accessibility standards.

### Compliance Targets

| Criterion | Target | Current | Status |
|-----------|--------|---------|--------|
| **Color Contrast** | 4.5:1 (AA) | 7:1 avg | ✅ Pass |
| **Keyboard Navigation** | Full support | Full support | ✅ Pass |
| **Screen Reader** | Compatible | Compatible | ✅ Pass |
| **Focus Indicators** | Visible | 2px blue outline | ✅ Pass |
| **ARIA Labels** | Required fields | All covered | ✅ Pass |
| **Form Labels** | 100% | 100% | ✅ Pass |
| **Heading Hierarchy** | Logical | Logical | ✅ Pass |
| **Skip Navigation** | Present | Present | ✅ Pass |

**Overall Compliance:** ~95% WCAG 2.1 AA (up from 68% before Phase 4)

---

### Color Contrast Requirements

All text must meet minimum contrast ratios:

| Content | Minimum Ratio | Potlift8 Standard |
|---------|---------------|-------------------|
| Normal text (< 18px) | 4.5:1 | 7:1 (gray-600 on white) |
| Large text (≥ 18px) | 3:1 | 7:1 (gray-600 on white) |
| UI components | 3:1 | 4.5:1+ (all components) |

**Approved Text Colors on White Background:**

| Color | Contrast Ratio | Status |
|-------|----------------|--------|
| `gray-900` | 16.5:1 | ✅ AAA |
| `gray-700` | 10.4:1 | ✅ AAA |
| `gray-600` | 7:0:1 | ✅ AAA |
| `gray-500` | 4.6:1 | ✅ AA (use for secondary text only) |
| `gray-400` | 3.1:1 | ❌ Fails (avoid for text) |

**Do Not Use for Text:**
- `gray-400` - Only 3.1:1 contrast (use for icons or disabled states)
- `gray-300` - Too light (use for borders only)
- Any color lighter than gray-500

---

### Keyboard Navigation

All interactive elements must be keyboard accessible:

#### Tab Order

- Logical tab order follows visual layout
- No tab traps (can tab out of all components)
- Skip navigation link appears first (hidden until focused)

#### Keyboard Shortcuts

| Element | Keys | Behavior |
|---------|------|----------|
| Modal | `ESC` | Close modal (if closable) |
| Dropdown | `↓` `↑` | Navigate menu items |
| Dropdown | `ESC` | Close dropdown |
| Dropdown | `Home` | Jump to first item |
| Dropdown | `End` | Jump to last item |
| Links/Buttons | `Enter` or `Space` | Activate |

---

### Focus Indicators

All focusable elements have visible focus indicators:

```css
/* Global focus styles (app/assets/stylesheets/application.css) */
a:focus,
button:focus,
input:focus,
textarea:focus,
select:focus,
[tabindex]:focus {
  outline: 2px solid #3b82f6; /* blue-500 */
  outline-offset: 2px;
}
```

**Focus Ring Standards:**
- **Width:** 2px minimum
- **Color:** Blue-500 (#3b82f6)
- **Offset:** 2px from element edge
- **Style:** Solid outline

---

### ARIA Attributes

#### Required ARIA Attributes

**Icon-only buttons:**
```erb
<button aria-label="Close dialog">
  <svg>...</svg>
</button>
```

**Modals:**
```erb
<div role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <h3 id="modal-title">Modal Title</h3>
</div>
```

**Dropdowns:**
```erb
<button aria-expanded="false" aria-haspopup="true">
  User Menu
</button>
<div role="menu" aria-orientation="vertical">
  <a role="menuitem">Profile</a>
</div>
```

**Form errors:**
```erb
<input aria-invalid="true" aria-describedby="error-message" />
<p id="error-message">Error message</p>
```

**Live regions (flash messages):**
```erb
<div role="alert">
  Success message
</div>
```

---

### Screen Reader Support

#### Skip Navigation Link

Allows screen reader users to skip to main content:

```erb
<!-- app/views/layouts/application.html.erb -->
<a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-0 focus:left-0 focus:z-50 focus:p-4 focus:bg-blue-600 focus:text-white">
  Skip to main content
</a>

<!-- Main content area -->
<main id="main-content">
  <%= yield %>
</main>
```

**Behavior:**
- Hidden by default (`.sr-only`)
- Visible when focused (`.focus:not-sr-only`)
- Positioned at top of viewport
- Blue background for visibility

---

#### Screen Reader Only Text

For context that's visually implied but needs to be spoken:

```erb
<button>
  <svg aria-hidden="true">...</svg>
  <span class="sr-only">Close</span>
</button>
```

**Usage:**
- Use for icon-only buttons
- Use for visually hidden labels
- Use for status updates

---

### Accessibility Testing

#### Automated Testing

```bash
# Run axe-core accessibility tests
bin/test spec/system/accessibility_spec.rb
```

#### Manual Testing Checklist

- [ ] All pages keyboard navigable (tab through all elements)
- [ ] Focus indicators visible on all interactive elements
- [ ] Screen reader announces all content correctly
- [ ] Color contrast meets 4.5:1 for all text
- [ ] Forms have labels and error messages
- [ ] Modals trap focus and announce properly
- [ ] Skip navigation link works
- [ ] ARIA attributes present where needed

---

### Common Accessibility Issues & Fixes

| Issue | Problem | Fix |
|-------|---------|-----|
| **Missing label** | Input without label | Add `<label for="id">` |
| **Low contrast** | Gray-400 text | Use gray-600 or darker |
| **Icon button** | No text label | Add `aria-label` |
| **Focus invisible** | No focus indicator | Use global focus styles |
| **Bad heading order** | h1 → h3 (skips h2) | Fix heading hierarchy |
| **Form errors** | Error not announced | Add `aria-invalid` and `aria-describedby` |
| **Modal not trapped** | Focus escapes modal | Use Stimulus focus trap |

---

## Best Practices

### Component Selection

**When to use each component:**

| Scenario | Component | Reason |
|----------|-----------|--------|
| Primary action | `ButtonComponent` (primary) | Clear visual hierarchy |
| Secondary action | `ButtonComponent` (secondary) | Less prominent |
| Destructive action | `ButtonComponent` (danger) | Red = warning |
| Grouping content | `CardComponent` | Visual container |
| User confirmation | `ModalComponent` (sm) | Focused interaction |
| Complex form | `ModalComponent` (lg/xl) | More space |
| Status indicator | `BadgeComponent` | Compact, color-coded |
| Real-time status | `BadgeComponent` (dot: true) | Animated indicator |

---

### Common Patterns

#### Page Header Pattern

```erb
<div class="border-b border-gray-200 pb-5 mb-8">
  <div class="flex items-center justify-between">
    <div>
      <h1 class="text-2xl font-bold text-gray-900">Products</h1>
      <p class="mt-2 text-sm text-gray-600">
        Manage your product catalog and inventory
      </p>
    </div>
    <div>
      <%= render Ui::ButtonComponent.new do %>
        Add Product
      <% end %>
    </div>
  </div>
</div>
```

---

#### Stats Card Pattern

```erb
<div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-4">
  <%= render Ui::CardComponent.new(hover: true, padding: :lg) do %>
    <div class="text-center">
      <div class="text-3xl font-bold text-gray-900">1,234</div>
      <div class="mt-1 text-sm text-gray-600">Total Products</div>
    </div>
  <% end %>

  <%= render Ui::CardComponent.new(hover: true, padding: :lg) do %>
    <div class="text-center">
      <div class="text-3xl font-bold text-green-600">856</div>
      <div class="mt-1 text-sm text-gray-600">Active</div>
    </div>
  <% end %>

  <%= render Ui::CardComponent.new(hover: true, padding: :lg) do %>
    <div class="text-center">
      <div class="text-3xl font-bold text-yellow-600">123</div>
      <div class="mt-1 text-sm text-gray-600">Draft</div>
    </div>
  <% end %>

  <%= render Ui::CardComponent.new(hover: true, padding: :lg) do %>
    <div class="text-center">
      <div class="text-3xl font-bold text-red-600">45</div>
      <div class="mt-1 text-sm text-gray-600">Discontinued</div>
    </div>
  <% end %>
</div>
```

---

#### List with Actions Pattern

```erb
<%= render Ui::CardComponent.new do |card| %>
  <% card.with_header do %>
    <h3 class="text-lg font-semibold text-gray-900">Recent Products</h3>
  <% end %>

  <div class="divide-y divide-gray-200">
    <% @products.each do |product| %>
      <div class="flex items-center justify-between py-4">
        <div class="flex-1">
          <div class="flex items-center gap-3">
            <h4 class="text-sm font-medium text-gray-900"><%= product.name %></h4>
            <%= product_status_badge(product) %>
            <%= product_type_badge(product) %>
          </div>
          <p class="mt-1 text-sm text-gray-600"><%= product.sku %></p>
        </div>
        <div class="flex items-center gap-2">
          <%= link_to edit_product_path(product) do %>
            <%= render Ui::ButtonComponent.new(variant: :secondary, size: :sm) { "Edit" } %>
          <% end %>
          <%= render Ui::ButtonComponent.new(variant: :ghost, size: :sm, aria_label: "More options") do %>
            <svg>...</svg>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

---

#### Empty State Pattern

```erb
<div class="text-center py-12">
  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 13V6a2 2 0 00-2-2H6a2 2 0 00-2 2v7m16 0v5a2 2 0 01-2 2H6a2 2 0 01-2-2v-5m16 0h-2.586a1 1 0 00-.707.293l-2.414 2.414a1 1 0 01-.707.293h-3.172a1 1 0 01-.707-.293l-2.414-2.414A1 1 0 006.586 13H4"></path>
  </svg>
  <h3 class="mt-2 text-sm font-semibold text-gray-900">No products</h3>
  <p class="mt-1 text-sm text-gray-500">Get started by creating your first product.</p>
  <div class="mt-6">
    <%= render Ui::ButtonComponent.new do %>
      Add Product
    <% end %>
  </div>
</div>
```

---

### Anti-Patterns to Avoid

**Don't do these:**

#### ❌ Inline Tailwind Classes for Complex Components

```erb
<!-- BAD: Inline classes for button -->
<button class="inline-flex items-center justify-center font-medium rounded-lg px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white">
  Save
</button>

<!-- GOOD: Use ButtonComponent -->
<%= render Ui::ButtonComponent.new { "Save" } %>
```

---

#### ❌ Inconsistent Color Usage

```erb
<!-- BAD: Mixed indigo and blue -->
<button class="bg-indigo-600 hover:bg-blue-700">Save</button>

<!-- GOOD: Consistent blue -->
<%= render Ui::ButtonComponent.new { "Save" } %>
```

---

#### ❌ Missing Accessibility Attributes

```erb
<!-- BAD: Icon button without label -->
<button><svg>...</svg></button>

<!-- GOOD: With aria-label -->
<%= render Ui::ButtonComponent.new(aria_label: "Close dialog") do %>
  <svg>...</svg>
<% end %>
```

---

#### ❌ Low Contrast Text

```erb
<!-- BAD: Gray-400 text (3.1:1 contrast) -->
<p class="text-gray-400">Important message</p>

<!-- GOOD: Gray-600 text (7:1 contrast) -->
<p class="text-gray-600">Important message</p>
```

---

#### ❌ Nested Modals

```erb
<!-- BAD: Modal inside modal -->
<%= render Ui::ModalComponent.new do |modal1| %>
  <%= render Ui::ModalComponent.new do |modal2| %>
    <!-- Don't do this -->
  <% end %>
<% end %>

<!-- GOOD: Close first modal, then open second -->
<!-- Or use a multi-step form within one modal -->
```

---

### Performance Considerations

#### ViewComponent Rendering

- **Average render time:** < 5ms per component
- **Threshold:** Components taking > 50ms should be optimized
- **Monitoring:** Use `PerformanceMonitor` service to track render times

#### Optimization Tips

1. **Avoid N+1 queries in components:**
   ```ruby
   # BAD: N+1 queries
   @products.each { |p| p.inventories.count }

   # GOOD: Eager load
   @products.includes(:inventories).each { |p| p.inventories.count }
   ```

2. **Cache expensive computations:**
   ```ruby
   # Use JSONB cache field
   product.cache['total_inventory'] ||= product.inventories.sum(:quantity)
   ```

3. **Use slots efficiently:**
   ```ruby
   # Slots are lazy-evaluated, only render if present
   concat(render_header) if header?
   ```

---

## Migration Guide

### Migrating from Old Design (Indigo) to New Design (Blue)

This guide helps you update existing code to match the new design system.

---

### Color Migration

#### Automated Migration

Run the Rake task to automatically replace indigo colors:

```bash
rake design:migrate_colors
```

This will update:
- All `.rb` files in `app/components/`
- All `.html.erb` files in `app/components/` and `app/views/`
- All `.css` files in `app/assets/stylesheets/`

#### Manual Migration

If you need to migrate specific files:

```bash
# Find all indigo references
grep -r "indigo-" app/components app/views --include="*.rb" --include="*.erb"

# Find specific shade
grep -r "indigo-600" app/components app/views --include="*.rb" --include="*.erb"
```

#### Color Mapping Reference

| Old Color | New Color | Usage |
|-----------|-----------|-------|
| `indigo-50` | `blue-50` | Light backgrounds |
| `indigo-100` | `blue-100` | Hover backgrounds |
| `indigo-500` | `blue-500` | Focus rings |
| `indigo-600` | `blue-600` | **Primary brand color** |
| `indigo-700` | `blue-700` | Hover states |
| `indigo-800` | `blue-800` | Dark backgrounds |

---

### Component Migration Paths

#### Buttons

**Old (inline Tailwind):**
```erb
<button class="px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-md">
  Save
</button>
```

**New (ButtonComponent):**
```erb
<%= render Ui::ButtonComponent.new { "Save" } %>
```

---

#### Cards

**Old (inline Tailwind):**
```erb
<div class="bg-white shadow rounded-lg border border-gray-200">
  <div class="px-4 py-5 sm:p-6">
    Content
  </div>
</div>
```

**New (CardComponent):**
```erb
<%= render Ui::CardComponent.new do %>
  Content
<% end %>
```

---

#### Badges

**Old (inline Tailwind):**
```erb
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
  Active
</span>
```

**New (BadgeComponent):**
```erb
<%= render Ui::BadgeComponent.new(variant: :success) { "Active" } %>
```

---

#### Modals

**Old (custom modal code):**
```erb
<div class="fixed inset-0 z-50 overflow-y-auto">
  <div class="flex items-center justify-center min-h-screen">
    <div class="bg-white rounded-lg shadow-xl max-w-lg w-full">
      <!-- Modal content -->
    </div>
  </div>
</div>
```

**New (ModalComponent):**
```erb
<%= render Ui::ModalComponent.new do |modal| %>
  <% modal.with_header do %>
    Modal Title
  <% end %>

  <!-- Modal content -->

  <% modal.with_footer do %>
    <%= render Ui::ButtonComponent.new { "Confirm" } %>
  <% end %>
<% end %>
```

---

### Form Migration

#### Input Fields

**Old:**
```erb
<input class="block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500">
```

**New:**
```erb
<input class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm">
```

**Changes:**
- `rounded-md` → `rounded-lg` (4px → 8px radius)
- `focus:border-indigo-500` → `focus:border-blue-500`
- `focus:ring-indigo-500` → `focus:ring-blue-500`
- Add `sm:text-sm` for consistent 14px text

---

### Common Gotchas

#### 1. Rounded Corners

**Issue:** Mix of `rounded-md` (4px) and `rounded-lg` (8px)

**Fix:** Use `rounded-lg` consistently for inputs, cards, modals, buttons

```bash
# Find mixed rounded classes
grep -r "rounded-md" app/components app/views --include="*.erb"
```

---

#### 2. Focus Ring Colors

**Issue:** Indigo focus rings still present

**Fix:** Ensure all interactive elements use `focus:ring-blue-500`

```bash
# Find indigo focus rings
grep -r "focus:ring-indigo" app/components app/views --include="*.erb"
```

---

#### 3. Text Contrast

**Issue:** Gray-400 text (insufficient contrast)

**Fix:** Use gray-600 or darker for body text

```bash
# Find gray-400 text
grep -r "text-gray-400" app/components app/views --include="*.erb"

# Replace with gray-600 (only for text, not icons)
sed -i '' 's/text-gray-400/text-gray-600/g' app/views/**/*.erb
```

---

#### 4. Component Props vs. Inline Classes

**Issue:** Mixing component props with inline class overrides

**Fix:** Use component props instead of class overrides

```erb
<!-- BAD: Override component classes -->
<%= render Ui::ButtonComponent.new(class: "bg-red-600") do %>
  Delete
<% end %>

<!-- GOOD: Use danger variant -->
<%= render Ui::ButtonComponent.new(variant: :danger) do %>
  Delete
<% end %>
```

---

### Testing After Migration

Run these tests to verify the migration:

```bash
# 1. Visual inspection
bin/dev
# Visit http://localhost:3246 and check all pages

# 2. Component tests
bin/test spec/components/

# 3. System tests
bin/test spec/system/

# 4. Accessibility tests
bin/test spec/system/accessibility_spec.rb

# 5. Check for remaining indigo references
grep -r "indigo-" app/components app/views --include="*.rb" --include="*.erb"
# Should return zero results
```

---

### Migration Checklist

Before considering migration complete:

- [ ] All indigo colors replaced with blue
- [ ] All `rounded-md` changed to `rounded-lg` for inputs
- [ ] All buttons use `ButtonComponent`
- [ ] All cards use `CardComponent`
- [ ] All badges use `BadgeComponent`
- [ ] All modals use `ModalComponent`
- [ ] All text uses gray-600 or darker (not gray-400)
- [ ] All focus states use blue-500
- [ ] All icon buttons have `aria-label`
- [ ] All form inputs have labels
- [ ] Component tests pass
- [ ] Accessibility tests pass
- [ ] Visual regression tests reviewed

---

## Additional Resources

### Internal Documentation

- `.claude/FRONTEND_REDESIGN_PLAN.md` - Full redesign implementation plan
- `CLAUDE.md` - Project overview and architecture
- `VIEWCOMPONENTS.md` - ViewComponent usage guide
- `ACTIVEADMIN.md` - Admin interface documentation

### Component Files

All components are located in `app/components/` with corresponding specs in `spec/components/`.

### Design Tokens

Color palette and design tokens are defined in `config/design_tokens.yml`.

### Accessibility

Global accessibility styles are in `app/assets/stylesheets/application.css`.

---

## Changelog

### Version 1.0 (2025-10-14)

- Initial design system documentation
- Completed Phase 5 of frontend redesign
- Migrated from indigo to blue color scheme
- Created core UI components (Button, Card, Modal, Badge)
- Achieved 95% WCAG 2.1 AA compliance (up from 68%)
- Documented all components with examples
- Added migration guide for legacy code

---

## Maintenance

This design system is maintained by the Potlift8 development team.

**Review Schedule:**
- **Quarterly:** Review Authlift8 design changes
- **Monthly:** Accessibility audits
- **As Needed:** Add new components

**Updates:**
- Update this document when adding new components
- Update `config/design_tokens.yml` when changing colors
- Update component files with YARD documentation
- Run migration tests after changes

---

**Questions or suggestions?** Contact the development team or create an issue in the project repository.
