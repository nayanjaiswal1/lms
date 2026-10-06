"""A state-changing request needs the session's token in the X-CSRF-Token header; reads do not."""

from fastapi.testclient import TestClient

from backend.app.main import create_app

PASSWORD = "correct-horse-battery"


def signed_in(csrf_header):
    client = TestClient(create_app())
    login = client.post("/api/auth/login", json={"email": "alice@shop.test", "password": PASSWORD})
    session, csrf = login.cookies.get("session"), login.cookies.get("csrf_token")
    client.cookies.clear()
    headers = {"Cookie": f"session={session}; csrf_token={csrf}"}
    if csrf_header is not None:
        headers["X-CSRF-Token"] = csrf if csrf_header == "valid" else csrf_header
    client.headers.update(headers)
    return client


def test_an_empty_token_header_is_rejected_with_csrf_failed():
    response = signed_in("").put("/api/profile", json={"name": "Alice N", "phone": "", "version": 1})
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "csrf_failed"


def test_reads_work_without_a_token_header():
    assert signed_in(None).get("/api/orders").status_code == 200


def test_the_session_token_in_the_header_is_accepted():
    assert signed_in("valid").post("/api/auth/logout").status_code == 200
