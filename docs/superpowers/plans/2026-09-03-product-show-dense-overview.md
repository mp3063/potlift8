# Product Show Page Dense Overview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `/products/:id` fit one 909px viewport for a typical product by stating every fact once, rendering attributes one row each, collapsing editors, and moving the variants summary into a sticky sidebar.

**Architecture:** A new `Products::HeaderComponent` absorbs the Basic Information and Status cards. The attribute partials keep their `<dl>` semantics but become single-line flex rows, with the Product-tab row and the catalog override row each owned by one partial that both the page and the Turbo stream responses render. Images, Labels, and the Configurable card are restyled in place; Labels' picker moves into a modal and the image gallery behind a native `<details>`.

**Tech Stack:** Rails 8.0.3, Ruby 3.4.7, ViewComponent, Hotwire (Turbo + Stimulus), Tailwind CSS v4 (`tailwindcss-rails` 4.3, arbitrary values allowed), RSpec 7 with `render_inline` component specs and request specs.

**Spec:** `docs/superpowers/specs/2026-09-03-product-show-dense-overview-design.md`

## Global Constraints

- Run tests with `bundle exec rspec ... --format progress`, never `bin/test`.
- Always scope data by the product's company; never widen queries.
- Prefer ViewComponents over partials for UI, but the attribute rows stay partials because the controllers' Turbo stream responses render them.
- Do not modify any controller. Only views, components, JS-free templates, and specs change.
- Keep the drill-down pages (edit, variants, configurations, inventories, assets, versions) untouched.
- Keep every existing Stimulus controller unchanged: `inline-editor`, `catalog-tabs`, `image-upload`, `product-images`, `bulk-images`, `image-reorder`, `image-metadata`, `product-label-manager`, `dropdown`, `modal`.
- The `image-upload` controller reads `this.element.action`, so it must stay on the upload `<form>`.
- `dom_id(record, :value)` on a row root is what the Turbo stream responses replace. Every row partial must put that id on its outermost element.
- Every `create(:company)` auto-seeds the system attributes (`price` and `description_html` are mandatory). Tests must compute counts from `company.product_attributes`, never hard-code them.
- Rubocop (omakase) must pass on every Ruby file touched: `bundle exec rubocop <files>`.
- Tailwind is not watching in the running dev server. Run `bin/rails tailwindcss:build` before checking the page in a browser.
- Commit after each task with the trailer `Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc` as the last line of the message.

---

## File Structure

| Action | Path | Responsibility |
|---|---|---|
| Create | `app/components/products/header_component.rb` / `.html.erb` | Title, status and type badges, actions, facts strip, description, inactive-variants notice |
| Create | `spec/components/products/header_component_spec.rb` | Header behaviour |
| Delete | `app/components/products/basic_info_component.rb` / `.html.erb` and spec | Replaced by header |
| Delete | `app/components/products/status_card_component.rb` / `.html.erb` and spec | Replaced by header |
| Modify | `app/views/products/show.html.erb` | Page layout: header frame, columns, sticky sidebar |
| Modify | `app/views/products/toggle_active.turbo_stream.erb`, `activate_variants.turbo_stream.erb` | Re-render the header frame |
| Modify | `app/components/products/catalog_tabs_component.html.erb` | Drop panel padding |
| Modify | `app/views/products/_attribute_value.html.erb` | Single source for a Product-tab attribute row |
| Modify | `app/views/products/catalog_tabs/_product_attributes.html.erb` | Loop rows, group unset attributes in `<details>` |
| Create | `app/views/products/catalog_tabs/_catalog_override_row.html.erb` | Single source for a catalog override row |
| Modify | `app/views/products/catalog_tabs/_catalog_attributes.html.erb` | Compact catalog header, inherited rows, override rows |
| Modify | `app/views/catalog_item_attribute_values/update.turbo_stream.erb` | Replace the whole panel like create/destroy |
| Create | `spec/components/products/catalog_tabs_component_spec.rb` | Row rendering rules on both tabs |
| Create | `spec/requests/catalog_item_attribute_values_spec.rb` | Update response targets the panel |
| Modify | `app/components/products/images_component.rb` / `.html.erb` | Thumbnail strip, Upload label, gallery behind details |
| Modify | `spec/components/products/images_component_spec.rb` | New structure |
| Modify | `app/components/products/labels_component.html.erb` | Chips plus picker in a modal |
| Modify | `spec/components/products/labels_component_spec.rb` | New structure |
| Modify | `app/components/products/configurable_card_component.html.erb` | Compact sidebar variants card |
| Create | `spec/components/products/configurable_card_component_spec.rb` | Card behaviour |
| Modify | `app/components/products/inventory_summary_component.html.erb` | Small padding |
| Modify | `app/components/products/activity_timeline_component.rb` / `.html.erb` | Three entries, tighter spacing |
| Modify | `spec/components/products/activity_timeline_component_spec.rb` | Limit is three |

---

### Task 1: `Products::HeaderComponent`

**Files:**
- Create: `app/components/products/header_component.rb`
- Create: `app/components/products/header_component.html.erb`
- Test: `spec/components/products/header_component_spec.rb`

**Interfaces:**
- Consumes: `Product` (AASM `active?`, enums `product_status`, `product_type`, `configuration_type`, `product.description` from info, `product.subproducts`), route helpers `edit_product_path`, `toggle_active_product_path`, `activate_variants_product_path`, `product_product_assets_path`, `duplicate_product_path`, `product_path`.
- Produces: `Products::HeaderComponent.new(product:)`. Task 2 renders it inside `turbo_frame_tag "product-header-#{product.id}"`.

- [ ] **Step 1: Write the failing spec**

Create `spec/components/products/header_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::HeaderComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company, sku: "TEST-001", name: "Test Product", product_status: :active) }

  it "renders the product name as the page heading" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("h1", text: "Test Product")
  end

  describe "status badge" do
    it "renders a success badge with a dot for active products" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-green-100.text-green-800", text: "Active")
      expect(page).to have_css("span.bg-current")
    end

    it "renders a warning badge for draft products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-yellow-100.text-yellow-800", text: "Draft")
    end

    it "renders a danger badge for discontinued products" do
      product.update!(product_status: :discontinued)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-red-100.text-red-800", text: "Discontinued")
    end

    it "renders a gray badge for disabled products" do
      product.update!(product_status: :disabled)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-gray-100.text-gray-800", text: "Disabled")
    end
  end

  describe "type badge" do
    it "shows the product type" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.bg-blue-100", text: "Sellable")
    end

    it "appends the configuration type for configurables" do
      configurable = create(:product, :configurable_variant, company: company)
      render_inline(described_class.new(product: configurable))

      expect(page).to have_css("span.bg-blue-100", text: "Configurable · Variant")
    end
  end

  describe "facts strip" do
    it "shows the SKU in monospace" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd.font-mono", text: "TEST-001")
    end

    it "shows the EAN when present" do
      product.update!(ean: "1234567890123")
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd.font-mono", text: "1234567890123")
    end

    it "shows a dash when the EAN is blank" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("dd", text: "—")
    end

    it "shows the restock level from info" do
      product.update!(info: { "restock_level" => 25 })
      render_inline(described_class.new(product: product))

      expect(page).to have_text("Restock level")
      expect(page).to have_css("dd", text: "25")
    end

    it "shows the last updated time" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("ago")
    end
  end

  describe "description" do
    it "is omitted when blank" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("p.line-clamp-2")
    end

    it "renders clamped to two lines when present" do
      product.update!(info: { "description" => "A long description" })
      render_inline(described_class.new(product: product))

      expect(page).to have_css("p.line-clamp-2", text: "A long description")
    end
  end

  describe "actions" do
    it "links to the edit page" do
      render_inline(described_class.new(product: product))

      expect(page).to have_link("Edit", href: "/products/#{product.id}/edit")
    end

    it "shows a gray Deactivate button for active products" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-gray-600", text: "Deactivate")
    end

    it "shows a green Activate button for inactive products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).to have_css("button.bg-green-600", text: "Activate")
    end

    it "puts Assets, Duplicate and Delete in the More menu" do
      render_inline(described_class.new(product: product))

      menu = "[data-controller='dropdown'] [role='menu']"
      expect(page).to have_css("#{menu} a[role='menuitem']", text: "Assets")
      expect(page).to have_css("#{menu} button[role='menuitem']", text: "Duplicate")
      expect(page).to have_css("#{menu} button[role='menuitem']", text: "Delete")
    end
  end

  describe "inactive variants notice" do
    let(:configurable) { create(:product, :configurable_variant, company: company, product_status: :draft) }

    before do
      active_variant = create(:product, company: company, product_status: :active)
      draft_variant = create(:product, company: company, product_status: :draft)
      create(:product_configuration, superproduct: configurable, subproduct: active_variant)
      create(:product_configuration, superproduct: configurable, subproduct: draft_variant)
    end

    it "shows the count and an activate-all button for an inactive configurable with inactive variants" do
      render_inline(described_class.new(product: configurable))

      expect(page).to have_text("1 of 2 variants not yet active")
      expect(page).to have_button("Activate all variants")
    end

    it "is hidden when the product is active" do
      configurable.update!(product_status: :active)
      render_inline(described_class.new(product: configurable))

      expect(page).not_to have_button("Activate all variants")
    end

    it "is hidden for sellable products" do
      product.update!(product_status: :draft)
      render_inline(described_class.new(product: product))

      expect(page).not_to have_button("Activate all variants")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/products/header_component_spec.rb --format progress`
Expected: FAIL with `uninitialized constant Products::HeaderComponent`

- [ ] **Step 3: Create the component class**

Create `app/components/products/header_component.rb`:

