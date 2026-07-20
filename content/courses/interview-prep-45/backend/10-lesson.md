---
kind: lesson
id_key: interview-prep-45/day-10-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 10 — API Versioning and Error Handling"
position: 10
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
An API that works is table stakes; an API that can change without breaking every client is what separates a junior design from a senior one. Today: the real trade-offs between versioning strategies, a standardized error envelope, FastAPI error-handling middleware, and rate limiting at the API layer.

## API versioning strategies

| Strategy | Example | Pros | Cons |
|---|---|---|---|
| **URL path** | `/v1/posts`, `/v2/posts` | Explicit, cacheable, visible in logs/metrics, easy to route to different code versions | Versions the whole API even for unrelated changes; URL isn't a stable identifier for a resource anymore |
| **Header** | `Accept: application/vnd.myapi.v2+json` | Keeps URLs stable, resource identity doesn't change | Invisible in logs/browser, harder to test manually (curl needs explicit header), harder to cache by URL |
| **Query param** | `/posts?version=2` | Simple to add | Easy to omit accidentally, mixes with other query semantics, least conventional |

Most production APIs use **URL path versioning at the major-version level only** (`/v1`, `/v2`) and handle everything else — new optional fields, new endpoints, deprecations — without bumping the version, because a new major version means maintaining two full codepaths in parallel. That's the practical answer to "how would you version an API": version rarely, and reserve it for actual breaking changes.

## What counts as a breaking change

- Removing a field from a response
- Renaming a field
- Changing a field's type (`string` → `int`)
- Changing validation to be stricter (rejecting requests that used to succeed)
- Changing a status code for an existing scenario

**Not breaking:**

