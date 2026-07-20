---
kind: lesson
id_key: interview-prep-45/day-03-backend
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Day 3 — FastAPI ASGI and Async"
position: 3
estimated_minutes: 45
source:
    - 45-day-interview-roadmap.md
---
FastAPI's whole pitch is async performance, and interviewers will push on whether you actually understand what "async" buys you or if you're just decorating functions with `async def` out of habit. Today: ASGI vs WSGI, what `await` really does, concurrent I/O with `asyncio.gather`, and error handling that doesn't swallow exceptions in a task group.

## WSGI vs ASGI

**WSGI** (Web Server Gateway Interface) is synchronous and one-request-per-thread: the server hands your app a request, your app blocks until it produces a response, the thread is unavailable to anyone else in the meantime. Concurrency comes from spinning up more worker processes/threads (Gunicorn workers).

**ASGI** (Asynchronous Server Gateway Interface) lets a single worker handle many concurrent connections by cooperatively yielding control during I/O waits. When your code hits an `await` on a DB call or HTTP request, the event loop parks that coroutine and runs another one until the I/O completes.

| | WSGI (Django default, Flask) | ASGI (FastAPI, Django Channels) |
|---|---|---|
| Concurrency model | OS threads/processes | Single-threaded event loop + coroutines |
| Scales with | More workers | More concurrent I/O-bound requests per worker |
| Best for | CPU-bound, simple sync code | I/O-bound: many concurrent DB/HTTP calls |
| Blocking a sync function | Blocks one worker | Blocks the *entire event loop* — the big footgun |

**The footgun interviewers probe for:** calling a blocking, synchronous function (e.g. `requests.get()`, `time.sleep()`, a sync DB driver) inside an `async def` route freezes the whole event loop — every other concurrent request on that worker stalls. FastAPI mitigates this for `def` (non-async) routes by running them in a thread pool automatically, but if you write `async def` and then call blocking code inside it, you own the bug.

```python
# WRONG — blocks the entire event loop for every concurrent request
@app.get("/bad")
async def bad_endpoint():
    time.sleep(2)  # blocking call inside an async route
    return {"ok": True}

# RIGHT — either don't mark it async, or use the async-native equivalent
@app.get("/good")
def sync_endpoint():
    time.sleep(2)  # FastAPI runs def routes in a thread pool, so this doesn't block the loop
    return {"ok": True}

@app.get("/also-good")
async def async_sleep():
    await asyncio.sleep(2)  # yields control back to the event loop
    return {"ok": True}
```

## async / await, precisely

`async def` defines a **coroutine function** — calling it returns a coroutine object immediately, it does not run the body. `await` is what actually drives the coroutine forward and yields control back to the event loop whenever the awaited thing isn't ready.

```python
async def fetch_user(user_id: int) -> dict:
    ...

coro = fetch_user(1)      # nothing has run yet — this is a coroutine object
result = await coro       # NOW the body executes, with control returned to the loop on any internal await
```

Interview one-liner: **`await` doesn't block a thread — it suspends the current coroutine and lets the event loop run something else until the awaited operation completes, then resumes exactly where it left off.**

## Concurrent I/O with asyncio.gather

The whole point of async in a web backend: fire off multiple independent I/O calls and wait for all of them concurrently instead of sequentially.

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
        "https://api.example.com/users",
        "https://api.example.com/orders",
        "https://api.example.com/inventory",
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

Sequential version of the same three calls takes `sum(latency)`; `asyncio.gather` takes `max(latency)` because all three requests are in flight at once. That's the number to quote in an interview: three 200ms calls sequentially is 600ms, concurrently it's ~200ms plus overhead.

**`return_exceptions` matters:** by default (`False`), the first exception raised by any task propagates immediately and cancels the rest is *not* automatic — the other tasks keep running in the background unless you handle cancellation explicitly. Setting `return_exceptions=True` instead collects exceptions as results instead of raising, letting you inspect which calls failed without aborting the whole batch:

```python
results = await asyncio.gather(*tasks, return_exceptions=True)
succeeded = [r for r in results if not isinstance(r, Exception)]
failed = [r for r in results if isinstance(r, Exception)]
```

## Background tasks for fire-and-forget work

For work that shouldn't block the response but doesn't need a full task queue (see Day 8's Celery lesson for heavier jobs):

```python
from fastapi import BackgroundTasks

def send_confirmation_email(email: str, order_id: int) -> None:
    # runs after the response is sent, in the same process
    ...

@app.post("/orders/{order_id}/confirm")
async def confirm_order(order_id: int, background_tasks: BackgroundTasks):
    # do the fast, synchronous work first
    background_tasks.add_task(send_confirmation_email, "user@example.com", order_id)
    return {"status": "confirmed"}
```

`BackgroundTasks` runs after the response is returned to the client but still inside the same worker process — it is not durable (a worker crash loses the task) and not distributed. That distinction — durable queue vs in-process background task — is exactly what Day 11 digs into.

## Measuring sync vs async

```python
import time
import asyncio
import httpx

async def timed_gather(urls):
    start = time.perf_counter()
    async with httpx.AsyncClient() as client:
        await asyncio.gather(*(client.get(u) for u in urls))
    return time.perf_counter() - start

def timed_sequential(urls):
    import requests
    start = time.perf_counter()
    for u in urls:
        requests.get(u)
    return time.perf_counter() - start
```

Run both against the same set of URLs with artificial latency (e.g. `httpbin.org/delay/1`) and you'll see the sequential version scale linearly with the number of URLs while the concurrent version stays close to the slowest single call.

## Key takeaways

- WSGI = one worker per in-flight request; ASGI = one event loop juggling many coroutines during I/O waits.
- A blocking call inside `async def` freezes the entire event loop for every concurrent request on that worker — that's the #1 async bug to name in interviews.
- `await` suspends a coroutine and returns control to the event loop; it does not block an OS thread.
- `asyncio.gather` turns `sum(latency)` into `max(latency)` for independent I/O calls — quote real numbers when explaining the win.
- `return_exceptions=True` on `gather` is how you avoid one failed call aborting a whole batch.
- `BackgroundTasks` is in-process and non-durable — for anything that must survive a worker crash, use a real queue (Celery/RQ), not `BackgroundTasks`.

## Today's checklist

- [ ] Read: ASGI vs WSGI difference
- [ ] Implement: async endpoint with a background task
- [ ] Implement: measure the difference between a sync and async function
- [ ] Build endpoint that fetches from 3 APIs concurrently using `asyncio.gather`
- [ ] Implement proper error handling in an async context
- [ ] Be ready to answer: what is the difference between async and await? How does FastAPI handle concurrency?
