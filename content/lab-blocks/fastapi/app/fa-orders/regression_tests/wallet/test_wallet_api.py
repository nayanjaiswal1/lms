from app.testing import *  # noqa: F401,F403


def test_credits_accumulate_and_are_recorded_in_the_ledger(client, db):
    customer = make_customer(db, credit_cents=100)
    first = client.post("/api/v1/wallet/credit", json={"amount_cents": 500, "reason": "promo"}, headers=customer.headers)
    second = client.post("/api/v1/wallet/credit", json={"amount_cents": 250}, headers=customer.headers)
    assert first.json() == {"balance_cents": 600}
    assert second.json() == {"balance_cents": 850}
    assert client.get("/api/v1/wallet", headers=customer.headers).json() == {"balance_cents": 850}
    ledger = client.get("/api/v1/wallet/transactions", headers=customer.headers).json()
    assert [(t["delta_cents"], t["reason"], t["balance_after_cents"]) for t in ledger] == [
        (250, "top-up", 850),
        (500, "promo", 600),
    ]


def test_each_customer_has_their_own_balance(client, db):
    amy = make_customer(db)
    ben = make_customer(db, credit_cents=40)
    client.post("/api/v1/wallet/credit", json={"amount_cents": 300}, headers=amy.headers)
    assert client.get("/api/v1/wallet", headers=amy.headers).json() == {"balance_cents": 300}
    assert client.get("/api/v1/wallet", headers=ben.headers).json() == {"balance_cents": 40}
    assert client.get("/api/v1/wallet/transactions", headers=ben.headers).json() == []


def test_credit_validation_and_authentication(client, db):
    customer = make_customer(db)
    assert client.post("/api/v1/wallet/credit", json={"amount_cents": 0}, headers=customer.headers).status_code == 422
    assert client.post("/api/v1/wallet/credit", json={"amount_cents": -5}, headers=customer.headers).status_code == 422
    assert client.post("/api/v1/wallet/credit", json={"amount_cents": 2_000_000}, headers=customer.headers).status_code == 422
    assert client.post("/api/v1/wallet/credit", json={"amount_cents": 100}).status_code == 401
    assert client.get("/api/v1/wallet").status_code == 401
