---
kind: lesson
id_key: jwt/jwt/code
course: jwt
section: jwt
section_title: JWT
section_position: 1
title: JWT code with FastAPI and PyJWT
position: 1
estimated_minutes: 15
source:
  - knowledge/backend/api/jwt_code.md
---

# JWT code

### 2.4 The biggest confusion: Base64URL is not encryption

```python
import base64, json
part = token.split(".")[1]
print(json.loads(base64.urlsafe_b64decode(part + "=" * (-len(part) % 4))))
```

### 15.1 Creating and verifying tokens

```python
import uuid
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import settings  # JWT_SECRET, JWT_ISSUER, JWT_AUDIENCE come from env

ALGORITHM = "HS256"
ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=7)
LEEWAY = timedelta(seconds=30)  # clock skew


def create_token(sub: str, token_type: str, ttl: timedelta, **extra) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "type": token_type,
        "iss": settings.JWT_ISSUER,
        "aud": settings.JWT_AUDIENCE,
        "iat": now,
        "exp": now + ttl,
        "jti": str(uuid.uuid4()),
        **extra,
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=ALGORITHM)


def decode_token(token: str, expected_type: str) -> dict:
    try:
        claims = jwt.decode(
            token,
            settings.JWT_SECRET,
            algorithms=[ALGORITHM],  # never take alg from the token
            audience=settings.JWT_AUDIENCE,
            issuer=settings.JWT_ISSUER,
            leeway=LEEWAY,
            options={"require": ["exp", "iat", "sub", "jti"]},
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    if claims.get("type") != expected_type:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Wrong token type")
    return claims


bearer = HTTPBearer()


def tokens_valid_after(user_id: str) -> int:
    # Redis mirror of users.tokens_valid_after (section 19.6); 0 = never revoked
    return int(redis.get(f"user:valid_after:{user_id}") or 0)


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> dict:
    claims = decode_token(creds.credentials, "access")
    if redis.exists(f"jwt:block:{claims['jti']}") or claims["iat"] < tokens_valid_after(claims["sub"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token revoked")
    return claims
```

### 15.2 Login, refresh (rotation + reuse detection), logout, revoke all sessions

```python
from fastapi import APIRouter, Cookie, Request, Response

router = APIRouter(prefix="/auth")
REFRESH_COOKIE = "__Host-refresh"
CSRF_HEADER, CSRF_VALUE = "X-Requested-With", "XMLHttpRequest"
GRACE = timedelta(seconds=15)  # parallel requests/tabs may still send the just-rotated token

# One atomic step: consume the token and open the grace window, or report reuse
ROTATE = redis.register_script("""
if redis.call('GETDEL', KEYS[1]) then
  redis.call('SET', KEYS[2], '1', 'EX', ARGV[1])
  return 1
end
return redis.call('EXISTS', KEYS[2])
""")


def issue_tokens(response: Response, user_id: str, family: str) -> dict:
    jti = str(uuid.uuid4())
    refresh = create_token(user_id, "refresh", REFRESH_TTL, jti=jti, fam=family)  # extra overrides the default jti
    redis.setex(f"rt:{jti}", REFRESH_TTL, family)  # "unused" refresh token
    refresh_repo.add(jti=jti, family_id=family, user_id=user_id)  # durable record (section 19.5); Redis is the fast path
    response.set_cookie(
        REFRESH_COOKIE, refresh, httponly=True, secure=True, samesite="strict",
        path="/", max_age=int(REFRESH_TTL.total_seconds()),
    )
    return {"access_token": create_token(user_id, "access", ACCESS_TTL), "token_type": "bearer"}


@router.post("/login")
def login(body: LoginIn, response: Response):
    user = authenticate(body.email, body.password)  # bcrypt/argon2 verify
    return issue_tokens(response, user.id, family=str(uuid.uuid4()))


@router.post("/refresh")
def refresh(request: Request, response: Response, token: str | None = Cookie(None, alias=REFRESH_COOKIE)):
    # A custom header forces a CORS preflight, so a cross-site form/fetch cannot send it (section 20.3)
    if request.headers.get(CSRF_HEADER) != CSRF_VALUE:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Missing CSRF header")
    if not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "No refresh token")
    claims = decode_token(token, "refresh")
    family = claims["fam"]
    # Password change / "log out everywhere" must kill refresh tokens too, not only access tokens
    if redis.exists(f"fam:revoked:{family}") or claims["iat"] < tokens_valid_after(claims["sub"]):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Session revoked")
    jti = claims["jti"]
    if not ROTATE(keys=[f"rt:{jti}", f"rt:grace:{jti}"], args=[int(GRACE.total_seconds())]):
        redis.setex(f"fam:revoked:{family}", REFRESH_TTL, "1")  # Reuse after the grace window = theft, revoke the whole family
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Refresh token reuse detected")
    return issue_tokens(response, claims["sub"], family)


def revoke_all_sessions(user_id: str) -> None:
    """Call on password change, 'log out of all devices', or account takeover."""
    now = int(datetime.now(timezone.utc).timestamp())
    users_repo.set_tokens_valid_after(user_id, now)  # DB is the source of truth
    redis.set(f"user:valid_after:{user_id}", now)     # fast path read by every request


optional_bearer = HTTPBearer(auto_error=False)


@router.post("/logout")
def logout(response: Response, creds: HTTPAuthorizationCredentials | None = Depends(optional_bearer),
           token: str | None = Cookie(None, alias=REFRESH_COOKIE)):
    # works even if the access token already expired; refresh cookie alone is enough
    now = int(datetime.now(timezone.utc).timestamp())
    for raw, kind in ((creds.credentials if creds else None, "access"), (token, "refresh")):
        if not raw:
            continue
        try:
            claims = decode_token(raw, kind)
        except HTTPException:
            continue  # expired/invalid: nothing left to revoke
        if kind == "access":
            redis.setex(f"jwt:block:{claims['jti']}", max(claims["exp"] - now, 1), "1")  # TTL = token's remaining lifetime
        else:
            redis.setex(f"fam:revoked:{claims['fam']}", REFRESH_TTL, "1")
    response.delete_cookie(REFRESH_COOKIE, path="/", secure=True, httponly=True, samesite="strict")  # attrs must match set_cookie, __Host- needs Secure
    return {"ok": True}
```

