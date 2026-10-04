"""seed.dirty: the small dataset plus the mess a years-old production database accumulates.

NULLs in nullable text columns, duplicate names, legacy enum values (cancelled orders, past_due subscriptions),
duplicate active subscriptions (inserted with ON CONFLICT DO NOTHING, so they only appear when the schema does
not forbid them) and paid orders that never got an invoice.
"""

from seedlib import load_base, run


def load(conn, params):
    pct = int(params.get("dirty_percent", 20))
    info = load_base(conn, customers=params.get("customers", 60), products=params.get("products", 120), orders=params.get("orders", 400))
    conn.execute(f"UPDATE catalog_product SET subtitle = NULL WHERE id % 100 < {pct}")
    conn.execute(f"UPDATE catalog_product SET description = '' WHERE id % 100 >= {100 - pct // 2}")
    conn.execute(
        "UPDATE catalog_product p SET name = q.name FROM catalog_product q WHERE q.id = p.id - 1 AND p.id % 5 = 0 AND p.id % 100 < "
        f"{pct * 2}"
    )
    conn.execute(f"UPDATE customers_customer SET phone = NULL WHERE id > 7 AND id % 100 < {pct * 2}")
    conn.execute(f"UPDATE customers_customer SET full_name = 'Customer' WHERE id > 7 AND id % 100 < {pct}")
    conn.execute(f"UPDATE reviews_review SET title = NULL WHERE id % 100 < {pct * 2}")
    conn.execute(f"UPDATE orders_order SET status = 'cancelled' WHERE status = 'paid' AND id % 100 < {pct // 2}")
    conn.execute("DELETE FROM payments_payment WHERE order_id IN (SELECT id FROM orders_order WHERE status = 'cancelled')")
    conn.execute("DELETE FROM orders_invoice WHERE order_id IN (SELECT id FROM orders_order WHERE status = 'cancelled')")
    conn.execute(f"UPDATE subscriptions_subscription SET status = 'past_due' WHERE status = 'active' AND id % 7 = 0")
    conn.execute(
        "DELETE FROM orders_invoice WHERE order_id IN (SELECT id FROM orders_order WHERE status = 'paid' AND id % 10 = 0)"
    )
    conn.execute(
        "INSERT INTO subscriptions_subscription (customer_id, plan_id, status, started_at) "
        "SELECT customer_id, plan_id, 'active', started_at + interval '1 day' FROM subscriptions_subscription "
        "WHERE status = 'active' AND id % 2 = 0 ON CONFLICT DO NOTHING"
    )
    conn.execute("ANALYZE")


if __name__ == "__main__":
    run(load)
