---
kind: lesson
id_key: interview-prep-45/day-01-backend
course: interview-prep-45
section: backend-django
section_title: "Django"
section_position: 7
section_group: "Backend"
title: "Django Request Lifecycle"
position: 1
estimated_minutes: 30
source:
    - 45-day-interview-roadmap.md
---

"Walk me through what happens when a request hits your Django app" is one of the most common backend warm-up questions there is. It isn't really about Django. It's checking whether you understand the framework underneath your code, or only know how to call its APIs. This lesson traces a request end to end, then has you build the two pieces of middleware almost every interviewer expects a backend candidate to have written from scratch.

## The request lifecycle, end to end

Picture a request as a letter passed hand to hand through a line of clerks before it reaches the person who can actually answer it, and then passed back through the same line, in reverse, on its way out. Each clerk in Django's chain gets a look at the letter going in, and another look at the reply going out.

A request to a Django app running behind Gunicorn or uWSGI goes through these stages:

1. **WSGI server** (Gunicorn) accepts the TCP connection and parses the raw HTTP request into a WSGI environ dict.
2. **`WSGIHandler`** (`django.core.handlers.wsgi`) wraps that environ in an `HttpRequest` object.
3. **Middleware chain, request phase:** each middleware's code *before* it calls `get_response(request)` runs top to bottom, in the order listed in `MIDDLEWARE`.
4. **URL resolver:** Django walks `ROOT_URLCONF`, matches the path against `urlpatterns`, and resolves it to a view function plus any captured URL arguments. A failed match becomes a 404 response before any view code runs.
5. **View:** the matched view runs. This is where your business logic, database calls, and response-building happen. It returns an `HttpResponse`.
6. **Middleware chain, response phase:** each middleware's code *after* `get_response(request)` runs bottom to top, the reverse of step 3, letting each one add headers, compress the body, or set cookies on the way out.
7. **WSGI server** turns the `HttpResponse` back into raw HTTP bytes and writes them to the socket.

The detail interviewers actually probe for: **middleware is a chain of closures, not a list Django loops through.** Each middleware wraps the next one. `MIDDLEWARE = [A, B, C]` builds `A(B(C(view)))`. That's why `A`'s request-phase code runs before `B`'s, while `A`'s response-phase code runs *after* `B`'s: you're unwinding the exact call stack you built going in.

```python
# Simplified mental model of what Django builds from MIDDLEWARE
def build_chain(view, middlewares):
    handler = view
    for mw_class in reversed(middlewares):
        handler = mw_class(handler)  # each middleware wraps the previous handler
    return handler
```

> **Remember:** `MIDDLEWARE = [A, B, C]` builds `A(B(C(view)))`. Request-phase code runs A, B, C in order; response-phase code unwinds C, B, A.

```knowledge-check
{ "questions": [
    { "id": "backend-django-request-lifecycle-order-q1", "type": "mcq",
      "prompt": "MIDDLEWARE = [A, B, C]. In what order does each middleware's response-phase code (the part after get_response) run?",
      "options": [
        {"id":"a","text":"A, then B, then C -- the same order as request phase"},
        {"id":"b","text":"C, then B, then A -- the reverse of request phase, since each middleware wraps the next"},
        {"id":"c","text":"All three run at exactly the same time"},
        {"id":"d","text":"Only the last middleware's response-phase code runs"}
      ],
      "correct": "b",
      "explanation": "MIDDLEWARE = [A, B, C] builds A(B(C(view))). Going in, A's code runs first, then B's, then C's. Coming back out, you unwind the same stack: C's response code runs first, then B's, then A's." }
] }
```

## Writing middleware

