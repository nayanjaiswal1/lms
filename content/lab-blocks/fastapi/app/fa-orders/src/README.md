# Orders

The orders service of a small online shop: catalog, orders, customer wallet credit, payments through an
external provider, feature flags and staff reports. FastAPI, async SQLAlchemy 2, Alembic, PostgreSQL.

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