```ruby
# frozen_string_literal: true

module Products
  class HeaderComponent < ViewComponent::Base
    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def status_badge_variant
      case product.product_status
      when "active" then :success
      when "draft", "incoming" then :warning
      when "discontinued", "deleted" then :danger
      else :gray
      end
    end

    def status_label
      product.product_status.humanize
    end

    def type_label
      label = product.product_type.humanize
      return label unless product.product_type_configurable? && product.configuration_type.present?

      "#{label} · #{product.configuration_type.humanize}"
    end

    def restock_level
      product.info&.dig("restock_level") || 0
    end

    def toggle_button_text
      product.active? ? "Deactivate" : "Activate"
    end

    def toggle_button_classes
      base = "inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-medium text-white shadow-sm " \
             "focus:outline-none focus:ring-2 focus:ring-offset-2"
      if product.active?
        "#{base} bg-gray-600 hover:bg-gray-500 focus:ring-gray-500"
      else
        "#{base} bg-green-600 hover:bg-green-500 focus:ring-green-500"
      end
    end

    def show_inactive_variants_notice?
      return false if product.active?
      return false unless product.product_type_configurable? || product.product_type_bundle?

      inactive_variant_count.positive?
    end

    def inactive_variant_count
      @inactive_variant_count ||= product.subproducts.where.not(product_status: :active).count
    end

    def total_variant_count
      @total_variant_count ||= product.subproducts.count
    end
  end
end
```

- [ ] **Step 4: Create the component template**

Create `app/components/products/header_component.html.erb`:

```erb
<div class="mb-6">
  <div class="sm:flex sm:items-start sm:justify-between sm:gap-4">
    <div class="min-w-0">
      <div class="flex flex-wrap items-center gap-x-3 gap-y-1">
        <h1 class="truncate text-2xl font-semibold leading-tight text-gray-900"><%= product.name %></h1>
        <%= render Ui::BadgeComponent.new(variant: status_badge_variant, size: :md, dot: true) do %>
          <%= status_label %>
        <% end %>
        <%= render Ui::BadgeComponent.new(variant: :info, size: :md) do %>
          <%= type_label %>
        <% end %>
      </div>

      <dl class="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-gray-500">
        <div class="flex items-center gap-x-1">
          <dt>SKU</dt>
          <dd class="font-mono text-gray-700"><%= product.sku %></dd>
        </div>
        <div class="flex items-center gap-x-1">
          <dt>EAN</dt>
          <dd class="font-mono text-gray-700"><%= product.ean.presence || "—" %></dd>
        </div>
        <div class="flex items-center gap-x-1">
          <dt>Restock level</dt>
          <dd class="text-gray-700"><%= number_with_delimiter(restock_level) %></dd>
        </div>
        <div class="flex items-center gap-x-1">
          <dt>Updated</dt>
          <dd class="text-gray-700" title="<%= product.updated_at.strftime('%B %d, %Y at %I:%M %p') %>"><%= time_ago_in_words(product.updated_at) %> ago</dd>
        </div>
      </dl>

      <% if product.description.present? %>
        <p class="mt-2 line-clamp-2 text-sm text-gray-600"><%= product.description %></p>
      <% end %>
    </div>

    <div class="mt-4 flex shrink-0 items-center gap-x-2 sm:mt-0">
      <%= render Ui::ButtonComponent.new(href: edit_product_path(product), variant: :secondary) do %>
        Edit
      <% end %>

      <% if product.active? %>
        <%= button_to toggle_button_text, toggle_active_product_path(product),
              method: :patch,
              class: toggle_button_classes,
              form: { data: { turbo_confirm: "Are you sure you want to deactivate this product?" } } %>
      <% else %>
        <%= button_to toggle_button_text, toggle_active_product_path(product),
              method: :patch,
              class: toggle_button_classes %>
      <% end %>

      <div class="relative" data-controller="dropdown">
        <button type="button"
                class="inline-flex items-center justify-center rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                data-dropdown-target="button"
                data-action="click->dropdown#toggle"
                aria-haspopup="menu"
                aria-expanded="false">
          More
          <svg class="ml-1 h-4 w-4 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 11.168l3.71-3.938a.75.75 0 111.08 1.04l-4.25 4.5a.75.75 0 01-1.08 0l-4.25-4.5a.75.75 0 01.02-1.06z" clip-rule="evenodd" />
          </svg>
        </button>
        <div class="absolute right-0 z-20 mt-2 hidden w-44 origin-top-right rounded-md bg-white py-1 shadow-lg ring-1 ring-black/5 focus:outline-none"
             role="menu"
             aria-orientation="vertical"
             data-dropdown-target="menu">
          <%= link_to "Assets", product_product_assets_path(product),
                class: "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100",
                role: "menuitem" %>
          <%= button_to "Duplicate", duplicate_product_path(product),
                method: :post,
                class: "block w-full px-4 py-2 text-left text-sm text-gray-700 hover:bg-gray-100",
                role: "menuitem",
                form: { data: { turbo_frame: "_top" } } %>
          <%= button_to "Delete", product_path(product),
                method: :delete,
                class: "block w-full px-4 py-2 text-left text-sm text-red-600 hover:bg-red-50",
                role: "menuitem",
                form: { data: { turbo_confirm: "Are you sure you want to delete #{product.name}?" } } %>
        </div>
      </div>
    </div>
  </div>

  <% if show_inactive_variants_notice? %>
    <div class="mt-3 flex items-center justify-between rounded-md border border-yellow-200 bg-yellow-50 px-3 py-2">
      <p class="text-sm text-yellow-800">
        <%= inactive_variant_count %> of <%= total_variant_count %> variant<%= "s" if total_variant_count != 1 %> not yet active
      </p>
      <%= button_to "Activate all variants", activate_variants_product_path(product),
            method: :patch,
            class: "rounded-md bg-yellow-500 px-3 py-1.5 text-xs font-semibold text-white shadow-sm hover:bg-yellow-400 focus:outline-none focus:ring-2 focus:ring-yellow-500 focus:ring-offset-2" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run the spec to verify it passes**

Run: `bundle exec rspec spec/components/products/header_component_spec.rb --format progress`
Expected: 21 examples, 0 failures

- [ ] **Step 6: Rubocop and commit**

```bash
bundle exec rubocop app/components/products/header_component.rb spec/components/products/header_component_spec.rb
git add app/components/products/header_component.rb app/components/products/header_component.html.erb spec/components/products/header_component_spec.rb
git commit -m "feat(products): add HeaderComponent for the show page

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 2: Wire the header into the show page and delete the two old cards

**Files:**
- Modify: `app/views/products/show.html.erb`
- Modify: `app/views/products/toggle_active.turbo_stream.erb`
- Modify: `app/views/products/activate_variants.turbo_stream.erb`
- Delete: `app/components/products/basic_info_component.rb`, `app/components/products/basic_info_component.html.erb`, `spec/components/products/basic_info_component_spec.rb`
- Delete: `app/components/products/status_card_component.rb`, `app/components/products/status_card_component.html.erb`, `spec/components/products/status_card_component_spec.rb`
- Test: `spec/requests/products_spec.rb` (existing show and toggle_active examples)

**Interfaces:**
- Consumes: `Products::HeaderComponent.new(product:)` from Task 1.
- Produces: the page layout every later task renders into. Frame ids: `product-header-<id>`, `catalog-tabs-<id>`, `sync-preview-drawer`.

- [ ] **Step 1: Confirm the existing request specs pass before the change**

Run: `bundle exec rspec spec/requests/products_spec.rb --format progress`
Expected: 0 failures (record the example count)

- [ ] **Step 2: Rewrite `app/views/products/show.html.erb`**

Replace the whole file with:

```erb
<% content_for :title, "#{@product.name} - Potlift8" %>
<div class="px-4 sm:px-6 lg:px-8">
  <nav class="flex mb-4" aria-label="Breadcrumb">
    <ol role="list" class="flex items-center space-x-4">
      <li>
        <div>
          <%= link_to products_path, class: "text-gray-600 hover:text-gray-700" do %>
            <svg class="h-5 w-5 flex-shrink-0" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M9.293 2.293a1 1 0 011.414 0l7 7A1 1 0 0117 11h-1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-3a1 1 0 00-1-1H9a1 1 0 00-1 1v3a1 1 0 01-1 1H5a1 1 0 01-1-1v-6H3a1 1 0 01-.707-1.707l7-7z" clip-rule="evenodd" />
            </svg>
            <span class="sr-only">Home</span>
          <% end %>
        </div>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="h-5 w-5 flex-shrink-0 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
          </svg>
          <%= link_to "Products", products_path, class: "ml-4 text-sm font-medium text-gray-500 hover:text-gray-700" %>
        </div>
      </li>
      <li>
        <div class="flex items-center">
          <svg class="h-5 w-5 flex-shrink-0 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
            <path fill-rule="evenodd" d="M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z" clip-rule="evenodd" />
          </svg>
          <span class="ml-4 text-sm font-medium text-gray-500" aria-current="page"><%= @product.sku %></span>
        </div>
      </li>
    </ol>
  </nav>

  <%= turbo_frame_tag "product-header-#{@product.id}" do %>
    <%= render Products::HeaderComponent.new(product: @product) %>
  <% end %>

  <div class="grid grid-cols-1 gap-4 lg:grid-cols-3">
    <div class="lg:col-span-2 space-y-4">
      <%= render Products::ImagesComponent.new(product: @product) %>

      <%= turbo_frame_tag "catalog-tabs-#{@product.id}" do %>
        <%= render Products::CatalogTabsComponent.new(
          product: @product,
          catalog_items: @product.catalog_items,
          attribute_values: @attribute_values,
          available_catalogs: @available_catalogs
        ) %>
      <% end %>

      <%= render Products::LabelsComponent.new(product: @product) %>
    </div>

    <div class="space-y-4 lg:sticky lg:top-20 lg:self-start">
      <%= render Products::InventorySummaryComponent.new(product: @product) %>
      <%= render Products::ConfigurableCardComponent.new(product: @product) %>

      <% shopify_catalogs = @product.catalog_items.includes(:catalog)
           .select { |ci| ci.catalog.shopify_connected? } %>
      <% if shopify_catalogs.any? %>
        <div class="bg-white shadow-sm rounded-lg border border-gray-200 p-4">
          <h3 class="text-sm font-medium text-gray-900 mb-3">Shopify Sync Preview</h3>
          <div class="space-y-2">
            <% shopify_catalogs.each do |ci| %>
              <div class="flex items-center justify-between p-2 rounded hover:bg-gray-50 transition-colors">
                <span class="text-sm text-gray-700"><%= ci.catalog.name %></span>
                <div class="flex items-center gap-2">
                  <div id="sync-btn-<%= ci.catalog.code %>">
                    <%= button_to sync_product_catalog_path(ci.catalog.code, product_id: @product.id),
                        method: :post,
                        class: "inline-flex items-center gap-1 px-2 py-1 text-xs font-medium text-indigo-600
                               bg-indigo-50 rounded hover:bg-indigo-100 transition-colors",
                        data: { turbo_submits_with: "Syncing..." } do %>
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                        <path fill-rule="evenodd" d="M4 2a1 1 0 011 1v2.101a7.002 7.002 0 0111.601 2.566 1 1 0 11-1.885.666A5.002 5.002 0 005.999 7H9a1 1 0 010 2H4a1 1 0 01-1-1V3a1 1 0 011-1zm.008 9.057a1 1 0 011.276.61A5.002 5.002 0 0014.001 13H11a1 1 0 110-2h5a1 1 0 011 1v5a1 1 0 11-2 0v-2.101a7.002 7.002 0 01-11.601-2.566 1 1 0 01.61-1.276z" clip-rule="evenodd"/>
                      </svg>
                      Sync
                    <% end %>
                  </div>
                  <%= link_to sync_preview_catalog_path(ci.catalog.code, product_id: @product.id),
                      data: { turbo_frame: "sync-preview-drawer" },
                      class: "text-xs text-gray-400 hover:text-indigo-600 transition-colors" do %>
                    Preview &rarr;
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <turbo-frame id="sync-preview-drawer"></turbo-frame>

      <%= render Products::ActivityTimelineComponent.new(product: @product) %>
    </div>
  </div>
</div>
```

