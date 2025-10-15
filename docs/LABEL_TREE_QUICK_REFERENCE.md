# Label Tree - Quick Reference

Quick reference guide for implementing and using the label tree controllers.

## Controller Setup

### 1. HTML Structure

```html
<div data-controller="label-tree">
  <ul data-label-tree-target="list">
    <li data-label-id="1">
      <div>
        <!-- Toggle button (with keyboard support) -->
        <button
          data-action="click->label-tree#toggle keydown.enter->label-tree#toggle keydown.space->label-tree#toggle"
          aria-expanded="false"
        >
          <svg data-label-tree-target="icon" class="rotate-0 transition-transform">
            <!-- Chevron right icon -->
          </svg>
        </button>

        <!-- Label content -->
        <span>Label Name</span>
      </div>

      <!-- Children (hidden by default) -->
      <ul data-label-tree-target="list" class="hidden">
        <!-- Sublabels -->
      </ul>
    </li>
  </ul>
</div>
```

### 2. Required CSS Classes

```css
.rotate-0 { transform: rotate(0deg); }
.rotate-90 { transform: rotate(90deg); }
.transition-transform { transition: transform 0.2s ease-in-out; }
```

### 3. Rails Partial Example

```erb
<!-- labels/_tree_node.html.erb -->
<li data-label-id="<%= label.id %>">
  <div class="flex items-center gap-2">
    <% if label.children.any? %>
      <button
        data-action="click->label-tree#toggle"
        aria-expanded="false"
        class="p-1"
      >
        <svg data-label-tree-target="icon" class="w-4 h-4 rotate-0 transition-transform">
          <path d="M9 5l7 7-7 7" />
        </svg>
      </button>
    <% end %>

    <span><%= label.name %></span>
  </div>

  <% if label.children.any? %>
    <ul data-label-tree-target="list" class="hidden ml-6">
      <%= render partial: 'labels/tree_node', collection: label.children, as: :label %>
    </ul>
  <% end %>
</li>
```

---

## Backend Setup

### 1. Routes

```ruby
# config/routes.rb
resources :labels do
  patch :reorder, on: :collection
end
```

### 2. Controller Action

```ruby
# app/controllers/labels_controller.rb
class LabelsController < ApplicationController
  def reorder
    label = current_potlift_company.labels.find(params[:label_id])

    # Update parent
    label.update(parent_id: params[:parent_id])

    # Update positions
    params[:sibling_ids].each_with_index do |id, index|
      Label.where(id: id).update_all(position: index)
    end

    render json: { message: 'Label reordered successfully' }
  rescue => e
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
```

### 3. Migration (if needed)

```ruby
class AddPositionAndParentToLabels < ActiveRecord::Migration[8.0]
  def change
    add_column :labels, :position, :integer, default: 0
    add_column :labels, :parent_id, :integer
    add_index :labels, :parent_id
    add_index :labels, [:company_id, :position]
  end
end
```

### 4. Model

```ruby
# app/models/label.rb
class Label < ApplicationRecord
  belongs_to :company
  belongs_to :parent, class_name: 'Label', optional: true
  has_many :children, class_name: 'Label', foreign_key: :parent_id, dependent: :destroy

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scope for root labels
  scope :root, -> { where(parent_id: nil) }

  # Order by position
  default_scope { order(position: :asc) }
end
```

---

## Flash Notifications

### 1. Layout Setup

```erb
<!-- app/views/layouts/application.html.erb -->
<div
  data-controller="flash"
  data-flash-target="container"
  class="fixed top-16 right-4 z-50 w-full max-w-sm"
>
  <% flash.each do |type, message| %>
    <div data-flash-target="message">
      <%= message %>
    </div>
  <% end %>
</div>
```

### 2. Trigger from JavaScript

```javascript
// From label_tree_controller.js (automatic)
// Or manually:
const event = new CustomEvent('flash:show', {
  detail: {
    type: 'success',  // 'success' | 'error' | 'warning' | 'info'
    message: 'Label reordered successfully'
  }
})
window.dispatchEvent(event)
```

---

## localStorage Structure

```json
{
  "label_tree_expanded": ["1", "5", "12"]
}
```

- Array of label IDs (strings)
- Automatically saved on toggle
- Restored on page load

