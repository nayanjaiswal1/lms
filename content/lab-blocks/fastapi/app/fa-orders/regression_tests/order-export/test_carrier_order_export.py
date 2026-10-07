import csv
import io

from app.testing import *  # noqa: F401,F403


def test_export_lists_every_order_of_the_customer_as_csv(client, db):
    customer = make_customer(db)
    other = make_customer(db)
    product = make_product(db, price_cents=900)
    ids = [make_order(db, customer, lines=[(product, 1), (product, 2)]) for _ in range(6)]
    make_order(db, other, lines=[(product, 1)])
    response = client.get("/api/v1/exports/orders", headers=customer.headers)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/csv")
    rows = list(csv.reader(io.StringIO(response.text)))
    assert rows[0] == ["order_id", "status", "items", "total_cents", "created_at"]
    assert [int(r[0]) for r in rows[1:]] == sorted(ids, reverse=True)
    assert all(r[2] == "3" and r[3] == "2700" for r in rows[1:])


def test_export_needs_a_token(client):
    assert client.get("/api/v1/exports/orders").status_code == 401
