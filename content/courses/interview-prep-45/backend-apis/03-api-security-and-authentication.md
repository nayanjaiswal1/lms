---
kind: lesson
id_key: interview-prep-45/day-24-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "API Security and Authentication"
position: 3
estimated_minutes: 70
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

Every API interview eventually asks some version of one question: how does the server know who's asking, and what stops that from being abused? This lesson covers JWTs, OAuth, and API keys, a real JWT login flow, refresh token rotation, session versus JWT, CSRF, SQL injection, secrets management, password hashing, and the OWASP API Security Top 10. It's the single most-asked backend topic in interviews; expect at least one system-design question and one "explain the difference between X and Y" question built from this exact material.

## JWT, OAuth, and API keys: three different problems

These three get lumped together because they can all ride in the same `Authorization` header, but each one answers a different question.

**JWT (JSON Web Token)** is a signed, self-contained token that proves a claim, "this is user 42, expires at time T", without a database lookup. It has three base64 parts separated by dots: `header.payload.signature`.

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

The server never stores this token. Anyone holding the secret (or the matching public key, for the RS256 variant) can verify it. That's the whole point, and also the whole risk: a leaked signing key, or a stolen token that hasn't expired yet, can't be revoked without extra machinery, which is exactly what refresh token rotation exists for.

**OAuth 2.0** is a delegation protocol, not an authentication mechanism by itself. It lets a user grant a third-party app limited access to their data on another service, "let this app read your calendar", without ever handing over their password. The output is usually an access token (often a JWT) plus a refresh token. The Authorization Code flow, with PKCE for public clients, is the one to be able to draw on a whiteboard:

1. The app redirects the user to the provider's `/authorize` endpoint with a `client_id`, `redirect_uri`, `scope`, and `state`.
2. The user logs in and approves; the provider redirects back with a one-time `code`.
3. The app's backend exchanges that `code`, plus a `client_secret` or a PKCE `code_verifier`, for an access token at `/token`.
4. The app calls the resource API using the access token.

**API keys** are a static, long-lived secret that identifies a *client*, a service or app, not a *user*. No expiry, no claims, just "is this string in my allowed set." Good for server-to-server and third-party integrations, bad for representing a logged-in human, since a key can't carry identity claims or expire gracefully on its own.

| | Identifies | Expires | Carries claims | Typical use |
|---|---|---|---|---|
| JWT | A user, usually | Yes, short-lived | Yes | API auth after login |
| OAuth token | A user, via delegation | Yes | Yes (scopes) | Third-party access |
| API key | A client or service | No, until rotated | No | Server-to-server |

> **Remember:** JWT proves a claim about a user, OAuth delegates limited access on a user's behalf, and an API key just identifies a client. Reach for the one that matches who or what you're actually identifying.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-jwtoauthkeys-q1", "type": "mcq",
      "prompt": "A mobile app needs to read a user's Google Calendar without ever seeing the user's Google password. Which mechanism is designed for exactly this?",
      "options": [
        {"id":"a","text":"A shared API key given to every mobile client"},
        {"id":"b","text":"OAuth 2.0, since it delegates limited access to a third-party app without sharing the user's credentials"},
        {"id":"c","text":"A JWT signed by the mobile app itself"},
        {"id":"d","text":"Basic auth with the user's real password sent on every request"}
      ],
      "correct": "b",
      "explanation": "OAuth exists precisely for this case: a user grants a third-party app scoped access to their data on another service, without that app ever learning the user's password." }
] }
```

## A real JWT login flow

The shape you'd write in an interview or a take-home: hash passwords, issue a short-lived token, verify it on every protected route.

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

Three details interviewers check for: passwords are hashed with bcrypt, never stored or compared as plaintext; expiry is enforced server-side, `jwt.decode` raises automatically once `exp` has passed; and the signing secret never leaves the server (with the asymmetric RS256 scheme, only the private key signs, and the public key can be handed to other services so they can verify tokens without ever gaining the power to mint one).

> **Remember:** hash with bcrypt, let `exp` expire tokens automatically, and never let a signing secret leave the server that issues tokens.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-jwtlogin-q1", "type": "mcq",
      "prompt": "In the login flow above, what actually enforces that an expired token gets rejected?",
      "options": [
        {"id":"a","text":"The server checks a separate expiry database on every request"},
        {"id":"b","text":"jwt.decode() itself raises ExpiredSignatureError once the token's exp claim is in the past, with no separate lookup needed"},
        {"id":"c","text":"FastAPI automatically deletes expired tokens from memory"},
        {"id":"d","text":"Expired tokens are rejected by the browser before the request is sent"}
      ],
      "correct": "b",
      "explanation": "A JWT is self-contained: its exp claim is checked by the decoding library itself. No database lookup is needed to know a token has expired, which is the whole appeal of a JWT over a server-stored session." }
] }
```