Modern Django (1.10 and later) writes middleware as a class with one `__call__` entry point, not the older `process_request`/`process_response` hook pair (those still work through `MiddlewareMixin`, but they're the legacy style).

```python
# middleware.py
import time
import uuid
import logging

logger = logging.getLogger("request_timing")


class RequestTimingMiddleware:
    """Logs method, path, status code, and duration for every request."""

    def __init__(self, get_response):
        # Called once, at server startup -- expensive setup goes here, not in __call__.
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

Register both in `settings.py`. Order matters here too: put `RequestIDMiddleware` early, so the ID is already set before anything downstream, including exception logging, might want it.

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

One trade-off worth saying out loud in an interview: middleware runs on *every* request, including static files and health checks if they're routed through Django. Expensive middleware, a database lookup, an external call, belongs in a view decorator or the view itself, scoped to the routes that actually need it, not applied globally where it slows down everything.

> **Remember:** put cheap, universal middleware (request ID, timing) early in the list, and keep expensive checks (a DB lookup, an external call) out of middleware entirely; scope them to the views that need them instead.

```knowledge-check
{ "questions": [
    { "id": "backend-django-request-lifecycle-middleware-q1", "type": "mcq",
      "prompt": "Why is it a bad idea to put an expensive database lookup inside a globally registered middleware?",
      "options": [
        {"id":"a","text":"Middleware cannot access the database at all"},
        {"id":"b","text":"Middleware runs on every request, including static files and health checks, so the cost lands on requests that never needed it"},
        {"id":"c","text":"Django caches middleware output automatically, so this is never actually a problem"},
        {"id":"d","text":"Database lookups are faster inside middleware than inside a view"}
      ],
      "correct": "b",
      "explanation": "A globally registered middleware runs before every single request that reaches Django. An expensive check belongs in a view or decorator, scoped only to the routes that genuinely need it." }
] }
```

## A timing decorator for a single function

Middleware times a whole request. Sometimes you need to time one function instead: a slow database call, a serializer, a background task's body.

```python
import time
import functools
import logging

logger = logging.getLogger(__name__)


def timed(func):
    """Decorator that logs how long the wrapped function took to run."""

    @functools.wraps(func)  # preserves __name__/__doc__ -- without this, introspection and Django's URL naming break
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

`functools.wraps` is the detail interviewers probe for here. Without it, `generate_report.__name__` becomes `"wrapper"`, which quietly breaks anything relying on introspection: admin registration, some testing frameworks, chained `@method_decorator` calls.

> **Remember:** always add `@functools.wraps(func)` inside a decorator's inner function. Skipping it silently renames every function the decorator wraps.

```knowledge-check
{ "questions": [
    { "id": "backend-django-request-lifecycle-wraps-q1", "type": "mcq",
      "prompt": "A decorator's inner wrapper function forgets @functools.wraps(func). What breaks?",
      "options": [
        {"id":"a","text":"Nothing; wraps is purely cosmetic"},
        {"id":"b","text":"The wrapped function's __name__ and __doc__ get replaced by the wrapper's own, breaking anything that relies on introspection, like admin registration or method_decorator chains"},
        {"id":"c","text":"The decorated function stops running entirely"},
        {"id":"d","text":"Python raises a SyntaxError at import time"}
      ],
      "correct": "b",
      "explanation": "Without functools.wraps, the wrapped function's identity (name, docstring) is replaced by the generic wrapper's. Code that inspects a function by name, including Django's own tooling, sees 'wrapper' instead of the real name." }
] }
```

## What happens on a POST request specifically

This is the most-asked variant of the lifecycle question.

1. Same middleware and URL resolution as above.
2. If the view is a DRF `APIView`, **content negotiation** picks a parser (`JSONParser`, `MultiPartParser`, and so on) based on the request's `Content-Type`.
3. **CSRF check:** `CsrfViewMiddleware` validates the CSRF token for session-authenticated requests. This is skipped for API clients using token or JWT auth that don't rely on cookies.
4. The parser turns the body into `request.data` (DRF), or you read `request.POST`/`request.body` directly in plain Django.
5. Validation runs: a `Form.is_valid()` call, or a DRF `Serializer.is_valid()` call.
6. The view executes the write, typically inside a transaction if it touches more than one table.
7. Response serialization and the middleware unwind happen exactly as before.

A common follow-up: **"Where would you put a database transaction?"** Wrap the write in `django.db.transaction.atomic()` inside the view or a service function, not in middleware. Middleware has no idea where your table-level boundaries are, and wrapping every single request in a transaction wastes a database connection on read-only GET requests that never needed one.

> **Remember:** a transaction belongs around the actual write, in the view or a service function. Middleware doesn't know your table boundaries, and wrapping GETs in a transaction wastes connections for nothing.

```knowledge-check
{ "questions": [
    { "id": "backend-django-request-lifecycle-transaction-q1", "type": "mcq",
      "prompt": "Where should a multi-table database write be wrapped in transaction.atomic()?",
      "options": [
        {"id":"a","text":"In a middleware, so every request is automatically protected"},
        {"id":"b","text":"In the view or a service function, around the actual write, since middleware doesn't know your table-level boundaries"},
        {"id":"c","text":"In the WSGI server configuration"},
        {"id":"d","text":"It doesn't matter where, as long as it happens somewhere in the process"}
      ],
      "correct": "b",
      "explanation": "A transaction needs to know exactly where a unit of work starts and ends. Middleware runs for every request regardless of whether it touches the database at all, so wrapping every request in a transaction wastes connections on plain reads." }
] }
```