- [ ] **Step 3: Point both Turbo stream responses at the header frame**

Replace `app/views/products/toggle_active.turbo_stream.erb` with:

```erb
<%= turbo_stream.replace "product-header-#{@product.id}" do %>
  <%= turbo_frame_tag "product-header-#{@product.id}" do %>
    <%= render Products::HeaderComponent.new(product: @product) %>
  <% end %>
<% end %>

<%= turbo_stream.update "flash" do %>
  <%= render "shared/flash" %>
<% end %>
```

Replace `app/views/products/activate_variants.turbo_stream.erb` with the identical content.

- [ ] **Step 4: Delete the two superseded components and their specs**

```bash
git rm app/components/products/basic_info_component.rb app/components/products/basic_info_component.html.erb spec/components/products/basic_info_component_spec.rb
git rm app/components/products/status_card_component.rb app/components/products/status_card_component.html.erb spec/components/products/status_card_component_spec.rb
grep -rn "BasicInfoComponent\|StatusCardComponent\|product-status-" app spec
```

Expected: the grep prints nothing.

- [ ] **Step 5: Run the request specs and the component suite**

Run: `bundle exec rspec spec/requests/products_spec.rb spec/components/products --format progress`
Expected: 0 failures. The show examples still find `SHOW001` and `Show Product` in the body because the header renders the SKU and name.

- [ ] **Step 6: Commit**

```bash
git add app/views/products/show.html.erb app/views/products/toggle_active.turbo_stream.erb app/views/products/activate_variants.turbo_stream.erb
git commit -m "feat(products): replace Basic Info and Status cards with header, sticky sidebar

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 3: Product-tab attribute rows as single lines with an unset group

**Files:**
- Modify: `app/views/products/_attribute_value.html.erb`
- Modify: `app/views/products/catalog_tabs/_product_attributes.html.erb`
- Modify: `app/components/products/catalog_tabs_component.html.erb` (line 61: `<div class="p-6">`)
- Test: `spec/components/products/catalog_tabs_component_spec.rb` (new)

**Interfaces:**
- Consumes: `Products::CatalogTabsComponent.new(product:, catalog_items:, attribute_values:, available_catalogs:)` where `attribute_values` is a Hash keyed by `ProductAttribute`.
- Produces: partial `products/attribute_value` with locals `attribute:`, `value:`, `product:` whose root element has `id = dom_id(attribute, :value)`. `ProductAttributeValuesController#update` already renders this partial with these locals, so the row re-renders in place after an inline edit. Task 4 reuses the same row classes.

Row structure used by this task and Task 4 (the `display` wrapper is what the inline editor hides; the `dl` only contains `dt`/`dd`, which keeps axe happy):

```
div#<row id>.group.px-6.py-2.border-b.border-gray-100   [data-controller="inline-editor"]
├─ div.flex.items-start.gap-x-4                          [data-inline-editor-target="display"]
│   ├─ dl.flex.flex-1.min-w-0.items-start.gap-x-4
│   │   ├─ dt.w-44.shrink-0   (name, badges)
│   │   └─ dd.flex-1.min-w-0  (value)
│   └─ div.flex.shrink-0.items-center.gap-1  (actions or "inherited" tag)
└─ div.hidden.mt-2                                        [data-inline-editor-target="editor"]  (form)
```

- [ ] **Step 1: Write the failing spec**

Create `spec/components/products/catalog_tabs_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::CatalogTabsComponent, type: :component do
  include ActionView::RecordIdentifier

  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }
  let(:price_attribute) { company.product_attributes.find_by!(code: "price") }
  let(:brand_attribute) { company.product_attributes.find_by!(code: "brand") }

  def attribute_values_for(product)
    product.product_attribute_values.reload.index_by(&:product_attribute)
  end

  def render_component(product, available_catalogs: [])
    render_inline(described_class.new(
      product: product,
      catalog_items: product.catalog_items,
      attribute_values: attribute_values_for(product),
      available_catalogs: available_catalogs
    ))
  end

  describe "Product tab" do
    it "renders one row per attribute, rooted at the value row id" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product)

      expect(page).to have_css("##{dom_id(brand_attribute, :value)} dd", text: "Acme")
    end

    it "keeps attributes with values out of the unset group" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product)

      expect(page).not_to have_css("details ##{dom_id(brand_attribute, :value)}")
    end

    it "groups non-mandatory unset attributes inside a details block with a count" do
      render_component(product)

      unset_count = company.product_attributes.where(mandatory: false).count
      expect(page).to have_css("details summary", text: "Show #{unset_count} unset attributes")
      expect(page).to have_css("details ##{dom_id(brand_attribute, :value)} dd", text: "Not set")
    end

    it "keeps mandatory unset attributes visible with a Required badge" do
      render_component(product)

      row = "##{dom_id(price_attribute, :value)}"
      expect(page).not_to have_css("details #{row}")
      expect(page).to have_css("#{row} span.bg-yellow-100", text: "Required")
      expect(page).to have_css("#{row} dd.text-amber-700", text: "Not set")
    end

    it "wires each row to the inline editor with a hidden editor block" do
      render_component(product)

      row = "##{dom_id(price_attribute, :value)}"
      expect(page).to have_css("#{row}[data-controller='inline-editor']")
      expect(page).to have_css("#{row} [data-inline-editor-target='display']")
      expect(page).to have_css("#{row} [data-inline-editor-target='editor'].hidden")
      expect(page).to have_css("#{row} button[aria-label='Edit #{price_attribute.name}']")
    end

    it "puts the attribute description on the name as a tooltip instead of a third line" do
      brand_attribute.update!(description: "Manufacturer brand")
      render_component(product)

      expect(page).to have_css("##{dom_id(brand_attribute, :value)} dt[title='Manufacturer brand']")
      expect(page).not_to have_css("##{dom_id(brand_attribute, :value)} dd", text: "Manufacturer brand")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/products/catalog_tabs_component_spec.rb --format progress`
Expected: FAIL. The `details` and `Required` expectations fail because the current partial renders every attribute as a stacked block with no grouping.

- [ ] **Step 3: Rewrite `app/views/products/_attribute_value.html.erb`**

Replace the whole file with:

