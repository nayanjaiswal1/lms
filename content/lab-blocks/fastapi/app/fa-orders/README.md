# fa-orders (app block, FastAPI)

A small orders service that students debug: catalog and search, orders with atomic stock reservation, a customer wallet, payments through an
external provider (the `stub.payments` block), feature flags, staff reports and signed webhooks. FastAPI 0.115, async SQLAlchemy 2 (asyncpg),
Alembic, pydantic 2, PostgreSQL. **Slot defaults are the correct code**; a fault block replaces slots (or whole files) with the broken version.
`block.yaml` carries a description per slot.

## Layout

- `src/` scaffold: `app/` (`config`, `db`, `registry`, `main`, `customers`, `catalog`, `testing`), `alembic/` (revision `a1c4e7f20b13`:
  customers and products), `scripts/{bootstrap,dev-env}.sh`, `.lab/services/app.sh` (uvicorn under debugpy), visible `tests/test_smoke.py`.
- `history/<feature>/` overlays, one commit each, in the order of `block.yaml`: `orders`, `wallet`, `payments`, `flags` (these four carry
  Alembic revisions `b72d90e5c418` -> `c35f18a9d6e2` -> `d8e0a4b71c59` -> `e4a6f27c0d81`), then `profile`, `search`, `stock`, `reports`,
  `webhooks`, `storefront` (no migrations). A fault commit lands after the last migration, so a fault revision can always name `e4a6f27c0d81` as its parent.
- `noise/<name>/` trivial commits (README, runbook, requirements grouping, `.gitignore`).
- `regression_tests/core/**` and `regression_tests/<feature>/**` (pytest, no conftest: every module does `from app.testing import *`, which
  gives `client`, `db`, `make_customer`, `make_product`, `make_order`, `fake_payments`, `scratch_database_url`, `alembic_cli`). A test asserting
  the behavior a fault breaks does not belong here: regression tests must pass on every broken baseline.
- `carriers/<name>/app/ext/<module>.py` ready-to-copy carrier features (not part of the workspace; a fault copies the file and lists it under
  `carrier.files`). Their tests live in `regression_tests/<carrier>/`. `app.registry` mounts every `app/ext/*.py` that exposes `router`.

## Runtime contract

`app.sh` runs `uvicorn app.main:app` on :8000 under debugpy (:5678), after sourcing `.lab/env` (env blocks export the payments stub faults).
`readiness_path` is `/healthz` (no database); `/readyz` checks the database. Setup runs `scripts/bootstrap.sh` (`alembic upgrade head`; a
failing upgrade is reported but does not abort, so migration faults stay gradable) and then the data block's generator.

## Probe helpers

Seeded accounts (`seed.fa-small`): `staff`, `alice`, `bob`, `carol`, `dan`, `erin`, `frank` at `<name>@shop.test`, password `shop-pass-1`,
token `mf_tok_<name>` sent as `Authorization: Bearer mf_tok_alice`. Every statement of the app goes through asyncpg, so `check.query-count`
counts them like any other client.

## Faults shipped for this app

| Fault | Category | Difficulty | Slot or files | Probes |
|---|---|---|---|---|
| `fa.mig.divergent-heads` | migrations | beginner | two revisions on the same parent (files) | M |
| `fa.mig.not-null-without-default` | migrations | intermediate | `catalog/models.py` + revision (files) | M |
| `fa.perf.order-list-n-plus-one` | performance | beginner | `orders.service.list_for_customer` | Q |
| `fa.async.bcrypt-blocks-event-loop` | async | intermediate | `customers.security.verify` | L, T |
| `fa.async.wallet-lost-update` | async | advanced | `wallet.service.apply_credit` | C, T |
| `fa.svc.payments-no-timeout` | service-calls | beginner | `payments.client.http_client` | P, T |
| `fa.err.payment-failure-returns-200` | errors | beginner | `payments.router.errors` | P, T |
| `fa.data.patch-wipes-fields` | data-model | intermediate | `profile.service.changes` | P, T |
| `fa.cfg.docs-ignore-root-path` | config | intermediate | `main.app.factory` | T |
| `fa.sec.order-idor` | auth | beginner | `orders.service.get_one` | P, T |
| `fa.async.blocking-call-in-async-handler` | async | intermediate | `search.router.synonyms` | L, T |
| `fa.perf.sequential-awaits` | performance | beginner | `storefront.service.compose` | L, T |
| `fa.perf.client-per-request` | performance | intermediate | `payments.client.send` | T |
| `fa.svc.retry-new-idempotency-key` | service-calls | advanced | `payments.client.headers` (chain 1/3) | T |
| `fa.async.session-leak-on-error` | async | advanced | `db.session.dependency` (chain 2/3, masks A) | T |
| `fa.cfg.flag-cache-stale` | config | advanced | `flags.service.lookup` (chain 3/3, masks B) | P, T |

Unused slots with a ready scenario in the spec: `flags.service.lookup` (stale `lru_cache`, FA-SVC-7), `payments.client.headers` (retry
without idempotency key, FA-SVC-2), `db.session.dependency` (session not closed on error, FA-ASYNC-4).
