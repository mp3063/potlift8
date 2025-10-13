# Component Usage Guide

Quick reference for using the UI components built in Phase 7.

## ViewComponents

### SidebarComponent

Desktop and mobile navigation sidebar with company branding.

```erb
<%= render SidebarComponent.new(
  items: navigation_items,
  active_path: request.path,
  company: current_potlift_company
) %>
```

**Parameters:**
- `items` (Array<Hash>): Navigation items with `:name`, `:path`, `:icon_path`
- `active_path` (String): Current request path for highlighting active item
- `company` (Company): Current company for display

**Features:**
- Fixed desktop sidebar (hidden on mobile)
- Overlay mobile sidebar (controlled by `mobile-sidebar` Stimulus controller)
- Active state highlighting
- Company info at bottom

---

### TopbarComponent

Top navigation bar with search, company selector, and user menu.

```erb
<%= render TopbarComponent.new(
  user: current_user,
  company: current_potlift_company,
  companies: current_user.accessible_companies
) %>
```

**Parameters:**
- `user` (Hash): User hash with `:id`, `:email`, `:name`
- `company` (Company): Current company
- `companies` (Array<Company>): All accessible companies (optional)

**Features:**
- Mobile menu toggle button
- Global search bar with ⌘K shortcut
- Company selector dropdown (if multiple companies)
- User menu with avatar initials

---

### FlashComponent

Auto-dismissible flash messages.

```erb
<%= render FlashComponent.new %>
```

**Parameters:**
- `flash` (ActionDispatch::Flash::FlashHash): Optional, defaults to view's flash

**Features:**
- Three types: `:notice` (green), `:alert` (red), `:warning` (yellow)
- Auto-dismiss after 5 seconds
- Manual dismiss button
- Smooth fade-out animation

**Usage in controllers:**
```ruby
redirect_to root_path, notice: 'Success message'
redirect_to root_path, alert: 'Error message'
redirect_to root_path, warning: 'Warning message'
```

---

## Stimulus Controllers

### dropdown_controller.js

Toggle dropdown menus with outside-click-to-close.

```erb
<div data-controller="dropdown">
  <button data-action="click->dropdown#toggle" aria-expanded="false">
    Toggle Menu
  </button>
  <div data-dropdown-target="menu" class="hidden">
    Menu content
  </div>
</div>
```

**Actions:**
- `toggle` - Toggle dropdown open/closed
- `open` - Open dropdown
- `close` - Close dropdown

---

### mobile_sidebar_controller.js

Open/close mobile sidebar overlay.

```erb
<div data-controller="mobile-sidebar">
  <button data-action="click->mobile-sidebar#open">
    Open Menu
  </button>
  <div data-mobile-sidebar-target="overlay" class="hidden">
    Sidebar content
    <button data-action="click->mobile-sidebar#close">Close</button>
  </div>
</div>
```

**Actions:**
- `open` - Show sidebar (prevents body scroll)
- `close` - Hide sidebar (restores body scroll)

---

### flash_controller.js

Auto-dismiss flash messages.

```erb
<div data-controller="flash">
  <div data-flash-target="message">
    Flash message
    <button data-action="click->flash#dismiss">Dismiss</button>
  </div>
</div>
```

**Actions:**
- `dismiss` - Manually dismiss specific message
- Auto-dismisses all messages after 5 seconds

---

### global_search_controller.js

Keyboard shortcuts for global search.

```erb
<form data-controller="global-search">
  <input
    data-global-search-target="input"
    data-action="keydown->global-search#handleKeydown"
    placeholder="Search... (⌘K)"
  >
</form>
```

**Keyboard Shortcuts:**
- `⌘K` or `Ctrl+K` - Focus search input
- `ESC` - Blur search input

---

### layout_controller.js

Global layout controller (placeholder for future features).

```erb
<body data-controller="layout">
  <!-- Layout content -->
</body>
```

---

## Helpers

### navigation_items

Returns array of navigation menu items.

```ruby
# In navigation_helper.rb
def navigation_items
  [
    {
      name: 'Dashboard',
      path: root_path,
      icon_path: '<path d="..." />'
    },
    # ... more items
  ]
end
```

**Usage:**
```erb
<% navigation_items.each do |item| %>
  <%= link_to item[:name], item[:path] %>
<% end %>
```

---

### nav_active?

Check if navigation path is active.

```ruby
nav_active?(path, current_path = request.path)
# => true if current_path starts with path
```

---

## Layout Structure

The application layout conditionally renders based on authentication:

