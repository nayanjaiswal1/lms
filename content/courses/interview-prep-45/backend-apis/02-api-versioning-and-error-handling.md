---
kind: lesson
id_key: interview-prep-45/day-10-backend
course: interview-prep-45
section: backend-apis
section_title: "APIs, Security & Deployment"
section_position: 11
section_group: "Backend"
title: "API Versioning and Error Handling"
position: 2
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---

An API that works is table stakes. An API that can change without breaking every client that calls it is what separates a junior design from a senior one. This lesson covers the real trade-offs between versioning strategies, what actually counts as a breaking change, a standardized error shape every endpoint can share, the status codes worth knowing cold, and rate limiting at the API layer.

## Choosing a versioning strategy

| Strategy | Example | Strength | Weakness |
|---|---|---|---|
| **URL path** | `/v1/posts`, `/v2/posts` | Explicit, cacheable, visible in logs and metrics, easy to route to different code | Versions the whole API even for one unrelated change; the URL stops being a stable name for the resource |
| **Header** | `Accept: application/vnd.myapi.v2+json` | Keeps URLs stable; the resource's identity never changes | Invisible in logs and the browser, harder to test by hand (curl needs an explicit header), harder to cache by URL |
| **Query param** | `/posts?version=2` | Simple to add | Easy to forget, mixes with other query semantics, the least conventional choice |

Picture a shop that renumbers every aisle whenever it changes one shelf, versus one that only renumbers when it rebuilds the whole layout. Most production APIs use **URL path versioning at the major-version level only** (`/v1`, `/v2`), and handle everything else, new optional fields, new endpoints, deprecations, without bumping the version at all. A new major version means running two full codepaths side by side, which is expensive, so the practical answer to "how would you version an API" is: version rarely, and reserve it for genuine breaking changes.

> **Remember:** version at the major level only, through the URL path, and treat a version bump as expensive. Most changes don't need one.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-strategy-q1", "type": "mcq",
      "prompt": "Why do most production APIs version only at the major level (/v1, /v2) instead of bumping a version for every change?",
      "options": [
        {"id":"a","text":"HTTP only supports two API versions at a time"},
        {"id":"b","text":"Each major version means maintaining a full parallel codepath, so it's reserved for genuinely breaking changes, not routine additions"},
        {"id":"c","text":"Minor versions are not supported by any web framework"},
        {"id":"d","text":"URL path versioning is the only strategy that works at all"}
      ],
      "correct": "b",
      "explanation": "A new major version usually means keeping two complete implementations running side by side until clients migrate. That cost is why teams reserve version bumps for real breaking changes and handle everything else without one." }
] }
```

## What counts as a breaking change

- Removing a field from a response
- Renaming a field
- Changing a field's type (`string` to `int`)
- Making validation stricter, so requests that used to succeed now get rejected
- Changing the status code an existing scenario returns

**Not breaking:**

- Adding a new optional field to a response (a client that doesn't know about it just ignores it)
- Adding a new endpoint
- Adding a new optional request parameter with a sensible default
- Loosening validation, so requests that used to be rejected now succeed

The rule to say out loud: additive changes are safe, removals, renames, and type changes are not. Pair that with deprecating gracefully: add a `Deprecation` and `Sunset` header and give clients a real migration window before removing anything.

```python
from fastapi import Response

@app.get("/v1/posts/{post_id}")
async def get_post_v1(post_id: int, response: Response):
    response.headers["Deprecation"] = "true"
    response.headers["Sunset"] = "Sat, 31 Jan 2026 00:00:00 GMT"
    response.headers["Link"] = '</v2/posts/{post_id}>; rel="successor-version"'
    return get_post(post_id)
```

> **Remember:** adding is safe, removing/renaming/retyping is not. Deprecate with a `Sunset` header and a migration window before you ever remove a field.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-breaking-q1", "type": "mcq",
      "prompt": "Which of these is a breaking change to an existing API endpoint's response?",
      "options": [
        {"id":"a","text":"Adding a new optional field that existing clients can safely ignore"},
        {"id":"b","text":"Changing a field's type from string to int"},
        {"id":"c","text":"Adding a brand new endpoint elsewhere in the API"},
        {"id":"d","text":"Loosening a validation rule so more requests succeed"}
      ],
      "correct": "b",
      "explanation": "Changing a field's type breaks any client that parses that field expecting the old type. Additive changes (a new field, a new endpoint, looser validation) are the safe category; removals, renames, and type changes are not." }
] }
```

## Keeping the version boundary out of business logic

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

Both routers call the exact same `post_service.get()`. The version boundary lives at the serialization layer, the shape returned to the client, not duplicated inside business logic. That single detail is what shows an interviewer you won't end up copy-pasting an entire module every time you cut a new version.