```erb
<%# Single Product-tab attribute row. The root id is what
    ProductAttributeValuesController#update replaces via turbo_stream.
    Locals: attribute (ProductAttribute), value (ProductAttributeValue or nil), product %>
<% has_value = value.present? && value.value.present? %>
<% unset_mandatory = !has_value && attribute.mandatory? %>
<% value_classes = if has_value
     "text-gray-900"
   elsif unset_mandatory
     "text-amber-700 italic"
   else
     "text-gray-400 italic"
   end %>
<div id="<%= dom_id(attribute, :value) %>"
     class="group px-6 py-2 border-b border-gray-100"
     data-controller="inline-editor"
     data-inline-editor-url-value="<%= product_attribute_value_path(product, attribute) %>">
  <div class="flex items-start gap-x-4" data-inline-editor-target="display">
    <dl class="flex flex-1 min-w-0 items-start gap-x-4">
      <dt class="flex w-44 shrink-0 items-center gap-2 text-sm font-medium text-gray-500"
          <% if attribute.description.present? %>title="<%= attribute.description %>"<% end %>>
        <span class="truncate"><%= attribute.name %></span>
        <% if unset_mandatory %>
          <%= render Ui::BadgeComponent.new(variant: :warning, size: :sm) do %>Required<% end %>
        <% end %>
      </dt>
      <dd class="flex-1 min-w-0 text-sm <%= attribute.patype_rich_text? ? 'line-clamp-2' : 'truncate' %> <%= value_classes %>"
          <% if has_value %>title="<%= value.value %>"<% end %>>
        <%= has_value ? value.value : 'Not set' %>
      </dd>
    </dl>
    <div class="flex shrink-0 items-center gap-1">
      <%= button_tag type: "button",
          class: "p-1 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity text-gray-400 hover:text-gray-600 rounded hover:bg-gray-100",
          data: { action: "click->inline-editor#edit" },
          aria: { label: "Edit #{attribute.name}" } do %>
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
        </svg>
      <% end %>
    </div>
  </div>

  <div class="hidden mt-2" data-inline-editor-target="editor">
    <%= form_with url: product_attribute_value_path(product, attribute),
        method: :patch,
        data: {
          inline_editor_target: "form",
          action: "turbo:submit-end->inline-editor#handleSubmit"
        } do |form| %>
      <div class="space-y-3">
        <div>
          <label class="block text-sm font-medium text-gray-700"><%= attribute.name %></label>
          <% if attribute.patype_select? %>
            <%= form.select :value,
                options_for_select(attribute.options, value&.value),
                { prompt: "Select an option" },
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif attribute.patype_multiselect? %>
            <%= form.select :value,
                options_for_select(attribute.options, value&.value),
                { prompt: "Select options" },
                multiple: true,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif attribute.patype_boolean? %>
            <%= form.check_box :value,
                { checked: value&.value == 'true' },
                class: "h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <% elsif attribute.patype_number? %>
            <%= form.number_field :value,
                value: value&.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{attribute.name.downcase}" %>
          <% elsif attribute.patype_date? %>
            <%= form.date_field :value,
                value: value&.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif attribute.patype_rich_text? %>
            <%= form.text_area :value,
                value: value&.value,
                rows: 4,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{attribute.name.downcase}" %>
          <% else %>
            <%= form.text_field :value,
                value: value&.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{attribute.name.downcase}" %>
          <% end %>
          <% if attribute.description.present? %>
            <p class="mt-1 text-xs text-gray-500"><%= attribute.description %></p>
          <% end %>
        </div>

        <div class="flex gap-x-2">
          <%= render Ui::ButtonComponent.new(variant: :primary, type: "submit", size: :sm) do %>
            Save
          <% end %>
          <%= render Ui::ButtonComponent.new(
            variant: :secondary,
            type: "button",
            size: :sm,
            data: { action: "click->inline-editor#cancel" }
          ) do %>
            Cancel
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Rewrite `app/views/products/catalog_tabs/_product_attributes.html.erb`**

Replace the whole file with:

```erb
<%
  visible_attributes, hidden_attributes = all_attributes.partition do |attribute|
    value = attribute_values[attribute]
    (value.present? && value.value.present?) || attribute.mandatory?
  end
%>
<div>
  <% visible_attributes.each do |attribute| %>
    <%= render partial: "products/attribute_value",
               locals: { attribute: attribute, value: attribute_values[attribute], product: product } %>
  <% end %>

  <% if hidden_attributes.any? %>
    <details>
      <summary class="cursor-pointer px-6 py-2 text-sm font-medium text-blue-600 hover:text-blue-500">
        Show <%= hidden_attributes.size %> unset attribute<%= "s" unless hidden_attributes.size == 1 %>
      </summary>
      <% hidden_attributes.each do |attribute| %>
        <%= render partial: "products/attribute_value",
                   locals: { attribute: attribute, value: attribute_values[attribute], product: product } %>
      <% end %>
    </details>
  <% end %>

  <% if all_attributes.empty? %>
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No attributes defined</h3>
      <p class="mt-1 text-sm text-gray-500">This company has no product attributes defined yet.</p>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Drop the panel padding in the tabs component template**

In `app/components/products/catalog_tabs_component.html.erb`, change the line `  <div class="p-6">` (directly after the closing `</div>` of the tab bar) to `  <div>`. Nothing else in that file changes.

- [ ] **Step 6: Run the new spec**

Run: `bundle exec rspec spec/components/products/catalog_tabs_component_spec.rb --format progress`
Expected: 6 examples, 0 failures

- [ ] **Step 7: Run the inline-edit request spec, which renders the row partial**

Run: `bundle exec rspec spec/requests/product_attribute_values_spec.rb --format progress`
Expected: 0 failures

- [ ] **Step 8: Commit**

```bash
git add app/views/products/_attribute_value.html.erb app/views/products/catalog_tabs/_product_attributes.html.erb app/components/products/catalog_tabs_component.html.erb spec/components/products/catalog_tabs_component_spec.rb
git commit -m "feat(products): render Product-tab attributes as single rows with unset group

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 4: Catalog-tab rows, compact catalog header, one override row source

**Files:**
- Create: `app/views/products/catalog_tabs/_catalog_override_row.html.erb`
- Modify: `app/views/products/catalog_tabs/_catalog_attributes.html.erb`
- Modify: `app/views/catalog_item_attribute_values/update.turbo_stream.erb`
- Test: `spec/components/products/catalog_tabs_component_spec.rb` (append a `describe "catalog tab"` block)
- Test: `spec/requests/catalog_item_attribute_values_spec.rb` (new)

**Interfaces:**
- Consumes: the row structure from Task 3; `catalog_item.catalog_item_attribute_values` (loaded in full by the show action); `catalog_item_attribute_value_path(override)`; `catalog_items_path(catalog)`; `product_catalog_path(product, catalog_id)`.
- Produces: partial `products/catalog_tabs/catalog_override_row` with locals `catalog_override:`, `product_attribute:`, `product_value:`, `catalog_item:`, `product:`; root id `dom_id(catalog_override, :value)`.

- [ ] **Step 1: Append the failing catalog-tab examples to the component spec**

Add inside the top-level `RSpec.describe` block of `spec/components/products/catalog_tabs_component_spec.rb`, after the `describe "Product tab"` block:

```ruby
  describe "catalog tab" do
    let(:catalog) { create(:catalog, company: company, name: "European Webshop") }
    let!(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
    let(:short_description) { company.product_attributes.find_by!(code: "short_description") }
    let(:panel) { "#panel-#{catalog.code}" }

    it "renders a one-line catalog header with view and remove actions" do
      render_component(product.reload)

      expect(page).to have_css("#{panel} h4", text: "European Webshop")
      expect(page).to have_css("#{panel} a", text: "View catalog")
      expect(page).to have_css("#{panel} button", text: "Remove")
      expect(page).not_to have_css("#{panel} button", text: "Remove from Catalog")
    end

    it "marks inherited product values with an inherited tag and no editor" do
      create(:product_attribute_value, product: product, product_attribute: brand_attribute, value: "Acme")
      render_component(product.reload)

      expect(page).to have_css("#{panel} dd", text: "Acme")
      expect(page).to have_css("#{panel} span.text-gray-400", text: "inherited")
      expect(page).not_to have_text("Inherited from product")
    end

    it "renders overrides with the Override badge and edit/remove controls" do
      override = create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: short_description, value: "EU copy")
      render_component(product.reload)

      row = "##{dom_id(override, :value)}"
      expect(page).to have_css("#{row} dd", text: "EU copy")
      expect(page).to have_css("#{row} span.bg-blue-100", text: "Override")
      expect(page).to have_css("#{row}[data-controller='inline-editor']")
      expect(page).to have_css("#{row} button[aria-label='Edit #{short_description.name}']")
      expect(page).to have_css("#{row} button[aria-label='Remove override for #{short_description.name}']")
    end

    it "omits attributes with neither an override nor a product value" do
      render_component(product.reload)

      expect(page).not_to have_css("#{panel} dt", text: brand_attribute.name)
    end

    it "still offers the Add Attribute Override action" do
      render_component(product.reload)

      expect(page).to have_css("#{panel} button", text: "Add Attribute Override")
    end
  end
```

- [ ] **Step 2: Run the spec to verify the new examples fail**

Run: `bundle exec rspec spec/components/products/catalog_tabs_component_spec.rb --format progress`
Expected: the six Product-tab examples pass; "inherited tag", "one-line catalog header", and "Override badge and edit/remove controls" fail.

- [ ] **Step 3: Create `app/views/products/catalog_tabs/_catalog_override_row.html.erb`**

```erb
<%# Single catalog override row. Rendered by _catalog_attributes for each override.
    Locals: catalog_override (CatalogItemAttributeValue), product_attribute (ProductAttribute),
            product_value (ProductAttributeValue or nil), catalog_item, product %>
