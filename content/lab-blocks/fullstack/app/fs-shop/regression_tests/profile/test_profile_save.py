from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in(email="alice@shop.test"):
    client = TestClient(create_app())
    login = client.post("/api/auth/login", json={"email": email, "password": PASSWORD})
    session, csrf = login.cookies.get("session"), login.cookies.get("csrf_token")
    client.cookies.clear()
    client.headers.update({"Cookie": f"session={session}; csrf_token={csrf}", "X-CSRF-Token": csrf})
    return client


def test_profile_needs_a_session():
    assert TestClient(create_app()).get("/api/profile").status_code == 401


def test_profile_starts_at_version_one():
    assert signed_in().get("/api/profile").json() == {
        "name": "Alice Nguyen", "email": "alice@shop.test", "phone": "555-0100", "version": 1,
    }


def test_a_save_updates_the_profile_and_bumps_the_version():
    client = signed_in()
    saved = client.put("/api/profile", json={"name": " Alice N. ", "phone": "555-0199", "version": 1})
    assert saved.status_code == 200
    assert (saved.json()["name"], saved.json()["phone"], saved.json()["version"]) == ("Alice N.", "555-0199", 2)
    again = client.put("/api/profile", json={"name": "Alice Nguyen", "phone": "555-0199", "version": 2})
    assert again.json()["version"] == 3
    assert client.get("/api/profile").json()["name"] == "Alice Nguyen"


def test_invalid_changes_are_rejected():
    client = signed_in()
    assert client.put("/api/profile", json={"name": "", "phone": "1", "version": 1}).status_code == 422
    assert client.put("/api/profile", json={"name": "A", "phone": "1"}).status_code == 422


def test_saving_needs_a_csrf_token():
    client = signed_in()
    del client.headers["X-CSRF-Token"]
    assert client.put("/api/profile", json={"name": "A", "phone": "1", "version": 1}).status_code == 403
