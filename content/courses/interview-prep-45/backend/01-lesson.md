---
kind: lesson
id_key: interview-prep-45/day-01-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Django Request Lifecycle"
position: 1
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
Today you trace a Django request from socket to response and build the two pieces of middleware every backend interviewer expects you to have written from scratch: a request-timer and an `X-Request-ID` injector. "Walk me through what happens when a request hits your Django app" is one of the most common backend system-design warm-ups — it tests whether you understand the framework or just call its APIs.

## The request lifecycle, end to end

A request to a Django app running behind Gunicorn/uWSGI goes through these stages:

1. **WSGI server** (Gunicorn) accepts the TCP connection and parses the raw HTTP request into a WSGI environ dict.
2. **`WSGIHandler`** (`django.core.handlers.wsgi`) wraps the environ in an `HttpRequest` object.
3. **Middleware chain (request phase)** — each middleware's code *before* calling `get_response(request)` runs top-to-bottom, in the order listed in `MIDDLEWARE`.
4. **URL resolver** — Django walks `ROOT_URLCONF`, matches the path against `urlpatterns`, and resolves it to a view function plus captured URL kwargs. A `Resolver404` here becomes a 404 response before any view runs.
5. **View** — the matched view executes. This is where your business logic, ORM calls, and serialization happen. It returns an `HttpResponse` (or DRF's `Response`, which is a subclass).
6. **Middleware chain (response phase)** — each middleware's code *after* `get_response(request)` runs bottom-to-top (reverse of step 3), letting you mutate the response (add headers, gzip, set cookies).
7. **WSGI server** serializes the `HttpResponse` back into raw HTTP bytes and writes to the socket.

The critical interview detail: **middleware is a chain of closures, not a list of classes that Django loops through.** Each middleware wraps the next one. `MIDDLEWARE = [A, B, C]` builds `A(B(C(view)))`. That's why request-phase code in `A` runs before `B`'s, but response-phase code in `A` runs *after* `B`'s — you're unwinding the same call stack you built going in.

```python
# Simplified mental model of what Django builds from MIDDLEWARE
def build_chain(view, middlewares):
    handler = view
    for mw_class in reversed(middlewares):
        handler = mw_class(handler)  # each middleware wraps the previous handler
    return handler
```

## Writing middleware

Modern Django (1.10+) uses function-based or class-based middleware with a single `__call__` entry point, not the old `process_request`/`process_response` hooks (those still work via `MiddlewareMixin` but are legacy).

```python
# middleware.py
import time
import uuid
import logging

logger = logging.getLogger("request_timing")


class RequestTimingMiddleware:
    """Logs method, path, status code, and duration for every request."""

    def __init__(self, get_response):
        # Called once, at server startup — expensive setup goes here, not in __call__.
        self.get_response = get_response

    def __call__(self, request):
        start = time.monotonic()

        response = self.get_response(request)  # <-- everything downstream runs here

        duration_ms = (time.monotonic() - start) * 1000
        logger.info(
            "%s %s -> %s in %.2fms",
            request.method,
            request.path,
            response.status_code,
            duration_ms,
        )
        return response


class RequestIDMiddleware:
    """Attaches a unique ID to every request and echoes it back as a response header."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.request_id = request_id  # available to views/logging via request.request_id

        response = self.get_response(request)

        response["X-Request-ID"] = request_id
        return response
```

Register both in `settings.py`. Order matters — put `RequestIDMiddleware` early so the ID is available to everything downstream, including exception logging:

```python
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "myapp.middleware.RequestIDMiddleware",
    "myapp.middleware.RequestTimingMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    # ...
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
```

**Trade-off to mention in an interview:** middleware runs on *every* request, including static files and health checks if they're routed through Django. Expensive middleware (DB lookups, external calls) belongs in a view decorator or the view itself, scoped to the routes that need it — not global middleware.

## A timing decorator (function-level, not request-level)

Middleware times a whole request; sometimes you need to time a single function — a slow ORM call, a serializer, a Celery task body.

```python
import time
import functools
import logging

logger = logging.getLogger(__name__)


def timed(func):
    """Decorator that logs how long the wrapped function took to run."""

    @functools.wraps(func)  # preserves __name__/__doc__ — without this, introspection and Django's URL naming break
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        try:
            return func(*args, **kwargs)
        finally:
            elapsed = time.perf_counter() - start
            logger.info("%s took %.4fs", func.__qualname__, elapsed)

    return wrapper


@timed
def generate_report(user_id: int) -> dict:
    ...
```

`functools.wraps` is the detail interviewers probe for — without it, `generate_report.__name__` becomes `"wrapper"`, which breaks anything relying on introspection (admin registration, some testing frameworks, `@method_decorator` chains).

## What happens on a POST request specifically

This is the single most-asked variant of the lifecycle question:

1. Same middleware/URL resolution as above.
2. If the view is a DRF `APIView`, **content negotiation** picks a parser (`JSONParser`, `MultiPartParser`, etc.) based on `Content-Type`.
3. **CSRF check** — `CsrfViewMiddleware` validates the CSRF token for session-authenticated requests (skipped for API clients using token/JWT auth that don't rely on cookies).
4. The parser deserializes the body into `request.data` (DRF) or you read `request.POST`/`request.body` directly in plain Django.
5. Validation runs — a `Form.is_valid()` or DRF `Serializer.is_valid()` call.
6. The view executes the write, typically inside a transaction if it touches more than one table.
7. Response serialization and the middleware unwind as before.

Common follow-up: **"Where would you put a database transaction?"** — wrap the write in `django.db.transaction.atomic()` inside the view or a service function, not in middleware (middleware doesn't know your table-level boundaries and wrapping every request in a transaction wastes connections on read-only GETs).

## Key takeaways

- Middleware is nested function wrapping, not a flat iteration — request-phase code runs top-down, response-phase code runs bottom-up, because it's literally unwinding a call stack.
- `get_response(request)` is the pivot point: code before it is "on the way in," code after it is "on the way out."
- Put `functools.wraps` on every decorator — it's a two-second interview tell for whether you've written real decorators before.
- Global middleware costs every request, including ones that don't need it — scope expensive logic to specific views instead.
- CSRF validation, content negotiation, and body parsing happen before your view code ever runs on a POST — know that order cold.
