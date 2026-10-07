---
kind: lesson
id_key: production-debugging/lesson-latency-and-slow-apis
course: production-debugging
section: fastapi-latency
section_title: "Latency and slow APIs"
section_position: 21
section_group: "FastAPI"
title: "Debugging a slow API: blocked loops, sequential awaits and throwaway clients"
position: 1
estimated_minutes: 20
source:
    - docs/debug-labs.md
---

A slow API has three usual suspects that no profiler of your own code shows at first: something stops the event loop, independent waits run one after another, or every call pays for setup it should have paid once. The skill this section trains is turning "it feels slow" into a number that points at one of them.

## A blocking call stops everyone

An `async def` handler shares one thread with every other request of the process. A synchronous call that waits (`time.sleep`, `requests`, a legacy client, heavy CPU work) holds that thread, so unrelated requests, even `/healthz`, wait behind it. The test is to time a cheap endpoint while the suspect endpoint runs. The cure is to move the call off the loop (`run_in_threadpool`, `asyncio.to_thread`) or to use an async client. Adding `await` in front of a synchronous function, a lock around it, or `asyncio.wait_for` does not make it yield.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-blocking-q1",
      "type": "mcq",
      "prompt": "Search calls a synchronous lookup that waits 300 ms inside an async def handler. While 5 searches run, what happens to GET /healthz?",
      "options": [
        { "id": "a", "text": "It answers normally, async handlers run in parallel" },
        { "id": "b", "text": "It waits behind the searches, because the blocked event loop cannot run anything else" },
        { "id": "c", "text": "It fails with a 500 because the pool is full" },
        { "id": "d", "text": "Only requests from the same client are delayed" }
      ],
      "correct": "b",
      "explanation": "The synchronous call keeps the single event loop thread busy. Every other coroutine, including the health check, only runs when the loop is free again."
    }
  ]
}
```

## Independent waits should overlap

When a handler needs two things that do not depend on each other (two remote services, two queries on separate sessions), `await a(); await b()` costs the sum of both. `asyncio.gather(a(), b())` starts both and costs the longest. Measure each dependency alone, then the endpoint: a total close to the sum is the signature. Calls that need each other's result, or that share one `AsyncSession`, must stay sequential.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-gather-q1",
      "type": "mcq",
      "prompt": "A page awaits two independent 300 ms lookups one after another. Roughly how long does it take, and what is the fix?",
      "options": [
        { "id": "a", "text": "About 300 ms, nothing to fix" },
        { "id": "b", "text": "About 600 ms; start both with asyncio.gather" },
        { "id": "c", "text": "About 600 ms; wrap each lookup in asyncio.wait_for" },
        { "id": "d", "text": "About 300 ms; add a lock so they do not interfere" }
      ],
      "correct": "b",
      "explanation": "Sequential awaits add their latencies. gather runs the two waits at the same time, so the total becomes the longer one. wait_for only adds a timeout and a lock would force them to run one at a time."
    }
  ]
}
```

## Build the client once

An `httpx.AsyncClient` owns a connection pool with keep-alive. Creating one per call and closing it at the end of the block throws the pool away, so every call pays for a new TCP (and in production TLS) handshake and leaves a socket in TIME_WAIT. On localhost this is invisible, which is why it survives review. Create the client once at startup, share it, and close it at shutdown. Counting how often the client is constructed is a better test than timing.

```knowledge-check
{
  "questions": [
    {
      "id": "production-debugging-fa-latency-client-q1",
      "type": "mcq",
      "prompt": "Why does building an httpx.AsyncClient inside every request handler hurt, even though each call succeeds?",
      "options": [
        { "id": "a", "text": "The client is not thread safe" },
        { "id": "b", "text": "Each client discards its connection pool, so every call opens a new connection and handshake" },
        { "id": "c", "text": "httpx forbids more than one client per process" },
        { "id": "d", "text": "It makes the response body larger" }
      ],
      "correct": "b",
      "explanation": "The pool and its keep-alive connections belong to the client. A client that lives for one call can never reuse a connection, so the setup cost is paid every time."
    }
  ]
}
```
