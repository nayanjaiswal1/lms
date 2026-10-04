# Shared lab blocks (Django debug labs)

Support blocks that compose with `django/app/dj-shop` (see its README for the slot catalog). This file is not a block.

## check.* (one per probe kind of `lab-images/lab-debug/grader/lib/probes`)

`params` mirror the probe parameters exactly (unknown keys are rejected by the engine, so a fault's `checks[].params` can only
use these names). The engine was extended so check blocks may declare `array`/`object` properties (probe configuration such as
`steps`, `explain`, `invariant`); every other kind is still scalar-only. The `failure_message` is the generic student-facing text of
the kind; probes never leak expected values.

| Block | Probe | Key params |
|---|---|---|
| `check.http-behavior` | P | `steps[]` `{method,path,headers,body,session,expect_status,expect_json[],save{}}` or the single-step keys |
| `check.query-count` | Q | `endpoint`/`request`, `scales[]`, `pre_sql[]`, `max_queries`, `max_growth`, `explain[]` |
| `check.concurrent-invariant` | C | `request`, `before_sql[]`, `count`, `workers`, `allowed_status[]`, `expect_successes{}`, `invariant{sql,equals|min|max}` |
| `check.migrate-from-snapshot` | M | `steps[]` `{db: clean|snapshot, snapshot_sql, cmd, expect_rc, post_sql[]}` |
| `check.latency-while` | L | `background{}`, `probe{path,samples,p95_ms_max}`, `start_delay_ms` |
| `check.http-contract` | H | `path`, `expect_status`, `expect_headers{}`, `forbid_headers{}`, `expect_cookies{}`, `json_schema{}` |
| `check.pytest-node` | T | `paths[]`, `args[]`, `timeout` |

Probe tips for dj-shop: users authenticate with `Authorization: Token mf_tok_<name>` (`staff`, `alice`, `bob`, `carol`, `dan`,
`erin`, `frank`); CSRF flows use `GET /api/csrf/` + `save`; `pg_stat_statements` counts include the payments stub's INSERT into
`mf_stub_payments_charge` on payment paths.

## seed.* (data blocks; `python3 generate.py <params.json>` with `MF_SEED` and `DATABASE_URL`)

All four ship an identical `seedlib.py` (set-based SQL, deterministic: values come from `hashtext(row || seed)`, never `random()`),
truncate the shop tables first (re-runnable), skip with a warning (exit 0) when the schema is not migrated, and use
`session_replication_role = replica` when the role is a superuser (saves the deferred FK check at commit).

| Block | Params | Result |
|---|---|---|
| `seed.small` | `customers` 30, `products` 60, `orders` 150, `reviews` 80 | readable dataset; demo accounts `staff|alice|bob|carol|dan|erin|frank@shop.test`, password `shop-pass-1`, tokens `mf_tok_<name>` |
| `seed.prod-scale` | `rows` 500000, `days` 365 | about 565k rows in the default (100k orders, 200k items, 93k invoices, 93k payments, 25k reviews); 17 s on a slow laptop |
| `seed.dirty` | `dirty_percent` 20, `customers`, `products`, `orders` | NULL subtitles/phones/titles, duplicate product names, legacy statuses (`cancelled`, `past_due`), paid orders without invoice, duplicate active subscriptions (only when the unique constraint is absent) |
| `seed.tz-spread` | `days` 14, `per_day` 12, `start_date` 2025-03-03 | paid orders between 22:00 and 01:59 America/New_York across the March 2025 DST change (`shipping_name = 'Night owl'`) |

## stub.payments (`.lab/services/payments-stub.sh`, port 9101)

Stdlib HTTP stub (psycopg is used when importable). `POST /v1/charges` with `Idempotency-Key` replay, `402` for references
containing `decline`. Fault API: `POST /__fault {latency_ms, error_rate, contract_version (1|2), error_mode (after|before)}`,
`GET /__fault`, `GET /__charges`, `POST /__reset`. Initial faults come from `PAYMENTS_STUB_LATENCY_MS`, `PAYMENTS_STUB_ERROR_RATE`,
`PAYMENTS_STUB_CONTRACT_VERSION`, `PAYMENTS_STUB_ERROR_MODE` (read from `.lab/env`). Probes reach the stub through SQL: every recorded
charge is mirrored into `mf_stub_payments_charge(idempotency_key, reference, amount_cents, created_at)`, so e.g.
`SELECT count(*) - count(DISTINCT reference) FROM mf_stub_payments_charge` must be 0 (P steps cannot reach the stub port, only the app).

## env.*

`env.prod-mode` (settings module `config.settings.prod`, gunicorn, collectstatic; DEBUG off, hashed static files via whitenoise),
plus static stub fault modes usable by faults: `env.payments-down` (30 s latency), `env.payments-flaky` (50 percent 500s after the charge
is recorded), `env.payments-contract-v2`.
