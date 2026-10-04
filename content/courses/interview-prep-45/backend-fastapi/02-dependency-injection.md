---
kind: lesson
id_key: interview-prep-45/day-23-backend
course: interview-prep-45
section: backend-fastapi
section_title: "FastAPI"
section_position: 8
section_group: "Backend"
title: "FastAPI Dependency Injection"
position: 2
estimated_minutes: 35
source:
    - 45-day-interview-roadmap.md
---

A candidate who has only used `@app.get` decorators gets tripped up the moment they're asked to share authentication logic, database sessions, or caching across endpoints cleanly. This is exactly what FastAPI's dependency system is for, and it's what makes FastAPI feel different from Flask in an interview.

## How FastAPI resolves dependencies

A dependency is just a callable, a function, or a class with `__call__`, that FastAPI calls for you before your endpoint runs, injecting its return value as an argument. Dependencies can themselves depend on other dependencies, and FastAPI resolves the whole graph on every request.

```python
from fastapi import FastAPI, Depends

app = FastAPI()

def get_query_params(q: str | None = None, limit: int = 20):
    return {"q": q, "limit": limit}

@app.get("/items")
def list_items(params: dict = Depends(get_query_params)):
    return {"params": params}
```

Under the hood, FastAPI inspects the endpoint's signature at route-registration time, finds every parameter with a `Depends(...)` default, and builds a dependency graph from that. On each request, it walks the graph, resolving sub-dependencies first, then passes each return value into your endpoint as a regular argument. This is dependency injection through plain function signatures: no decorators to configure and no container or registry to set up, which is the design detail worth naming if you're comparing it to something like Spring's `@Autowired`.

> **Remember:** `Depends()` isn't a function that runs anything by itself. It's a marker telling FastAPI "resolve this parameter by calling the given callable instead of parsing it from the request."

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-di-howitworks-q1", "type": "mcq",
      "prompt": "When does FastAPI actually call a function passed to Depends()?",
      "options": [
        {"id":"a","text":"Once, when the app first starts up"},
        {"id":"b","text":"On each request, when resolving the dependency graph for that endpoint's signature"},
        {"id":"c","text":"Only when the endpoint explicitly calls it by name"},
        {"id":"d","text":"Never automatically; the developer must call it manually inside the route"}
      ],
      "correct": "b",
      "explanation": "FastAPI inspects the endpoint's signature at route-registration time to find Depends() parameters, then walks and resolves that dependency graph fresh on every incoming request." }
] }
```

## What Depends() accepts

```python
class Pagination:
    def __init__(self, skip: int = 0, limit: int = 20):
        self.skip = skip
        self.limit = limit

@app.get("/users")
def list_users(pagination: Pagination = Depends()):
    return {"skip": pagination.skip, "limit": pagination.limit}
```

`Depends()` accepts a plain function, called fresh for each place it's used (subject to caching, covered next); a class, where FastAPI calls `SomeClass(...)`, so `__init__`'s parameters become sub-dependencies and the instance itself is what gets injected; or nothing at all, which infers the callable from the parameter's own annotated type, as in `Pagination` above.

> **Remember:** passing a class to `Depends()` makes its `__init__` parameters into sub-dependencies automatically. The injected value is the constructed instance.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-di-classdepends-q1", "type": "mcq",
      "prompt": "`pagination: Pagination = Depends()` where Pagination.__init__ takes skip and limit. What gets injected into the endpoint?",
      "options": [
        {"id":"a","text":"The Pagination class itself, not an instance"},
        {"id":"b","text":"An instance of Pagination, built by FastAPI calling Pagination(...) with skip/limit resolved as sub-dependencies from the request"},
        {"id":"c","text":"Nothing; Depends() with no argument is invalid"},
        {"id":"d","text":"A dictionary with keys skip and limit"}
      ],
      "correct": "b",
      "explanation": "FastAPI calls the class like any other dependency, so __init__'s own parameters (skip, limit) become sub-dependencies read from the request, and the constructed Pagination instance is what's injected." }
] }
```

## Caching a dependency's result

By default, FastAPI **caches a dependency's result for the duration of one request**. If two different dependencies both depend on `get_db` within the same request, `get_db` runs once and both receive the same returned value, not two separate calls. This is `use_cache=True`, the default.

```python
from fastapi import Depends

def get_settings():
    print("loading settings")   # only prints once per request, even if used twice below
    return load_app_settings()

def get_feature_flags(settings=Depends(get_settings)):
    return settings.feature_flags

def get_rate_limits(settings=Depends(get_settings)):   # same get_settings call, cached
    return settings.rate_limits

@app.get("/config")
def config_endpoint(
    flags=Depends(get_feature_flags),
    limits=Depends(get_rate_limits),
):
    return {"flags": flags, "limits": limits}
```

For caching *across* requests, not just within one, don't rely on FastAPI's per-request cache. Use `functools.lru_cache` on the dependency itself, the standard pattern for expensive, request-independent setup like loading settings from environment variables once per process:

```python
from functools import lru_cache

@lru_cache
def get_settings():
    return Settings()   # e.g. a pydantic-settings model reading env vars, loaded once and reused forever

@app.get("/health")
def health(settings: Settings = Depends(get_settings)):
    return {"env": settings.environment}
```

