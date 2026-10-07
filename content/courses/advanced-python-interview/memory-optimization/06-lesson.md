---
kind: lesson
id_key: advanced-python-interview/performance-testing/async-memory-antipatterns
course: advanced-python-interview
section: memory-optimization
section_title: "Memory Optimization"
section_position: 6
section_group: Advanced
title: "Memory & Resource Anti-Patterns in Async Services"
position: 4
estimated_minutes: 12
source: ["knowledge/backend/python/async-memory-patterns.md"]
---
Long-running async services rarely fail from one big bug. They bloat from many small habits: too many copies alive at once, caches that never evict, tasks nobody tracks. This lesson condenses the common culprits into five themes you can name in an interview and check for in a code review.

## Allocation and lifetime

Memory peaks come from objects that live longer, or exist in more copies, than necessary.

- **Build expensive objects inside the concurrency gate.** If you create a large string or rendered prompt *before* acquiring a semaphore, N tasks hold N copies at once. Create it after, so at most `limit` copies exist.
- **`del` large objects after last use**, especially before an `await`; a local stays alive until the scope ends even if it is never read again.
- **Do not accumulate everything, then serialize.** Objects and their serialized bytes coexist at peak. Serialize incrementally and drop the source.
- **Avoid chains of string copies.** `s = s[:n]; s = s[:m]; s += tail` makes three objects; compute the cut position on the original and slice once.
- **Buffer and copy coexist.** `buf.getvalue()` returns a copy while `buf` still holds the original. `del buf` right after (same for `StringIO`, `BytesIO`).

```python
import asyncio

async def render(i):
    return "x" * 1_000_000  # stand-in for an expensive rendered object

async def worker(i, gate, results):
    async with gate:                 # build inside the gate: at most 2 live at once
        payload = await render(i)
        results.append(len(payload))
        del payload                  # release before the slot is freed

async def main():
    gate = asyncio.Semaphore(2)
    results = []
    await asyncio.gather(*(worker(i, gate, results) for i in range(6)))
    print(results)

asyncio.run(main())  # [1000000, 1000000, 1000000, 1000000, 1000000, 1000000]
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-async-memory-antipatterns-q1",
      "type": "mcq",
      "prompt": "Why should an expensive object be built inside a semaphore block rather than before it?",
      "options": [
        { "id": "a", "text": "Otherwise every waiting task already holds its own copy, so peak memory scales with total tasks, not the limit" },
        { "id": "b", "text": "Semaphores free memory automatically on release" },
        { "id": "c", "text": "It makes the object immutable" },
        { "id": "d", "text": "Python forbids allocation outside async with" }
      ],
      "correct": "a",
      "explanation": "The gate bounds concurrency only for code inside it; anything built earlier exists once per task."
    },
    {
      "id": "performance-testing-async-memory-antipatterns-q2",
      "type": "mcq",
      "prompt": "After `data = buf.getvalue()`, what keeps peak memory high?",
      "options": [
        { "id": "a", "text": "`getvalue()` returns a view, not a copy" },
        { "id": "b", "text": "The buffer still holds the original while `data` is a second copy" },
        { "id": "c", "text": "Strings are always cached forever" },
        { "id": "d", "text": "The garbage collector is disabled in async code" }
      ],
      "correct": "b",
      "explanation": "Two copies coexist until you `del buf` (or let it leave scope)."
    }
  ]
}
```

## Caching without bounds

A cache is a deliberate memory leak unless it has a limit and a lifecycle.

- **Unbounded dict caches** grow forever; add a max size and eviction (or a TTL).
- **`@lru_cache` without a deliberate `maxsize`**: the default is 128, which hides intent. A zero-argument function only needs `maxsize=1`.
- **Module-level caches never cleared** accumulate every request's data. Scope the cache to the request or task, or clear it at the boundary.

```python
from functools import lru_cache

@lru_cache(maxsize=1)           # zero-arg config loader: one slot is enough
def load_config():
    return {"region": "ap-southeast-1"}

print(load_config() is load_config())  # True
print(load_config.cache_info().maxsize)  # 1
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-async-memory-antipatterns-q3",
      "type": "mcq",
      "prompt": "A module-level dict is filled on every request and never cleared. What is the problem?",
      "options": [
        { "id": "a", "text": "It makes requests slower only on the first call" },
        { "id": "b", "text": "It accumulates data from every request and grows without bound" },
        { "id": "c", "text": "Python deletes it automatically after each request" },
        { "id": "d", "text": "It is thread-unsafe but memory-neutral" }
      ],
      "correct": "b",
      "explanation": "Module globals live for the process lifetime, so unbounded growth is a leak. Clear it per task or bound it."
    }
  ]
}
```

