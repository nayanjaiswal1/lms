---
kind: lesson
id_key: advanced-python-interview/performance-testing/optimizing-slow-code
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 5
section_group: Advanced
title: "Optimizing Slow Python Code"
position: 5
estimated_minutes: 13
source: ["knowledge/backend/python/python-internals.md"]
---
"How would you speed up slow Python code?" is a staple. The strong answer has an order: measure first, fix the algorithm and data structure, then reach for caching, vectorised libraries, and finally parallelism or compilation.

## Profile before you optimize

Guessing where time goes is usually wrong. `cProfile` reports time per function; `line_profiler` (a third-party package) reports time per line of a function you decorate with `@profile`. Optimize only the hot spot, then measure again to confirm the change helped.

```python
import cProfile
import io
import pstats

def slow_sum(n):
    total = 0
    for i in range(n):
        total += i
    return total

def work():
    return slow_sum(200_000)

profiler = cProfile.Profile()
profiler.enable()
work()
profiler.disable()

stream = io.StringIO()
pstats.Stats(profiler, stream=stream).sort_stats("cumulative").print_stats(5)
print("slow_sum" in stream.getvalue())  # True: the report names the hot function
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-optimizing-slow-code-q1",
      "type": "mcq",
      "prompt": "What is the right first step when asked to speed up a slow Python program?",
      "options": [
        { "id": "a", "text": "Rewrite it in Cython" },
        { "id": "b", "text": "Add multiprocessing" },
        { "id": "c", "text": "Profile it to find the real bottleneck" },
        { "id": "d", "text": "Replace every list with a generator" }
      ],
      "correct": "c",
      "explanation": "Use cProfile (function level) or line_profiler (line level) so effort goes to the code that is actually slow."
    }
  ]
}
```

## Use builtins, the right data structure, and less work per iteration

Most wins are not clever. Built-ins and libraries such as NumPy run their loops in C. A set or dict turns a repeated O(n) scan into O(1). Work that does not change between iterations belongs before the loop.

```python
import math

data = list(range(2000))
lookups = list(range(0, 4000, 2))

# Slow: O(n) list scan per lookup
slow_hits = 0
for x in lookups:
    if x in data:
        slow_hits += 1

# Faster: set membership, builtin sum, invariant hoisted out of the loop
data_set = set(data)
fast_hits = sum(1 for x in lookups if x in data_set)

factor = math.sqrt(2)  # computed once, not per iteration
scaled = [x * factor for x in data]

assert slow_hits == fast_hits == 1000
print(fast_hits, len(scaled))  # 1000 2000
```

Use generator expressions instead of lists when you only iterate once, and `collections.deque` instead of a list when popping from the front.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-optimizing-slow-code-q2",
      "type": "mcq",
      "prompt": "Inside a loop you test `item in big_list` thousands of times. What is the best fix?",
      "options": [
        { "id": "a", "text": "Convert the list to a set once, before the loop" },
        { "id": "b", "text": "Sort the list on every iteration" },
        { "id": "c", "text": "Wrap the loop in a try/except" },
        { "id": "d", "text": "Use a global variable for the list" }
      ],
      "correct": "a",
      "explanation": "Set membership is O(1) on average versus O(n) for a list, and building the set once amortizes its cost."
    },
    {
      "id": "performance-testing-optimizing-slow-code-q3",
      "type": "mcq",
      "prompt": "Why is `sum(values)` generally faster than a manual `for` loop that adds the values?",
      "options": [
        { "id": "a", "text": "Built-ins run their loop in C instead of the Python bytecode loop" },
        { "id": "b", "text": "It skips type checks and may give wrong answers" },
        { "id": "c", "text": "It runs on multiple cores" },
        { "id": "d", "text": "It caches the result between calls" }
      ],
      "correct": "a",
      "explanation": "The iteration happens inside the interpreter's C code, avoiding per-iteration bytecode overhead."
    }
  ]
}
```

## Cache repeated work with lru_cache

If a pure function is called repeatedly with the same arguments, memoize it. `functools.lru_cache` stores results keyed by the arguments (which must be hashable). Always set `maxsize` deliberately so the cache cannot grow without bound.

```python
from functools import lru_cache