> **Remember:** keep one shared service underneath every version. Only the response shape changes per version; the logic that fetches and validates data never forks.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-boundary-q1", "type": "mcq",
      "prompt": "Why should the /v1 and /v2 routers in the example both call the same post_service.get() instead of each having their own copy of the fetch logic?",
      "options": [
        {"id":"a","text":"FastAPI requires every router to share the exact same functions"},
        {"id":"b","text":"Duplicating business logic per version means every future bug fix or change has to be made twice, and the two versions will eventually drift"},
        {"id":"c","text":"Only one version of an API is allowed to touch the database"},
        {"id":"d","text":"Shared functions run faster than duplicated ones"}
      ],
      "correct": "b",
      "explanation": "Keeping the version boundary at the serialization layer means a bug fix or new validation rule only needs to be written once. Forking business logic per version guarantees the two copies drift apart over time." }
] }
```

## A standardized error response shape

Every endpoint, every error, the same envelope, so a client writes one error-handling path instead of one per endpoint.

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

The catch-all `Exception` handler is the one interviewers pay attention to. Without it, an unhandled bug leaks its stack trace, and sometimes a database connection string inside it, straight to whoever sent the request. With it, the client sees a clean generic message while the full detail still lands in your own logs.

> **Remember:** log the full error server-side, but never send a stack trace or internal detail back to the client. A generic message plus a stable error code is enough for the client to act on.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-errors-q1", "type": "mcq",
      "prompt": "Why does the catch-all Exception handler return a generic \"An unexpected error occurred\" message instead of the real exception's text?",
      "options": [
        {"id":"a","text":"FastAPI does not allow returning the real exception text"},
        {"id":"b","text":"The real exception can contain internal details, like a stack trace or a database connection string, that must never reach the client; full detail is logged server-side instead"},
        {"id":"c","text":"Generic messages are required by the HTTP specification"},
        {"id":"d","text":"It makes the response smaller, which is the only reason"}
      ],
      "correct": "b",
      "explanation": "An unhandled exception's message or traceback can expose internals an attacker could use. Logging the full detail server-side while returning a generic message to the client is what keeps that information from leaking." }
] }
```

## Status codes worth knowing cold

| Code | Meaning | When |
|---|---|---|
| 200 | OK | A successful GET, PUT, or PATCH |
| 201 | Created | A successful POST that created a resource; include a `Location` header |
| 204 | No Content | A successful DELETE, or a PUT/PATCH with nothing to return |
| 400 | Bad Request | A malformed request the client should fix (the generic case) |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Authenticated, but not allowed to do this |
| 404 | Not Found | The resource doesn't exist |
| 409 | Conflict | A state conflict, like a duplicate unique key or a version mismatch on optimistic locking |
| 422 | Unprocessable Entity | Syntactically valid but semantically invalid (FastAPI's default for a failed Pydantic validation) |
| 429 | Too Many Requests | Rate limited; include a `Retry-After` header |
| 500 | Internal Server Error | An unhandled failure on the server |
| 503 | Service Unavailable | Temporarily down, for a deploy or an overload; include `Retry-After` |

> **Remember:** 401 means "I don't know who you are," 403 means "I know who you are, and the answer is no." Mixing those two up is one of the most common status-code mistakes.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-statuscodes-q1", "type": "mcq",
      "prompt": "A logged-in user with a valid session tries to delete another user's post. What status code fits?",
      "options": [
        {"id":"a","text":"401 Unauthorized, since they aren't allowed to do this"},
        {"id":"b","text":"403 Forbidden, since they are authenticated but not permitted to perform this action"},
        {"id":"c","text":"404 Not Found, to hide that the post exists"},
        {"id":"d","text":"400 Bad Request"}
      ],
      "correct": "b",
      "explanation": "401 means the server doesn't know who is asking (missing or invalid authentication). This user is authenticated, so the correct code is 403: identity is known, but the action is not permitted." }
] }
```

## Rate limiting at the API level

A rate limiter built as middleware, wrapping the same sliding-window idea used for a Redis-backed cache elsewhere in this course:

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

Rate limit by API key, or by authenticated user ID, whenever you have one, and only fall back to the raw IP address for anonymous traffic. IP-based limiting alone is easy to both defeat and over-trigger: a malicious client can rotate IPs to dodge the limit, while an entire office sharing one NAT'd IP can get throttled together for someone else's traffic.

> **Remember:** rate limit by API key or user ID first, and only fall back to IP for anonymous traffic. IP alone is both too easy to dodge and too easy to over-trigger on shared IPs.

```knowledge-check
{ "questions": [
    { "id": "backend-apis-versioning-ratelimit-q1", "type": "mcq",
      "prompt": "Why does the rate limiter prefer the X-API-Key header over the client's raw IP address when both are available?",
      "options": [
        {"id":"a","text":"IP addresses cannot be used as a Redis key"},
        {"id":"b","text":"An API key identifies one specific client, while an IP can represent a whole shared office (over-triggers on legitimate traffic) or be rotated by an attacker (under-triggers on abuse)"},
        {"id":"c","text":"Rate limiting by IP is not supported in FastAPI"},
        {"id":"d","text":"API keys never expire, so they are simpler to track"}
      ],
      "correct": "b",
      "explanation": "An IP is a poor proxy for identity: many legitimate users can share one IP behind NAT, and a determined abuser can rotate IPs. An API key or authenticated user ID identifies the actual caller directly." }
] }
```
