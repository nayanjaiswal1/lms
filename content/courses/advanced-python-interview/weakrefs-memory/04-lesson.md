---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/memory-profiler
course: advanced-python-interview
section: weakrefs-memory
section_title: "Weak References & Memory Optimization"
section_position: 6
title: "memory_profiler"
position: 3
estimated_minutes: 12
source: [fifty-advanced-python-concepts/43.memory_profiler.py, fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md]
---
Knowing *that* a program uses too much memory is easy — knowing *which line* is responsible is the actual debugging work. `memory_profiler` is a third-party package built for exactly that: line-by-line memory usage inside a specific function.

## The `@profile` decorator (needs its own runner)

```python
# requires: pip install memory-profiler, then run with `python -m memory_profiler script.py`
# (the @profile decorator only activates under that runner -- it can't run standalone)
from memory_profiler import profile


@profile
def my_function():
    a = [i for i in range(100_000)]   # allocates a list of 100k ints
    b = [i * 2 for i in a]            # allocates a second list
    return b


if __name__ == "__main__":
    my_function()
```

Running that under `python -m memory_profiler script.py` prints a line-by-line table: memory usage before and after each line, and how much that line added. That per-line increment is the whole value proposition — a regular profiler tells you which *function* is slow, `memory_profiler` tells you which *line inside* that function is the one allocating memory you didn't expect.

## Getting the same signal from the standard library

`memory_profiler` needs to be installed and run through its own entry point, so it can't execute inside a plain `python file.py` run. The stdlib's `tracemalloc` module covers a lot of the same ground without an extra dependency — it can't attribute cost to individual source lines inside one profiler run the way `memory_profiler` can, but it can snapshot allocations and tell you where they came from:

```python
import tracemalloc

tracemalloc.start()

snapshot_before = tracemalloc.take_snapshot()

a = [i for i in range(100_000)]
b = [i * 2 for i in a]

snapshot_after = tracemalloc.take_snapshot()

top_stats = snapshot_after.compare_to(snapshot_before, "lineno")
for stat in top_stats[:3]:
    print(stat)

tracemalloc.stop()
```

`compare_to` reports the size delta per allocation site (file + line number) between the two snapshots, which is the same "which line grew memory" question `memory_profiler` answers — `tracemalloc` just requires you to bracket the code with explicit snapshots instead of decorating a function.

## When to reach for this

Neither tool is something you run in production continuously — both add real overhead. Reach for line-level memory profiling when a specific function is suspected of a leak or excessive allocation and you've already narrowed the problem down that far (via `sys.getsizeof`, general monitoring, or just watching RSS climb); it's a targeted debugging tool, not a monitoring strategy.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-memory-profiler-q1",
      "type": "mcq",
      "prompt": "What does memory_profiler's @profile decorator give you that a normal time-based profiler doesn't?",
      "options": [
        { "id": "a", "text": "Faster overall function execution" },
        { "id": "b", "text": "A line-by-line breakdown of memory usage inside the decorated function" },
        { "id": "c", "text": "Automatic memory leak fixes" },
        { "id": "d", "text": "CPU usage instead of memory usage" }
      ],
      "correct": "b",
      "explanation": "memory_profiler's @profile output shows memory before/after and the delta for each individual line in the function, pinpointing exactly which line is responsible for an allocation."
    },
    {
      "id": "weakrefs-memory-memory-profiler-q2",
      "type": "mcq",
      "prompt": "Why can't the @profile-decorated example run under plain `python script.py`?",
      "options": [
        { "id": "a", "text": "It's a syntax error in modern Python" },
        { "id": "b", "text": "@profile's line-by-line reporting only activates when run through the `python -m memory_profiler` entry point" },
        { "id": "c", "text": "memory_profiler only works on macOS" },
        { "id": "d", "text": "The function itself has a bug" }
      ],
      "correct": "b",
      "explanation": "memory_profiler's line-by-line output requires its own runner (`python -m memory_profiler` or the `mprof` CLI) to hook into and report per-line memory deltas -- the decorator alone under plain python won't produce that report."
    }
  ]
}
```
