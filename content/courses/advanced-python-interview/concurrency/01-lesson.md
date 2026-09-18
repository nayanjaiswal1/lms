---
kind: lesson
id_key: advanced-python-interview/concurrency/gil
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "The Global Interpreter Lock (GIL)"
position: 0
estimated_minutes: 18
source: ["fifty-advanced-python-concepts/8.global_interpreter_lock.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
The **Global Interpreter Lock (GIL)** is a single mutex inside CPython that ensures only one thread executes Python bytecode at any instant — even on a machine with 16 cores, and even with 16 Python threads running. It exists because CPython's reference counting (every object's refcount incremented/decremented on almost every operation) is not thread-safe by default; wrapping every single refcount update in its own lock would be correct but brutally slow, so CPython instead takes one coarse lock around bytecode execution itself.

## Seeing it in action

```python
import threading
import time

def cpu_task():
    total = 0
    for _ in range(10**7):
        total += 1

threads = [threading.Thread(target=cpu_task) for _ in range(4)]

start = time.time()
for t in threads:
    t.start()
for t in threads:
    t.join()

print(f"4 threads, CPU-bound: {time.time() - start:.2f}s")
# Roughly the SAME as running cpu_task() four times sequentially —
# the GIL means only one thread's bytecode runs at a time.
```

Run that against a single-threaded loop of the same total work and the wall-clock time is nearly identical — the four threads never actually run in parallel on separate cores; they take turns holding the GIL, switching every so often (CPython's scheduler periodically forces a switch so no thread starves).

## What the GIL does and doesn't affect

- **CPU-bound work on threads: no speedup.** Pure computation (tight loops, number crunching) doesn't benefit from more `threading.Thread`s, because only one thread's bytecode ever runs at once. This is the single most common threading mistake: reaching for `threading` to parallelize CPU work and being confused why it isn't faster.
- **IO-bound work on threads: real speedup.** A thread blocked on a network call, disk read, or `time.sleep` **releases the GIL** while waiting, letting another thread run. This is why threads are still the right tool for concurrent downloads, database queries, or file I/O.
- **Multiprocessing is unaffected.** Each process gets its own Python interpreter, its own memory space, and its own GIL — the next lesson covers this as the actual way to get CPU-bound parallelism in Python.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-gil-q1",
      "type": "mcq",
      "prompt": "Why does CPython have a Global Interpreter Lock at all?",
      "options": [
        { "id": "a", "text": "To make Python syntax simpler" },
        { "id": "b", "text": "To keep reference counting (CPython's memory management) thread-safe without locking every individual object" },
        { "id": "c", "text": "To prevent developers from using multiprocessing" },
        { "id": "d", "text": "It's a historical accident with no technical reason" }
      ],
      "correct": "b",
      "explanation": "CPython uses reference counting for memory management. A single coarse lock around bytecode execution keeps refcount updates safe without the overhead of per-object locking."
    },
    {
      "id": "concurrency-gil-q2",
      "type": "mcq",
      "prompt": "Four Python threads run a tight CPU-bound loop on an 8-core machine. What speedup should you expect over one thread doing the same total work?",
      "options": [
        { "id": "a", "text": "Roughly 4x, since threads run independently" },
        { "id": "b", "text": "Roughly 8x, using all available cores" },
        { "id": "c", "text": "Essentially no speedup — only one thread executes Python bytecode at a time under the GIL" },
        { "id": "d", "text": "It depends only on available RAM, not cores" }
      ],
      "correct": "c",
      "explanation": "The GIL means CPU-bound Python threads take turns, not run in parallel — total wall-clock time for the same total work is roughly unchanged versus doing it in one thread."
    }
  ]
}
```