## Refresh token rotation

Access tokens are short-lived, minutes, so a leaked one does limited damage. Refresh tokens are long-lived, days or weeks, and exist only to mint new access tokens, but a long-lived token sitting in storage is itself a target. Rotation means: every time a refresh token gets used, invalidate it and hand back a brand new one. If a stolen refresh token is ever used by an attacker *and* later by the real user, or the other way around, the reuse of an already-rotated token is a clear, detectable signal that something has been stolen.

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

Store only the **hash** of the refresh token, the same way you'd store a password. If the database leaks, the tokens inside it aren't directly usable. This is also the mechanism that makes an otherwise-unrevokable JWT practically revocable: you can't kill a live access token early, but you can kill its refresh chain so no new one ever gets minted.

> **Remember:** rotate refresh tokens on every use, and store only their hash. Reuse of an already-rotated token is a compromise signal, not a bug to swallow silently.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-refreshtoken-q1", "type": "mcq",
      "prompt": "A refresh token that was already rotated (marked revoked) gets used again in a new request. What should the server do?",
      "options": [
        {"id":"a","text":"Silently issue a new access token as if nothing happened"},
        {"id":"b","text":"Treat it as a compromise signal: revoke the entire refresh token chain for that user and reject the request"},
        {"id":"c","text":"Ignore the revoked flag since the token hash still matches a record"},
        {"id":"d","text":"Extend the revoked token's expiry instead of rejecting it"}
      ],
      "correct": "b",
      "explanation": "A revoked token being reused means someone has a copy of a token that should no longer exist, which is only possible if it leaked. Revoking the whole chain forces re-authentication rather than letting a possible attacker keep a live session." }
] }
```

## JWT versus session: the honest answer

| | Session (cookie plus server-side store) | JWT |
|---|---|---|
| Where the state lives | Server-side, in Redis or a database | Nowhere; the token is self-contained |
| Revoking it | Instant: delete the session record | Hard: wait for expiry, or check a blocklist |
| Scaling across servers | Needs a shared session store | Any server can verify it independently |
| Payload size | Small, just a session ID | Larger, since claims travel with every request |
| Typical use | Traditional web apps, same-origin | APIs, mobile apps, microservices, cross-domain |

The honest interview answer: sessions are simpler to revoke and reason about. JWTs scale better across services because verifying one needs no shared store, at the cost of harder revocation, which is exactly why refresh rotation and short access-token lifetimes exist. Don't claim either one is unconditionally better; the right one depends on whether instant revocation or stateless scaling matters more for the system you're describing.

> **Remember:** sessions revoke instantly but need a shared store. JWTs scale without a shared store but revoke slowly. Refresh rotation is the patch that makes JWT revocation practical.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-jwtvssession-q1", "type": "mcq",
      "prompt": "A system needs to instantly kill a user's access the moment an admin bans them. Which auth model makes that trivial, and why?",
      "options": [
        {"id":"a","text":"JWT, because tokens always check a blocklist automatically"},
        {"id":"b","text":"Session-based auth, because deleting the server-side session record immediately invalidates access on the next request"},
        {"id":"c","text":"Both are equally instant"},
        {"id":"d","text":"Neither can support instant revocation"}
      ],
      "correct": "b",
      "explanation": "A session's state lives on the server, so deleting the record takes effect immediately. A JWT is self-contained and valid until it expires unless you build extra machinery, like a blocklist, on top of it." }
] }
```

## Preventing CSRF

