# Open Issues — Sync & Cleanup Follow-ups (2026-09-29)

Issues discovered while executing `docs/superpowers/plans/2026-09-28-sync-and-cleanup-followups.md` (Tasks 1–5, 9 and the manual checks). None of these are fixed. Each one needs its own plan or a decision.

**Source** says how each issue was found:
- **verified live**: reproduced against the dev servers and the Shopify test shop.
- **code**: found by reading the code; not reproduced.
- **review**: raised by the final code review.

Paths are relative to `Ozz-Rails-8/`.

## Summary

| ID | Issue | App | Severity | Source |
|----|-------|-----|----------|--------|
| SYNC-01 | Status changes (disable, discontinue, delete) never sync to Shopify | Potlift8 | High | verified live |
| SYNC-02 | Adding a product to a catalog does not sync it | Potlift8 | High | verified live |
| SYNC-03 | Sync deduplication drops a second change instead of delaying it | Potlift8 | High | verified live |
| SYNC-04 | `ProductSyncJob` ignores a failed sync result; the item stays "pending" and is never retried | Potlift8 | High | code |
| UI-01 | Inline attribute edit: the row keeps the old value until the page is reloaded | Potlift8 | Medium | verified live |
| SYNC-05 | Shopify8 sends tasks without a shop to the company's first shop | Shopify8 | Medium | verified live |
| SYNC-06 | Deleting a whole catalog leaves its products in Shopify | Potlift8 | Medium (decision) | review |
| SYNC-07 | Removals made while a catalog's sync is paused are never replayed | Potlift8 | Low (decision) | review |
| SYNC-08 | An inactive item in another catalog keeps the product in that shop | Potlift8 | Low (decision) | review |
| SYNC-09 | Money metafield currency is wrong for non-EUR catalogs without overrides | Shopify8 | Low (future) | review |
| SYNC-10 | Money attributes without a metafield mapping are still sent as cents | Shopify8 | Low | review |
| SYNC-11 | The same shop with and without an API token counts as two shops | Potlift8 | Low | review |
| IMP-01 | Catalog import counts a failed price-override write as "skipped" | Potlift8 | Low | review |
| IMP-02 | Product import row numbers are wrong for CSVs with multi-line quoted fields | Potlift8 | Low | review |
| UI-02 | Every inline editor input has `id="value"` (duplicate ids) | Potlift8 | Low | verified live |
| CODE-01 | `Catalog#shop_connected?` duplicates `Catalog#shopify_connected?` | Potlift8 | Low | review |
| CODE-02 | `ProductDiscontinuedJob` is a TODO stub | Potlift8 | Low | code |
| CODE-03 | The imports page still mentions "catalog items" | Potlift8 | Low | review |
| TEST-01 | No test that a removal is sent when the product's other catalog uses a different shop | Potlift8 | Low | review |

