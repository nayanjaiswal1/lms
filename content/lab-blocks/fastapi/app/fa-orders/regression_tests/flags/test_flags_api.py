from app.testing import *  # noqa: F401,F403


def test_staff_can_create_and_change_a_flag_and_readers_see_the_change_immediately(client, db):
    staff = make_staff(db)
    assert client.get("/api/v1/flags/new_checkout").status_code == 404
    created = client.put("/api/v1/staff/flags/new_checkout", json={"enabled": True}, headers=staff.headers)
    assert created.json() == {"key": "new_checkout", "enabled": True}
    assert client.get("/api/v1/flags/new_checkout").json() == {"key": "new_checkout", "enabled": True}
    client.put("/api/v1/staff/flags/new_checkout", json={"enabled": False}, headers=staff.headers)
    assert client.get("/api/v1/flags/new_checkout").json() == {"key": "new_checkout", "enabled": False}
    assert db.one("SELECT count(*) FROM feature_flags") == 1


def test_only_staff_can_write_flags(client, db):
    customer = make_customer(db)
    assert client.put("/api/v1/staff/flags/x", json={"enabled": True}).status_code == 401
    assert client.put("/api/v1/staff/flags/x", json={"enabled": True}, headers=customer.headers).status_code == 403
    assert db.one("SELECT count(*) FROM feature_flags") == 0


def test_flag_keys_are_length_limited(client, db):
    staff = make_staff(db)
    assert client.get("/api/v1/flags/" + "k" * 65).status_code == 422
    assert client.put("/api/v1/staff/flags/" + "k" * 64, json={"enabled": True}, headers=staff.headers).status_code == 200
