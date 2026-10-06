"""Every API error carries {"error": {"code", "message"}}, the shape the console reads."""

from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def login(client, password=PASSWORD):
    return client.post("/api/auth/login", json={"email": "alice@shop.test", "password": password})


def test_a_rejected_login_has_the_error_envelope():
    response = login(TestClient(create_app()), password="nope")
    assert response.status_code == 401
    assert response.json() == {"error": {"code": "invalid_credentials", "message": "Wrong email or password."}}


def test_an_unauthenticated_request_has_the_error_envelope():
    response = TestClient(create_app()).get("/api/auth/me")
    assert response.status_code == 401
    body = response.json()
    assert "detail" not in body
    assert body["error"]["code"] == "not_authenticated"
    assert body["error"]["message"] == "Sign in to continue."


def test_a_version_conflict_has_the_error_envelope():
    client = TestClient(create_app())
    session = login(client).cookies
    headers = {"Cookie": f"session={session['session']}; csrf_token={session['csrf_token']}", "X-CSRF-Token": session["csrf_token"]}
    response = client.put("/api/profile", json={"name": "A", "phone": "1", "version": 99}, headers=headers)
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "version_conflict"
    assert response.json()["error"]["message"].startswith("The profile was changed elsewhere")
