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

This course covers Python's object model in depth elsewhere: method resolution order, memory management and the GIL, deep vs. shallow copy. But four fundamentals candidates are expected to rattle off cold don't have a home yet: closures, context managers, generators, and LEGB scope resolution. These are quick, but they're exactly the kind of "explain this in one sentence, then show a gotcha" questions that open a Python round.

## Closures

One-line definition: an inner function that remembers a variable from its enclosing function's scope, even after the enclosing function has already returned.

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

`multiply` doesn't get a snapshot of `factor` at creation time. It keeps a live reference to the variable itself, inspectable via `double.__closure__[0].cell_contents`. Concretely: `make_multiplier(2)` runs once, creates a cell holding `2`, and returns `multiply` with that cell attached as its closure. Every later call to `double(x)` looks up `factor` in that same cell rather than re-reading anything from `make_multiplier`'s already-finished call frame, which is what lets `double` and `triple` behave differently even though they're the same function object built from the same code.

The gotcha that trips people up: closures in a loop capture the variable, not its value at iteration time.

```python
funcs = [lambda: i for i in range(3)]
[f() for f in funcs]   # [2, 2, 2] — all three closures share the same 'i' cell

funcs = [lambda i=i: i for i in range(3)]   # fix: snapshot via a default argument
[f() for f in funcs]   # [0, 1, 2]
```

In the broken version, all three lambdas close over the exact same `i` cell, and by the time any of them is called, the loop has already finished and `i` is stuck at its final value, `2`. The fix works because default argument values are evaluated immediately, at function-definition time, once per lambda, so `i=i` copies the current loop value into each lambda's own default argument instead of leaving it as a shared closure variable.

This closure-over-a-variable mechanism is the same one behind middleware chaining in a web framework, where each layer wraps the next (`A(B(C(view)))`) by closing over it, and it's also exactly why a decorator's `wrapper` function is a closure over the original function it wraps.

## Context managers

One-line definition: an object that sets something up before your code runs and cleans it up after, no matter what happens, including on an exception.

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

**Function-based**, via `@contextmanager`, usually the less boilerplate-heavy choice for a one-off:

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

Everything before `yield` is `__enter__`; everything after is `__exit__`. Walking through `with timer(): do_work()`: entering the `with` block runs `timer()` up to the `yield`, recording `start`; `do_work()` then runs as the body of the `with` block; and once it finishes, execution resumes in `timer()` right after `yield`, printing the elapsed time. If the `with` block raises instead, the exception surfaces at the `yield` line inside the generator, so you'd wrap it in `try/finally` there if cleanup must run even on error.

Common real uses: `open()` for files, `threading.Lock()` for acquire/release, a DB connection for connect/disconnect, and `unittest.mock.patch` for patch/restore. The `__exit__` return value matters in interviews: returning `True` suppresses the exception, which is a subtle footgun if you don't mean to swallow errors silently.

## Generators

A generator is a function that produces a lazy sequence via `yield` instead of building and returning a full list. Nothing is computed until the caller asks for the next value.

```python
def squares(n):
    for i in range(n):
        yield i * i

gen = squares(5)
next(gen)   # 0 — nothing beyond this has run yet
next(gen)   # 1

total = sum(x * x for x in range(10_000_000))   # generator expression — no intermediate list materialized
```

Calling `squares(5)` doesn't run any of the function body; it just creates a generator object. The first `next(gen)` runs the function up to the first `yield`, producing `0` and then pausing exactly there, with `i` still equal to `0` in the paused frame. The second `next(gen)` resumes right after that `yield`, continues the loop to `i = 1`, and yields again. The interview framing: the payoff is memory, not raw speed. `sum(x*x for x in range(10_000_000))` never holds 10 million values in memory simultaneously, unlike the list-comprehension equivalent. This is the same reason building a `dict`, `Counter`, or `defaultdict` from a generator expression scales to inputs a list comprehension can't.

## LEGB: scope resolution order

Python resolves a name by checking four scopes in order: Local, then Enclosing, then Global, then Built-in. The first scope where the name exists wins.

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

To *write* to an outer scope, rather than just read it, requires an explicit declaration. This is the part people forget under pressure:

```python
count = 0

def increment():
    global count      # without this, 'count += 1' raises UnboundLocalError
    count += 1
```

Without `global count`, Python sees the assignment `count += 1` anywhere in the function body and decides, at compile time, that `count` is a local variable for the whole function. That makes the read half of `count += 1` fail with `UnboundLocalError`, since the local `count` hasn't been assigned yet at the point it's read. `nonlocal` plays the same role one level up, for writing to an *enclosing* function's variable (not global) from a nested function. It's the same mechanism a closure needs if it wants to mutate, not just read, the variable it captured.

## Default mutable argument: the classic gotcha

```python
def add_item(item, cart=[]):   # BAD — the list literal is created ONCE, at function definition time
    cart.append(item)
    return cart

add_item("apple")   # ['apple']
add_item("banana")  # ['apple', 'banana'] — the SAME list, carried over from the previous call
```

Default argument values are evaluated **once**, when the `def` statement runs, not once per call. So the `[]` in `cart=[]` is a single list object created when `add_item` is defined, and every call that doesn't pass its own `cart` argument shares and mutates that same list, which is why `"banana"` shows up alongside `"apple"` from the previous call instead of starting fresh.

```python
def add_item(item, cart=None):   # GOOD — sentinel default, fresh list created inside the call
    if cart is None:
        cart = []
    cart.append(item)
    return cart
```

Here, `None` is the (immutable, safely shared) default, and a brand new list is created inside the function body on every call that doesn't supply its own `cart`, which is what actually gives each caller a fresh list instead of one they unknowingly share with every other caller.
