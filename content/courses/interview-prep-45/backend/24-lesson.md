---
kind: lesson
id_key: interview-prep-45/day-24-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "API Security"
position: 24
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

Today covers how APIs authenticate and authorize requests: JWTs, OAuth, API keys, rate limiting, and CSRF. This is the single most-asked backend topic in interviews. Every company wants to know you can reason about "how does the server know who you are, and how do you stop abuse." Expect at least one system-design question and one "explain the difference between X and Y" question on this exact material.

## JWT, OAuth, and API keys: what each one is for

These three solve different problems. Interviewers probe whether you know which to reach for.

**JWT (JSON Web Token)**: a signed, self-contained token proving a claim ("this is user 42, expires at time T") without a DB lookup. Three base64 parts separated by dots: `header.payload.signature`.

```python
import jwt  # PyJWT
import datetime

SECRET = "use-an-env-var-in-real-code"

payload = {
    "sub": "42",
    "exp": datetime.datetime.now(datetime.UTC) + datetime.timedelta(minutes=15),
    "iat": datetime.datetime.now(datetime.UTC),
}
token = jwt.encode(payload, SECRET, algorithm="HS256")

decoded = jwt.decode(token, SECRET, algorithms=["HS256"])  # raises on bad sig or expiry
```

The server never stores this token. Anyone with the secret (or the matching public key, for RS256) can verify it. That's the whole point, and also the whole risk: a leaked signing key or an unexpired stolen token cannot be revoked without extra machinery (see refresh rotation below).

**OAuth 2.0**: a delegation protocol, not an auth mechanism by itself. It lets a user grant a third-party app limited access to their resources on another service ("let this app read your Google Calendar") without handing over their password. The output of an OAuth flow is usually an access token (often a JWT) plus a refresh token. Authorization Code flow (with PKCE for public clients) is the one you should be able to draw on a whiteboard:

1. App redirects user to provider's `/authorize` with `client_id`, `redirect_uri`, `scope`, `state`.
2. User logs in and approves; provider redirects back with a one-time `code`.
3. App's backend exchanges `code` (+ `client_secret` or PKCE `code_verifier`) for an access token at `/token`.
4. App calls the resource API with the access token.

**API keys**: a static, long-lived secret identifying a *client* (a service or app), not a *user*. No expiry, no claims, just "is this string in my allowed set." Good for server-to-server and third-party integrations; bad for representing a logged-in human because they can't carry identity claims or expire gracefully.

| | Identifies | Expires | Carries claims | Typical use |
|---|---|---|---|---|
| JWT | User (usually) | Yes, short-lived | Yes | API auth after login |
| OAuth token | User (delegated) | Yes | Yes (scopes) | Third-party access |
| API key | Client/service | No (until rotated) | No | Server-to-server |

## Implementing JWT authentication (FastAPI)

Full login + protected-route flow, the shape you'd write in an interview or take-home.

```python
from datetime import datetime, timedelta, UTC
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from passlib.context import CryptContext
import jwt

SECRET_KEY = "read-from-env"  # os.environ["JWT_SECRET"] in real code
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15

app = FastAPI()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Stand-in for a DB lookup
FAKE_USERS = {
    "alice": {"username": "alice", "hashed_password": pwd_context.hash("secret123")}
}


def create_access_token(subject: str, expires_delta: timedelta) -> str:
    to_encode = {
        "sub": subject,
        "exp": datetime.now(UTC) + expires_delta,
        "iat": datetime.now(UTC),
    }
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    user = FAKE_USERS.get(form_data.username)
    if not user or not pwd_context.verify(form_data.password, user["hashed_password"]):
        raise HTTPException(status_code=401, detail="Incorrect username or password")
    token = create_access_token(
        user["username"], timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    )
    return {"access_token": token, "token_type": "bearer"}


def get_current_user(token: str = Depends(oauth2_scheme)) -> str:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
    if username not in FAKE_USERS:
        raise HTTPException(status_code=401, detail="User not found")
    return username


@app.get("/me")
def read_current_user(username: str = Depends(get_current_user)):
    return {"username": username}
```

Key details interviewers check:
- **Passwords are hashed with bcrypt** (via passlib), never stored or compared as plaintext.
- **Expiry is enforced server-side** via `exp`; `jwt.decode` raises automatically on an expired token.
- **The secret never leaves the server.** If it's an asymmetric scheme (RS256), only the private key signs; the public key can be handed to other services to verify without granting them the ability to mint tokens.

## Rate limiting decorator

Rate limiting protects against brute force, scraping, and runaway clients. Token bucket and sliding window are the two algorithms interviewers expect you to name. Below is a Redis-backed fixed-window limiter as a decorator: the standard building block, which you'd extend with sliding-window logic for stricter needs.

```python
import time
import functools
from fastapi import Request, HTTPException
import redis

r = redis.Redis(host="localhost", port=6379, decode_responses=True)


def rate_limit(max_requests: int, window_seconds: int):
    def decorator(func):
        @functools.wraps(func)
        async def wrapper(request: Request, *args, **kwargs):
            client_id = request.client.host  # or the authenticated user id
            key = f"rl:{func.__name__}:{client_id}:{int(time.time()) // window_seconds}"

            # INCR is atomic; first caller in the window sets the expiry
            count = r.incr(key)
            if count == 1:
                r.expire(key, window_seconds)

            if count > max_requests:
                raise HTTPException(status_code=429, detail="Rate limit exceeded")

            return await func(request, *args, **kwargs)
        return wrapper
    return decorator


@app.post("/login")
@rate_limit(max_requests=5, window_seconds=60)
async def login_route(request: Request):
    ...
```

