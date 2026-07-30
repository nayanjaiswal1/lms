---
kind: lesson
id_key: interview-prep-45/note-closures-context-managers-generators-scope
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Closures, Context Managers, Generators & Scope Resolution"
position: 115
estimated_minutes: 20
source:
    - interview-prep-notes.md
---

The course covers Python's object model in depth — MRO (backend/107), memory management and the GIL (backend/106), deep vs shallow copy (backend/109) — but four fundamentals candidates are expected to rattle off cold don't have a home yet: closures, context managers, generators, and LEGB scope resolution. These are quick, but they're exactly the kind of "explain this in one sentence, then show a gotcha" questions that open a Python round.

## Closures

> **One-line definition:** "An inner function that remembers a variable from its enclosing function's scope, even after the enclosing function has already returned."

```python
def make_multiplier(factor):
    def multiply(x):
        return x * factor      # 'factor' is captured, not copied
    return multiply

double = make_multiplier(2)
triple = make_multiplier(3)
double(5)  # 10
triple(5)  # 15
```

`multiply` doesn't get a snapshot of `factor` at creation time — it keeps a live reference to the variable itself, inspectable via `double.__closure__[0].cell_contents`.

**The gotcha that trips people up — closures in a loop capture the variable, not its value at iteration time:**

```python
funcs = [lambda: i for i in range(3)]
[f() for f in funcs]   # [2, 2, 2] — all three closures share the same 'i' cell

funcs = [lambda i=i: i for i in range(3)]   # fix: snapshot via a default argument
[f() for f in funcs]   # [0, 1, 2]
```

This is the same closure-over-a-variable mechanism backend/01 mentions for Django middleware (`A(B(C(view)))` — each layer closes over the next) — a decorator's `wrapper` function is a closure over the original function for the exact same reason.

## Context managers

> **One-line definition:** "An object that sets something up before your code runs and cleans it up after, no matter what happens — including on an exception."

```python
with open("file.txt") as f:
    data = f.read()
# file is closed here even if .read() raised
```

**Class-based**, via `__enter__`/`__exit__`:

```python
class Timer:
    def __enter__(self):
        self.start = time.time()
        return self
    def __exit__(self, exc_type, exc_val, exc_tb):
        print(f"Elapsed: {time.time() - self.start:.3f}s")
        return False   # False/None re-raises any exception; True would swallow it

with Timer():
    do_work()
```

**Function-based**, via `@contextmanager` — usually the less boilerplate-heavy choice for a one-off:

```python
from contextlib import contextmanager

@contextmanager
def timer():
    start = time.time()
    yield                      # code inside the `with` block runs here
    print(f"Elapsed: {time.time() - start:.3f}s")

with timer():
    do_work()
```

Everything before `yield` is `__enter__`; everything after is `__exit__`. If the `with` block raises, the exception surfaces at the `yield` line — wrap it in `try/finally` inside the generator if cleanup must run even on error.

**Common real uses:** `open()` (file), `threading.Lock()` (acquire/release), a DB connection (connect/disconnect), `unittest.mock.patch` (patch/restore). The `__exit__` return value matters in interviews: returning `True` suppresses the exception — a subtle footgun if you don't mean to swallow errors silently.

## Generators

A generator is a function that produces a lazy sequence via `yield` instead of building and returning a full list — nothing is computed until the caller asks for the next value.

```python
def squares(n):
    for i in range(n):
        yield i * i

gen = squares(5)
next(gen)   # 0 — nothing beyond this has run yet
next(gen)   # 1

total = sum(x * x for x in range(10_000_000))   # generator expression — no intermediate list materialized
```

**Interview framing:** the payoff is memory, not raw speed — `sum(x*x for x in range(10_000_000))` never holds 10 million values in memory simultaneously, unlike the list-comprehension equivalent. This is the same reason `dict`/`Counter`/`defaultdict` construction from a generator expression scales to inputs a list comprehension can't.

## LEGB — scope resolution order

Python resolves a name by checking four scopes in order: **L**ocal → **E**nclosing → **G**lobal → **B**uilt-in — the first scope where the name exists wins.

```python
x = "global"

def outer():
    x = "enclosing"
    def inner():
        x = "local"
        print(x)     # "local" — found in Local scope, search stops immediately
    inner()

outer()
```

To *write* to an outer scope (rather than just read it) requires an explicit declaration — this is the part people forget under pressure:

```python
count = 0

def increment():
    global count      # without this, 'count += 1' raises UnboundLocalError
    count += 1
```

`nonlocal` plays the same role one level up, for writing to an *enclosing* function's variable (not global) from a nested function — the same mechanism a closure needs if it wants to mutate, not just read, the captured variable.

## Default mutable argument — the classic gotcha

```python
def add_item(item, cart=[]):   # BAD — the list literal is created ONCE, at function definition time
    cart.append(item)
    return cart

add_item("apple")   # ['apple']
add_item("banana")  # ['apple', 'banana'] — the SAME list, carried over from the previous call
```

Default argument values are evaluated **once**, when the `def` statement runs — not once per call. A mutable default (list, dict, set) is therefore shared and accumulates state across every call that doesn't explicitly pass its own.

```python
def add_item(item, cart=None):   # GOOD — sentinel default, fresh list created inside the call
    if cart is None:
        cart = []
    cart.append(item)
    return cart
```

## Key takeaways

- Closure = inner function + captured variable from an enclosing scope, alive after that scope returns; loop-variable capture is the classic gotcha (all closures share one cell unless you snapshot via a default argument).
- Context manager = guaranteed setup/teardown around a block, even on exception; `__exit__` returning `True` swallows the exception — usually not what you want.
- Generators trade eagerness for memory: nothing computes until `next()` is called, so a generator expression never materializes an intermediate collection.
- LEGB (Local → Enclosing → Global → Built-in) is the read-resolution order; writing to an outer scope needs an explicit `global`/`nonlocal`, or Python creates a new local variable instead.
- A mutable default argument (`def f(x, cache=[])`) is created once at function-definition time and shared across every call — always default to `None` and create the mutable value inside the function body.