Also in this document: [planned work that was decided but not started](#planned-work-decided-not-started) and [a tooling note](#tooling-note).

---

## High

### SYNC-01 — Status changes (disable, discontinue, delete) never sync to Shopify

**Where:** `Potlift8/app/models/concerns/product_state_machine.rb:9`

**Problem:** `aasm column: :product_status, enum: true, skip_validation_on_save: true`. With `skip_validation_on_save`, AASM saves the new state with `update_all`, which skips callbacks, so `ChangePropagator` never runs.

Only `activate!` reaches Shopify, and only because its `after:` hook queues `ProductActivatedJob`. `disable!`, `discontinue!`, `finish_discontinuation!` and `mark_as_deleted!` change the status in Potlift but send nothing.

**Evidence:**
- Clicking "Deactivate" on product 206 logged `Product Update All … SET "product_status" = 4` and queued no sync.
- Shopify stayed `ACTIVE` until a sync was forced by hand. The forced sync then showed the new status mapping works (disabled → DRAFT, discontinued → ARCHIVED).

**Impact:** the status mapping shipped in Shopify8 `4f5c2e5` only takes effect on the product's next unrelated edit. Discontinued products keep selling in Shopify.

**Suggested fix:**
1. Queue a sync after every committed transition, for example an `after_commit` on `saved_change_to_product_status?`. Since `update_all` skips that callback, this needs either persistence through `save` (drop `skip_validation_on_save`) or an explicit `ChangePropagator` call from an AASM `after_all_commits` hook.
2. Test every event, not just `activate!`.

### SYNC-02 — Adding a product to a catalog does not sync it

**Where:**
- `Potlift8/app/controllers/product_catalogs_controller.rb:39-45`
- `Potlift8/app/controllers/catalog_items_controller.rb:56-62`
- `Potlift8/app/models/catalog_item.rb` (it only has an `after_destroy_commit`)

**Problem:** creating a `CatalogItem` queues nothing. The product only reaches the shop on its next edit or a manual "Sync".

**Evidence:** product 206 was re-added to WEB-EUR at 21:54:28 on 2026-09-28. Shopify8 received no task until a sync was forced by hand.

**Impact:** a product added to a shop-connected catalog doesn't appear in Shopify. This mirrors the removal case fixed in `a978dde`.

**Suggested fix:** add an `after_create_commit` on `CatalogItem` that queues `ProductSyncJob` when the catalog is connected to a shop and not paused. Add request specs for both "add" endpoints.

### SYNC-03 — Sync deduplication drops a second change instead of delaying it

**Where:**
- `Potlift8/app/jobs/product_sync_job.rb:14-26` and `:122`
- `Potlift8/app/services/job_deduplicator.rb:26`
- `Potlift8/app/models/concerns/product_batch_sync.rb:23-29`

**Problem:** `JobDeduplicator#unique?` does a Redis `SET NX EX 30`. A second `ProductSyncJob` for the same product and catalog within 30 seconds is skipped ("Job executed recently"). Because the first job has already built its payload, the later change is never sent.

**Evidence:** price edits on product 206 at 21:45:33 and 21:45:52. The second (12,37 €) logged `Skipping duplicate sync …` and never reached Shopify.

**Impact:** fast consecutive edits lose the last one silently. This also made the catalog-override bug found in the final review intermittent.

**Suggested fix:** make the dedup trailing instead of leading. If a sync is already queued or recent, reschedule it for when the window ends (e.g. `set(wait: remaining)`) rather than dropping it. Alternatively keep a "dirty" flag and re-queue once the current job finishes.

### SYNC-04 — `ProductSyncJob` ignores a failed sync result

**Where:** `Potlift8/app/jobs/product_sync_job.rb:68-77`

**Problem:** `ProductSyncService#sync_to_external_system` catches its own errors (timeouts, connection failures, HTTP errors) and returns `failure_result`. `sync_product` never checks `result.success?`:
- It sets the catalog item to `sync_status: :pending, last_sync_error: nil`.
- It logs "Product sync completed".
- The job finishes normally, so ActiveJob never retries.

**Impact:** when Shopify8 is down or returns an error, the item stays "pending" forever, with no error shown and no retry.

**Suggested fix:** when `result.success?` is false, set the item to `:failed` with `last_sync_error` and raise, so retry/backoff applies. Add a spec with a stubbed failing service result.

---

## Medium

### UI-01 — Inline attribute edit: the row keeps the old value until the page is reloaded

**Where:**
- `Potlift8/app/views/products/_attribute_value.html.erb` (the row, `dom_id(attribute, :value)`)
- `Potlift8/app/controllers/product_attribute_values_controller.rb:27-39`
- The catalog override rows in the catalog tabs show the same behaviour.

**Problem:** after Save, all of the following happen correctly:
- the PATCH returns 200 as a turbo-stream;
- the DB is updated;
- the response's `replace` for `value_product_attribute_<id>` carries the new value, confirmed by fetching it from the page;
- Turbo fires `turbo:before-stream-render replace#value_product_attribute_<id>`, and the element is a new DOM node afterwards.

Yet the new node shows the value from page load: 12,35 was saved but the row showed 12,34, the value at page load. After a reload the value is correct.

**Ruled out:** the `inline-editor` Stimulus controller (it never touches content), duplicate element ids for the row, `data-turbo-permanent`, and the server response.

**Still to check:**
- `products/catalog_tabs/_product_attributes.html.erb` renders the partial in two places (`:9`, `:19`).
- `Products::AttributesComponent` wraps rows in `turbo_frame_tag dom_id(attribute, :value)`, the same id as the partial's div (`attributes_component.html.erb:26`). Not rendered on the show page today, but a trap.
- Turbo morph/refresh settings in the layout.
- The Turbo version.

**Also open:** the check with a real mouse click was never done. Orca clicks don't reach the page (see [tooling note](#tooling-note)).

**Suggested fix:** reproduce in a system spec (Capybara + Cuprite) so the bug has a failing test, then bisect.

### SYNC-05 — Shopify8 sends tasks without a shop to the company's first shop

**Where:** `Shopify8/app/models/sync_task.rb:81-91` (`current_shop`)

**Problem:** with no `shop_id` and no `load.shop.name`, `current_shop` falls back to `company.shops.first`.

**Evidence:** on 2026-03-11, 30 WEB-SEK/WEB-NOK/SUPPLY tasks were executed against the EUR test shop (mp3063). Potlift8 now only syncs catalogs connected to a shop (`3b98c1b`), and the final comparison showed no leftovers in the shop. The fallback itself is unchanged.

**Impact:** any other client, or a future Potlift8 regression, that sends no shop writes into the wrong store.

**Suggested fix:** reject (fail the task with a clear error) when the shop can't be resolved explicitly. Keep the fallback only if the company has exactly one shop, or drop it entirely.

### SYNC-06 — Deleting a whole catalog leaves its products in Shopify (decision needed)

**Where:**
- `Potlift8/app/models/catalog.rb:11` (`has_many :catalog_items, dependent: :destroy`)
- `Potlift8/app/models/catalog_item.rb:100` (`return if destroyed_by_association`)

**Problem:** item destroys caused by a catalog delete are skipped on purpose (so a product delete doesn't send a duplicate removal). So deleting a connected catalog sends no removals.

**Decision needed:** should deleting a catalog empty its shop, or keep the shop as it is? If the shop should be emptied, send removals from `Catalog` itself (e.g. collect SKUs `before_destroy` and queue `ProductRemovalJob` per SKU `after_destroy_commit`), respecting the shared-shop rule.

---

## Low

### SYNC-07 — Removals made while sync is paused are never replayed (decision needed)

**Where:**
- `Potlift8/app/models/catalog_item.rb:101`
- `Potlift8/app/controllers/catalogs_controller.rb:200` (`toggle_sync_pause`)

**Problem:** the plan required "paused → send nothing", but when sync is resumed, products removed during the pause stay in Shopify.

**Suggested fix:** on resume, compare catalog SKUs with the shop's products and remove the extras, or record pending removals while paused.

### SYNC-08 — An inactive item in another catalog keeps the product in that shop (decision needed)

**Where:** `Potlift8/app/models/catalog_item.rb:102`

**Problem:** the "does another catalog still feed this shop?" check counts catalog items in any state, including `inactive`. Inactive items are still synced today, so this is consistent for now.

**Decision needed:** should inactive catalog items be in the shop at all?

### SYNC-09 — Money metafield currency is wrong for non-EUR catalogs without overrides (future)

**Where:** `Shopify8/app/services/shopify/product_schema/build.rb:387-393`

**Problem:** for `money`-type metafields the currency is the catalog's `currency_code`. The attribute values are "effective" values, meaning catalog overrides (catalog currency) merged with product values (always EUR). A SEK catalog without an override would label a EUR amount as SEK.

**Impact:** none today, since only WEB-EUR is connected to a shop.

**Suggested fix:** have Potlift8 send each money value's own currency (override → catalog currency, product value → EUR) in the payload, and use that.

### SYNC-10 — Money attributes without a metafield mapping are still sent as cents

**Where:** `Shopify8/app/services/shopify/product_schema/build.rb:370` (the auto-map branch)

**Problem:** non-system attributes without a mapping are written to `custom.<code>` as raw values, ignoring the `money` flag. A user-created money attribute such as "rrp" would appear as `"4000"`. The system money attributes (price, special_price, purchase_price) are excluded, so nothing in dev is affected.

**Suggested fix:** apply `money_metafield_value` in that branch too.

### SYNC-11 — The same shop with and without an API token counts as two shops

**Where:**
- `Potlift8/app/models/catalog_item.rb:107` (`shop_key`)
- `Potlift8/app/models/concerns/change_propagator.rb` (`capture_removal_catalog_ids`)

**Problem:** the key is `[info["shopify_api_token"], info["shop_id"]]`. Two catalogs pointing at the same `shop_id`, one with a token and one without, are treated as different shops. That can cause a duplicate removal, or a removal while another catalog still feeds the shop.

**Suggested fix:** key on `shop_id` alone, unless tokens really can point at different Shopify8 instances.

### IMP-01 — Catalog import counts a failed price-override write as "skipped"

**Where:** `Potlift8/app/controllers/catalog_imports_controller.rb:148-153`

**Problem:** if `update_price_override` returns false, the row is counted as "skipped" with no reason. That happens when the price attribute doesn't allow catalog-level values, or when the save fails.

**Suggested fix:** count it as failed with an error message (`Row N: price override could not be saved: …`).

### IMP-02 — Product import row numbers are wrong for CSVs with multi-line quoted fields

**Where:** `Potlift8/app/services/product_import_service.rb:76-84`

**Problem:** row numbers are `index + 2`, i.e. data rows, not file lines. A quoted field with line breaks shifts every later row number. This predates the row-offset fix in `9e3e8f5`.

**Suggested fix:** use the parser's line numbers (`CSV#lineno`, or iterate with `CSV.new(...).each` and read `lineno`).

### UI-02 — Every inline editor input has `id="value"`

**Where:** `Potlift8/app/views/products/_attribute_value.html.erb:55-70` (`form.select :value` / `form.text_field :value` inside `form_with url:`)

**Problem:** every row's input gets `id="value"`, so the page has many duplicate ids. That is invalid HTML, and labels / `aria-*` references can point at the wrong field (the project targets WCAG 2.1 AA).

**Suggested fix:** pass `id: "#{dom_id(attribute, :value)}_input"`, and point the label's `for` at it.

### CODE-01 — `Catalog#shop_connected?` duplicates `Catalog#shopify_connected?`

**Where:** `Potlift8/app/models/catalog.rb:42` and `:195`

**Problem:** the same rule has two names. `shop_connected?` was added in `3b98c1b`, while views and controllers already use `shopify_connected?`.

**Suggested fix:** keep one (e.g. `shopify_connected?`) and replace the other everywhere, including specs and the `:shop_connected` factory trait name if desired.

### CODE-02 — `ProductDiscontinuedJob` is a TODO stub

**Where:** `Potlift8/app/jobs/product_discontinued_job.rb:9`

**Problem:** it only logs. The intended work is listed but not implemented: inventory policies, promotions, search indices, notifications, bundle/configurable impact. Related to SYNC-01.

### CODE-03 — The imports page still mentions "catalog items"

**Where:** `Potlift8/app/views/imports/index.html.erb:26`

**Problem:** the empty state says "import products or catalog items". The catalog-items import type was removed in `addf332`; catalog items are imported from the catalog page.

### TEST-01 — No test that a removal is sent when the product's other catalog uses a different shop

**Where:** `Potlift8/spec/models/catalog_item_spec.rb` ("removal from the shop on destroy")

**Problem:** the tests cover same shop → no removal, but not other catalog on a different shop → removal sent. That positive case is what proves the shop comparison works.

---

## Planned work (decided, not started)

- **Tasks 6–8 of the 2026-09-28 plan (deferred by the user):** drop `prices` + `customer_groups`, `company_states`, and `sync_locks` (+ `products.sync_lock_id`, `catalogs.sync_lock_id`). The steps are in the plan.
- **D3 decisions (2026-09-28), each needs its own plan:**
  - **`translations`:** build an editor. Sync reads translations (`product_sync_service.rb:85`), but nothing writes them.
  - **`related_products`:** link it in the UI (`Product has_many :related_products`, `product.rb:69`). It currently has no UI entry point.
  - **`company_memberships`:** keep it (multi-company users are planned). It is written on login and not read anywhere yet (`app/models/company_membership.rb`).

## Tooling note

On 2026-09-29, Orca's `click` and `exec "click …"` delivered no events to the Potlift8 page (a capture listener saw nothing), although the tab was visible and focused. In-page `element.click()` via `orca eval` worked. Browser checks must confirm each submit in `log/development.log`. UI-01's real-click check is still open because of this.