CSRF (Cross-Site Request Forgery) exploits a browser's habit of auto-attaching cookies to every request, including ones a malicious third-party site triggers without the user noticing. It only matters for **cookie-based** auth: a JWT sent by hand in an `Authorization` header isn't vulnerable, because a foreign page's form submission has no way to set that header.

Defenses, strongest first:

1. **`SameSite=Lax` or `SameSite=Strict` cookies.** This blocks the cookie from being sent on cross-site requests at all. `Lax` still allows a top-level navigation GET through; `Strict` blocks everything cross-site. This alone stops most CSRF today.
2. **A CSRF token (the synchronizer token pattern).** The server embeds a random token in the page; the client must echo it back in a header or hidden field on any state-changing request. A forged request from another site can't read that token, since the same-origin policy blocks it from doing so.
3. **Check the `Origin` or `Referer` header** on state-changing requests as a secondary layer.

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

Use `secrets.compare_digest`, a constant-time comparison, instead of `==`. A plain `==` comparison exits as soon as it finds the first mismatched character, so how long the comparison takes leaks how many leading characters were correct. That's a small detail, but interviewers notice when it's skipped on anything security-adjacent.

> **Remember:** CSRF only threatens cookie-based auth. `SameSite=Lax`/`Strict` stops most of it; a CSRF token plus constant-time comparison covers what's left.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-csrf-q1", "type": "mcq",
      "prompt": "An API sends its JWT manually in an Authorization header, never in a cookie. Is it vulnerable to CSRF?",
      "options": [
        {"id":"a","text":"Yes, all APIs are equally vulnerable to CSRF"},
        {"id":"b","text":"No, because CSRF relies on the browser auto-attaching a cookie; a forged cross-site request has no way to set a custom Authorization header"},
        {"id":"c","text":"Yes, but only if SameSite is not configured"},
        {"id":"d","text":"No, but only if the API also uses HTTPS"}
      ],
      "correct": "b",
      "explanation": "CSRF works by exploiting the browser's automatic cookie attachment. An Authorization header must be set deliberately by the client's own code, which a foreign page triggering a form submission or image load cannot do." }
] }
```

## Bearer token, token authentication, and RBAC: three different layers

These three get conflated because they all show up in the same `Authorization` header, but each answers a different question.

**Bearer token** is a *transport scheme*, not a credential type. It means "whoever holds this token is authorized," sent as `Authorization: Bearer <token>`. It says nothing about what's inside the token or how it was issued. A JWT, an opaque session ID, and a raw API key can all travel as bearer tokens; "bearer" only describes how the value moves in the header.

**Token authentication** is the *authentication* mechanism: proving who you are. Django REST Framework's `TokenAuthentication` is one concrete example. It stores an opaque token server-side per user and looks it up on each request, so the token itself carries no information, unlike a JWT, which is self-contained.

**RBAC (Role-Based Access Control)** is the *authorization* model: once the system knows who you are, what are you allowed to do. Permissions attach to roles, users get assigned one or more roles, and an endpoint checks role membership instead of checking individual users one by one.

The framing that ties these together: authentication answers "who is this," authorization answers "what can they do." A request can carry a perfectly valid bearer token naming a known user, and still get rejected by RBAC, because that user's role doesn't permit the action being requested. Don't let "bearer token" stand in for the whole story. It's the envelope the credential travels in, not the credential itself, and not the permission check that happens after.

> **Remember:** bearer token is how a credential travels, token authentication is proving who you are, and RBAC is deciding what that identity is allowed to do. A valid credential can still fail the RBAC check.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-bearerbac-q1", "type": "mcq",
      "prompt": "A request carries a valid, unexpired bearer token for a known user, but the server still returns 403 Forbidden. What's the most likely explanation?",
      "options": [
        {"id":"a","text":"A valid bearer token can never be rejected"},
        {"id":"b","text":"Authentication succeeded (the user is known), but RBAC rejected the specific action because that user's role doesn't permit it"},
        {"id":"c","text":"Bearer tokens are only used for RBAC, not authentication"},
        {"id":"d","text":"The token must have actually been invalid despite appearing valid"}
      ],
      "correct": "b",
      "explanation": "Bearer token validity only proves the request is authenticated. Authorization is a separate check: RBAC can still reject an authenticated user's request if their role doesn't include the required permission." }
] }
```