Why Redis and not an in-process dict: a dict is per-process memory, so with 4 gunicorn workers a client gets 4x the limit and it resets on every deploy. Redis is shared and survives restarts. `INCR` + `EXPIRE` is atomic enough for fixed windows, but fixed windows have a known edge-case flaw: a client can send `max_requests` right before the window boundary and `max_requests` right after, getting 2x burst at the edge. Sliding window log or sliding window counter fixes that at the cost of more Redis memory/CPU. Know the trade-off, don't over-engineer past what the interviewer asked.

## Refresh token rotation

Access tokens are short-lived (minutes) so a leaked one does limited damage. Refresh tokens are long-lived (days/weeks) and used only to mint new access tokens, but a long-lived token sitting in storage is itself a juicy target. Rotation means: every time a refresh token is used, invalidate it and issue a brand new one. If a stolen refresh token gets used by an attacker *and* later by the real user (or vice versa), the reuse of an already-rotated token is a detectable signal of compromise.

```python
import secrets
from datetime import datetime, timedelta, UTC

# refresh_tokens table: token_hash, user_id, expires_at, revoked, replaced_by

def issue_refresh_token(db, user_id: str) -> str:
    raw_token = secrets.token_urlsafe(32)
    token_hash = hash_token(raw_token)  # sha256, never store raw
    db.refresh_tokens.insert(
        token_hash=token_hash,
        user_id=user_id,
        expires_at=datetime.now(UTC) + timedelta(days=14),
        revoked=False,
    )
    return raw_token


def rotate_refresh_token(db, raw_token: str) -> dict:
    token_hash = hash_token(raw_token)
    record = db.refresh_tokens.get(token_hash=token_hash)

    if record is None or record.expires_at < datetime.now(UTC):
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    if record.revoked:
        # Reuse of a rotated-out token: someone has a copy of an old token.
        # Treat as compromise: revoke the whole chain for this user.
        db.refresh_tokens.revoke_all_for_user(record.user_id)
        raise HTTPException(status_code=401, detail="Token reuse detected, session revoked")

    # Rotate: revoke old, issue new, link them for audit
    new_raw = secrets.token_urlsafe(32)
    new_hash = hash_token(new_raw)
    db.refresh_tokens.insert(
        token_hash=new_hash,
        user_id=record.user_id,
        expires_at=datetime.now(UTC) + timedelta(days=14),
        revoked=False,
    )
    db.refresh_tokens.mark_revoked(token_hash=token_hash, replaced_by=new_hash)

    new_access = create_access_token(record.user_id, timedelta(minutes=15))
    return {"access_token": new_access, "refresh_token": new_raw}
```

Store only the **hash** of the refresh token (like a password). If the DB leaks, the tokens aren't directly reusable. This is the mechanism that makes JWTs (otherwise unrevokable) practically revocable: you can't kill a live access token, but you can kill its refresh chain so no new ones get minted.

## JWT vs session: the interview answer

| | Session (cookie + server store) | JWT |
|---|---|---|
| State | Server-side (Redis/DB) | Stateless, self-contained |
| Revocation | Instant: delete the session record | Hard: must wait for expiry or check a blocklist |
| Scaling | Needs shared session store across servers | Any server can verify independently |
| Payload size | Small (just a session ID) | Larger (claims travel with every request) |
| Typical use | Traditional web apps, same-origin | APIs, mobile, microservices, cross-domain |

The honest answer in an interview: "Sessions are simpler to revoke and reason about. JWTs scale better across services because verification doesn't need a shared store, at the cost of harder revocation, which is why refresh token rotation and short access-token TTLs exist." Don't claim one is unconditionally better.

## Preventing CSRF

CSRF (Cross-Site Request Forgery) exploits the browser auto-attaching cookies to any request, including ones triggered by a malicious third-party site. It only matters when you use **cookie-based** auth; a JWT sent manually in an `Authorization` header is not vulnerable to CSRF because a foreign page's form submission can't set that header.

Defenses, in order of strength:

1. **`SameSite=Lax` or `SameSite=Strict` cookies.** Blocks the cookie from being sent on cross-site requests. `Lax` still allows top-level navigation GETs; `Strict` blocks everything cross-site. This alone stops most CSRF today.
2. **CSRF token (synchronizer token pattern).** Server embeds a random token in the page/response; client must echo it back in a header or hidden form field on state-changing requests. The attacker's forged request can't know the token because same-origin policy blocks reading it.
3. **Check the `Origin`/`Referer` header** on state-changing requests as a secondary defense.

```python
from fastapi import Request, HTTPException
import secrets

def generate_csrf_token() -> str:
    return secrets.token_urlsafe(32)

def verify_csrf(request: Request, session_csrf_token: str):
    header_token = request.headers.get("X-CSRF-Token")
    if not header_token or not secrets.compare_digest(header_token, session_csrf_token):
        raise HTTPException(status_code=403, detail="CSRF token invalid")
```

Use `secrets.compare_digest` (constant-time) instead of `==` to avoid timing attacks on the comparison itself. It's a small detail, but interviewers notice when you skip it on anything security-adjacent.

JWT, OAuth, API keys, rate limiting, and CSRF defenses look like five separate topics, but they're really answers to two questions an interviewer keeps circling back to: how does the server know who's asking, and what stops that mechanism from being abused or stolen. Keeping that framing in mind is more useful under pressure than memorizing each section in isolation.