---

## API Reference

### Label Tree Controller

#### Targets
- `list` - All `<ul>` elements containing labels
- `icon` - Chevron icons that rotate on toggle

#### Values
- `reorderUrl` (String) - Default: `/labels/reorder`

#### Actions
- `toggle` - Expand/collapse sublabels
- `handleDrop` - Internal: handles SortableJS drop event

#### Methods
- `connect()` - Initialize sortable and load state
- `disconnect()` - Clean up sortable instances
- `initSortable()` - Create SortableJS instances
- `toggle(event)` - Toggle expand/collapse
- `handleDrop(event)` - Handle reorder
- `saveExpandedState(labelId, expanded)` - Save to localStorage
- `loadExpandedState()` - Load from localStorage

---

## Flash Controller (Enhanced)

#### Targets
- `message` - Individual flash message elements
- `container` - Container for dynamic messages

#### Methods
- `show(type, message)` - Show dynamic flash message
- `dismiss(event)` - Dismiss a message
- `dismissAll()` - Dismiss all messages

#### Custom Event
- `flash:show` - Trigger to show a new message
  - `detail.type`: 'success' | 'error' | 'warning' | 'info'
  - `detail.message`: Message text

---

## Modal Controller (Existing)

#### Targets
- `backdrop` - Modal backdrop overlay
- `container` - Modal content container

#### Values
- `closable` (Boolean) - Default: true

#### Actions
- `open` - Open the modal
- `close` - Close the modal (if closable)
- `preventClose` - Prevent close when clicking content

---

## Common Tasks

### Change Reorder URL

```html
<div data-controller="label-tree" data-label-tree-reorder-url-value="/api/v1/labels/reorder">
```

### Disable Drag Handle

```javascript
// In label_tree_controller.js, remove or comment out:
// handle: '.drag-handle',
```

### Change Animation Speed

```javascript
// In label_tree_controller.js, change:
animation: 150,  // milliseconds
```

### Customize Expanded State Key

```javascript
// In label_tree_controller.js, change:
const key = 'label_tree_expanded'  // Change this
```

---

## Troubleshooting

### Labels don't expand/collapse
- Check: `data-label-tree-target="icon"` on SVG
- Check: `data-label-tree-target="list"` on children `<ul>`
- Check: CSS classes `rotate-0`, `rotate-90`, `transition-transform` exist

### Drag and drop not working
- Check: SortableJS imported in importmap
- Check: `data-label-id` attribute on `<li>` elements
- Check: Console for JavaScript errors

### Reorder request fails
- Check: Route exists: `rake routes | grep reorder`
- Check: CSRF token in meta tag
- Check: User authenticated
- Check: Label belongs to current company

### Expanded state not persisting
- Check: localStorage enabled in browser
- Check: Browser console for localStorage errors
- Check: Label IDs are consistent (not changing on reload)

---

## Testing Checklist

- [ ] Expand/collapse works with mouse click
- [ ] Expand/collapse works with Enter key
- [ ] Expand/collapse works with Space key
- [ ] Expanded state persists on page reload
- [ ] Drag and drop reorders labels
- [ ] Drag to different parent changes parent_id
- [ ] Success notification shows on successful reorder
- [ ] Error notification shows on failed reorder
- [ ] Network errors handled gracefully
- [ ] Works on mobile (touch events)
- [ ] Screen reader announces expand/collapse state
- [ ] Focus indicators visible on all interactive elements

---

## Performance Tips

### For Large Trees (1,000+ labels)

1. **Lazy Load Children**:
   ```ruby
   # Only load when expanded
   render turbo_stream: turbo_stream.replace("label_#{label.id}_children") do
     render partial: 'labels/children', locals: { label: label }
   end
   ```

2. **Virtual Scrolling**:
   - Use stimulus-use's useIntersection
   - Only render visible labels

3. **Optimize localStorage**:
   ```javascript
   // Store only expanded IDs, not full state
   localStorage.setItem('label_tree_expanded', JSON.stringify(expandedIds))
   ```

4. **Debounce Reorder Requests**:
   ```javascript
   // Wait 300ms after drop before sending request
   this.reorderTimeout = setTimeout(() => {
     this.sendReorderRequest(payload)
   }, 300)
   ```