## Concurrency mistakes in asyncio

- **Creating all coroutines up front and gating late.** `as_completed([f(x) for x in items])` creates every coroutine immediately; any setup before the semaphore runs N times in parallel. Move setup inside the gated section.
- **Fire-and-forget `asyncio.create_task`.** The event loop keeps only a weak reference to tasks, so an untracked task can be garbage-collected mid-flight and is dropped at shutdown. Await it, or hold a reference and discard it when done.
- **`asyncio.get_event_loop()`** is deprecated outside a running loop; inside async code use `asyncio.get_running_loop()`.
- **A new client or connection pool per request.** Under load that is N pools and N TCP connections alive together. Share one client for the process.

```python
import asyncio

background = set()

def spawn(coro):
    task = asyncio.create_task(coro)
    background.add(task)                    # strong reference keeps it alive
    task.add_done_callback(background.discard)
    return task

async def job():
    await asyncio.sleep(0)
    return "done"

async def main():
    task = spawn(job())
    print(await task)       # done
    print(len(background))  # 0

asyncio.run(main())
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-async-memory-antipatterns-q4",
      "type": "mcq",
      "prompt": "Why keep a reference to a task created with `asyncio.create_task`?",
      "options": [
        { "id": "a", "text": "Tasks only run when referenced by a variable name" },
        { "id": "b", "text": "The loop holds tasks weakly, so an unreferenced task can be garbage-collected before it finishes" },
        { "id": "c", "text": "It makes the task run on another thread" },
        { "id": "d", "text": "References are needed to cancel the event loop" }
      ],
      "correct": "b",
      "explanation": "Keep the task in a set (and discard on completion), or await it, so it is not collected mid-flight."
    },
    {
      "id": "performance-testing-async-memory-antipatterns-q5",
      "type": "mcq",
      "prompt": "Creating a new HTTP client for every request in a high-traffic service mainly causes what?",
      "options": [
        { "id": "a", "text": "Better isolation with no cost" },
        { "id": "b", "text": "Many clients and connections alive at peak concurrency, wasting RAM and sockets" },
        { "id": "c", "text": "Automatic connection reuse" },
        { "id": "d", "text": "A deprecation warning" }
      ],
      "correct": "b",
      "explanation": "Share one client or pool so connections are reused and memory stays flat."
    }
  ]
}
```

## I/O and loading

- **Open a file once per call**, pass the handle down, and close after the last use, instead of reopening it in each helper.
- **Do not read a whole file for metadata.** Use lazy or streaming reads (first page, header) when the format allows.
- **Do not define classes or run imports inside hot functions.** The body re-executes on every call. Move it to module level or a lazy singleton.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-async-memory-antipatterns-q6",
      "type": "mcq",
      "prompt": "You only need a PDF's page count. What is the resource-friendly approach?",
      "options": [
        { "id": "a", "text": "Read the entire file into memory, then count" },
        { "id": "b", "text": "Open it separately in every helper function" },
        { "id": "c", "text": "Use a lazy or streaming read that touches only the header or metadata" },
        { "id": "d", "text": "Convert it to a string first" }
      ],
      "correct": "c",
      "explanation": "Reading less data means lower peak memory and faster responses."
    }
  ]
}
```

## Process lifetime

CPython's allocator often keeps freed memory in its own pools, so the process footprint does not shrink after one huge task even though the objects are gone. Two practical consequences:

- **Recycle workers** after N tasks (for example Celery's `--max-tasks-per-child`) so the OS reclaims the bloated heap.
- **Never attach per-task data to long-lived service objects.** Parsed results or rendered bytes stored on a process-lifetime instance are a leak; keep them in local variables.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-async-memory-antipatterns-q7",
      "type": "mcq",
      "prompt": "A worker's memory stays high after a single huge task finishes and the objects are freed. What is a standard mitigation?",
      "options": [
        { "id": "a", "text": "Call `gc.collect()` after every line" },
        { "id": "b", "text": "Recycle the worker process after a set number of tasks" },
        { "id": "c", "text": "Switch to global variables" },
        { "id": "d", "text": "Increase the cache `maxsize`" }
      ],
      "correct": "b",
      "explanation": "Freed memory may stay in Python's allocator pools; restarting the worker returns it to the OS."
    }
  ]
}
```
