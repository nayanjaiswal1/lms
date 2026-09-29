"""seed.tz-spread: the small dataset plus paid orders clustered around local midnight.

For each of `days` business days starting at `start_date` (America/New_York), `per_day` orders are placed between
22:00 and 01:59 local time, so a report that buckets by UTC or by a naive date puts them on the wrong day. The
default window spans the March 2025 DST change. Every extra order has one item and totals 10.00 + 8.25% tax.
"""

from seedlib import load_base, run, seed_int

LOCAL_TZ = "America/New_York"


def load(conn, params):
    days = int(params.get("days", 14))
    per_day = int(params.get("per_day", 12))
    start = str(params.get("start_date", "2025-03-03"))
    info = load_base(conn, customers=30, products=60, orders=60)
    seed = seed_int()
    conn.execute(
        "INSERT INTO orders_order (public_id, customer_id, status, subtotal, tax, total, currency, shipping_name, created_at, updated_at) "
        f"SELECT md5('tz:' || d || ':' || n || ':{seed}')::uuid, 2 + (d * {per_day} + n) % {info['buyers']}, 'paid', 10.00, 0.83, 10.83, 'USD', "
        f"'Night owl', (date '{start}' + d + (CASE WHEN n % 2 = 0 THEN time '22:00' ELSE time '00:00' END) "
        f"+ (n * 7 % 120) * interval '1 minute') AT TIME ZONE '{LOCAL_TZ}', now() "
        f"FROM generate_series(0, {days - 1}) d CROSS JOIN generate_series(0, {per_day - 1}) n"
    )
    conn.execute(
        "INSERT INTO orders_orderitem (order_id, product_id, quantity, unit_price, line_total) "
        "SELECT id, 1, 1, 10.00, 10.00 FROM orders_order WHERE shipping_name = 'Night owl'"
    )
    conn.execute(
        "INSERT INTO orders_invoice (order_id, number, issued_at, total) "
        "SELECT id, 'INV-TZ-' || lpad(id::text, 8, '0'), created_at, total FROM orders_order WHERE shipping_name = 'Night owl'"
    )
    conn.execute(
        "INSERT INTO payments_payment (order_id, provider_ref, status, amount, idempotency_key, created_at) "
        "SELECT id, 'ch_tz_' || id, 'succeeded', total, public_id, created_at FROM orders_order WHERE shipping_name = 'Night owl'"
    )
    conn.execute("ANALYZE")


if __name__ == "__main__":
    run(load)
