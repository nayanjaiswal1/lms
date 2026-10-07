# Orders

The orders service of a small online shop: catalog and search, orders with stock reservation, customer store credit
(wallet), payments through an external provider, feature flags, staff reports and payment webhooks.
FastAPI, async SQLAlchemy 2 (asyncpg), Alembic, PostgreSQL.

## Working on it

```bash
. scripts/dev-env.sh            # DATABASE_URL and service URLs for this sandbox
python3 -m alembic upgrade head # schema
python3 -m pytest               # tests live in tests/
tail -f /var/log/mindforge-lab/app.log
```

The lab already runs the API for you on :8000 (interactive docs at `/docs`). Seeded demo accounts use the
password `shop-pass-1` and the API token `mf_tok_<name>` (`alice`, `bob`, `carol`, `dan`, `erin`, `frank`, and
`staff` for the staff account). Send it as `Authorization: Bearer mf_tok_alice`.

## Layout

Every package under `app/` is a feature: `models.py` (picked up by Alembic), `router.py` (mounted automatically),
`service.py` (business logic) and, when it needs the application's lifespan, `lifecycle.py`. Small add-on endpoints
live in `app/ext/`. Migrations are in `alembic/versions/`.
