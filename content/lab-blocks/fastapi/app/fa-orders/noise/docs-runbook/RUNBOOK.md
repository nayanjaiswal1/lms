# Runbook

## Restarting the API

`mf-svc restart-workspace` restarts the API and its stubs. Logs: `/var/log/mindforge-lab/app.log`.

## Database

- Schema changes go through Alembic: `python3 -m alembic revision --autogenerate -m "what changed"`, then **read the
  generated file** before committing it.
- Check the current state with `python3 -m alembic current` and `python3 -m alembic heads`.

## Payments provider

The provider is called through `app/payments/client.py`. Charges carry an idempotency key per order.
