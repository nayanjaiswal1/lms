"""seed.small: a compact, readable dataset (about 30 customers, 60 products, 150 orders)."""

from seedlib import load_base, run


def load(conn, params):
    load_base(
        conn,
        customers=params.get("customers", 30),
        products=params.get("products", 60),
        orders=params.get("orders", 150),
        reviews=params.get("reviews", 80),
    )


if __name__ == "__main__":
    run(load)
