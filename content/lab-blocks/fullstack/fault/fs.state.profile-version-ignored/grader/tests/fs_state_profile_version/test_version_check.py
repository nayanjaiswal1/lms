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


def save(client, name, version):
    return client.put("/api/profile", json={"name": name, "phone": "555-0100", "version": version})


def assert_conflict(response):
    assert response.status_code == 409, response.text
    assert response.json()["error"]["code"] == "version_conflict"


def test_a_second_save_with_the_same_version_conflicts_and_changes_nothing():
    client = signed_in()
    assert save(client, "Alice First", 1).status_code == 200
    assert_conflict(save(client, "Alice Stale", 1))
    profile = client.get("/api/profile").json()
    assert (profile["name"], profile["version"]) == ("Alice First", 2)


def test_a_version_that_is_several_saves_behind_conflicts():
    client = signed_in()
    assert save(client, "One", 1).json()["version"] == 2
    assert save(client, "Two", 2).json()["version"] == 3
    assert_conflict(save(client, "Stale", 2))
    assert_conflict(save(client, "Stale", 1))
    assert client.get("/api/profile").json()["name"] == "Two"


def test_a_version_from_the_future_conflicts():
    client = signed_in()
    assert_conflict(save(client, "Future", 5))
    assert client.get("/api/profile").json()["version"] == 1