## SQL injection and parameterized queries

Injection happens when user input gets concatenated directly into a query string instead of passed as a bound parameter.

```python
# VULNERABLE — user input becomes part of the SQL itself
query = f"SELECT * FROM users WHERE email = '{email}'"
cursor.execute(query)
# email = "' OR '1'='1" returns every row
```

The vulnerable version fails because the string `' OR '1'='1` never stays data. Once it's spliced into the query text, the database parses it as SQL, and `WHERE email = '' OR '1'='1'` is always true, so the query returns every row in the table no matter what email was actually being searched for.

```python
# SAFE — parameterized: the driver sends value and query separately,
# the DB never interprets the value as SQL syntax
cursor.execute("SELECT * FROM users WHERE email = %s", [email])
```

In the safe version, the query text and the value travel to the database as two separate things. The database compiles the query shape once, with a placeholder, then substitutes the value in afterward, purely as data. No matter what characters `email` contains, the database never re-parses it as SQL grammar, so there's no way for it to change what the query does.

An ORM like Django's (`Model.objects.filter(email=email)`) parameterizes automatically. That's why raw `.raw()` queries, or SQL built with `str.format()`, are the actual risk surface in an ORM-based codebase, not the ORM itself. The interview framing: an ORM's safety comes from consistently doing parameterization for you, not from special magic, and the risk comes right back the moment someone drops to raw SQL and string-formats it instead of binding a parameter.

> **Remember:** a parameterized query sends the SQL shape and the data as two separate things, so user input can never be re-parsed as SQL syntax. String-building a query is what reopens that door.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-sqlinjection-q1", "type": "mcq",
      "prompt": "A Django codebase mostly uses the ORM, but one endpoint drops to a raw SQL query built with an f-string for \"performance.\" Why is this the actual risk, not the ORM-based endpoints?",
      "options": [
        {"id":"a","text":"Django's ORM is itself vulnerable to injection by default"},
        {"id":"b","text":"The ORM parameterizes queries automatically; an f-string-built raw query splices user input directly into SQL text, reopening the exact hole the ORM closes"},
        {"id":"c","text":"Raw SQL is always slower and less safe than an ORM regardless of how it's written"},
        {"id":"d","text":"Django does not support parameterized raw queries at all"}
      ],
      "correct": "b",
      "explanation": "The ORM's safety comes from consistently parameterizing every query. A hand-built f-string query bypasses that entirely, splicing user input straight into the SQL text the same way any other unparameterized query would." }
] }
```

## Secrets management

Never hardcode a secret in code, and never commit one in a `.env` file. A secret that reaches git history is compromised even if the commit is later reverted, since the history still exists and remains fetchable. The standard practice:

- Use a managed secrets store, Vault, AWS Secrets Manager, GCP Secret Manager, rather than an environment file checked into a repo, so the app fetches secrets at startup or runtime instead of reading them from a committed file.
- Rotate keys on a schedule, and immediately on a suspected breach. A secret that can't be rotated without a full deploy is a design flaw, not just an inconvenience.
- Use `.gitignore` plus a pre-commit secret-scanning hook (tools like detect-secrets or gitleaks) to catch a leak before it's pushed, rather than after.
- Mask sensitive fields in logs. Tokens, passwords, and personal data should never appear in plaintext log output, since logs are often kept and searched with less access control than the primary database.

> **Remember:** a secret in git history is compromised the moment it's committed, revert or not. Fetch secrets from a managed store at runtime instead of a checked-in file.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-secrets-q1", "type": "mcq",
      "prompt": "A developer commits an API key by accident, then immediately reverts the commit. Is the key still compromised?",
      "options": [
        {"id":"a","text":"No, reverting the commit removes it from the repository entirely"},
        {"id":"b","text":"Yes, the key still exists in git history and remains fetchable even after a revert, so it must be rotated"},
        {"id":"c","text":"Only if the repository is public"},
        {"id":"d","text":"No, as long as the revert happens within a few minutes"}
      ],
      "correct": "b",
      "explanation": "A revert adds a new commit undoing the change; it does not erase the old commit from history. Anyone with access to the repository's history can still find and use the leaked key, so it must be rotated regardless." }
] }
```

