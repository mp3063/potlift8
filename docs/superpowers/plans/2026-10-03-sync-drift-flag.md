# Sync drift flag ("changed since last sync")

Goal: show, on the product page and the catalog items page, when a product in a
shop-connected catalog has changed since its last confirmed sync, and fix the
Sync Data Preview drawer so it compares against this product's own last sync.

Branch: `feat/sync-drift-flag` in Potlift8 and Shopify8.

## Shopify8 (done)

`GET /api/v1/sync_tasks` now filters on `origin_target_id` (the SKU for
`product_changed` tasks). Spec in `spec/requests/api/v1/sync_tasks_spec.rb`.

## Task 1 — record changes per catalog item

- Migration: `catalog_items.content_changed_at` (datetime, null).
- One entry point, `Catalog#queue_product_sync(product, timestamp = Time.current)`:
  stamps `content_changed_at = timestamp` on the (catalog, product) catalog item
  (`update_all`, no callbacks), then returns if the catalog is sync-paused or not
  shop-connected, otherwise enqueues `ProductSyncJob`. The stamp happens even when
  paused — that is the point.
- Route the edit-driven enqueue sites through it: `ChangePropagator#propagate_to_catalogs`,
  `AttributeValues` (concern, ~line 85), `CatalogItemAttributeValue` (~line 60),
  `ProductActivatedJob`, `ProductBatchSync` (check what it is first). Keep their
  existing logging where useful.
  Not the manual "Sync" button (`CatalogsController#sync_product`), `CatalogItem#sync_to_shop`
  (a new item is `never_synced` anyway) or `BatchProductSyncJob` (Sync All): these sync, they
  don't change content.
- `CatalogItem#out_of_date?`: `sync_synced? && content_changed_at.present? &&
  (last_synced_at.nil? || content_changed_at > last_synced_at)`, plus a matching scope.
- Known limit (document in a comment, don't solve): a confirmation that arrives after
  a later edit can set `last_synced_at` past that edit; the trailing sync job
  re-marks the item `pending`, so it is not hidden for long.

## Task 2 — show it

- `Catalog#sync_counts` `outdated:` uses the new scope instead of "synced more than
  1 hour ago"; `synced:` is synced and not out of date. Check every consumer of
  `sync_counts` / the `outdated` key / the `?sync_status=` filter and keep them
  consistent (label: "Changed since sync").
- The badge helper (`sync_status_badge_for` in `products_helper.rb`) shows the
  out-of-date state with a warning (yellow) badge; the catalog items sync cell uses it.
- Product page "Shopify Sync Preview" card (`app/views/products/show.html.erb` ~58-92):
  each row shows the same badge plus relative time of last sync and the error when
  failed. Avoid N+1 (the rows come from `@product.catalog_items.includes(:catalog)`).
- `CatalogsController#sync_product` turbo response: show a "Queued" (pending) badge
  instead of the green "Synced" label.
- If `SyncBroadcastable` can also update the product-page row with little code, do it;
  otherwise skip and say so.

## Task 3 — fix the Sync Data Preview drawer

- `CatalogsController#fetch_shopify_comparison` (~396-427): pass
  `shop_id: @catalog.shop_id` alongside `origin_target_id`, so "Last synced" and the
  diff are this product in this shop.
- `Products::SyncPreviewComponent`: the "Basic Product Info" diff reads
  `last_payload["product"]`, but the sent payload is flattened to the top level, so
  it never shows a badge. Compare against the right keys.
- Drawer header: if the catalog item is out of date, show the same "Changed since
  sync" badge.

## Done when

- Specs cover: stamping (including while paused), `out_of_date?`/scope, counts,
  badge rendering on both pages, the queued response, the drawer query params and
  the Basic Product Info diff.
- `bundle exec rspec` for touched areas passes; full suite has no new failures
  (coverage gate TEST-02 is known at 79.99%).
- Manual check in Orca on product 206 (`PRD_C8CF8A0E`, WEB-EUR).
