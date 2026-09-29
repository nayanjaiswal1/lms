# Shop

A small e-commerce backend: catalog, carts, orders with invoices, a payments provider client, subscriptions,
reviews, revenue reports and a Celery worker for email. Django 5.1, Django REST framework, PostgreSQL, Redis.

## Working on it

```bash
. scripts/dev-env.sh            # DATABASE_URL, secrets and service URLs for this sandbox
python3 manage.py migrate
python3 manage.py runserver     # the lab already runs the app for you on :8000
python3 -m pytest               # tests live in tests/
tail -f /var/log/mindforge-lab/app.log
```

Seeded demo accounts use the password `shop-pass-1` (for example `alice@shop.test`; staff is `staff@shop.test`).
The admin is at `/admin/`, the API under `/api/`.

## Layout

- `config/` settings (`base`, `dev`, `prod`, `test`), URLs, Celery
- `core/` shared helpers: money, clock, audit trail, request context
- one Django app per domain: `customers`, `catalog`, `inventory`, `cart`, `orders`, `payments`, ...