```erb
<body data-controller="layout">
  <% if authenticated? %>
    <!-- Full layout with sidebar & topbar -->
    <div class="min-h-full">
      <%= render SidebarComponent %>
      <div class="lg:pl-72">
        <%= render TopbarComponent %>
        <main class="py-10">
          <%= render FlashComponent %>
          <%= yield %>
        </main>
      </div>
    </div>
  <% else %>
    <!-- Simple layout for unauthenticated users -->
    <%= yield %>
  <% end %>
</body>
```

---

## Styling Guidelines

### Tailwind Classes

**Colors:**
- Primary: `indigo-600`, `indigo-700`
- Success: `green-50`, `green-400`, `green-800`
- Error: `red-50`, `red-400`, `red-800`
- Warning: `yellow-50`, `yellow-400`, `yellow-800`
- Sidebar: `gray-900`, `gray-800`
- Background: `gray-50`

**Spacing:**
- Sidebar width: `w-72` (18rem / 288px)
- Topbar height: `h-16` (4rem / 64px)
- Main padding: `px-4 sm:px-6 lg:px-8`

**Responsive:**
- Mobile: `< lg` (< 1024px)
- Desktop: `lg:` (>= 1024px)

---

## Accessibility

All components include:
- ARIA labels (`aria-label`, `aria-expanded`, `aria-current`)
- Semantic HTML (`<nav>`, `<main>`, `<button>`)
- Keyboard navigation support
- Screen reader text (`.sr-only`)
- Focus management

---

## Examples

### Adding a new navigation item

1. Edit `/app/helpers/navigation_helper.rb`:

```ruby
def navigation_items
  [
    # ... existing items ...
    {
      name: 'Reports',
      path: reports_path,
      icon_path: '<path stroke-linecap="round" stroke-linejoin="round" d="M3 13.125C3 12.504 3.504 12 4.125 12h2.25c.621 0 1.125.504 1.125 1.125v6.75C7.5 20.496 6.996 21 6.375 21h-2.25A1.125 1.125 0 013 19.875v-6.75zM9.75 8.625c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125v11.25c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V8.625zM16.5 4.125c0-.621.504-1.125 1.125-1.125h2.25C20.496 3 21 3.504 21 4.125v15.75c0 .621-.504 1.125-1.125 1.125h-2.25a1.125 1.125 0 01-1.125-1.125V4.125z" />'
    }
  ]
end
```

2. Add route in `/config/routes.rb`:

```ruby
resources :reports
```

3. Navigation item will automatically appear in sidebar.

---

### Using flash messages

In controllers:

```ruby
class ProductsController < ApplicationController
  def create
    @product = current_potlift_company.products.build(product_params)
    
    if @product.save
      redirect_to @product, notice: 'Product created successfully'
    else
      redirect_to new_product_path, alert: 'Failed to create product'
    end
  end
  
  def update
    if @product.update(product_params)
      redirect_to @product, notice: 'Product updated successfully'
    else
      redirect_to edit_product_path(@product), warning: 'Some fields need attention'
    end
  end
end
```

---

### Creating a custom dropdown

```erb
<div class="relative" data-controller="dropdown">
  <button
    type="button"
    class="btn"
    data-action="click->dropdown#toggle"
    aria-expanded="false"
    aria-haspopup="true"
  >
    Options
    <svg class="h-5 w-5"><!-- chevron icon --></svg>
  </button>

  <div
    class="hidden absolute right-0 z-10 mt-2 w-48 rounded-md bg-white shadow-lg"
    data-dropdown-target="menu"
    role="menu"
  >
    <%= link_to "Edit", edit_path, class: "block px-4 py-2", role: "menuitem" %>
    <%= link_to "Delete", delete_path, class: "block px-4 py-2", role: "menuitem" %>
  </div>
</div>
```

---

## Testing

Components can be tested with RSpec + Capybara:

```ruby
# spec/components/sidebar_component_spec.rb
RSpec.describe SidebarComponent, type: :component do
  let(:company) { create(:company, name: 'Test Co') }
  let(:items) do
    [
      { name: 'Products', path: '/products', icon_path: '<path/>' }
    ]
  end

  it 'renders navigation items' do
    render_inline(described_class.new(
      items: items,
      active_path: '/products',
      company: company
    ))

    expect(page).to have_link('Products', href: '/products')
    expect(page).to have_text('Test Co')
  end
end
```

---

## Resources

- **ViewComponent**: https://viewcomponent.org/
- **Stimulus**: https://stimulus.hotwired.dev/
- **Tailwind CSS**: https://tailwindcss.com/
- **Heroicons**: https://heroicons.com/
