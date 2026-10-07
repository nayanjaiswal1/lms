---
kind: lesson
id_key: interview-prep-45/day-03-backend
course: interview-prep-45
section: backend-fastapi
section_title: "FastAPI"
section_position: 8
section_group: "Backend"
title: "FastAPI, ASGI, and Async"
position: 1
estimated_minutes: 40
source:
    - 45-day-interview-roadmap.md
    - interview-prep-notes.md
---

FastAPI's whole pitch is async performance, and an interviewer will push on whether you actually understand what "async" buys you, or you're just decorating functions with `async def` out of habit. This lesson covers WSGI vs ASGI, what `await` really does, running several I/O calls at once with `asyncio.gather`, and where FastAPI fits against Django and Flask.

## WSGI vs ASGI

Picture a restaurant with one waiter per table: the waiter stands at that table until the whole meal is served, unavailable to anyone else the entire time. That's WSGI. Now picture one waiter who takes an order, drops it at the kitchen window, and immediately goes to take the next table's order while the first meal cooks, coming back to each table exactly when its food is ready. That's ASGI.

**WSGI** (Web Server Gateway Interface) is synchronous, one request per thread: the server hands your app a request, your app blocks until it produces a response, and that thread is unavailable to anyone else in the meantime. Concurrency comes from running more worker processes or threads.

**ASGI** (Asynchronous Server Gateway Interface) lets one worker handle many connections at once, by cooperatively pausing whenever it's waiting on something. When your code hits `await` on a database call or an HTTP request, the event loop parks that piece of work and runs something else until the wait is over.

| | WSGI (Django default, Flask) | ASGI (FastAPI) |
|---|---|---|
| Concurrency model | OS threads/processes | One event loop plus coroutines |
| Scales by | Adding more workers | Handling more concurrent I/O-bound requests per worker |
| Best for | CPU-bound, simple synchronous code | I/O-bound: lots of concurrent database/HTTP calls |
| A blocking call inside it | Blocks one worker | Blocks the *entire event loop* |

That last row is the trap interviewers probe for: calling a blocking, synchronous function (`requests.get()`, `time.sleep()`, a sync database driver) inside an `async def` route freezes the whole event loop. Every other concurrent request on that worker stalls. FastAPI protects a plain `def` route automatically by running it in a thread pool, but the moment you write `async def` and then call blocking code inside it, you own the bug.

```python
# WRONG -- blocks the entire event loop for every concurrent request
@app.get("/bad")
async def bad_endpoint():
    time.sleep(2)  # blocking call inside an async route
    return {"ok": True}

# RIGHT -- either don't mark it async, or use the async-native equivalent
@app.get("/good")
def sync_endpoint():
    time.sleep(2)  # FastAPI runs def routes in a thread pool, so this doesn't block the loop
    return {"ok": True}

@app.get("/also-good")
async def async_sleep():
    await asyncio.sleep(2)  # yields control back to the event loop
    return {"ok": True}
```

> **Remember:** `async def` is a promise you'll only await non-blocking things. Break that promise once and every concurrent request on that worker pays for it.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-asgi-blocking-q1", "type": "mcq",
      "prompt": "Why does calling time.sleep(2) inside an async def route freeze every other concurrent request on that worker?",
      "options": [
        {"id":"a","text":"It doesn't; each request gets its own thread automatically"},
        {"id":"b","text":"A single-threaded event loop is running that coroutine; a blocking call never yields control back, so nothing else on that worker can run until it returns"},
        {"id":"c","text":"time.sleep() is disabled inside FastAPI routes"},
        {"id":"d","text":"Only the calling request is affected, never other requests"}
      ],
      "correct": "b",
      "explanation": "ASGI's concurrency comes from one event loop juggling many coroutines by yielding at await points. A blocking call never yields, so it holds the entire loop hostage until it finishes, stalling every other request that worker was serving." }
] }
```

## async / await, precisely

`async def` defines a **coroutine function**. Calling it returns a coroutine object immediately; it does not run the function body. `await` is what actually drives the coroutine forward, and it's also the point where control can be handed back to the event loop if the awaited thing isn't ready yet.

```python
async def fetch_user(user_id: int) -> dict:
    ...

coro = fetch_user(1)      # nothing has run yet -- this is just a coroutine object
result = await coro       # NOW the body runs, yielding control at any internal await
```

The one-line interview answer: **`await` doesn't block a thread. It suspends the current coroutine and lets the event loop run something else until the awaited operation is ready, then resumes exactly where it left off.**

> **Remember:** calling an `async def` function does nothing by itself. The body only runs once you `await` it.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-asgi-await-q1", "type": "mcq",
      "prompt": "What does `coro = fetch_user(1)` do, on its own, without an await?",
      "options": [
        {"id":"a","text":"Runs fetch_user's body to completion and stores the result in coro"},
        {"id":"b","text":"Creates a coroutine object without running any of the function body yet"},
        {"id":"c","text":"Raises a SyntaxError, since async functions must always be awaited immediately"},
        {"id":"d","text":"Blocks until fetch_user finishes"}
      ],
      "correct": "b",
      "explanation": "Calling a coroutine function just builds a coroutine object. Nothing inside it runs until that object is awaited (or otherwise scheduled on the event loop)." }
] }
```

## Running several I/O calls at once with asyncio.gather

This is the entire point of async in a web backend: fire off several independent I/O calls and wait for all of them concurrently, instead of one after another.