---

## Code Snippets

### ERB Partial with Full Features

```erb
<!-- labels/_tree_node.html.erb -->
<li data-label-id="<%= label.id %>" class="group">
  <div class="flex items-center gap-2 p-2 hover:bg-gray-50 rounded">
    <!-- Toggle -->
    <% if label.children.any? %>
      <button
        data-action="click->label-tree#toggle keydown.enter->label-tree#toggle keydown.space->label-tree#toggle"
        aria-expanded="false"
        aria-label="Toggle <%= label.name %> sublabels"
        class="p-1 hover:bg-gray-100 rounded focus:ring-2 focus:ring-blue-500"
      >
        <svg
          data-label-tree-target="icon"
          class="w-4 h-4 transition-transform rotate-0 text-gray-500"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </button>
    <% else %>
      <div class="w-6"></div>
    <% end %>

    <!-- Drag Handle -->
    <div class="drag-handle cursor-move p-1 opacity-0 group-hover:opacity-100 transition-opacity">
      <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
      </svg>
    </div>

    <!-- Label Name -->
    <span class="flex-1 text-sm text-gray-900"><%= label.name %></span>

    <!-- Color Badge -->
    <% if label.color.present? %>
      <span class="w-4 h-4 rounded-full" style="background-color: <%= label.color %>;"></span>
    <% end %>

    <!-- Actions -->
    <div class="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
      <%= link_to "Edit", edit_label_path(label), class: "text-blue-600 hover:text-blue-800 text-xs px-2 py-1 rounded hover:bg-blue-50" %>
      <%= link_to "Delete", label_path(label), method: :delete, data: { confirm: "Delete #{label.name}?" }, class: "text-red-600 hover:text-red-800 text-xs px-2 py-1 rounded hover:bg-red-50" %>
    </div>
  </div>

  <!-- Children -->
  <% if label.children.any? %>
    <ul data-label-tree-target="list" class="hidden ml-6 mt-1 space-y-1 border-l-2 border-gray-200 pl-2">
      <%= render partial: 'labels/tree_node', collection: label.children, as: :label %>
    </ul>
  <% end %>
</li>
```

### Index View

```erb
<!-- labels/index.html.erb -->
<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
  <% content_for :page_header do %>
    <div class="flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-bold text-gray-900">Labels</h1>
        <p class="mt-2 text-sm text-gray-700">Organize products with hierarchical labels</p>
      </div>
      <div class="flex gap-3">
        <%= link_to new_label_path, class: "inline-flex items-center px-4 py-2 border border-transparent rounded-lg shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500" do %>
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          New Label
        <% end %>
      </div>
    </div>
  <% end %>

  <%= render Ui::CardComponent.new do %>
    <div data-controller="label-tree" class="space-y-2">
      <% if @root_labels.any? %>
        <ul data-label-tree-target="list" class="space-y-1">
          <%= render partial: 'labels/tree_node', collection: @root_labels, as: :label %>
        </ul>
      <% else %>
        <%= render Shared::EmptyStateComponent.new(
          title: "No labels yet",
          description: "Get started by creating your first label",
          icon: :tag
        ) %>
      <% end %>
    </div>
  <% end %>
</div>
```

---

## Files Reference

| File | Purpose |
|------|---------|
| `app/javascript/controllers/label_tree_controller.js` | Main tree controller |
| `app/javascript/controllers/modal_controller.js` | Modal dialogs |
| `app/javascript/controllers/flash_controller.js` | Flash notifications |
| `app/views/labels/_tree_node.html.erb` | Recursive tree node partial |
| `app/views/labels/index.html.erb` | Labels index view |
| `app/controllers/labels_controller.rb` | Labels controller with reorder action |
| `app/models/label.rb` | Label model with parent/children |
| `config/importmap.rb` | SortableJS import |

---

## Additional Resources

- Full Documentation: `docs/LABEL_TREE_STIMULUS_CONTROLLERS.md`
- Design System: `docs/DESIGN_SYSTEM.md`
- Accessibility: `docs/ACCESSIBILITY_QUICK_REFERENCE.md`
- Stimulus Handbook: https://stimulus.hotwired.dev
- SortableJS: https://github.com/SortableJS/Sortable
