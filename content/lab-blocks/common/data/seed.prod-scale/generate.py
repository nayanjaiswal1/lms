"""seed.prod-scale: roughly `rows` rows across the shop tables, built with set-based SQL (a few seconds)."""

from seedlib import load_base, run


def load(conn, params):
    rows = int(params.get("rows", 500000))
    orders = int(rows * 0.2)
    load_base(
        conn,
        customers=min(50000, max(50, rows // 25)),
        products=min(20000, max(100, rows // 50)),
        orders=orders,
        reviews=int(rows * 0.05),
        days=int(params.get("days", 365)),
        subscriptions=min(5000, rows // 100),
    )


if __name__ == "__main__":
    run(load)
