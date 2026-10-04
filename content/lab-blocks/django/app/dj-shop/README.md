# dj-shop (app block, Django 5.1)

A small e-commerce Django project that students debug. **Slot defaults are the correct code**; a fault block
replaces slots with the broken version. Faults are authored against the slot names below (`block.yaml` also carries a
description per slot).

Stack pins (the lab-debug image): Django 5.1.4, DRF 3.15.2, Celery 5.4, whitenoise 6.8.2, gunicorn 23, psycopg 3,
redis, requests, tenacity. No `dj-database-url`, no `pytz`.

## Layout

- `src/` scaffold: `config/` (settings split `base|dev|prod|test`, celery, urls), `core` (audit, counters, clock, money,
  timeutils, request context), `customers` (custom user, signup, session login, token auth, account close), `catalog`
  (categories, products, soft delete, search, top-products cache), templates, static, `tests/` (visible smoke tests),
  `scripts/bootstrap.sh` + `scripts/dev-env.sh`, `gunicorn.conf.py`, `.lab/services/{app,worker}.sh`.
- `history/<feature>/` overlays (one commit each, in this order): `inventory`, `cart`, `notifications`, `checkout`
  (orders + invoices + payments client), `subscriptions`, `reviews`, `reports`, `webhooks`, `catalog-import`, `account`.
  Only the scaffold and the first six features carry migrations, so a fault migration slot can never collide with a
  later feature migration (the fault commit lands between the last 2-4 features).
- `noise/<name>/` trivial commits (docs, css, requirements comment, script polish).
- `regression_tests/core/**` and `regression_tests/<feature>/**` (pytest + pytest-django, no conftest: each module does
  `from core.testing import *`, which also calls `django.setup()` so the hardened `python -I ... --noconftest` runner
  works). Tests marked `needs_postgres` skip on sqlite; everything else is DB-agnostic.
- `carriers/<name>/` ready-to-copy carrier feature files (NOT part of the workspace; copy them into a fault block and
  list them under `carrier.files`). Their tests live in `regression_tests/<carrier>/`.

Runtime contract: `.lab/services/app.sh` (dev server under debugpy with `--noreload`, or gunicorn when
`MF_SERVER=gunicorn`), `worker.sh` (Celery). Env knobs come from `.lab/env` (written by env blocks):
`DJANGO_SETTINGS_MODULE` (`config.settings.prod` = prod mode), `MF_SERVER`, `MF_COLLECTSTATIC`, `DB_CONN_MAX_AGE`.
`readiness_path` is `/healthz/` (no DB). `/readyz/` returns `{"status", "database": vendor}`.
Setup runs `scripts/bootstrap.sh` (migrate; a failing migrate is reported but does not abort, so migration faults are
gradable) and then the data block generator (which no-ops with a warning when the schema is missing).

Probe helpers: `GET /api/csrf/` returns `{"csrfToken"}` and sets the cookie (P `save`); seeded users have DRF tokens
`mf_tok_<localpart>` (`mf_tok_staff`, `mf_tok_alice`, ...) so P/Q/C probes send `Authorization: Token mf_tok_alice`.
Demo password of every seeded account: `shop-pass-1`. Lab webhook secret `whsec_mindforge_lab`, header
`X-Shop-Signature: sha256=<hmac_sha256(raw body)>`.

Last migration per app (default rendering): core 0001, customers 0001, catalog 0001, inventory 0001, cart 0001,
notifications 0001, orders 0003 (`0002_orderitem_line_total`, `0003_orderitem_line_total_required`), payments 0001,
subscriptions 0001, reviews 0001. A migration slot `migrations.<app>` inserts the next number.

## Slot catalog and DJ-* mapping

Types: R region, V value, M migration.