<% product_has_value = product_value.present? && product_value.value.present? %>
<% differs_from_product = product_has_value && catalog_override.value != product_value.value %>
<div id="<%= dom_id(catalog_override, :value) %>"
     class="group px-6 py-2 border-b border-gray-100"
     data-controller="inline-editor"
     data-inline-editor-url-value="<%= catalog_item_attribute_value_path(catalog_override) %>">
  <div class="flex items-start gap-x-4" data-inline-editor-target="display">
    <dl class="flex flex-1 min-w-0 items-start gap-x-4">
      <dt class="flex w-44 shrink-0 items-center gap-2 text-sm font-medium text-gray-500"
          <% if product_attribute.description.present? %>title="<%= product_attribute.description %>"<% end %>>
        <span class="truncate"><%= product_attribute.name %></span>
        <span class="inline-flex shrink-0 items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800">Override</span>
      </dt>
      <dd class="flex-1 min-w-0 text-sm text-gray-900 <%= product_attribute.patype_rich_text? ? 'line-clamp-2' : 'truncate' %>"
          title="<%= differs_from_product ? "Product value: #{product_value.value}" : catalog_override.value %>">
        <%= catalog_override.value %>
      </dd>
    </dl>
    <div class="flex shrink-0 items-center gap-1">
      <%= button_tag type: "button",
          class: "p-1 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity text-gray-400 hover:text-gray-600 rounded hover:bg-gray-100",
          data: { action: "click->inline-editor#edit" },
          aria: { label: "Edit #{product_attribute.name}" } do %>
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>
        </svg>
      <% end %>
      <%= button_to catalog_item_attribute_value_path(catalog_override),
            method: :delete,
            form: { data: { turbo_confirm: "Remove override for #{product_attribute.name}? This will use the product value instead." } },
            class: "p-1 opacity-0 group-hover:opacity-100 focus:opacity-100 transition-opacity text-red-400 hover:text-red-600 border-0 bg-transparent rounded hover:bg-gray-100",
            aria: { label: "Remove override for #{product_attribute.name}" },
            title: "Remove override (use product value)",
            data: { turbo_frame: "_top" } do %>
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
        </svg>
      <% end %>
    </div>
  </div>

  <div class="hidden mt-2" data-inline-editor-target="editor">
    <%= form_with url: catalog_item_attribute_value_path(catalog_override),
        method: :patch,
        data: {
          inline_editor_target: "form",
          action: "turbo:submit-end->inline-editor#handleSubmit"
        } do |form| %>
      <div class="space-y-3">
        <div>
          <label class="block text-sm font-medium text-gray-700">
            <%= product_attribute.name %>
            <span class="inline-flex items-center rounded-full bg-blue-100 px-2 py-0.5 text-xs font-medium text-blue-800 ml-2">
              Override
            </span>
          </label>
          <% if product_attribute.patype_select? %>
            <%= form.select :value,
                options_for_select(product_attribute.options, catalog_override.value),
                { prompt: "Select an option" },
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif product_attribute.patype_multiselect? %>
            <%= form.select :value,
                options_for_select(product_attribute.options, catalog_override.value),
                { prompt: "Select options" },
                multiple: true,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif product_attribute.patype_boolean? %>
            <%= form.check_box :value,
                { checked: catalog_override.value == 'true' },
                class: "h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500" %>
          <% elsif product_attribute.patype_number? %>
            <%= form.number_field :value,
                value: catalog_override.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{product_attribute.name.downcase}" %>
          <% elsif product_attribute.patype_date? %>
            <%= form.date_field :value,
                value: catalog_override.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm" %>
          <% elsif product_attribute.patype_rich_text? %>
            <%= form.text_area :value,
                value: catalog_override.value,
                rows: 4,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{product_attribute.name.downcase}" %>
          <% else %>
            <%= form.text_field :value,
                value: catalog_override.value,
                class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                placeholder: "Enter #{product_attribute.name.downcase}" %>
          <% end %>
          <% if differs_from_product %>
            <p class="mt-1 text-xs text-gray-500">
              Product value: <%= product_value.value %>
            </p>
          <% end %>
        </div>

        <div class="flex gap-x-2">
          <%= render Ui::ButtonComponent.new(variant: :primary, type: "submit", size: :sm) do %>
            Save
          <% end %>
          <%= render Ui::ButtonComponent.new(
            variant: :secondary,
            type: "button",
            size: :sm,
            data: { action: "click->inline-editor#cancel" }
          ) do %>
            Cancel
          <% end %>
        </div>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Rewrite `app/views/products/catalog_tabs/_catalog_attributes.html.erb`**

Replace the whole file with (the Add Attribute Override modal block is the existing one, moved into a footer row):

```erb
<div>
  <div class="flex items-center justify-between px-6 py-3 border-b border-gray-200">
    <div class="flex items-center gap-2">
      <h4 class="text-sm font-medium text-gray-900"><%= catalog_item.catalog.name %></h4>
      <%= render Ui::BadgeComponent.new(variant: catalog_item.active? ? :success : :gray, size: :sm) do %>
        <%= catalog_item.catalog_item_state.titleize %>
      <% end %>
    </div>
    <div class="flex items-center gap-4 text-sm font-medium">
      <%= link_to "View catalog", catalog_items_path(catalog_item.catalog),
            class: "text-blue-600 hover:text-blue-500",
            data: { turbo_frame: "_top" } %>
      <%= button_to "Remove", product_catalog_path(product, catalog_item.catalog_id),
            method: :delete,
            form: { data: { turbo_confirm: "Remove #{product.name} from #{catalog_item.catalog.name}?", turbo_frame: "catalog-tabs-#{product.id}" } },
            class: "border-0 bg-transparent p-0 text-red-600 hover:text-red-500" %>
    </div>
  </div>

  <% if all_attributes.any? %>
    <div>
      <% all_attributes.each do |product_attribute| %>
        <% catalog_override = catalog_item.catalog_item_attribute_values.find { |ciav| ciav.product_attribute_id == product_attribute.id } %>
        <% product_value = attribute_values[product_attribute] %>
        <% next unless catalog_override.present? || (product_value.present? && product_value.value.present?) %>

        <% if catalog_override.present? %>
          <%= render partial: "products/catalog_tabs/catalog_override_row",
                     locals: {
                       catalog_override: catalog_override,
                       product_attribute: product_attribute,
                       product_value: product_value,
                       catalog_item: catalog_item,
                       product: product
                     } %>
        <% else %>
          <div class="px-6 py-2 border-b border-gray-100">
            <div class="flex items-start gap-x-4">
              <dl class="flex flex-1 min-w-0 items-start gap-x-4">
                <dt class="w-44 shrink-0 truncate text-sm font-medium text-gray-500"
                    <% if product_attribute.description.present? %>title="<%= product_attribute.description %>"<% end %>>
                  <%= product_attribute.name %>
                </dt>
                <dd class="flex-1 min-w-0 text-sm text-gray-900 <%= product_attribute.patype_rich_text? ? 'line-clamp-2' : 'truncate' %>"
                    title="<%= product_value.value %>">
                  <%= product_value.value %>
                </dd>
              </dl>
              <span class="shrink-0 text-xs text-gray-400">inherited</span>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>

    <div class="flex justify-end px-6 py-3">
      <% available_attrs = all_attributes
           .select { |attr| attr.catalog_scope? || attr.product_and_catalog_scope? }
           .reject { |attr| catalog_item.catalog_item_attribute_values.any? { |ciav| ciav.product_attribute_id == attr.id } } %>

      <%= render Ui::ModalComponent.new(size: :md, modal_id: "add-override-modal-#{catalog_item.catalog.code}") do |modal| %>
        <% modal.with_trigger do %>
          <%= render Ui::ButtonComponent.new(variant: :secondary, size: :sm) do %>
            <svg class="-ml-0.5 mr-1.5 h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
            </svg>
            Add Attribute Override
          <% end %>
        <% end %>

        <% modal.with_header do %>
          Add Attribute Override
        <% end %>

        <% if available_attrs.any? %>
          <div data-controller="attribute-override" data-attribute-override-product-id-value="<%= product.id %>">
            <%= form_with url: catalog_item_attribute_values_path, method: :post, id: "add-override-form-#{catalog_item.catalog.code}", data: { turbo_frame: "_top" } do |f| %>
              <%= f.hidden_field :catalog_item_id, value: catalog_item.id %>

              <div class="space-y-4">
                <div>
                  <label for="attribute-select-<%= catalog_item.catalog.code %>" class="block text-sm font-medium text-gray-700">
                    Attribute
                  </label>
                  <%= f.select :product_attribute_id,
                        options_for_select(available_attrs.map { |attr| [attr.name, attr.id, { 'data-code': attr.code }] }),
                        { prompt: 'Select an attribute...' },
                        {
                          id: "attribute-select-#{catalog_item.catalog.code}",
                          class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                          data: {
                            action: "change->attribute-override#loadProductValue",
                            attribute_override_target: "attributeSelect"
                          }
                        } %>
                </div>

                <div>
                  <label for="value-input-<%= catalog_item.catalog.code %>" class="block text-sm font-medium text-gray-700">
                    Override Value
                  </label>
                  <%= f.text_field :value,
                        id: "value-input-#{catalog_item.catalog.code}",
                        class: "mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm",
                        placeholder: "Enter override value",
                        data: {
                          attribute_override_target: "valueInput"
                        } %>
                  <p class="mt-1 text-xs text-gray-500" data-attribute-override-target="productValueHint">
                  </p>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
            </svg>
            <p class="mt-2 text-sm text-gray-900">All attributes have overrides</p>
            <p class="mt-1 text-xs text-gray-500">You've already overridden all available attributes for this catalog.</p>
          </div>
        <% end %>

        <% modal.with_footer do %>
          <%= render Ui::ButtonComponent.new(
                variant: :secondary,
                data: { action: "click->modal#close" }
              ) do %>
            Cancel
          <% end %>
          <% if available_attrs.any? %>
            <%= render Ui::ButtonComponent.new(
                  variant: :primary,
                  type: "submit",
                  form: "add-override-form-#{catalog_item.catalog.code}"
                ) do %>
              Add Override
            <% end %>
          <% end %>
        <% end %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-12">
      <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"></path>
      </svg>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No attributes</h3>
      <p class="mt-1 text-sm text-gray-500">No attributes are defined for this company yet.</p>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run the component spec**

Run: `bundle exec rspec spec/components/products/catalog_tabs_component_spec.rb --format progress`
Expected: 11 examples, 0 failures

- [ ] **Step 6: Write the failing request spec for the override update response**

Create `spec/requests/catalog_item_attribute_values_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe "/catalog_item_attribute_values", type: :request do
  let(:company) { create(:company) }
  let(:user) { create(:user, company: company) }
  let(:product) { create(:product, company: company) }
  let(:catalog) { create(:catalog, company: company) }
  let(:catalog_item) { create(:catalog_item, catalog: catalog, product: product) }
  let(:attribute) { company.product_attributes.find_by!(code: "short_description") }
  let!(:override) { create(:catalog_item_attribute_value, catalog_item: catalog_item, product_attribute: attribute, value: "Old copy") }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(ApplicationController).to receive(:authenticated?).and_return(true)
    allow_any_instance_of(ApplicationController).to receive(:current_company).and_return({
      id: company.id,
      code: company.code,
      name: company.name
    })
    allow_any_instance_of(ApplicationController).to receive(:current_potlift_company).and_return(company)
    allow_any_instance_of(ApplicationController).to receive(:pundit_user).and_return(
      UserContext.new(nil, "admin", [ "read", "write" ], company)
    )
  end

  describe "PATCH /catalog_item_attribute_values/:id as turbo_stream" do
    it "replaces the whole catalog panel with the updated override row" do
      patch catalog_item_attribute_value_path(override, format: :turbo_stream), params: { value: "New copy" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(target="panel-#{catalog.code}"))
      expect(response.body).to include("New copy")
      expect(response.body).to include("Override")
      expect(override.reload.value).to eq("New copy")
    end
  end
