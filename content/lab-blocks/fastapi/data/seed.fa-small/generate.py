"""seed.fa-small: a compact, readable dataset for the orders service (fa-orders).

Contract of the data blocks: ``python3 generate.py <params.json>`` with MF_SEED set (hex) and DATABASE_URL pointing at
the target PostgreSQL database. The output is a pure function of (seed, params) apart from the age of orders, which is
relative to now() in whole days. The generator is re-runnable (it truncates first), skips with a warning when the schema
is not migrated, and fills optional columns that a fault may have added (hs_code).
"""

import json
import os
import random
import sys
from datetime import datetime, timedelta, timezone

import bcrypt
import psycopg

NAMED = ["staff", "alice", "bob", "carol", "dan", "erin", "frank"]
PASSWORD = "shop-pass-1"
BCRYPT_ROUNDS = 12
CATEGORIES = ["kitchen", "office", "lighting", "furniture", "outdoor", "storage", "textiles", "electronics"]
HS_CODES = {
    "kitchen": "8215.99", "office": "9403.10", "lighting": "9405.21", "furniture": "9403.60",
    "outdoor": "9401.80", "storage": "3924.10", "textiles": "6302.60", "electronics": "8517.62",
}  # fmt: skip
ADJECTIVES = ["Compact", "Classic", "Modern", "Sturdy", "Slim", "Warm", "Bright", "Quiet", "Smart", "Nordic"]
NOUNS = ["lamp", "shelf", "desk", "chair", "kettle", "rug", "organizer", "speaker", "planter", "bin", "stool", "clock"]
FIRST = ["Ava", "Noah", "Mia", "Liam", "Zoe", "Ethan", "Ivy", "Owen", "Lena", "Kai", "Nora", "Leo"]
LAST = ["Archer", "Bishop", "Chen", "Duarte", "Evans", "Fischer", "Gupta", "Hughes", "Ito", "Jensen"]
TABLES = ["payments", "order_items", "orders", "wallet_transactions", "feature_flags", "products", "customers"]
FLAGS = {"new_checkout": True, "free_shipping_banner": False, "wallet_top_up": True, "loyalty_points": False}


def log(message):
    print(f"[seed] {message}", file=sys.stderr, flush=True)


def seed_int():
    return int(os.environ.get("MF_SEED", "0") or "0", 16) % 2147483647


def table_exists(conn, name):
    return conn.execute("SELECT to_regclass(%s)", (f"public.{name}",)).fetchone()[0] is not None


def has_column(conn, table, column):
    row = conn.execute(
        "SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = %s AND column_name = %s",
        (table, column),
    ).fetchone()
    return row is not None


