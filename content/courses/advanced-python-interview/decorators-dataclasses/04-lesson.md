---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/functools
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 7
title: "`functools`"
position: 3
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/48.functools.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
`functools` is the standard-library toolbox for working with functions themselves. Three tools from it come up constantly in senior interviews: `wraps` (fixes a subtle bug every hand-written decorator has), `lru_cache` (the built-in version of the memoization decorator from the previous section), and `reduce` (cumulative/fold operations).

## `wraps`: preserving a decorated function's identity

Every decorator written in the previous lesson has a hidden bug: once wrapped, the function's `__name__`, `__doc__`, and other metadata are replaced by the *wrapper's* — which breaks introspection, debuggers, and documentation tools.

```python
def my_decorator(func):
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return wrapper

@my_decorator
def greet(name):
    """Say hello to name."""
    return f"Hello, {name}"

print(greet.__name__)  # 'wrapper' — wrong! should be 'greet'
print(greet.__doc__)   # None — the docstring is gone
```

`functools.wraps` fixes this by copying the original function's metadata onto the wrapper:

```python
from functools import wraps

def my_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return wrapper

@my_decorator
def greet(name):
    """Say hello to name."""
    return f"Hello, {name}"

print(greet.__name__)  # 'greet' — correct
print(greet.__doc__)   # 'Say hello to name.'
```

Any decorator you write for real code should apply `@wraps(func)` to its inner wrapper — it costs one line and prevents a class of confusing bugs downstream.

## `lru_cache`: memoization without hand-rolling it

The `cache` decorator from the previous lesson (a dict keyed by arguments) is exactly what `lru_cache` gives you for free, plus an eviction policy (Least Recently Used) so the cache doesn't grow unbounded:

```python
from functools import lru_cache

@lru_cache(maxsize=3)
def expensive_computation(x):
    print(f"Computing {x}")
    return x * x

print(expensive_computation(2))  # Computing 2 -> 4
print(expensive_computation(2))  # 4 (served from cache, no "Computing 2" print)
print(expensive_computation(3))  # Computing 3 -> 9
```

`maxsize=3` caps the cache at 3 distinct argument combinations; once full, the least-recently-used entry is evicted to make room. `maxsize=None` makes it unbounded. Arguments must be hashable (this is a dict under the hood).

## `reduce`: cumulative operations

`reduce(function, iterable)` folds an iterable down to a single value by repeatedly applying a two-argument function — `reduce(f, [a, b, c])` computes `f(f(a, b), c)`:

```python
from functools import reduce

numbers = [1, 2, 3, 4]
product = reduce(lambda x, y: x * y, numbers)
print(product)  # 24

total = reduce(lambda x, y: x + y, numbers, 0)  # 0 is the starting value
print(total)  # 10
```

`sum()` already covers the addition case — `reduce` earns its place for anything without a dedicated built-in: running max with custom comparison, merging dicts, composing a chain of functions.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-functools-q1",
      "type": "mcq",
      "prompt": "What bug does functools.wraps fix?",
      "options": [
        { "id": "a", "text": "It makes decorated functions run faster" },
        { "id": "b", "text": "Without it, the wrapped function's __name__, __doc__, and other metadata get replaced by the wrapper function's own metadata" },
        { "id": "c", "text": "It prevents decorators from being stacked" },
        { "id": "d", "text": "It adds automatic error handling to every decorator" }
      ],
      "correct": "b",
      "explanation": "A plain wrapper function shadows the original's __name__ and __doc__. @wraps(func) copies that metadata onto the wrapper so introspection and debugging still show the original function's identity."
    },
    {
      "id": "decorators-dataclasses-functools-q2",
      "type": "mcq",
      "prompt": "What does maxsize=3 do on @lru_cache(maxsize=3)?",
      "options": [
        { "id": "a", "text": "Limits the function to being called 3 times total" },
        { "id": "b", "text": "Caps the cache at 3 distinct argument combinations, evicting the least-recently-used entry once full" },
        { "id": "c", "text": "Runs the function on up to 3 threads in parallel" },
        { "id": "d", "text": "Limits the result value to 3 bytes" }
      ],
      "correct": "b",
      "explanation": "lru_cache keeps at most maxsize cached results, keyed by call arguments; the Least Recently Used entry is evicted first when the cache is full and a new argument combination arrives."
    },
    {
      "id": "decorators-dataclasses-functools-q3",
      "type": "mcq",
      "prompt": "What does reduce(lambda x, y: x * y, [1, 2, 3, 4]) compute?",
      "options": [
        { "id": "a", "text": "[1, 2, 3, 4] unchanged" },
        { "id": "b", "text": "((1 * 2) * 3) * 4 = 24" },
        { "id": "c", "text": "1 + 2 + 3 + 4 = 10" },
        { "id": "d", "text": "A generator that hasn't been consumed yet" }
      ],
      "correct": "b",
      "explanation": "reduce folds the iterable left to right, repeatedly applying the two-argument function: ((1*2)*3)*4 = 24."
    }
  ]
}
```
