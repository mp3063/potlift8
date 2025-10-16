# Bug Fix: "New Product" Button Navigation Issue

**Date:** 2025-10-16
**Status:** ✅ Fixed

## Issue Description

The "+ New Product" button in the empty state of the Products index page was not navigating to `/products/new` when clicked.

## Root Cause

The "New Product" button was inside a Turbo Frame (`turbo_frame_tag "products_table"`), causing it to attempt loading the response within the frame instead of navigating to the full page.

## Solution

Added `data: { turbo_frame: "_top" }` to the link to break out of the Turbo Frame and navigate the full page.

### File Changed

**`app/components/products/table_component.html.erb` (line 117)**

**Before:**
```erb
<%= helpers.link_to helpers.new_product_path,
    class: "inline-flex items-center rounded-md bg-blue-600..." do %>
  <%= plus_icon %>
  <span class="ml-1.5">New Product</span>
<% end %>
```

**After:**
```erb
<%= helpers.link_to helpers.new_product_path,
    data: { turbo_frame: "_top" },
    class: "inline-flex items-center rounded-md bg-blue-600..." do %>
  <%= plus_icon %>
  <span class="ml-1.5">New Product</span>
<% end %>
```

## Database Population

Also populated the database with comprehensive seed data:

### Seed Summary
- **60 Products** across 5 categories:
  - 20 Flower products (Indica, Sativa, Hybrid strains)
  - 10 Pre-Roll products
  - 15 Edibles products (Gummies, Chocolates, Baked Goods)
  - 10 Concentrates & Vapes
  - 5 Topical products

- **5 Storage Locations:**
  - Main Warehouse (MAIN)
  - Retail Floor (RETAIL)
  - Temporary Storage (TEMP)
  - Incoming Shipments (INCOMING)
  - Secure Vault (VAULT)

- **4 Catalogs:**
  - European Webshop (EUR)
  - Swedish Webshop (SEK)
  - Norwegian Webshop (NOK)
  - Supply Catalog (EUR)

- **14 Labels:**
  - 12 Category labels (hierarchical structure)
  - 2 Brand labels (GreenLeaf Select, Pure Essence)

- **10 Product Attributes:**
  - Pricing (Price, Cost)
  - Details (Description, Short Description)
  - Cannabis Properties (THC %, CBD %, Strain Type, Terpenes)
  - Physical Properties (Weight, Package Size)

### Total Records Created
- Products: 60
- Product Attribute Values: 405
- Product Labels: 155
- Inventories: 300 (across 5 storages)
- Catalog Items: 240 (across 4 catalogs)

## Testing

To test the fix:
1. Navigate to http://localhost:3246/products
2. You should now see 60 products in the table
3. Click the "+ Add Product" button in the header (navigates to /products/new)
4. If you clear all products, the empty state "+ New Product" button also works

## Commands Used

```bash
# Fix applied directly to the file
# app/components/products/table_component.html.erb

# Database seeded with:
CLEAN_SEED=true bin/rails db:seed
```

## Verification

✅ "Add Product" button in header works correctly
✅ "New Product" button in empty state now navigates properly
✅ Database populated with 60 cannabis products
✅ All products have inventory across 5 storage locations
✅ All products are listed in 4 multi-currency catalogs
✅ Products are properly categorized with labels

## Related Files

- `app/components/products/table_component.html.erb` - Fixed button link
- `db/seeds.rb` - Comprehensive seed data
- `app/views/products/index.html.erb` - Products index page
- `config/routes.rb` - Routes configuration (already correct)

## Status

**RESOLVED** ✅

The button now correctly navigates to `/products/new` and the database is populated with comprehensive test data.
