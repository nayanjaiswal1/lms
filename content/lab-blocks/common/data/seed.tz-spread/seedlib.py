"""Shared seeding routines for the dj-shop data blocks (kept identical in every seed.* block).

Contract of the data blocks: ``python3 generate.py <params.json>`` with MF_SEED set (hex) and DATABASE_URL pointing at
the target PostgreSQL database. Output is a pure function of (seed, params): every "random" value comes from
hashtext() over row numbers mixed with the seed, never from random() or the clock (only the age of orders is
relative to now(), and orders are spread over whole days).
"""

import base64
import hashlib
import json
import os
import sys

import psycopg

TABLES = [
    "reviews_review", "payments_payment", "orders_invoice", "orders_orderitem", "orders_order",
    "subscriptions_subscription", "subscriptions_plan", "cart_cartitem", "cart_cart", "notifications_emaillog",
    "inventory_stocklevel", "inventory_warehouse", "catalog_product", "catalog_category", "authtoken_token",
    "core_auditentry", "core_counter", "customers_customer",
]  # fmt: skip
NAMED = ["alice", "bob", "carol", "dan", "erin", "frank"]
PASSWORD = "shop-pass-1"
PBKDF2_ITERATIONS = 870000
# Must match scripts/dev-env.sh: sessions are signed with the app's SECRET_KEY.
DEFAULT_SECRET_KEY = "dev-only-secret-key-not-for-production"
CATEGORIES = ["Kitchen", "Office", "Lighting", "Furniture", "Outdoor", "Storage", "Textiles", "Electronics"]


def log(message):
    print(f"[seed] {message}", file=sys.stderr, flush=True)


def read_params():
    with open(sys.argv[1], encoding="utf-8") as handle:
        return json.load(handle)


def seed_int():
    return int(os.environ.get("MF_SEED", "0") or "0", 16) % 2147483647


def connect():
    url = os.environ.get("DATABASE_URL", "")
    if not url.startswith(("postgres://", "postgresql://")):
        log("DATABASE_URL is not a PostgreSQL URL, nothing to seed")
        sys.exit(0)
    return psycopg.connect(url)


def schema_ready(conn):
    missing = [t for t in TABLES if not conn.execute("SELECT to_regclass(%s)", (f"public.{t}",)).fetchone()[0]]
    if missing:
        log(f"the shop schema is not fully migrated (missing {', '.join(missing[:3])}), skipping the data load")
        return False
    return True


def has_column(conn, table, column):
    """Faults may add columns to the shop tables; the seed fills the ones it can default."""
    row = conn.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = %s AND column_name = %s",
        (table, column),
    ).fetchone()
    return bool(row)


def password_hash():
    salt = hashlib.sha256(b"shop-demo-salt").hexdigest()[:22]
    digest = hashlib.pbkdf2_hmac("sha256", PASSWORD.encode(), salt.encode(), PBKDF2_ITERATIONS)
    return f"pbkdf2_sha256${PBKDF2_ITERATIONS}${salt}${base64.b64encode(digest).decode()}"


def seed_sessions(conn, count):
    """Ready-made login sessions (cookie ``sessionid=mf_sess_<name>``) for the first `count` customers, so probes
    can request login-protected pages. Signed exactly like Django does, with the SECRET_KEY the app runs with."""
    import django.conf

    if not django.conf.settings.configured:
        django.conf.settings.configure(SECRET_KEY=os.environ.get("DJANGO_SECRET_KEY") or DEFAULT_SECRET_KEY, USE_TZ=True)
    from django.contrib.sessions.backends.db import SessionStore
    from django.utils.crypto import salted_hmac

    key_salt = "django.contrib.auth.models.AbstractBaseUser.get_session_auth_hash"
    store = SessionStore()
    rows = conn.execute("SELECT id, email, password FROM customers_customer WHERE id <= %s ORDER BY id", (count,)).fetchall()
    for pk, email, password in rows:
        data = store.encode(
            {
                "_auth_user_id": str(pk),
                "_auth_user_backend": "django.contrib.auth.backends.ModelBackend",
                "_auth_user_hash": salted_hmac(key_salt, password, algorithm="sha256").hexdigest(),
            }
        )
        conn.execute(
            "INSERT INTO django_session (session_key, session_data, expire_date) VALUES (%s, %s, now() + interval '30 days')",
            ("mf_sess_" + email.split("@")[0], data),
        )


def reset(conn):
    existing = [t for t in TABLES if conn.execute("SELECT to_regclass(%s)", (f"public.{t}",)).fetchone()[0]]
    conn.execute("TRUNCATE " + ", ".join(existing) + " RESTART IDENTITY CASCADE")


