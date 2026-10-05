"""Cookie sessions with a double-submit CSRF token.

Login sets an HttpOnly session cookie and a script-readable `csrf_token` cookie. Every state-changing request must
echo the token in the X-CSRF-Token header, so a page on another site (which cannot read the cookie) cannot forge it.
"""

import hmac

from fastapi import APIRouter, Depends, Request, Response
from pydantic import BaseModel

from .deps import get_store
from .errors import ApiError
from .store import Store

SESSION_COOKIE = "session"
CSRF_COOKIE = "csrf_token"
CSRF_HEADER = "X-CSRF-Token"
SAFE_METHODS = {"GET", "HEAD", "OPTIONS"}

router = APIRouter(prefix="/auth", tags=["auth"])


class Credentials(BaseModel):
    email: str
    password: str


def public_user(user: dict) -> dict:
    return {"id": user["id"], "email": user["email"], "name": user["name"]}


def current_session(request: Request, store: Store = Depends(get_store)) -> dict:
    token = request.cookies.get(SESSION_COOKIE)
    session = store.sessions.get(token) if token else None
    if session is None:
        raise ApiError(401, "not_authenticated", "Sign in to continue.")
    return session


def current_user(session: dict = Depends(current_session), store: Store = Depends(get_store)) -> dict:
    return store.users[session["user_id"]]


def csrf_protect(request: Request, session: dict = Depends(current_session)) -> None:
    """Dependency for state-changing routes: the header and the cookie must both carry the session's token."""
    if request.method in SAFE_METHODS:
        return
    sent = request.headers.get(CSRF_HEADER, "")
    cookie = request.cookies.get(CSRF_COOKIE, "")
    expected = session["csrf"]
    if not (hmac.compare_digest(sent, expected) and hmac.compare_digest(cookie, expected)):
        raise ApiError(403, "csrf_failed", "The request could not be verified. Reload the page and try again.")


@router.post("/login")
def login(body: Credentials, response: Response, store: Store = Depends(get_store)) -> dict:
    user = store.authenticate(body.email, body.password)
    if user is None:
        raise ApiError(401, "invalid_credentials", "Wrong email or password.")
    token, csrf = store.open_session(user["id"])
    # mf:slot auth.cookie.attrs
    response.set_cookie(SESSION_COOKIE, token, httponly=True, samesite="lax", path="/")
    # mf:endslot
    # mf:slot auth.csrf.cookie
    response.set_cookie(CSRF_COOKIE, csrf, httponly=False, samesite="lax", path="/")
    # mf:endslot
    return {"user": public_user(user)}


@router.get("/me")
def me(user: dict = Depends(current_user)) -> dict:
    return {"user": public_user(user)}


@router.post("/logout", dependencies=[Depends(csrf_protect)])
def logout(request: Request, response: Response, store: Store = Depends(get_store)) -> dict:
    store.close_session(request.cookies.get(SESSION_COOKIE, ""))
    response.delete_cookie(SESSION_COOKIE, path="/")
    response.delete_cookie(CSRF_COOKIE, path="/")
    return {"ok": True}