end
```

- [ ] **Step 7: Run it to verify it fails**

Run: `bundle exec rspec spec/requests/catalog_item_attribute_values_spec.rb --format progress`
Expected: FAIL on the `target="panel-..."` expectation, because the current response replaces the row id instead of the panel.

- [ ] **Step 8: Replace `app/views/catalog_item_attribute_values/update.turbo_stream.erb`**

Replace the whole file with:

```erb
<%= turbo_stream.replace "panel-#{@catalog_item.catalog.code}" do %>
  <div
    data-catalog-tabs-target="panel"
    data-panel-id="<%= @catalog_item.catalog.code %>"
    id="panel-<%= @catalog_item.catalog.code %>"
    role="tabpanel"
    aria-labelledby="tab-<%= @catalog_item.catalog.code %>">
    <%= render partial: 'products/catalog_tabs/catalog_attributes',
               locals: {
                 catalog_item: @catalog_item,
                 product: @product,
                 attribute_values: @product.product_attribute_values.index_by(&:product_attribute),
                 all_attributes: @product.company.product_attributes
               } %>
  </div>
<% end %>

<%= turbo_stream.update "flash" do %>
  <%= render "shared/flash" %>
<% end %>
```

- [ ] **Step 9: Run the request spec and the catalog specs**

Run: `bundle exec rspec spec/requests/catalog_item_attribute_values_spec.rb spec/requests/product_catalogs_spec.rb spec/components/products/catalog_tabs_component_spec.rb --format progress`
Expected: 0 failures

- [ ] **Step 10: Commit**

```bash
git add app/views/products/catalog_tabs/_catalog_override_row.html.erb app/views/products/catalog_tabs/_catalog_attributes.html.erb app/views/catalog_item_attribute_values/update.turbo_stream.erb spec/components/products/catalog_tabs_component_spec.rb spec/requests/catalog_item_attribute_values_spec.rb
git commit -m "feat(products): single-line catalog attribute rows, one override row source

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 5: Images card: thumbnail strip, Upload label, gallery behind details

**Files:**
- Modify: `app/components/products/images_component.rb`
- Modify: `app/components/products/images_component.html.erb`
- Test: `spec/components/products/images_component_spec.rb` (rewrite)

**Interfaces:**
- Consumes: `product.images` (ActiveStorage `has_many_attached`), `product_images_path(product)`, partial `product_images/metadata_modal`.
- Produces: private helpers `strip_images` (Array of attachments, at most 8) and `overflow_count` (Integer). Only the template uses them.

- [ ] **Step 1: Rewrite the spec**

Replace `spec/components/products/images_component_spec.rb` with:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ImagesComponent, type: :component do
  let(:company) { create(:company) }
  let(:product) { create(:product, company: company) }

  def attach_images(count)
    count.times do |i|
      product.images.attach(
        io: File.open(Rails.root.join("spec", "fixtures", "files", "test_image.png")),
        filename: "test-#{i}.png",
        content_type: "image/png"
      )
    end
  end

  it "renders the images header" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("h3", text: "Images")
  end

  it "renders an Upload label bound to the hidden multi-file input" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("label[for='file-upload']", text: "Upload")
    expect(page).to have_css("input#file-upload[type='file'][multiple][accept='image/*'].sr-only")
  end

  it "keeps the image-upload controller on the form with dropzone and progress targets inside it" do
    render_inline(described_class.new(product: product))

    expect(page).to have_css("form[data-controller='image-upload']")
    expect(page).to have_css("form [data-image-upload-target='dropzone'][data-action*='drop->image-upload#handleDrop']")
    expect(page).to have_css("form [data-image-upload-target='progressContainer']")
    expect(page).to have_css("form input[data-image-upload-target='input'][data-action='change->image-upload#handleFiles']")
  end

  context "without images" do
    it "shows the one-line empty state and no gallery toggle" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No images yet. Upload or drop files here.")
      expect(page).not_to have_css("details")
      expect(page).not_to have_css("[data-controller*='product-images']")
    end

    it "does not show a count badge" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_css("h3 ~ span.rounded-full")
    end
  end

  context "with images attached" do
    before { attach_images(3) }

    it "shows the image count next to the header" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("span.rounded-full", text: "3")
    end

    it "renders a thumbnail strip with the primary marker on the first image only" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-image-upload-target='dropzone'] img", count: 3)
      expect(page).to have_css("[data-image-upload-target='dropzone'] .sr-only", text: "Primary image", count: 1)
    end

    it "puts the full gallery behind a Manage images toggle, outside the upload form" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("details summary", text: "Manage images")
      expect(page).to have_css("details [data-controller='product-images bulk-images image-reorder image-metadata']")
      expect(page).not_to have_css("form details")
    end
  end

  context "with more than eight images" do
    before { attach_images(10) }

    it "shows seven thumbnails and a +3 overflow tile" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-image-upload-target='dropzone'] img", count: 7)
      expect(page).to have_css("[data-image-upload-target='dropzone'] div", text: "+3")
    end
  end

  describe "gallery template" do
    let(:template_content) { File.read(Rails.root.join("app/components/products/images_component.html.erb")) }

    it "keeps selectImage and deleteImage actions without :stop modifiers" do
      expect(template_content).to include("click->product-images#selectImage")
      expect(template_content).not_to include("click->product-images#selectImage:stop")
      expect(template_content).to include("click->product-images#deleteImage")
      expect(template_content).not_to include("click->product-images#deleteImage:stop")
    end
  end
end
```

- [ ] **Step 2: Run it to verify the new expectations fail**

Run: `bundle exec rspec spec/components/products/images_component_spec.rb --format progress`
Expected: FAIL on the Upload label, empty-state text, thumbnail strip, and details expectations.

- [ ] **Step 3: Add the strip helpers to the component class**

Replace `app/components/products/images_component.rb` with:

```ruby
# frozen_string_literal: true

module Products
  class ImagesComponent < ViewComponent::Base
    STRIP_LIMIT = 8

    attr_reader :product

    def initialize(product:)
      @product = product
    end

    private

    def main_image
      product.images.first
    end

    def images
      product.images
    end

    def has_images?
      product.images.attached?
    end

    # Thumbnails shown in the collapsed strip. When more than STRIP_LIMIT images
    # exist, the last slot is reserved for the "+N" tile.
    def strip_images
      return images.to_a if images.count <= STRIP_LIMIT

      images.first(STRIP_LIMIT - 1)
    end

    def overflow_count
      return 0 if images.count <= STRIP_LIMIT

      images.count - (STRIP_LIMIT - 1)
    end
  end
end
```

- [ ] **Step 4: Restructure the template**

Open `app/components/products/images_component.html.erb`. Keep the block that starts with `<div data-controller="product-images bulk-images image-reorder image-metadata"` and ends with the `</div>` that follows `<%= render "product_images/metadata_modal", product: product %>` exactly as it is; call it GALLERY below. Replace everything else so the file reads:

```erb
<div id="product_images_card">
<%= render Ui::CardComponent.new(padding: :sm) do |card| %>
  <% card.with_header do %>
    <div class="flex items-center gap-2">
      <h3 class="text-base font-semibold leading-6 text-gray-900">Images</h3>
      <% if has_images? %>
        <%= render Ui::BadgeComponent.new(variant: :gray) do %>
          <%= images.count %>
        <% end %>
      <% end %>
    </div>
  <% end %>
  <% card.with_action do %>
    <label for="file-upload" class="inline-flex cursor-pointer items-center justify-center rounded-lg border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus-within:ring-2 focus-within:ring-blue-500 focus-within:ring-offset-2">
      Upload
    </label>
  <% end %>

  <%= form_with url: product_images_path(product), method: :post, multipart: true, data: { controller: "image-upload", turbo: false } do |form| %>
    <div class="rounded-md border border-transparent p-1 transition-colors"
         data-image-upload-target="dropzone"
         data-action="drop->image-upload#handleDrop dragover->image-upload#handleDragOver dragleave->image-upload#handleDragLeave">
      <% if has_images? %>
        <div class="flex gap-2 overflow-x-auto">
          <% strip_images.each_with_index do |image, index| %>
            <div class="relative h-16 w-16 shrink-0 overflow-hidden rounded">
              <%= image_tag image.variant(resize_to_fill: [128, 128]), class: "h-full w-full object-cover", alt: image.blob.metadata&.dig(:alt_text) || "#{product.name} - Image #{index + 1}" %>
              <% if index == 0 %>
                <span class="absolute left-1 top-1 rounded-full bg-yellow-500 p-0.5 text-white" title="Primary image">
                  <svg class="h-3 w-3" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
                    <path d="M10 15.27L16.18 19l-1.64-7.03L20 7.24l-7.19-.61L10 0 7.19 6.63 0 7.24l5.46 4.73L3.82 19z" />
                  </svg>
                  <span class="sr-only">Primary image</span>
                </span>
              <% end %>
            </div>
          <% end %>
          <% if overflow_count > 0 %>
            <div class="flex h-16 w-16 shrink-0 items-center justify-center rounded bg-gray-100 text-sm font-medium text-gray-600">+<%= overflow_count %></div>
          <% end %>
        </div>
      <% else %>
        <p class="text-sm text-gray-500">No images yet. Upload or drop files here.</p>
      <% end %>
    </div>

    <%= form.file_field :images,
        multiple: true,
        accept: "image/*",
        class: "sr-only",
        id: "file-upload",
        data: {
          image_upload_target: "input",
          action: "change->image-upload#handleFiles"
        } %>
    <div class="mt-2 space-y-2" data-image-upload-target="progressContainer"></div>
  <% end %>

  <% if has_images? %>
    <details class="mt-3">
      <summary class="cursor-pointer text-sm font-medium text-blue-600 hover:text-blue-500">Manage images</summary>
      <div class="mt-3">
        GALLERY
      </div>
    </details>
  <% end %>