## The OWASP API Security Top 10 as a checklist

A named list worth reaching for whenever an interviewer asks "how would you secure this API." Two items on it, BOLA and Mass Assignment, are the most likely to show up as a live code-review exercise ("here's an endpoint, what's wrong with it"), because both fail from authorization being checked at the wrong granularity rather than being missing outright.

1. **Broken Object Level Authorization (BOLA).** Not fixed by authentication alone. Every object-fetching endpoint must check that the *authenticated user* owns or can access *this specific* object ID, not just that they're logged in as someone. The classic bug: `/orders/{id}` returns any order to anyone who's logged in, regardless of whose order it actually is.
2. **Broken Authentication.** Covered by correct JWT/OAuth/session handling and refresh token rotation, above.
3. **Excessive Data Exposure.** A serializer returning a full model object instead of an explicit field allowlist. The fix: allowlist fields in the serializer, and don't rely on the client to politely ignore extra fields it receives.
4. **Lack of Resources and Rate Limiting.** Covered by the Redis-backed rate limiter in the API Versioning and Error Handling lesson.
5. **Broken Function Level Authorization.** A role check on the *action* being performed, not just a resource-level ownership check. An admin-only endpoint must reject a non-admin token even when the object-level check would otherwise pass, since the user might genuinely own the object they're trying to act on.
6. **Mass Assignment.** Accepting a full JSON body into a model or serializer with no explicit allowed-fields list. A request body containing `{"is_admin": true}` can silently escalate privilege if the endpoint blindly deserializes the whole body into the model.
7. **Security Misconfiguration.** Default credentials left in place, verbose error messages that leak a stack trace, or debug mode accidentally left on in production.
8. **Injection.** SQL injection, as above, plus the general principle: never let unsanitized input reach an interpreter, whether that's SQL, a shell command, or a template engine.
9. **Improper Assets Management.** An old or undocumented API version left running and unpatched. A `/v1/` endpoint nobody remembers exists is still just as attackable as the current one.
10. **Insufficient Logging and Monitoring.** Log auth failures, rate-limit hits, and unusual access patterns. A spike in 401/403 responses is often how a credential-stuffing attack actually gets caught in production.

