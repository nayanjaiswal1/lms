from core.testing import *  # noqa: F401,F403

pytestmark = pytest.mark.django_db


def test_healthz_does_not_need_database(client):
    assert client.get("/healthz/").json() == {"status": "ok"}


def test_readyz_reports_database(client):
    body = client.get("/readyz/").json()
    assert body["status"] == "ok" and body["database"] in ("postgresql", "sqlite")


def test_csrf_endpoint_sets_cookie(client):
    resp = client.get("/api/csrf/")
    assert resp.json()["csrfToken"]
    assert "csrftoken" in resp.cookies


def test_signup_creates_customer_and_rejects_duplicates(api_client):
    payload = {"email": "Ada@Shop.Test", "password": "pw-12345678", "full_name": "Ada"}
    first = api_client.post("/api/signup/", payload, format="json")
    assert first.status_code == 201
    assert first.json()["email"] == "ada@shop.test"
    assert api_client.post("/api/signup/", payload, format="json").status_code == 409


def test_signup_validates_password_length(api_client):
    resp = api_client.post("/api/signup/", {"email": "x@shop.test", "password": "short"}, format="json")
    assert resp.status_code == 400


def test_token_auth_and_me(api_client):
    make_customer("tok@shop.test", "pw-12345678")
    token = api_client.post("/api/auth/token/", {"username": "tok@shop.test", "password": "pw-12345678"}, format="json")
    assert token.status_code == 200
    api_client.credentials(HTTP_AUTHORIZATION=f"Token {token.json()['token']}")
    me = api_client.get("/api/me/")
    assert me.status_code == 200 and me.json()["email"] == "tok@shop.test"


def test_session_login_rotates_session_key(client):
    make_customer("sess@shop.test", "pw-12345678")
    session = client.session
    session["probe"] = 1
    session.save()
    before = client.session.session_key
    resp = client.post(
        "/api/session/login/", {"email": "sess@shop.test", "password": "pw-12345678"}, content_type="application/json"
    )
    assert resp.status_code == 200
    assert client.session.session_key != before


def test_session_login_rejects_bad_password(client):
    make_customer("sess2@shop.test", "pw-12345678")
    resp = client.post(
        "/api/session/login/", {"email": "sess2@shop.test", "password": "nope"}, content_type="application/json"
    )
    assert resp.status_code == 400


def test_me_patch_updates_profile():
    user = make_customer()
    client = authed(user)
    assert client.patch("/api/me/", {"full_name": "New Name"}, format="json").status_code == 200
    user.refresh_from_db()
    assert user.full_name == "New Name"


def test_close_account_anonymises_but_keeps_row():
    user = make_customer("bye@shop.test")
    assert authed(user).delete("/api/me/").status_code == 204
    user.refresh_from_db()
    assert not user.is_active and user.email.endswith("@deleted.invalid")


def test_request_context_exposes_customer_and_resets():
    from core import context

    user = make_customer()
    assert authed(user).get("/api/me/").status_code == 200
    assert context.get_current_customer() is None


def test_anonymous_cannot_read_me(api_client):
    assert api_client.get("/api/me/").status_code in (401, 403)