<% end %>
</div>
```

Then replace the literal word `GALLERY` with the preserved gallery block. Do not edit anything inside that block.

- [ ] **Step 5: Run the spec**

Run: `bundle exec rspec spec/components/products/images_component_spec.rb --format progress`
Expected: 10 examples, 0 failures

- [ ] **Step 6: Run the images request spec, which exercises the same attachments**

Run: `bundle exec rspec spec/requests/product_images_spec.rb --format progress`
Expected: 0 failures

- [ ] **Step 7: Rubocop and commit**

```bash
bundle exec rubocop app/components/products/images_component.rb spec/components/products/images_component_spec.rb
git add app/components/products/images_component.rb app/components/products/images_component.html.erb spec/components/products/images_component_spec.rb
git commit -m "feat(products): collapse image card to thumbnail strip with gallery behind details

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 6: Labels card: chips only, picker in a modal

**Files:**
- Modify: `app/components/products/labels_component.html.erb`
- Test: `spec/components/products/labels_component_spec.rb`

**Interfaces:**
- Consumes: `Ui::ModalComponent` (`with_trigger`, `with_header`, `with_footer`), `Ui::CardComponent#with_action`, the `product-label-manager` Stimulus targets `searchInput`, `labelList`, `labelOption`, `emptyState`, `selectedContainer`, `emptyMessage`.
- Produces: nothing new for later tasks.

- [ ] **Step 1: Add the failing examples to the spec**

In `spec/components/products/labels_component_spec.rb`, add this block right after the `it "renders labels header"` example:

```ruby
  describe "layout" do
    before { label1 }

    it "wraps the whole card in the label manager controller" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-controller='product-label-manager'] [data-controller='modal']")
      expect(page).to have_css("[data-controller='product-label-manager'] [data-product-label-manager-target='selectedContainer']")
    end

    it "offers an Add trigger in the card header that opens the picker modal" do
      render_inline(described_class.new(product: product))

      expect(page).to have_css("[data-action='click->modal#open'] button", text: "Add")
      expect(page).to have_css("[data-controller='modal'] input[data-product-label-manager-target='searchInput']")
      expect(page).to have_css("[data-controller='modal'] [data-product-label-manager-target='labelList']")
    end

    it "does not render the picker outside the modal" do
      render_inline(described_class.new(product: product))

      expect(page).not_to have_text("Select Labels")
      expect(page).not_to have_text("Selected Labels")
    end
  end
```

- [ ] **Step 2: Run the spec to verify the new examples fail**

Run: `bundle exec rspec spec/components/products/labels_component_spec.rb --format progress`
Expected: the three `layout` examples fail; all others pass.

- [ ] **Step 3: Rewrite `app/components/products/labels_component.html.erb`**

Replace the whole file with:

```erb
<div data-controller="product-label-manager" data-product-label-manager-product-id-value="<%= product.id %>">
  <%= render Ui::CardComponent.new(padding: :sm) do |card| %>
    <% card.with_header do %>
      <h3 class="text-base font-semibold leading-6 text-gray-900">Labels</h3>
    <% end %>
    <% card.with_action do %>
      <%= render Ui::ModalComponent.new(size: :md, modal_id: "add-label-modal-#{product.id}") do |modal| %>
        <% modal.with_trigger do %>
          <%= render Ui::ButtonComponent.new(variant: :secondary, size: :sm) do %>
            Add
          <% end %>
        <% end %>

        <% modal.with_header do %>
          Add labels
        <% end %>

        <p class="text-xs text-gray-600 mb-3">
          Click a label to add it to this product.
        </p>

        <div class="relative mb-3">
          <input
            type="text"
            id="label-search-<%= product.id %>"
            placeholder="Search labels..."
            class="block w-full rounded-lg border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            data-product-label-manager-target="searchInput"
            data-action="input->product-label-manager#filterLabels"
            aria-label="Search for labels"
          >
          <div class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
            <svg class="h-5 w-5 text-gray-400" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
              <path fill-rule="evenodd" d="M9 3.5a5.5 5.5 0 100 11 5.5 5.5 0 000-11zM2 9a7 7 0 1112.452 4.391l3.328 3.329a.75.75 0 11-1.06 1.06l-3.329-3.328A7 7 0 012 9z" clip-rule="evenodd" />
            </svg>
          </div>
        </div>

        <div class="max-h-64 overflow-y-auto border border-gray-200 rounded-lg bg-gray-50 p-3" data-product-label-manager-target="labelList">
          <% if available_labels.any? %>
            <div class="space-y-1">
              <% available_labels.each do |label| %>
                <button
                  type="button"
                  class="w-full text-left px-3 py-2 rounded-md text-sm hover:bg-blue-50 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-blue-50 transition-colors"
                  data-label-id="<%= label.id %>"
                  data-label-name="<%= label.full_name %>"
                  data-label-code="<%= label.code %>"
                  data-label-color="<%= label.info&.dig('color') || '#6b7280' %>"
                  data-action="click->product-label-manager#addLabel"
                  data-product-label-manager-target="labelOption"
                  aria-label="Add label <%= label.full_name %>"
                >
                  <div class="flex items-center gap-2">
                    <span class="h-2 w-2 rounded-full flex-shrink-0" style="background-color: <%= label.info&.dig('color') || '#6b7280' %>" aria-hidden="true"></span>
                    <span class="text-gray-900"><%= label.full_name %></span>
                  </div>
                </button>
              <% end %>
            </div>
          <% else %>
            <p class="text-sm text-gray-500 text-center py-4">No labels available. Create labels first to categorize products.</p>
          <% end %>
        </div>

        <div class="hidden max-h-64 border border-gray-200 rounded-lg bg-gray-50 p-3" data-product-label-manager-target="emptyState">
          <p class="text-sm text-gray-500 text-center py-4">No labels found matching your search.</p>
        </div>

        <% modal.with_footer do %>
          <%= render Ui::ButtonComponent.new(variant: :secondary, data: { action: "click->modal#close" }) do %>
            Close
          <% end %>
        <% end %>
      <% end %>
    <% end %>

    <div class="flex flex-wrap gap-2 min-h-[1.75rem]" data-product-label-manager-target="selectedContainer" aria-label="Selected labels">
      <% if has_labels? %>
        <% product.labels.each do |label| %>
          <span class="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm bg-blue-100 text-blue-800 border border-blue-200" data-label-id="<%= label.id %>" data-label-name="<%= label.full_name %>" data-label-code="<%= label.code %>" data-label-color="<%= label.info&.dig('color') || '#2563eb' %>" role="listitem">
            <span class="h-2 w-2 rounded-full flex-shrink-0" style="background-color: <%= label.info&.dig('color') || '#2563eb' %>" aria-hidden="true"></span>
            <span class="font-medium"><%= label.full_name %></span>
            <button
              type="button"
              class="ml-1 inline-flex items-center justify-center h-4 w-4 rounded-full hover:bg-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-1 transition-colors"
              data-action="click->product-label-manager#removeLabel"
              data-label-id="<%= label.id %>"
              aria-label="Remove label <%= label.full_name %>"
            >
              <span class="sr-only">Remove label <%= label.full_name %></span>
              <svg class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor" aria-hidden="true">
                <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z" />
              </svg>
            </button>
          </span>
        <% end %>
      <% else %>
        <p class="text-sm text-gray-500 py-1" data-product-label-manager-target="emptyMessage">No labels selected. Use Add to attach one.</p>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Run the spec**

Run: `bundle exec rspec spec/components/products/labels_component_spec.rb --format progress`
Expected: 0 failures. The existing "displays no labels selected message" still matches because the text starts with "No labels selected".

- [ ] **Step 5: Run the labels request spec**

Run: `bundle exec rspec spec/requests/product_labels_spec.rb --format progress`
Expected: 0 failures

- [ ] **Step 6: Commit**

```bash
git add app/components/products/labels_component.html.erb spec/components/products/labels_component_spec.rb
git commit -m "feat(products): show label chips only, move picker into a modal

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 7: Compact Variants card for the sidebar

**Files:**
- Modify: `app/components/products/configurable_card_component.html.erb`
- Test: `spec/components/products/configurable_card_component_spec.rb` (new)

**Interfaces:**
- Consumes: existing private helpers in `Products::ConfigurableCardComponent`: `configurations`, `configurations_count`, `variants_count`, `has_configurations?`, `has_variants?`, `can_generate_variants?`, `possible_combinations`, `configuration_type_label`, `configuration_type_badge_variant`, plus `render?`. The Ruby class does not change.
- Produces: nothing new.

- [ ] **Step 1: Write the failing spec**

Create `spec/components/products/configurable_card_component_spec.rb`:

```ruby
# frozen_string_literal: true

require "rails_helper"

RSpec.describe Products::ConfigurableCardComponent, type: :component do
  let(:company) { create(:company) }

  it "does not render for sellable products" do
    product = create(:product, company: company)
    render_inline(described_class.new(product: product))

    expect(page).not_to have_text("Variants")
  end

  context "with a configurable product" do
    let(:product) { create(:product, :configurable_variant, company: company) }

    def add_variants(count)
      count.times { create(:product_configuration, superproduct: product, subproduct: create(:product, company: company)) }
    end

    it "renders a Variants header with the variant count and configuration type" do
      add_variants(2)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("h3", text: "Variants")
      expect(page).to have_css("span.rounded-full", text: "2")
      expect(page).to have_css("span.rounded-full", text: "Variant")
    end

    it "renders one line per configuration with its value chips" do
      create(:configuration, :size, product: product, position: 1)
      create(:configuration, :color, product: product, position: 2)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("dt", text: "Size")
      expect(page).to have_css("dt", text: "Color")
      expect(page).to have_css("dd span", text: "Small")
      expect(page).to have_css("dd span", text: "Red")
      expect(page).not_to have_css("div.bg-gray-50.rounded-lg.p-4")
    end

    it "shows the combinations hint when fewer variants exist than combinations" do
      create(:configuration, :size, product: product)
      render_inline(described_class.new(product: product.reload))

      expect(page).to have_text("Up to 3 combinations possible, 0 generated")
    end

    it "hides the hint when every combination exists" do
      create(:configuration, :size, product: product)
      add_variants(3)
      render_inline(described_class.new(product: product.reload))

      expect(page).not_to have_text("combinations possible")
    end

    it "links to manage variants and to configurations" do
      render_inline(described_class.new(product: product))

      expect(page).to have_link("Manage variants", href: "/products/#{product.id}/variants")
      expect(page).to have_link("Configurations", href: "/products/#{product.id}/configurations")
    end

    it "shows a one-line empty state without configurations" do
      render_inline(described_class.new(product: product))

      expect(page).to have_text("No configurations yet")
      expect(page).not_to have_css("dl")
    end
  end
end
```