`Depends(..., use_cache=False)` is the opposite override: it forces a dependency to re-run even if it was already resolved earlier in the same request, useful for a dependency with a deliberate side effect you want repeated.

> **Remember:** FastAPI's built-in cache only lasts one request. For a value that should persist across requests, like settings loaded once per process, wrap the dependency in `functools.lru_cache` instead.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-di-caching-q1", "type": "mcq",
      "prompt": "Two endpoints in the same app both use `Depends(get_settings)`. Without @lru_cache, how many times does get_settings run across two separate requests?",
      "options": [
        {"id":"a","text":"Once total, shared across both requests"},
        {"id":"b","text":"Once per request: FastAPI's per-request cache means it won't re-run within one request, but it does run again for each new request"},
        {"id":"c","text":"Never; it only runs at app startup"},
        {"id":"d","text":"Twice per request, once for each endpoint"}
      ],
      "correct": "b",
      "explanation": "FastAPI's dependency cache is scoped to a single request, not the whole process. Without @lru_cache (or another process-level cache), a dependency re-runs fresh on every new request even if it produced the same result last time." }
] }
```

## Request-scoped setup and teardown with yield

A FastAPI dependency that uses `yield` instead of `return` gets request-scoped setup and teardown. The code after `yield` runs after the response is sent, which is the standard pattern for anything needing cleanup: database sessions, file handles, locks.

```python
from sqlalchemy.orm import Session
from fastapi import Depends

def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db              # this Session is what gets injected
    finally:
        db.close()             # runs after the endpoint (and response) completes

@app.get("/orders/{order_id}")
def get_order(order_id: int, db: Session = Depends(get_db)):
    return db.query(Order).get(order_id)
```

"Request-scoped" here means a fresh `Session` per request, never shared across concurrent requests (which would corrupt transactional state), but reused across every dependency and endpoint code within that one request, via the same per-request caching from the previous section. Compare that with a global module-level `Session` (wrong: shared mutable state across concurrent requests) or building a brand-new session in every function that touches the database (wrong: loses the "one unit of work per request" boundary and duplicates setup and teardown).

> **Remember:** a `yield`-based dependency splits into setup (before `yield`) and teardown (after it), with the teardown guaranteed to run once the response is done, wrapped in `try/finally` for anything that must clean up even on error.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-di-yield-q1", "type": "mcq",
      "prompt": "In a `yield`-based dependency like get_db above, when does the code after yield (db.close()) actually run?",
      "options": [
        {"id":"a","text":"Immediately, before the endpoint body even executes"},
        {"id":"b","text":"After the endpoint has finished and the response has been sent"},
        {"id":"c","text":"It never runs automatically; you must call it manually"},
        {"id":"d","text":"Only if the endpoint raises an exception"}
      ],
      "correct": "b",
      "explanation": "Everything before yield is setup, injected as the dependency's value. Everything after yield is teardown, which FastAPI runs once the request/response cycle for that endpoint is complete." }
] }
```

## Building an authentication dependency

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

SECRET_KEY = settings.jwt_secret   # from env, never hardcoded
ALGORITHM = "HS256"

def get_current_user(token: str = Depends(oauth2_scheme)) -> "User":
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = get_user_by_id(user_id)
    if user is None:
        raise credentials_exception
    return user

def get_current_active_user(user: "User" = Depends(get_current_user)) -> "User":
    if not user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return user

@app.get("/me")
def read_own_profile(current_user: "User" = Depends(get_current_active_user)):
    return {"id": current_user.id, "email": current_user.email}
```

Two points worth naming explicitly. `OAuth2PasswordBearer` doesn't perform authentication itself: it's a dependency that extracts the `Authorization: Bearer <token>` header, raising a 401 automatically if it's missing, and documents the security scheme in the OpenAPI schema so `/docs` shows an "Authorize" button. The actual token *validation* is your own code in `get_current_user`. And layering `get_current_user` into `get_current_active_user` lets different endpoints require different strictness: a "verify email" endpoint might accept an inactive user through `get_current_user` directly, while most endpoints require the stricter `get_current_active_user`. This composability, small dependencies building into stricter ones, is the payoff of FastAPI's dependency system over one monolithic auth check.

> **Remember:** `OAuth2PasswordBearer` only extracts the token; it doesn't validate it. Layer small dependencies (`get_current_user` -> `get_current_active_user`) instead of writing one big auth check.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-di-auth-q1", "type": "mcq",
      "prompt": "Does OAuth2PasswordBearer(tokenUrl=\"token\") validate the JWT's signature and claims?",
      "options": [
        {"id":"a","text":"Yes, it fully validates the token before injecting it"},
        {"id":"b","text":"No, it only extracts the Authorization: Bearer token from the header (and 401s if missing); actual validation is separate code, like get_current_user"},
        {"id":"c","text":"It validates the signature but not the expiry"},
        {"id":"d","text":"It only works with session cookies, not bearer tokens"}
      ],
      "correct": "b",
      "explanation": "OAuth2PasswordBearer's job is extracting the raw token string from the request and documenting the security scheme for OpenAPI. Decoding and validating that token is separate application code, layered on top via another dependency." }
] }
```
