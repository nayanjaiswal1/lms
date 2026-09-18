---
kind: lesson
id_key: advanced-python-interview/concurrency/concurrency-vs-parallelism
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "Concurrency vs Parallelism"
position: 1
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
These two words get used interchangeably in casual conversation, but they describe different things, and Python gives you distinct tools for each.

## Concurrency: managing multiple tasks, not necessarily running them simultaneously

**Concurrency** is about *structure* — dealing with more than one task over the same time period, interleaving progress on each, without requiring them to literally execute at the same instant. A single CPU core running two Python threads is concurrent: it switches between them, making progress on both, but only ever runs one at any given nanosecond.

## Parallelism: actually running at the same time

**Parallelism** is about *execution* — tasks genuinely running simultaneously, which requires multiple independent execution units: multiple CPU cores, or multiple processes.

```python
# Concurrent (interleaved, single core, GIL-limited) — good for IO-bound work
import threading, time

def fetch(name):
    time.sleep(1)  # simulates waiting on a network call
    print(f"{name} done")

threads = [threading.Thread(target=fetch, args=(f"req-{i}",)) for i in range(3)]
for t in threads: t.start()
for t in threads: t.join()
# All 3 finish in ~1s total, not 3s — while one waits on I/O, another runs.
# This is concurrency: interleaved progress, not necessarily simultaneous execution.
```

```python
# Parallel (separate processes, separate GILs, separate cores) — good for CPU-bound work
from multiprocessing import Process

def crunch(n):
    total = sum(i * i for i in range(n))

if __name__ == "__main__":
    procs = [Process(target=crunch, args=(10**7,)) for _ in range(4)]
    for p in procs: p.start()
    for p in procs: p.join()
    # These 4 processes can genuinely run on 4 different cores at once —
    # this is parallelism.
```

## Python's tools, mapped to the right job

| Tool | Concurrent? | Parallel? | Best for |
|---|---|---|---|
| `threading` | Yes | No (GIL-limited) | IO-bound: network, disk, DB calls |
| `asyncio` | Yes | No | IO-bound, especially many thousands of connections |
| `multiprocessing` | Yes | Yes (separate GILs) | CPU-bound: computation, image/data processing |

The recurring interview trap is reaching for `threading` on CPU-bound work expecting parallelism, or reaching for `multiprocessing` on IO-bound work and paying process-startup overhead for no benefit. Matching the tool to whether the bottleneck is *waiting* (threads/asyncio) or *computing* (processes) is the actual skill being tested.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-concurrency-vs-parallelism-q1",
      "type": "mcq",
      "prompt": "Two threads interleave on a single core, each making progress but never executing at the exact same instant. Is this concurrent, parallel, both, or neither?",
      "options": [
        { "id": "a", "text": "Concurrent only — structured to handle multiple tasks over the same period, without simultaneous execution" },
        { "id": "b", "text": "Parallel only" },
        { "id": "c", "text": "Both concurrent and parallel" },
        { "id": "d", "text": "Neither — a single core can't do either" }
      ],
      "correct": "a",
      "explanation": "Concurrency is about structure/interleaving; parallelism specifically requires simultaneous execution, which needs multiple cores or processes. A single core with interleaved threads is concurrent but not parallel."
    },
    {
      "id": "concurrency-concurrency-vs-parallelism-q2",
      "type": "mcq",
      "prompt": "Which Python tool should you reach for to genuinely parallelize a CPU-bound computation across cores?",
      "options": [
        { "id": "a", "text": "threading, since threads are lightweight" },
        { "id": "b", "text": "asyncio, since it handles many tasks efficiently" },
        { "id": "c", "text": "multiprocessing, since each process gets its own interpreter, memory, and GIL, enabling true multi-core execution" },
        { "id": "d", "text": "None — Python cannot parallelize CPU-bound work" }
      ],
      "correct": "c",
      "explanation": "threading and asyncio are both limited to one core's worth of Python bytecode execution at a time due to the GIL. multiprocessing sidesteps this entirely by giving each process its own GIL."
    }
  ]
}
```