### Migrations / schema
| Slot | T | Scenario use |
|---|---|---|
| `migrations.<app>` (core, customers, catalog, inventory, cart, notifications, orders, payments, subscriptions, reviews) | M | MIG-1 (two leaves: slot + an explicit `files` sibling with the same parent), MIG-2 fix (AlterField), MIG-3 (add slug + backfill), MIG-4 (rename, `db_column`), MIG-5 (`AddIndex` vs `AddIndexConcurrently`, use orders), MIG-6 (RunPython without reverse), MIG-7 (squash via `files`), DATA-3 fix (dedupe + constraint), DATA-4 (AlterField to Float) |
| `catalog.product.name_max_length` | V python_int (120) | MIG-2 (model 255, migration still 120) |
| `orders.migration.indexes` + `orders.model.indexes` | R | PERF-5 (drop both: composite `(status, -created_at)` index) |
| `orders.migration.constraints` + `orders.model.constraints` | R | DATA-8 (DB CHECK on status; drop `refunded` from the CHECK) |
| `subscriptions.migration.constraints` + `subscriptions.model.constraints` | R | DATA-3 (drop both = duplicates possible) |

### Data model / ORM
| Slot | T | Scenario |
|---|---|---|
| `orders.model.customer_fk` | R | DATA-1 (`PROTECT` -> `CASCADE`), DATA-2 |
| `orders.model.handler_fk` | R | DATA-2 (swap the two `related_name`s; override both slots) |
| `orders.model.status_choices` | R | DATA-8 (drop `CANCELLED`; legacy rows from `seed.dirty` crash `status_label`, admin, API) |
| `orders.model.totals`, `orders.model.item_prices`, `catalog.model.price` | R | DATA-4 (FloatField money; add AlterField migrations) |
| `orders.pricing.line_total`, `orders.pricing.tax`, `core.money.quantize` | R | DATA-4 (float math, `round()`), off-by-a-cent totals |
| `settings.use_tz`, `settings.time_zone` | V | DATA-5 (`USE_TZ = False`) |
| `core.clock.now` | R | DATA-5 (naive `datetime.now()`) |
| `reports.daily.bucket` | R | DATA-5 (`TruncDate` without tz / `Cast(DateField)`); business tz is `America/New_York` |
| `reviews.signals.counters` + `reviews.model.lifecycle` | R | DATA-6 (counter kept in `save()`; the queryset delete `DELETE /api/reviews/purge/?customer=` bypasses it). Override both slots |
| `catalog.model.managers` | R | DATA-7 (put `all_objects` first so reverse managers like `category.products` include deleted rows) |

### Performance
| Slot | T | Scenario |
|---|---|---|
| `orders.views.list_queryset` | R | PERF-1 (drop `select_related/prefetch_related`; page `/orders/`) |
| `orders.api.queryset`, `orders.serializers.items_count` | R | PERF-2 (`obj.items.count()` per row) |
| `settings.rest_framework` | R | PERF-3 (remove `DEFAULT_PAGINATION_CLASS`) |
| `orders.api.staff_queryset` | R | PERF-3/5/7 (`/api/staff/orders/?status=`) |
| `reports.dashboard.recent` | R | PERF-4 (queryset with `.count()`/`.exists()`/iteration = 3 queries) |
| `reports.revenue.product_stats` | R | PERF-6 (two multi-valued annotations = cartesian join; `/api/reports/revenue/`) |
| `orders.admin.changelist` | R | PERF-7 (no `list_select_related`, full COUNT) |
| `catalog.api.queryset` | R | PERF-2 variant on products |

### Concurrency
| Slot | T | Scenario |
|---|---|---|
| `inventory.views.availability` | R | CONC-1 (sync ORM in the async view `/api/products/<id>/availability/`) |
| `inventory.services.reserve` | R | CONC-2 (read-modify-write; C probe on `POST /api/orders/`) |
| `customers.services.register` | R | CONC-3 (exists()-then-create; C probe on `POST /api/signup/`) |
| `core.context.storage` | R | CONC-4 (module global instead of ContextVar; header name via `core.context_processors`, audit actor) |
| `notifications.tasks.send_once` | R | CONC-5 (drop the EmailLog guard) |
| `orders.services.notify_enqueue` | R | CONC-6 (`.delay()` inside the atomic block instead of `on_commit`) |
| `inventory.services.transfer_locks` | R | CONC-7 (lock in argument order = deadlock) |
| `settings.database.connection`, `gunicorn.workers`, `gunicorn.threads` | R/V | CONC-8 |

