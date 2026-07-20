---
kind: lesson
id_key: interview-prep-45/day-23-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 23 — FastAPI Dependency Injection"
position: 23
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
FastAPI's dependency system is what makes it feel different from Flask in interviews — candidates who've only used `@app.get` decorators get tripped up the moment they're asked to share auth logic, DB sessions, or caching across endpoints cleanly. Today covers how `Depends()` actually works, request-scoped dependencies, caching, and building an authentication dependency.

## How FastAPI manages dependencies

A dependency is just a callable (function, or a class with `__call__`) that FastAPI calls for you before your endpoint runs, and whose return value it injects as an argument. Dependencies can themselves depend on other dependencies — FastAPI resolves the whole graph per request.

```python
from fastapi import FastAPI, Depends

app = FastAPI()

def get_query_params(q: str | None = None, limit: int = 20):
    return {"q": q, "limit": limit}

@app.get("/items")
def list_items(params: dict = Depends(get_query_params)):
    return {"params": params}
```

What actually happens under the hood: FastAPI inspects the endpoint function's signature at route-registration time, finds parameters with a `Depends(...)` default, and builds a dependency graph. On each request, it walks that graph, calling each dependency (resolving *its* sub-dependencies first), and passes the return values into your endpoint as regular arguments. This is dependency injection via plain function signatures — no decorators, no container/registry to configure, which is the design detail interviewers want you to articulate versus, say, Spring's `@Autowired`.

## What is Depends()?

`Depends()` is a marker, not a function that runs anything itself — it tells FastAPI's routing layer "resolve this parameter by calling the given callable (with its own dependencies resolved first) rather than by parsing it from the request." It accepts:

- A plain function — called fresh (subject to caching, below) for each place it's used.
- A class — FastAPI calls `SomeClass(...)`, so `__init__`'s parameters become sub-dependencies, and the instance is what gets injected.
- Nothing (`Depends()` with no argument, in newer FastAPI) — infers the callable from the annotated type.

```python
class Pagination:
    def __init__(self, skip: int = 0, limit: int = 20):
        self.skip = skip
        self.limit = limit

@app.get("/users")
def list_users(pagination: Pagination = Depends()):
    return {"skip": pagination.skip, "limit": pagination.limit}
```

## Custom dependency with caching

By default, FastAPI **caches a dependency's result for the duration of a single request** — if two different dependencies in the same request both depend on `get_db`, `get_db` runs once and both receive the same returned session, not two separate calls. This is `use_cache=True`, the default.

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

For caching *across* requests (not just within one), don't rely on FastAPI's per-request cache — use `functools.lru_cache` on the dependency itself, which is the standard pattern for expensive, request-independent setup like loading settings from environment variables once per process:

```python
from functools import lru_cache

@lru_cache
def get_settings():
    return Settings()   # e.g. a pydantic-settings model reading env vars — loaded once, reused forever

@app.get("/health")
def health(settings: Settings = Depends(get_settings)):
    return {"env": settings.environment}
```

`use_cache=False` on `Depends(..., use_cache=False)` is the opposite override — forces a dependency to re-run even if already resolved earlier in the same request, useful for a dependency with side effects you deliberately want repeated (rare, but interviewers may ask when you'd need it).

## Scoped dependencies (request-level)

FastAPI dependencies that use `yield` instead of `return` get request-scoped setup/teardown — the code after `yield` runs after the response is sent, making this the standard pattern for anything that needs cleanup (DB sessions, file handles, locks).

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

This is "request-scoped" in the sense that matters for interviews: a fresh `Session` per request (never shared across concurrent requests, which would corrupt transactional state), but reused across every dependency/endpoint code within that one request via caching. Contrast with a global module-level `Session` (wrong — shared mutable state across concurrent requests) or creating a new session in every function that touches the DB (wrong — loses the "one unit of work per request" transaction boundary and duplicates setup/teardown).

## Implementation: authentication dependency

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

Two design points worth naming explicitly in an interview:

- **`OAuth2PasswordBearer`** doesn't perform auth itself — it's a dependency that extracts the `Authorization: Bearer <token>` header (raising 401 automatically if it's missing) and documents the security scheme in the OpenAPI schema, so `/docs` shows the "Authorize" button. The actual token *validation* is your code in `get_current_user`.
- **Layering `get_current_user` → `get_current_active_user`** lets different endpoints require different strictness — a "verify email" endpoint might accept an inactive user via `get_current_user` directly, while most endpoints require `get_current_active_user`. This composability (small dependencies building into stricter ones) is the payoff of FastAPI's DI system versus one monolithic auth check.

## Key takeaways

- `Depends()` marks a parameter for resolution via a callable; FastAPI builds and resolves the full dependency graph per request purely from function signatures — no separate container config.
- Dependency results are cached per request by default (`use_cache=True`); process-lifetime caching (e.g. settings) needs `functools.lru_cache`, not FastAPI's request cache.
- `yield`-based dependencies give request-scoped setup/teardown — the standard pattern for DB sessions, ensuring cleanup runs after the response without leaking connections.
- `OAuth2PasswordBearer` only extracts and documents the bearer token; validating it (JWT decode, user lookup) is application code layered on top via `Depends`.
- Small dependencies compose into stricter ones (`get_current_user` → `get_current_active_user`) instead of one large auth function — reuse and layering are the actual interview signal here.
- A class passed to `Depends()` turns its `__init__` parameters into sub-dependencies automatically, useful for grouping related query/path parameters like pagination.

## Today's checklist

- [ ] Read the FastAPI dependency injection system docs
- [ ] Implement a custom dependency with caching (lru_cache for process-lifetime)
- [ ] Implement scoped (request-level, yield-based) dependencies
- [ ] Answer: how FastAPI manages dependencies, and what Depends() does
- [ ] Implement an authentication dependency with layered strictness