- Adding a new optional field to a response (clients that don't know about it ignore it)
- Adding a new endpoint
- Adding a new optional request parameter with a sensible default
- Loosening validation (accepting requests that used to be rejected)

The "additive changes are safe, removals/renames/type-changes are not" rule is the concrete answer to "how do you handle breaking changes" — plus the practice of deprecating with a `Deprecation` / `Sunset` header and a migration window before removing anything:

```python
from fastapi import Response

@app.get("/v1/posts/{post_id}")
async def get_post_v1(post_id: int, response: Response):
    response.headers["Deprecation"] = "true"
    response.headers["Sunset"] = "Sat, 31 Jan 2026 00:00:00 GMT"
    response.headers["Link"] = '</v2/posts/{post_id}>; rel="successor-version"'
    return get_post(post_id)
```

## Versioning in FastAPI

The cleanest implementation is separate routers mounted at different prefixes, sharing business logic underneath so a v2-only change doesn't fork your whole codebase:

```python
from fastapi import FastAPI, APIRouter

app = FastAPI()
v1_router = APIRouter(prefix="/v1")
v2_router = APIRouter(prefix="/v2")


@v1_router.get("/posts/{post_id}")
async def get_post_v1(post_id: int):
    post = post_service.get(post_id)
    return {"id": post.id, "title": post.title, "body": post.body}  # v1 shape


@v2_router.get("/posts/{post_id}")
async def get_post_v2(post_id: int):
    post = post_service.get(post_id)  # same underlying service call
    return {
        "id": post.id,
        "title": post.title,
        "body": post.body,
        "author": {"id": post.author_id, "name": post.author.name},  # v2 adds nested author
    }


app.include_router(v1_router)
app.include_router(v2_router)
```

Both routers call the same `post_service.get()` — the version boundary lives at the serialization layer (the shape returned to the client), not duplicated in business logic. That's the detail that shows you're not just going to copy-paste the whole module per version.

## Standardized error response format

Every endpoint, every error, same shape — so clients can write one error-handling path instead of one per endpoint.

```python
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
import logging

app = FastAPI()
logger = logging.getLogger(__name__)


def error_envelope(code: str, message: str, details: list | None = None) -> dict:
    return {
        "error": {
            "code": code,          # stable machine-readable string, e.g. "VALIDATION_ERROR"
            "message": message,    # human-readable summary
            "details": details or [],
        }
    }


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    details = [
        {"field": ".".join(str(p) for p in err["loc"]), "issue": err["msg"]}
        for err in exc.errors()
    ]
    return JSONResponse(
        status_code=422,
        content=error_envelope("VALIDATION_ERROR", "Request validation failed", details),
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=error_envelope(f"HTTP_{exc.status_code}", str(exc.detail)),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # Never leak internals (stack traces, DB errors) to the client — log them, return a generic message
    logger.exception("Unhandled exception on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content=error_envelope("INTERNAL_ERROR", "An unexpected error occurred"),
    )
```

The catch-all `Exception` handler is the important one for an interview: it's the difference between leaking a stack trace with your DB connection string in it to a client, and returning a clean generic 500 while still logging the full detail server-side.

## Status codes worth knowing cold

| Code | Meaning | When |
|---|---|---|
| 200 | OK | Successful GET/PUT/PATCH |
| 201 | Created | Successful POST that created a resource — include `Location` header |
| 204 | No Content | Successful DELETE, or a PUT/PATCH with nothing to return |
| 400 | Bad Request | Malformed request the client should fix (generic) |
| 401 | Unauthorized | Missing/invalid authentication |
| 403 | Forbidden | Authenticated, but not allowed to do this |
| 404 | Not Found | Resource doesn't exist |
| 409 | Conflict | State conflict — e.g. duplicate unique key, version mismatch on optimistic locking |
| 422 | Unprocessable Entity | Syntactically valid but semantically invalid (FastAPI's default for Pydantic validation) |
| 429 | Too Many Requests | Rate limited — include `Retry-After` |
| 500 | Internal Server Error | Unhandled server-side failure |
| 503 | Service Unavailable | Temporarily down (deploy, overload) — include `Retry-After` |

## Rate limiting at the API level

Middleware wrapping the sliding-window pattern from Day 6:

```python
from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware

class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, redis_client, limit: int = 100, window_seconds: int = 60):
        super().__init__(app)
        self.redis = redis_client
        self.limit = limit
        self.window_seconds = window_seconds

    async def dispatch(self, request: Request, call_next):
        client_id = request.headers.get("X-API-Key", request.client.host)
        key = f"ratelimit:{client_id}:{int(time.time()) // self.window_seconds}"

        count = self.redis.incr(key)
        if count == 1:
            self.redis.expire(key, self.window_seconds)

        if count > self.limit:
            return JSONResponse(
                status_code=429,
                content=error_envelope("RATE_LIMITED", "Too many requests"),
                headers={"Retry-After": str(self.window_seconds)},
            )

        response = await call_next(request)
        response.headers["X-RateLimit-Limit"] = str(self.limit)
        response.headers["X-RateLimit-Remaining"] = str(max(0, self.limit - count))
        return response


app.add_middleware(RateLimitMiddleware, redis_client=redis.Redis(), limit=100, window_seconds=60)
```

Rate limit by API key (or authenticated user ID) when available, falling back to IP only for unauthenticated traffic — IP-based limiting alone is easy to defeat (NAT'd offices share an IP; malicious clients rotate IPs) and easy to over-trigger on legitimate shared-IP traffic.

## Key takeaways

- Version rarely, at the major-version/URL level, and only for actual breaking changes — additive changes (new optional fields, new endpoints) don't need a version bump.
- Route both versions to the same underlying business logic; the version boundary belongs at serialization, not duplicated deep in the codebase.
- One error envelope shape across every endpoint, with a stable machine-readable `code` and a catch-all handler that logs details server-side but never leaks them to the client.
- Know the status code table cold, especially the 401/403 distinction and 409 for conflicts — these come up in almost every API design discussion.
- Rate limit by API key/user ID first, IP as a fallback only — and always return `Retry-After`.

## Today's checklist

- [ ] Read: API versioning strategies
- [ ] Add versioning to a FastAPI endpoint
- [ ] Implement a standardized error response format
- [ ] Design error-handling middleware for FastAPI
- [ ] Implement rate limiting at the API level
- [ ] Be ready to answer: how do you handle breaking changes? What HTTP status codes do you use?