def load(conn, params, rng):
    customers = int(params.get("customers", 30))
    products = int(params.get("products", 60))
    orders = int(params.get("orders", 150))
    present = [t for t in TABLES if table_exists(conn, t)]
    conn.execute("TRUNCATE " + ", ".join(present) + " RESTART IDENTITY CASCADE")

    pw = bcrypt.hashpw(PASSWORD.encode(), bcrypt.gensalt(BCRYPT_ROUNDS)).decode()
    rows = []
    for i in range(customers):
        if i < len(NAMED):
            name, display = NAMED[i], f"{NAMED[i].title()} {rng.choice(LAST)}"
            token, email = f"mf_tok_{name}", f"{name}@shop.test"
        else:
            name = f"customer{i + 1}"
            display, token, email = f"{rng.choice(FIRST)} {rng.choice(LAST)}", f"mf_tok_{name}", f"{name}@shop.test"
        phone = f"+1555{rng.randint(0, 9999999):07d}"
        company = f"{rng.choice(LAST)} {rng.choice(['Studio', 'Supply', 'Works', 'Group'])}"
        notes = None
        if name == "alice":
            display, phone, company = "Alice Archer", "+15550100", "Archer Studio"
        rows.append((email, display, phone, company, notes, "en-GB" if name == "alice" else "en", pw, token, name == "staff"))
    conn.cursor().executemany(
        "INSERT INTO customers (email, display_name, phone, company, notes, locale, password_hash, api_token, is_staff) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
        rows,
    )

    with_hs = has_column(conn, "products", "hs_code")
    prod_rows = []
    for i in range(products):
        category = CATEGORIES[i % len(CATEGORIES)]
        name = f"{rng.choice(ADJECTIVES)} {rng.choice(NOUNS)} {i + 1}"
        row = [f"SKU-{i + 1:05d}", name, category, rng.randint(5, 200) * 100 - 1, rng.randint(15, 300)]
        if with_hs:
            row.append(HS_CODES[category])
        prod_rows.append(tuple(row))
    cols = "sku, name, category, price_cents, stock" + (", hs_code" if with_hs else "")
    marks = ", ".join(["%s"] * (6 if with_hs else 5))
    conn.cursor().executemany(f"INSERT INTO products ({cols}) VALUES ({marks})", prod_rows)
    prices = {i + 1: prod_rows[i][3] for i in range(products)}

    if table_exists(conn, "orders"):
        load_orders(conn, rng, customers, products, orders, prices)
    if table_exists(conn, "wallet_transactions"):
        conn.execute("UPDATE customers SET credit_cents = 5000 WHERE email = 'alice@shop.test'")
        conn.execute(
            "INSERT INTO wallet_transactions (customer_id, delta_cents, reason, balance_after_cents) "
            "SELECT id, 5000, 'welcome credit', 5000 FROM customers WHERE email = 'alice@shop.test'"
        )
    if table_exists(conn, "feature_flags"):
        conn.cursor().executemany("INSERT INTO feature_flags (key, enabled) VALUES (%s, %s)", list(FLAGS.items()))
    log(f"loaded {customers} customers, {products} products, {orders if table_exists(conn, 'orders') else 0} orders")


def load_orders(conn, rng, customers, products, orders, prices):
    now = datetime.now(timezone.utc).replace(hour=12, minute=0, second=0, microsecond=0)
    statuses = ["paid"] * 14 + ["pending"] * 3 + ["refunded"]
    order_rows, item_rows, payment_rows = [], [], []
    for n in range(1, orders + 1):
        customer_id = rng.randint(1, customers)
        status = rng.choice(statuses)
        created = now - timedelta(days=rng.randint(0, 120), minutes=rng.randint(0, 600))
        lines = []
        for product_id in rng.sample(range(1, products + 1), rng.randint(1, 3)):
            lines.append((n, product_id, rng.randint(1, 4), prices[product_id]))
        total = sum(q * p for _, _, q, p in lines)
        order_rows.append((n, customer_id, status, total, "USD", f"Customer {customer_id}", created, created))
        item_rows.extend(lines)
        if status in ("paid", "refunded"):
            payment_rows.append((n, f"ch_{n:06d}", "succeeded", total, created))
    cur = conn.cursor()
    cur.executemany(
        "INSERT INTO orders (id, customer_id, status, total_cents, currency, shipping_name, created_at, updated_at) "
        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
        order_rows,
    )
    cur.executemany("INSERT INTO order_items (order_id, product_id, quantity, unit_price_cents) VALUES (%s, %s, %s, %s)", item_rows)
    if table_exists(conn, "payments"):
        cur.executemany(
            "INSERT INTO payments (order_id, provider_charge_id, status, amount_cents, created_at) VALUES (%s, %s, %s, %s, %s)",
            payment_rows,
        )
    conn.execute("SELECT setval(pg_get_serial_sequence('orders', 'id'), (SELECT max(id) FROM orders))")


def main():
    with open(sys.argv[1], encoding="utf-8") as handle:
        params = json.load(handle).get("params", {})
    url = os.environ.get("DATABASE_URL", "")
    if not url.startswith(("postgres://", "postgresql://")):
        log("DATABASE_URL is not a PostgreSQL URL, nothing to seed")
        return
    with psycopg.connect(url) as conn:
        if not (table_exists(conn, "customers") and table_exists(conn, "products")):
            log("the schema is not migrated (customers/products are missing), skipping the data load")
            return
        load(conn, params, random.Random(seed_int()))


if __name__ == "__main__":
    main()