def h(expr, salt, seed):
    """SQL expression: stable non-negative pseudo-random integer for a row expression."""
    return f"abs(hashtext(({expr})::text || ':{salt}:{seed}'))"


def load_base(conn, customers=30, products=60, orders=150, reviews=80, days=60, subscriptions=12):
    """Insert the whole shop dataset with set-based SQL. Ids are 1..n in each table."""
    seed = seed_int()
    pw = password_hash()
    named = ["staff"] + NAMED
    for i, local in enumerate(named):
        conn.execute(
            "INSERT INTO customers_customer (password, is_superuser, email, full_name, phone, is_active, is_staff, date_joined) "
            "VALUES (%s, %s, %s, %s, %s, true, %s, now() - interval '400 days')",
            (pw, local == "staff", f"{local}@shop.test", local.title(), None if i % 2 else f"+1-555-01{i:02d}", local == "staff"),
        )
    extra = max(0, customers - len(named))
    conn.execute(
        "INSERT INTO customers_customer (password, is_superuser, email, full_name, phone, is_active, is_staff, date_joined) "
        f"SELECT '{pw}', false, 'customer' || g || '@shop.test', 'Customer ' || g, "
        f"CASE WHEN {h('g', 'phone', seed)} % 3 = 0 THEN NULL ELSE '+1-555-' || lpad(({h('g', 'ph', seed)} % 10000)::text, 4, '0') END, "
        f"true, false, now() - ({h('g', 'joined', seed)} % 380 + 20) * interval '1 day' FROM generate_series(1, {extra}) g"
    )
    conn.execute(
        "INSERT INTO authtoken_token (key, created, user_id) SELECT 'mf_tok_' || split_part(email, '@', 1), now(), id "
        f"FROM customers_customer WHERE id <= {len(named)}"
    )
    seed_sessions(conn, len(named))
    for name in CATEGORIES:
        conn.execute("INSERT INTO catalog_category (name, slug) VALUES (%s, %s)", (name, name.lower()))
    conn.execute(
        "INSERT INTO catalog_product (sku, name, slug, subtitle, description, category_id, price, is_deleted, deleted_at, "
        "review_count, rating_total, created_at) "
        f"SELECT 'SKU-' || lpad(g::text, 6, '0'), 'Item ' || g || ' ' || (ARRAY['lamp','desk','chair','mug','shelf','rug','kettle','stool'])"
        f"[1 + {h('g', 'nm', seed)} % 8], 'item-' || g, 'Subtitle ' || g, 'Description of item ' || g, "
        f"1 + {h('g', 'cat', seed)} % {len(CATEGORIES)}, round((5 + {h('g', 'price', seed)} % 9500) / 100.0, 2), "
        f"false, NULL, 0, 0, now() - ({h('g', 'pc', seed)} % 300) * interval '1 day' FROM generate_series(1, {products}) g"
    )
    conn.execute("INSERT INTO inventory_warehouse (code, name) VALUES ('MAIN', 'Main warehouse'), ('EAST', 'East warehouse')")
    conn.execute(
        "INSERT INTO inventory_stocklevel (product_id, warehouse_id, on_hand) "
        f"SELECT p.id, w.id, CASE WHEN w.code = 'MAIN' THEN 20 + {h('p.id', 'stock', seed)} % 180 ELSE {h('p.id', 'east', seed)} % 40 END "
        "FROM catalog_product p CROSS JOIN inventory_warehouse w"
    )
    nc = max(customers, len(named)) - 1  # buyers exclude the staff account (id 1)
    # Items first (order ids are 1..orders because the tables were truncated with RESTART IDENTITY), so the
    # order totals can be written in the same statement that creates the orders.
    conn.execute(
        "CREATE TEMP TABLE mf_items ON COMMIT DROP AS "
        f"SELECT g AS order_id, 1 + {h('g * 10 + n', 'prod', seed)} % {products} AS product_id, "
        f"1 + {h('g * 10 + n', 'qty', seed)} % 3 AS qty "
        f"FROM generate_series(1, {orders}) g CROSS JOIN LATERAL generate_series(1, 1 + {h('g', 'nitems', seed)} % 3) n"
    )
    conn.execute(
        "CREATE TEMP TABLE mf_totals ON COMMIT DROP AS "
        "SELECT i.order_id, sum(p.price * i.qty) AS sub FROM mf_items i JOIN catalog_product p ON p.id = i.product_id GROUP BY i.order_id"
    )
    conn.execute(
        "INSERT INTO orders_order (public_id, customer_id, handled_by_id, status, subtotal, tax, total, currency, shipping_name, "
        "created_at, updated_at) "
        f"SELECT md5(g::text || ':{seed}')::uuid, 2 + {h('g', 'cust', seed)} % {nc}, "
        f"CASE WHEN {h('g', 'hb', seed)} % 4 = 0 THEN 1 ELSE NULL END, "
        f"(CASE WHEN r < 60 THEN 'paid' WHEN r < 75 THEN 'shipped' WHEN r < 88 THEN 'delivered' WHEN r < 95 THEN 'cancelled' ELSE 'refunded' END), "
        f"t.sub, round(t.sub * 0.0825, 2), t.sub + round(t.sub * 0.0825, 2), 'USD', 'Buyer ' || g, "
        f"now() - ({h('g', 'age', seed)} % {days}) * interval '1 day' - ({h('g', 'sec', seed)} % 86400) * interval '1 second', now() "
        f"FROM (SELECT g, {h('g', 'st', seed)} % 100 AS r FROM generate_series(1, {orders}) g) s JOIN mf_totals t ON t.order_id = s.g "
        "ORDER BY s.g"
    )
    conn.execute(
        "INSERT INTO orders_orderitem (order_id, product_id, quantity, unit_price, line_total) "
        "SELECT i.order_id, i.product_id, i.qty, p.price, p.price * i.qty FROM mf_items i "
        "JOIN catalog_product p ON p.id = i.product_id ORDER BY i.order_id"
    )
    conn.execute(
        "INSERT INTO orders_invoice (order_id, number, issued_at, total) "
        "SELECT id, 'INV-' || to_char(created_at, 'YYYY') || '-' || lpad(id::text, 8, '0'), created_at, total "
        "FROM orders_order WHERE status IN ('paid', 'shipped', 'delivered', 'refunded')"
    )
    conn.execute(
        "INSERT INTO payments_payment (order_id, provider_ref, status, amount, idempotency_key, created_at) "
        "SELECT id, 'ch_seed_' || id, CASE WHEN status = 'refunded' THEN 'refunded' ELSE 'succeeded' END, total, public_id, created_at "
        "FROM orders_order WHERE status <> 'cancelled'"
    )
    conn.execute(
        "INSERT INTO subscriptions_plan (code, name, monthly_price) VALUES ('basic', 'Basic', 5.00), ('plus', 'Plus', 12.00), ('pro', 'Pro', 29.00)"
    )
    conn.execute(
        "INSERT INTO subscriptions_subscription (customer_id, plan_id, status, started_at, canceled_at) "
        f"SELECT 2 + (g - 1) % {nc}, 1 + (g - 1) / {nc} % 3, CASE WHEN g % 5 = 0 THEN 'canceled' ELSE 'active' END, "
        f"now() - (g * 3) * interval '1 day', CASE WHEN g % 5 = 0 THEN now() - g * interval '1 day' ELSE NULL END "
        f"FROM generate_series(1, {subscriptions}) g"
    )
    slug_col = ", slug" if has_column(conn, "reviews_review", "slug") else ""
    slug_val = ", 'review-' || g" if slug_col else ""
    conn.execute(
        f"INSERT INTO reviews_review (product_id, customer_id, rating, title, body, is_approved, created_at{slug_col}) "
        f"SELECT 1 + ((g - 1) / {nc} + ((g - 1) % {nc}) * 13) % {products}, 2 + (g - 1) % {nc}, 1 + {h('g', 'rate', seed)} % 5, "
        f"CASE WHEN g % 4 = 0 THEN NULL ELSE 'Review ' || g END, 'Review text ' || g, true, now() - (g % 200) * interval '1 day'{slug_val} "
        f"FROM generate_series(1, {reviews}) g"
    )
    conn.execute(
        "UPDATE catalog_product p SET review_count = s.n, rating_total = s.t FROM "
        "(SELECT product_id, count(*) n, sum(rating) t FROM reviews_review WHERE is_approved GROUP BY product_id) s WHERE s.product_id = p.id"
    )
    conn.execute("ANALYZE")
    log(f"loaded {customers} customers, {products} products, {orders} orders, {reviews} reviews")
    return {"customers": customers, "products": products, "orders": orders, "buyers": nc}


def relax(conn):
    """Bulk-load settings. Skipping the deferred foreign-key triggers (rows are consistent by construction)
    saves several seconds of checking at commit; it needs a superuser, so it is optional."""
    try:
        conn.execute("SET LOCAL session_replication_role = replica")
    except psycopg.errors.InsufficientPrivilege:
        conn.rollback()
        log("not a superuser: foreign keys are checked at commit (slower)")
    conn.execute("SET LOCAL synchronous_commit = off")


def run(loader):
    """Common entry point: read params, connect, skip when unmigrated, reset, load in one transaction."""
    params = read_params().get("params", {})
    with connect() as conn:
        if not schema_ready(conn):
            return
        relax(conn)
        reset(conn)
        loader(conn, params)
        conn.commit()