- [ ] **Step 2: Run the spec to verify it fails**

Run: `bundle exec rspec spec/components/products/configurable_card_component_spec.rb --format progress`
Expected: FAIL on the "Variants" header, the hint copy, and the empty-state copy (the current card says "Configuration").

- [ ] **Step 3: Rewrite `app/components/products/configurable_card_component.html.erb`**

Replace the whole file with:

```erb
<%= render Ui::CardComponent.new(padding: :sm) do |card| %>
  <% card.with_header do %>
    <div class="flex items-center gap-2">
      <h3 class="text-base font-semibold leading-6 text-gray-900">Variants</h3>
      <%= render Ui::BadgeComponent.new(variant: :gray) do %>
        <%= variants_count %>
      <% end %>
      <%= render Ui::BadgeComponent.new(variant: configuration_type_badge_variant, size: :sm) do %>
        <%= configuration_type_label %>
      <% end %>
    </div>
  <% end %>

  <% if has_configurations? %>
    <dl class="space-y-2">
      <% configurations.each do |config| %>
        <div class="flex items-start gap-x-2">
          <dt class="w-14 shrink-0 truncate pt-0.5 text-xs font-medium text-gray-500" title="<%= config.code %>"><%= config.name %></dt>
          <dd class="flex flex-wrap gap-1">
            <% config.configuration_values.order(:position).each do |value| %>
              <span class="inline-flex items-center rounded bg-blue-100 px-1.5 py-0.5 text-xs font-medium text-blue-800"><%= value.value %></span>
            <% end %>
            <% if config.configuration_values.empty? %>
              <span class="text-xs italic text-gray-400">No values defined</span>
            <% end %>
          </dd>
        </div>
      <% end %>
    </dl>

    <% if can_generate_variants? && variants_count < possible_combinations %>
      <p class="mt-3 text-xs text-blue-700">
        Up to <strong><%= possible_combinations %></strong> combinations possible, <%= variants_count %> generated.
      </p>
    <% end %>
  <% else %>
    <p class="text-sm text-gray-500">No configurations yet. Add dimensions such as Size or Color.</p>
  <% end %>

  <% card.with_footer do %>
    <div class="flex items-center justify-between text-sm font-medium">
      <%= link_to product_variants_path(product), class: "inline-flex items-center gap-1 text-blue-600 hover:text-blue-500" do %>
        Manage variants
        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
      <% end %>
      <%= link_to product_configurations_path(product), class: "inline-flex items-center gap-1 text-gray-600 hover:text-gray-900" do %>
        Configurations
        <svg class="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
      <% end %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 4: Run the spec**

Run: `bundle exec rspec spec/components/products/configurable_card_component_spec.rb --format progress`
Expected: 7 examples, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/components/products/configurable_card_component.html.erb spec/components/products/configurable_card_component_spec.rb
git commit -m "feat(products): compact Variants card for the sidebar

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 8: Sidebar tightening: inventory padding, three activity entries

**Files:**
- Modify: `app/components/products/inventory_summary_component.html.erb` (line 1)
- Modify: `app/components/products/activity_timeline_component.rb` (`limit(5)`)
- Modify: `app/components/products/activity_timeline_component.html.erb` (`pb-8`)
- Test: `spec/components/products/activity_timeline_component_spec.rb`

**Interfaces:** none new.

- [ ] **Step 1: Change the activity limit expectation**

In `spec/components/products/activity_timeline_component_spec.rb`, replace the `it "limits to 5 entries"` example with:

```ruby
    it "limits to 3 entries" do
      PaperTrail.request.whodunnit = "Jane Doe"
      5.times { |i| product.update!(name: "Name #{i}") }

      render_inline(described_class.new(product: product.reload))

      expect(page).to have_css("li", count: 3)
    end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bundle exec rspec spec/components/products/activity_timeline_component_spec.rb --format progress`
Expected: FAIL, 5 `li` elements found instead of 3

- [ ] **Step 3: Apply the three edits**

In `app/components/products/activity_timeline_component.rb`, change `versions = product.versions.order(id: :desc).limit(5)` to `versions = product.versions.order(id: :desc).limit(3)`.

In `app/components/products/activity_timeline_component.html.erb`, change `<div class="relative pb-8">` to `<div class="relative pb-4">`.

In `app/components/products/inventory_summary_component.html.erb`, change the first line `<%= render Ui::CardComponent.new do |card| %>` to `<%= render Ui::CardComponent.new(padding: :sm) do |card| %>`.

- [ ] **Step 4: Run both component specs**

Run: `bundle exec rspec spec/components/products/activity_timeline_component_spec.rb spec/components/products/inventory_summary_component_spec.rb --format progress`
Expected: 0 failures

- [ ] **Step 5: Rubocop and commit**

```bash
bundle exec rubocop app/components/products/activity_timeline_component.rb
git add app/components/products/inventory_summary_component.html.erb app/components/products/activity_timeline_component.rb app/components/products/activity_timeline_component.html.erb spec/components/products/activity_timeline_component_spec.rb
git commit -m "feat(products): tighten sidebar inventory and activity cards

Claude-Session: https://claude.ai/code/session_01XoJsncCVWCyAfgxYiDJmGc"
```

---

### Task 9: Full verification: suites, Tailwind rebuild, live page check

**Files:** none modified unless a check fails.

**Interfaces:** none.

- [ ] **Step 1: Run every spec that touches the product page**

Run:

```bash
bundle exec rspec spec/components spec/requests/products_spec.rb spec/requests/product_attribute_values_spec.rb spec/requests/product_catalogs_spec.rb spec/requests/catalog_item_attribute_values_spec.rb spec/requests/product_images_spec.rb spec/requests/product_labels_spec.rb --format progress
```

Expected: 0 failures. If anything fails, fix it in the task that owns the file and re-run before continuing.

- [ ] **Step 2: Run the accessibility system spec for the product pages**

Run: `bundle exec rspec spec/system/accessibility/page_accessibility_spec.rb --format progress`
Expected: 0 failures. If the environment has no browser driver and the file errors before any example runs, report that explicitly in the task summary rather than treating it as a pass.

- [ ] **Step 3: Rebuild Tailwind so the new utility classes exist**

Run: `bin/rails tailwindcss:build`
Expected: `app/assets/builds/tailwind.css` is rewritten with a fresh timestamp. Confirm the new classes compiled:

```bash
grep -c "line-clamp-2" app/assets/builds/tailwind.css
grep -c "w-44" app/assets/builds/tailwind.css
```

Expected: both counts greater than 0.

- [ ] **Step 4: Measure the live page in the Orca browser tab**

The dev server on port 3246 is already running. Reload product 206 and measure both tabs:

```bash
orca goto --url "http://localhost:3246/products/206#WEB-EUR" --json
orca wait --load networkidle --json
orca eval --expression "JSON.stringify({tab: location.hash, docH: document.documentElement.scrollHeight, vh: innerHeight})" --json
orca eval --expression "document.querySelector('[data-tab-id=product]').click(); JSON.stringify({tab: 'product', docH: document.documentElement.scrollHeight})" --json
```

Expected: `docH` at most 1000 for both tabs at the current 909px viewport. If a tab is taller, list the section heights with:

```bash
orca eval --expression "JSON.stringify(Array.from(document.querySelectorAll('main .grid > div > *, main .grid > div > turbo-frame > *')).map(el => ({h: el.offsetHeight, heading: (el.querySelector('h1,h2,h3,h4')||{}).textContent?.trim()?.slice(0,30)})))" --json
```

and shrink the offending block in its owning task.

- [ ] **Step 5: Exercise the interactive paths in Orca**

For each path below: `orca snapshot --json`, act on the refs, `orca snapshot --json` again, and take `orca screenshot --json` to confirm the visible result. Re-snapshot after every action that changes the page, because refs go stale.

1. Product tab: hover a row, click its pencil, change the value, save. The row re-renders with the new value. Repeat once on the same row. Expected: second save also re-renders (no stale value).
2. Catalog tab: open "Add Attribute Override", add one, then edit it inline and save. Expected: the panel re-renders and the European Webshop tab stays selected.
3. Labels: click Add, pick a label in the modal, close the modal. Expected: a chip appears; clicking its × removes it.
4. Images: click "Manage images". Expected: the full gallery appears below the strip. Click Upload. Expected: the file picker opens (cancel it).
5. Header: click Deactivate and confirm. Expected: the header re-renders with a green Activate button and a non-green status badge. Click Activate to restore.
6. Header: click More. Expected: Assets, Duplicate, Delete appear; Escape closes it.

- [ ] **Step 6: Capture before/after evidence**

```bash
cd /private/tmp/claude-501/-Users-sin-RubymineProjects-Ozz-Rails-8-Potlift8/212f9116-b4a8-47f6-9e5d-72b501982cfe/scratchpad
orca eval --expression "window.scrollTo(0,0);'ok'" --json
orca screenshot --json | python3 -c "import json,sys,base64; d=json.load(sys.stdin); open('after_top.png','wb').write(base64.b64decode(d['result']['data']))"
```

The before screenshots already exist in that directory as `slice_0.png` and `vp_*.png`.

- [ ] **Step 7: Final rubocop over everything touched and a clean tree check**

```bash
bundle exec rubocop app/components/products spec/components/products spec/requests/catalog_item_attribute_values_spec.rb
git status --short
```

Expected: rubocop reports no offenses; `git status` is clean (every task committed its own files).