```python
import asyncio
import httpx
from fastapi import FastAPI, HTTPException

app = FastAPI()

async def fetch_json(client: httpx.AsyncClient, url: str) -> dict:
    response = await client.get(url, timeout=5.0)
    response.raise_for_status()
    return response.json()

@app.get("/aggregate")
async def aggregate_endpoint():
    urls = [
        "https://api.mindforge.test/users",
        "https://api.mindforge.test/orders",
        "https://api.mindforge.test/inventory",
    ]
    async with httpx.AsyncClient() as client:
        try:
            users, orders, inventory = await asyncio.gather(
                *(fetch_json(client, url) for url in urls),
                return_exceptions=False,
            )
        except httpx.HTTPStatusError as exc:
            raise HTTPException(
                status_code=502,
                detail=f"Upstream call failed: {exc.request.url}",
            ) from exc
        except httpx.TimeoutException as exc:
            raise HTTPException(status_code=504, detail="Upstream timeout") from exc

    return {"users": users, "orders": orders, "inventory": inventory}
```

Say the numbers out loud in an interview: three calls at 200 ms each, run sequentially, take 600 ms total. Run through `asyncio.gather`, all three are in flight at once, so the total is close to `max(latency)`, about 200 ms plus a little overhead, not `sum(latency)`.

**`return_exceptions` changes the failure behavior.** By default (`False`), the first exception raised by any task propagates right away, but the other tasks are not automatically canceled; they keep running in the background unless you handle cancellation yourself. Setting `return_exceptions=True` instead collects every exception as a result rather than raising, so you can inspect which calls failed without aborting the whole batch:

```python
results = await asyncio.gather(*tasks, return_exceptions=True)
succeeded = [r for r in results if not isinstance(r, Exception)]
failed = [r for r in results if isinstance(r, Exception)]
```

> **Remember:** sequential awaits sum their latencies; `asyncio.gather` takes the max. Three 200 ms calls become 600 ms sequentially, or about 200 ms concurrently.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-asgi-gather-q1", "type": "mcq",
      "prompt": "Three independent upstream calls each take 200 ms. Roughly how long does asyncio.gather over all three take, compared to awaiting them one at a time?",
      "options": [
        {"id":"a","text":"About 600 ms either way -- gather doesn't change total latency"},
        {"id":"b","text":"About 200 ms with gather (the max of the three), versus about 600 ms awaiting them sequentially (the sum)"},
        {"id":"c","text":"gather always takes longer, since it has scheduling overhead"},
        {"id":"d","text":"About 66 ms with gather, since it splits the work three ways"}
      ],
      "correct": "b",
      "explanation": "Sequential awaits pay for each call's latency in turn: 200+200+200=600ms. Gather starts all three at once, so total time tracks the slowest single call, about 200ms, plus a little overhead." }
] }
```

## Django vs FastAPI vs Flask: picking the right one

The three-way comparison an interviewer asks for when the question is "which framework would you pick for X," rather than "how does FastAPI's dependency injection work."

| | Django | Flask | FastAPI |
|---|---|---|---|
| Type | Full, batteries-included framework | Minimal micro-framework | Modern, async-first micro-framework |
| Concurrency | WSGI (sync) by default | WSGI (sync) | ASGI (async), natively |
| Validation | Forms / DRF serializers, manual | Manual, or an add-on | Pydantic, automatic from type hints |
| ORM | Built in | Bring your own (usually SQLAlchemy) | Bring your own (usually SQLAlchemy) |
| Admin panel | Built in, auto-generated | None | None |
| API docs | Manual, or DRF's browsable API | Manual, or an add-on | Automatic OpenAPI/Swagger, generated from type hints |
| Best for | Content-heavy sites, admin-driven CRUD, teams that want strong conventions | Small services, prototypes, full control over every piece | High-concurrency APIs, I/O-heavy services, type safety end to end |

**Pick Django** when the project needs an admin interface out of the box, a batteries-included ORM with migrations, and you're building a traditional web app, server-rendered templates, forms, sessions, rather than a pure API.

**Pick FastAPI** when the project is API-first, I/O-bound (many concurrent database or HTTP calls, exactly what ASGI's concurrency model is built for), and you want request and response validation plus OpenAPI docs generated automatically from Python type hints. FastAPI has no opinion on ORM or admin; you assemble those yourself, typically SQLAlchemy plus Alembic.

**Flask still wins** for a small, mostly synchronous service where you want minimal magic and full control over every piece, or an existing Flask codebase where a rewrite isn't worth it. FastAPI's advantages, async concurrency, automatic validation and docs, compound as the API surface and concurrent-request volume grow; for a handful of simple synchronous endpoints, Flask's simplicity is often the pragmatic choice.

The honest framing: Django gives you more for free but is heavier and synchronous by default. FastAPI gives you async concurrency and automatic validation and docs but requires assembling the rest of the stack yourself. Neither is unconditionally better; the decision hinges on whether you're building a full web application or a high-throughput API service.

> **Remember:** Django for a full web app with an admin and an ORM built in. FastAPI for an API-first, I/O-heavy service that wants type-hint-driven validation and docs. Flask when you want minimal magic and are happy assembling everything yourself.

```knowledge-check
{ "questions": [
    { "id": "backend-fastapi-asgi-framework-choice-q1", "type": "mcq",
      "prompt": "A team is building an I/O-heavy API service with many concurrent calls to other services, and wants request validation and API docs generated automatically from type hints. Which framework fits best?",
      "options": [
        {"id":"a","text":"Django, for its built-in admin panel"},
        {"id":"b","text":"FastAPI, since ASGI concurrency suits I/O-bound work and Pydantic generates validation and OpenAPI docs from type hints automatically"},
        {"id":"c","text":"Flask, since it has the shallowest learning curve"},
        {"id":"d","text":"Any of the three would be identical for this use case"}
      ],
      "correct": "b",
      "explanation": "FastAPI's ASGI concurrency model is built exactly for many concurrent I/O-bound calls, and its Pydantic integration gives automatic validation and OpenAPI docs from type hints, which is the specific pair of requirements described here." }
] }
```
