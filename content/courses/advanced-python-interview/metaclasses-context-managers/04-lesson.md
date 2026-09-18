---
kind: lesson
id_key: advanced-python-interview/metaclasses-context-managers/custom-context-managers
course: advanced-python-interview
section: metaclasses-context-managers
section_title: "Metaclasses & Context Managers"
section_position: 5
title: "Custom Context Managers"
position: 3
estimated_minutes: 15
source: [fifty-advanced-python-concepts/38.custom_context_managers.py, fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md]
---
`with` isn't magic reserved for `open()` — any object that implements `__enter__`/`__exit__` (or any generator function wrapped in `@contextmanager`) can be used after `with`. Writing your own is one of the highest-leverage patterns for guaranteed cleanup in senior-level Python code.

## The class-based form: `__enter__` and `__exit__`

```python
class Timer:
    def __enter__(self):
        import time
        self._start = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        import time
        elapsed = time.perf_counter() - self._start
        print(f"elapsed: {elapsed:.4f}s")
        return False  # False (or None) means: don't suppress exceptions


with Timer():
    total = sum(i * i for i in range(1_000_000))
```

`__enter__`'s return value becomes the `as` target. `__exit__` receives the exception type/value/traceback if the block raised (all `None` if it didn't) — returning a truthy value from `__exit__` swallows the exception, which is almost never what you want, so `return False`/`None` explicitly.

## The generator form: `@contextmanager`

Writing a class for every context manager is boilerplate for simple cases. `contextlib.contextmanager` turns a single generator function — one `yield` splitting "setup" from "teardown" — into the same protocol:

```python
import sqlite3
from contextlib import contextmanager


@contextmanager
def database_connection(db_name):
    """Everything before yield is __enter__; everything after (in finally) is __exit__."""
    conn = sqlite3.connect(db_name)
    try:
        print("connection opened")
        yield conn
    finally:
        conn.close()
        print("connection closed")


with database_connection(":memory:") as conn:
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE users (id INTEGER, name TEXT)")
    cursor.execute("INSERT INTO users VALUES (?, ?)", (1, "Alice"))
    conn.commit()
    print("row inserted")
```

The code before `yield conn` runs on `__enter__`; whatever's passed to `yield` becomes the `as` target; the code after `yield` — wrapped in `try/finally` — runs on `__exit__`, whether the `with` block succeeded or raised. This is the far more common style in production code: it reads top-to-bottom like a script instead of splitting setup/teardown across two separate methods.

## Class-based vs. generator-based: when to pick which

Reach for `@contextmanager` by default — it's shorter and the setup/teardown logic stays visually adjacent. Drop to a full class when the context manager needs to hold reusable state across multiple `__enter__`/`__exit__` cycles (the same instance used in several separate `with` blocks), or needs to inspect the exception details in `__exit__` beyond "did one happen" (deciding whether to log, retry, or suppress based on `exc_type`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-custom-context-managers-q1",
      "type": "mcq",
      "prompt": "In the @contextmanager generator style, what does the code *after* `yield` correspond to?",
      "options": [
        { "id": "a", "text": "__enter__" },
        { "id": "b", "text": "__exit__, running whether the with-block succeeded or raised (when wrapped in try/finally)" },
        { "id": "c", "text": "It never runs unless an exception occurs" },
        { "id": "d", "text": "The __init__ of the generator function" }
      ],
      "correct": "b",
      "explanation": "Everything before yield is entry logic; everything after yield (typically in a finally block) is exit/teardown logic, running regardless of whether the with-block raised."
    },
    {
      "id": "metaclasses-context-managers-custom-context-managers-q2",
      "type": "mcq",
      "prompt": "What happens if a class-based context manager's __exit__ method returns True?",
      "options": [
        { "id": "a", "text": "Nothing different from returning False" },
        { "id": "b", "text": "Any exception raised inside the with-block is suppressed instead of propagating" },
        { "id": "c", "text": "The with-block is re-executed" },
        { "id": "d", "text": "It raises a TypeError, since __exit__ must return None" }
      ],
      "correct": "b",
      "explanation": "A truthy return from __exit__ tells Python to swallow the exception rather than let it propagate — which is why __exit__ should return False/None unless you specifically intend to suppress errors."
    }
  ]
}
```
