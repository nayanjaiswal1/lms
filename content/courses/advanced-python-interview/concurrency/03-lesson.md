---
kind: lesson
id_key: advanced-python-interview/concurrency/multithreading
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "Multithreading"
position: 2
estimated_minutes: 18
source: ["fifty-advanced-python-concepts/10.multithreading.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
Threads share the same process memory space and are lightweight to create — and because a thread blocked on I/O releases the GIL, threading is Python's go-to tool for running many blocking operations (network requests, file reads, DB queries) concurrently.

## Manual threads

```python
import threading
import time

def download(url):
    print(f"Starting download: {url}")
    time.sleep(2)  # simulates network wait — GIL is released during this
    print(f"Finished download: {url}")

urls = ["url1", "url2", "url3"]

threads = []
for url in urls:
    t = threading.Thread(target=download, args=(url,))
    threads.append(t)
    t.start()

for t in threads:
    t.join()  # block until every thread finishes

print("All downloads completed")
# Total time: ~2s (all three overlap), not 6s (sequential)
```

`.start()` launches the thread; `.join()` blocks the calling thread until it finishes. Forgetting to `.join()` doesn't crash anything, but it means your program can exit (or move on) before background threads finish their work.

## The preferred pattern: `ThreadPoolExecutor`

Manually managing a list of `Thread` objects, starting them, and joining them is boilerplate that's easy to get subtly wrong (leaking threads, not propagating exceptions). `concurrent.futures.ThreadPoolExecutor` manages a fixed pool of worker threads for you:

```python
from concurrent.futures import ThreadPoolExecutor
import time

def download(url):
    print(f"Downloading: {url}")
    time.sleep(2)
    print(f"Finished: {url}")

urls = ["url1", "url2", "url3"]

with ThreadPoolExecutor() as executor:
    executor.map(download, urls)
# The pool is automatically joined and cleaned up when the `with` block exits
```

`ThreadPoolExecutor` also gives you `.submit()` for individual tasks with real `Future` objects (so you can catch exceptions raised inside a thread, which manual `Thread` objects silently swallow unless you check `.exception()` yourself), and it reuses a bounded number of worker threads instead of spawning one OS thread per task — important once you're launching hundreds of concurrent requests rather than three.

## When threading is (and isn't) the right call

Threading shines specifically when a task spends most of its time **waiting**, not computing — an HTTP request, a database round-trip, reading a large file from a slow disk. During that wait, the GIL is released and other threads run. The moment the work becomes CPU-bound (parsing, hashing, numeric computation), threading stops helping — see the GIL lesson — and `multiprocessing` becomes the right tool instead.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-multithreading-q1",
      "type": "mcq",
      "prompt": "Why does time.sleep(2) inside a thread allow other threads to make progress, despite the GIL?",
      "options": [
        { "id": "a", "text": "time.sleep() explicitly releases the GIL while the thread is blocked" },
        { "id": "b", "text": "sleep() runs outside the GIL's scope entirely by using a separate interpreter" },
        { "id": "c", "text": "The GIL doesn't apply to the first thread started" },
        { "id": "d", "text": "sleep() disables the GIL globally for the process" }
      ],
      "correct": "a",
      "explanation": "I/O and blocking calls like sleep() release the GIL while waiting, which is exactly why threading helps for I/O-bound work: other threads get to run Python bytecode during that wait."
    },
    {
      "id": "concurrency-multithreading-q2",
      "type": "mcq",
      "prompt": "What's the main practical advantage of ThreadPoolExecutor over manually creating and joining Thread objects?",
      "options": [
        { "id": "a", "text": "It bypasses the GIL entirely" },
        { "id": "b", "text": "It manages a bounded pool of reusable worker threads and handles cleanup/joining automatically, avoiding the boilerplate and pitfalls of manual thread management" },
        { "id": "c", "text": "It makes threads run in parallel on separate cores" },
        { "id": "d", "text": "It's required for any thread that uses time.sleep()" }
      ],
      "correct": "b",
      "explanation": "ThreadPoolExecutor manages a fixed-size pool, reuses threads across tasks, exposes Future objects for exception handling, and automatically joins on context-manager exit — none of which manual Thread management gives you for free."
    }
  ]
}
```
