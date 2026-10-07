from app.testing import *  # noqa: F401,F403


def test_customs_export_lists_active_products_with_their_hs_codes(client, db):
    staff = make_staff(db)
    make_product(db, name="Desk lamp", sku="LMP-1", hs_code="9405.21")
    make_product(db, name="Retired", sku="OLD-1", hs_code="1111.11", is_active=False)
    body = client.get("/api/v1/staff/customs-export", headers=staff.headers).json()
    assert body == {"products": [{"sku": "LMP-1", "name": "Desk lamp", "hs_code": "9405.21"}]}


def test_customs_export_is_staff_only(client, db):
    customer = make_customer(db)
    assert client.get("/api/v1/staff/customs-export", headers=customer.headers).status_code == 403
    assert client.get("/api/v1/staff/customs-export").status_code == 401