### Service communication and caching
| Slot | T | Scenario |
|---|---|---|
| `payments.client.request` | R | SVC-1 (no `timeout`), SVC-2 (no `Idempotency-Key`) |
| `payments.client.retry` | R | SVC-2 (retry policy) |
| `payments.client.parse` | R | SVC-3 (`data.get("status", "declined")`; the stub with `contract_version=2` renames `status` -> `state`, `amount_cents` -> `amount`) |
| `webhooks.signature.verify` | R | SVC-4 (HMAC over re-serialised JSON, `==`) |
| `customers.cache.invalidate` | R | SVC-5 (wrong key) |
| `customers.views.summary_cache` | R | SVC-6 (`cache_page` without `Vary`; DRF token auth so no session Vary; `/api/me/summary/`) |
| `catalog.cache.top_products` | R | SVC-7 (no lock; recompute count in `core_counter` `catalog.top_products.recompute`) |
| `settings.cache` | R | cache backend |

### Config / deployment
| Slot | T | Scenario |
|---|---|---|
| `settings.middleware.static` | R | CFG-1 (drop whitenoise), together with `settings.static` (`STATIC_ROOT` / `STORAGES`) |
| `settings.database` | R | CFG-2 (sqlite fallback default) |
| `templates.product.assets` | R | CFG-3 (link to a file missing from the manifest; page `/products/<slug>/`, prod mode) |
| `core.timeutils.localize` | R | CFG-4 (`tz.localize()` pytz idiom; used by report day bounds) |
| `settings.middleware.auth` | R | CFG-5 (middleware order: context middleware before auth) |

### Auth / security
| Slot | T | Scenario |
|---|---|---|
| `orders.invoices.queryset`, `orders.views.invoice_lookup` | R | SEC-1 (IDOR on `/api/invoices/<id>/` and `/orders/invoices/<id>/`) |
| `settings.prod.proxy` | R | SEC-2 (`CSRF_TRUSTED_ORIGINS`, `SECURE_PROXY_SSL_HEADER`; use `/api/csrf/` + `/api/session/login/`) |
| `catalog.search.query` | R | SEC-3 (f-string in `raw()`; `/api/products/search/?q=`) |
| `reviews.api.permissions`, `reviews.permissions.object_check` | R | SEC-4 (`PATCH /api/reviews/<id>/` as another user) |
| `customers.views.session_login` | R | SEC-5 (manual session assignment without `cycle_key`) |

### Error handling / observability
| Slot | T | Scenario |
|---|---|---|
| `catalog.importer.row` | R | ERR-1 (bare `except: pass`; `manage.py import_products`, `POST /api/products/import/`) |
| `orders.services.place_order.atomic` | R | ERR-2 (drop `@transaction.atomic`) |
| `orders.services.shipped_callbacks` | R | ERR-3 (late-binding lambda in a loop; `bulk_ship`, admin action) |
| `orders.signals.order_saved` | R | ERR-4 (handler re-saves the instance) |

## Carriers (real features shipped in the fault commit; new files only)
Auto-discovered from `ext/` (each subpackage is a Django app; `ext/<name>/urls.py` is included automatically).
Reference files are in `carriers/<name>/`; tests are in `regression_tests/<name>/`.

| Carrier feature | Adds | Safe pairing |
|---|---|---|
| `order-export` | `GET /api/orders/export/` CSV of my orders | PERF, SEC, DATA-1/2, CFG, ERR |
| `product-feed` | `GET /feeds/products.json` public feed of live products | anything not touching `catalog.model.managers` |
| `stock-alerts` | `GET /api/staff/stock-alerts/` low-stock list | CONC, MIG, PERF |
| `order-timeline` | `GET /api/orders/<id>/timeline/` (owner only) | DATA (except status choices), MIG |
| `account-overview` | `GET /api/me/overview/` counts of orders/reviews/subscriptions | SVC, SEC (except session), CFG |