### 15.3 RS256 version (only what changes)

```python
private_key = settings.JWT_PRIVATE_KEY_PEM  # auth server only
public_key = settings.JWT_PUBLIC_KEY_PEM    # every service

jwt.encode(payload, private_key, algorithm="RS256", headers={"kid": settings.JWT_KID})
jwt.decode(token, public_key, algorithms=["RS256"], audience=..., issuer=...)

# Fetching the key from JWKS (in other services):
jwks_client = jwt.PyJWKClient(settings.JWKS_URL)  # caches internally
signing_key = jwks_client.get_signing_key_from_jwt(token)
jwt.decode(token, signing_key.key, algorithms=["RS256"], audience=..., issuer=...)
```

### 15.4 Frontend: Axios auto-refresh (single-flight, multi-tab safe)

```js
let accessToken = null;      // in memory, not localStorage
let refreshPromise = null;   // only one refresh at a time in this tab
const CSRF_HEADERS = { "X-Requested-With": "XMLHttpRequest" };
const authChannel = new BroadcastChannel("auth");

authChannel.onmessage = (e) => {
  if (e.data === "logout") { accessToken = null; redirectToLogin(); }   // logout in one tab = logout in all
};

function refreshAccessToken() {
  // Web Locks are shared across tabs: tabs take turns, and each one sends the latest cookie,
  // so two tabs never present the same refresh token (no false "reuse detected")
  return navigator.locks.request("auth-refresh", () =>
    api.post(REFRESH_URL, null, { withCredentials: true, headers: CSRF_HEADERS })
      .then((r) => (accessToken = r.data.access_token)));
}

async function logout() {
  await api.post(LOGOUT_URL, null, { withCredentials: true });
  accessToken = null;
  authChannel.postMessage("logout");
  redirectToLogin();
}

api.interceptors.request.use((config) => {
  if (accessToken) config.headers.Authorization = `Bearer ${accessToken}`;
  return config;
});

api.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config;
    const isRefreshCall = original.url === REFRESH_URL;
    if (error.response?.status !== 401 || original._retry || isRefreshCall) {
      return Promise.reject(error);
    }
    original._retry = true;
    refreshPromise ??= refreshAccessToken()
      .catch((e) => { accessToken = null; redirectToLogin(); throw e; })
      .finally(() => { refreshPromise = null; });
    await refreshPromise;
    original.headers.Authorization = `Bearer ${accessToken}`;
    return api(original);
  }
);
```

### 19.2 Planned rotation of an HS256 secret

```python
KEYS = settings.JWT_KEYS              # {"2026-10": "<new>", "2026-07": "<old>"} from the secret manager
SIGNING_KID = settings.JWT_CURRENT_KID


def encode(payload: dict) -> str:
    return jwt.encode(payload, KEYS[SIGNING_KID], algorithm="HS256", headers={"kid": SIGNING_KID})


def decode(token: str) -> dict:
    kid = jwt.get_unverified_header(token).get("kid")  # kid is only a lookup key, never trusted for anything else
    key = KEYS.get(kid)
    if key is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Unknown signing key")
    return jwt.decode(token, key, algorithms=["HS256"], audience=..., issuer=...)
```

### 19.5 Where everything is stored

```sql
CREATE TABLE refresh_tokens (
    jti          UUID PRIMARY KEY,
    family_id    UUID NOT NULL,
    user_id      BIGINT NOT NULL REFERENCES users(id),
    token_hash   CHAR(64),                  -- only if refresh tokens are opaque (sha256); JWT refresh tokens are identified by jti
    device_info  TEXT,
    ip           INET,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    used_at      TIMESTAMPTZ,               -- set on rotation; non-null + reused = theft
    revoked_at   TIMESTAMPTZ,
    expires_at   TIMESTAMPTZ NOT NULL
);
CREATE INDEX ON refresh_tokens (family_id);
CREATE INDEX ON refresh_tokens (user_id);
```

### 20.10 Tests to keep

```python
import base64, json
from datetime import timedelta

import pytest
from fastapi import HTTPException


def b64(data: dict) -> str:
    return base64.urlsafe_b64encode(json.dumps(data).encode()).rstrip(b"=").decode()


def test_rejects_alg_none():
    token = f'{b64({"alg": "none", "typ": "JWT"})}.{b64({"sub": "user_1", "type": "access"})}.'
    with pytest.raises(HTTPException):
        decode_token(token, "access")


def test_rejects_tampered_payload():
    header, _, signature = create_token("user_1", "access", ACCESS_TTL).split(".")
    with pytest.raises(HTTPException):
        decode_token(f'{header}.{b64({"sub": "admin", "type": "access"})}.{signature}', "access")


def test_rejects_expired_token():
    with pytest.raises(HTTPException, match="expired"):
        decode_token(create_token("user_1", "access", timedelta(minutes=-5)), "access")


def test_rejects_refresh_token_used_as_access():
    with pytest.raises(HTTPException, match="Wrong token type"):
        decode_token(create_token("user_1", "refresh", REFRESH_TTL), "access")
```