> **Remember:** BOLA and Mass Assignment are the two you're most likely to be asked to spot live in a code review. Both come from checking authorization at the wrong level, not from skipping it entirely.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-owasp-q1", "type": "mcq",
      "prompt": "An endpoint GET /orders/{id} checks that the caller is logged in, but returns any order to any logged-in user regardless of who placed it. Which OWASP API risk is this?",
      "options": [
        {"id":"a","text":"Broken Object Level Authorization (BOLA): authentication succeeded, but the endpoint never checked that this specific user owns this specific object"},
        {"id":"b","text":"Mass Assignment"},
        {"id":"c","text":"Insufficient Logging and Monitoring"},
        {"id":"d","text":"Security Misconfiguration"}
      ],
      "correct": "a",
      "explanation": "This is the textbook BOLA bug: the endpoint checks that someone is logged in, but never checks that the logged-in user actually owns the specific order they're requesting." }
] }
```

## Password hashing: why bcrypt, and what beats it

The login flow above hashes with bcrypt without explaining why bcrypt over the alternatives. Here's the comparison an interviewer expects if they push further.

| Algorithm | Type | Defense mechanism |
|---|---|---|
| MD5 / SHA-256 (alone) | Fast cryptographic hash | None |
| PBKDF2 | Key-derivation function | A configurable iteration count (work factor) |
| bcrypt | Password hash | A configurable cost factor (`2^cost` rounds) |
| scrypt | Password hash | Configurable CPU cost plus **memory cost** |
| Argon2 | Password hash | Time cost, memory cost, and parallelism, tunable independently |

Plain MD5 or SHA-256 must never be used for passwords. They're built to be fast, which is exactly the wrong property here: a modern GPU computes billions of hashes a second, making it trivial to brute-force every likely password against a stolen hash.

PBKDF2 fixes that by adding a configurable iteration count, so each guess costs more CPU time. It's widely supported and government-approved for regulated use, but it has no memory cost, so it's still crackable at scale by an attacker with enough parallel hardware.

Bcrypt has been the industry standard for over a decade. It's deliberately slow, with a cost factor you can raise as hardware gets faster, keeping the effective time to crack roughly constant.

Scrypt and Argon2 add **memory hardness** on top of bcrypt's approach. Bcrypt's cost factor only makes each guess slower on one CPU core, but an attacker with thousands of cheap GPU cores can still parallelize guesses cheaply. A memory-hard algorithm forces each guess to allocate a meaningful chunk of RAM, expensive to replicate thousands of times over, which blunts that parallelism advantage. Argon2, winner of the 2015 Password Hashing Competition, is the current best-practice pick for a new project; bcrypt remains an acceptable, battle-tested choice for existing systems already built on it.

**Salting** is automatic and built into bcrypt's own output format: one self-contained string shaped like `$2b$<cost>$<22-char-salt><31-char-hash>`. That's why you never see a separate "store the salt" step when using bcrypt; `bcrypt.checkpw()` pulls the salt out of the stored hash itself before checking a candidate password against it.

> **Remember:** a fast hash like MD5/SHA-256 has no cost knob and must never be used for passwords. Bcrypt, scrypt, and Argon2 are all deliberately slow with a tunable cost, so you raise the cost as hardware gets faster.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-passwordhash-q1", "type": "mcq",
      "prompt": "Why is SHA-256 alone unsuitable for hashing passwords, even though it's a strong cryptographic hash?",
      "options": [
        {"id":"a","text":"SHA-256 produces hashes that are too short to be secure"},
        {"id":"b","text":"SHA-256 is designed to be fast, which lets an attacker with modern GPU hardware try billions of password guesses per second against a stolen hash"},
        {"id":"c","text":"SHA-256 cannot be combined with a salt"},
        {"id":"d","text":"SHA-256 only works on data shorter than 64 characters"}
      ],
      "correct": "b",
      "explanation": "General-purpose cryptographic hashes are built for speed, which is the opposite of what password hashing needs. Password-hashing algorithms like bcrypt are deliberately slow and expose a tunable cost factor for exactly this reason." }
] }
```

## API key lifecycle in production

Knowing what an API key *is* only goes so far; interviewers who push further want the operational side.

- **Never in source control.** Load from environment variables or a secrets manager, never a hardcoded string, and never committed, even to a "private" repo.
- **Segregate per environment and per service.** A dev key and a prod key should be different values, so a leaked dev key can't touch production data, and revoking one service's key doesn't break every other integration.
- **Rotate on a schedule**, for example every 90 days, and immediately on a suspected leak. Rotation should be routine, not a fire drill, which means the system needs to accept two valid keys at once during the rotation window, so the old key keeps working for a grace period while callers migrate.
- **Transmit only over HTTPS, in a header** (`Authorization: Bearer <key>` or a custom header), never as a URL query parameter. URLs get logged by proxies, browsers, and web server access logs, silently leaking the key into logs that outlive the request itself.
- **Monitor usage per key.** Track request volume and source IPs per key, so an anomaly (a sudden spike, requests from an unexpected region) is detectable, and an unused key can be found and revoked instead of living forever "just in case."
- **Support instant revocation.** A key must be disable-able immediately, via a database flag checked on every request, not a cache that takes minutes to propagate, the moment a leak is suspected.

> **Remember:** never put a key in a URL, always support two valid keys during rotation, and make revocation a database check on every request, not something that waits for a cache to expire.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-security-apikeylifecycle-q1", "type": "mcq",
      "prompt": "Why must an API key be rejected instantly (via a live database check) rather than through a cache that refreshes every few minutes?",
      "options": [
        {"id":"a","text":"Caches are always slower than database queries"},
        {"id":"b","text":"The moment a leak is suspected, every minute a revoked key still works is a minute an attacker can keep using it"},
        {"id":"c","text":"API keys cannot be stored in a cache at all"},
        {"id":"d","text":"Database checks are required by the HTTP specification for authentication"}
      ],
      "correct": "b",
      "explanation": "Revocation exists to stop an active leak. A cache-based check that takes minutes to propagate gives a suspected attacker a window to keep using the compromised key, defeating the point of revoking it." }
] }
```