@lru_cache(maxsize=256)
def fib(n):
    return n if n < 2 else fib(n - 1) + fib(n - 2)

print(fib(80))             # 23416728348467685, instant instead of exponential
print(fib.cache_info())    # CacheInfo(hits=78, misses=81, maxsize=256, currsize=81)
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-optimizing-slow-code-q4",
      "type": "mcq",
      "prompt": "Which function is a good candidate for `@lru_cache`?",
      "options": [
        { "id": "a", "text": "One that returns the current time" },
        { "id": "b", "text": "A pure, expensive function called repeatedly with the same hashable arguments" },
        { "id": "c", "text": "One that writes to a database" },
        { "id": "d", "text": "One whose arguments are always unique lists" }
      ],
      "correct": "b",
      "explanation": "Caching only helps when results are deterministic and inputs repeat; arguments must be hashable, so list arguments fail."
    }
  ]
}
```

## CPU-bound vs I/O-bound

Diagnose which one you have before picking a tool. I/O-bound code (network, disk) waits, so `asyncio` or threads overlap the waiting. CPU-bound code needs real parallelism (`multiprocessing`) because of the GIL, or compilation: Numba JIT-compiles numeric functions, Cython lets you rewrite a hot section in C-like code. These come after algorithmic fixes, not before. See the concurrency section for the threading and multiprocessing details.

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-optimizing-slow-code-q5",
      "type": "mcq",
      "prompt": "A service spends most of its time waiting on HTTP responses. Which tool fits best?",
      "options": [
        { "id": "a", "text": "asyncio (or threads) to overlap the waiting" },
        { "id": "b", "text": "Cython" },
        { "id": "c", "text": "A larger `lru_cache`" },
        { "id": "d", "text": "Numba" }
      ],
      "correct": "a",
      "explanation": "Waiting on I/O does not use the CPU, so overlapping the waits helps. Compilation tools speed up CPU-bound work."
    }
  ]
}
```

## Interning and pymalloc

CPython reuses some objects to save memory and time. **Interning**: small integers from -5 to 256 are preallocated singletons, and some strings (identifier-like ones) are shared. **pymalloc** is the allocator for objects of 512 bytes or less; it carves arenas into pools so small allocations avoid a system `malloc` call each time. Larger objects go to the system allocator.

Consequence: use `==` for value comparison, never `is`. Identity of equal ints or strings is an implementation detail.

```python
a = int("100")
b = int("100")
print(a is b)   # True: 100 is in the small-int cache

c = int("1000")
d = int("1000")
print(c is d)   # False: 1000 is outside the cache, separate objects
print(c == d)   # True
```

```knowledge-check
{
  "questions": [
    {
      "id": "performance-testing-optimizing-slow-code-q6",
      "type": "mcq",
      "prompt": "Which range of integers does CPython preallocate and reuse?",
      "options": [
        { "id": "a", "text": "0 to 100" },
        { "id": "b", "text": "-5 to 256" },
        { "id": "c", "text": "-128 to 127" },
        { "id": "d", "text": "All integers below 1000" }
      ],
      "correct": "b",
      "explanation": "Integers from -5 through 256 are cached singletons, which is why `a is b` can be True for small ints only."
    },
    {
      "id": "performance-testing-optimizing-slow-code-q7",
      "type": "mcq",
      "prompt": "What does pymalloc handle?",
      "options": [
        { "id": "a", "text": "Allocations larger than 1 MB" },
        { "id": "b", "text": "Reference counting" },
        { "id": "c", "text": "Small object allocations up to 512 bytes, using pools and arenas" },
        { "id": "d", "text": "Cycle detection" }
      ],
      "correct": "c",
      "explanation": "pymalloc is a fast small-object allocator; larger requests fall through to the system allocator."
    }
  ]
}
```
