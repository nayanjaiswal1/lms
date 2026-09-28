---
kind: lesson
id_key: interview-prep-45/python-functions-deep-dive
course: interview-prep-45
section: backend-python
section_title: "Python"
section_position: 6
section_group: "Backend"
title: "Functions Deep Dive: Closures, Generators, Context Managers, Scope"
position: 2
estimated_minutes: 30
source:
    - interview-prep-notes.md
---

Four things almost every Python interview opens with, because each one is quick to ask and quick to spot a gap in: closures, context managers, generators, and how Python decides which variable you mean when a name could refer to several.

## Closures: a function that remembers where it came from

Picture a locker that comes pre-loaded with a note only that locker can read, even after the person who wrote the note has gone home. A closure is that: an inner function that keeps a live link to a variable from the function that created it, even after that outer function has already finished running.

```python
def make_multiplier(factor):
    def multiply(x):
        return x * factor      # 'factor' is remembered, not copied
    return multiply

double = make_multiplier(2)
triple = make_multiplier(3)
double(5)  # 10
triple(5)  # 15
```

`make_multiplier(2)` runs once, creates a little box (a "cell") holding `2`, and hands back `multiply` with that box attached. Every later call to `double(x)` reads from that same box. It never re-reads anything from `make_multiplier`'s call, which already ended. That's why `double` and `triple` behave differently even though they're built from the exact same code.

The classic trap: a closure captures the *variable*, not its value at the moment the closure was made.

```python
funcs = [lambda: i for i in range(3)]
[f() for f in funcs]   # [2, 2, 2] -- all three lambdas share the same 'i' box

funcs = [lambda i=i: i for i in range(3)]   # fix: copy the current value into a default argument
[f() for f in funcs]   # [0, 1, 2]
```

All three lambdas in the broken version share one `i` box, and by the time any of them runs, the loop is over and `i` is stuck at `2`. The fix works because default argument values are copied in at function-definition time, once per lambda, so `i=i` freezes that loop's current value instead of leaving it as a shared, still-changing variable.

> **Remember:** a closure keeps a live link to a variable, not a snapshot of its value. A loop variable in a closure needs a default argument to freeze it.

**Common mistake:** building a list of callbacks inside a loop and expecting each one to remember "its" iteration's value without the `i=i` fix.

```knowledge-check
{ "questions": [
    { "id": "backend-python-functions-closures-q1", "type": "mcq",
      "prompt": "Three lambdas are built inside `for i in range(3): funcs.append(lambda: i)`. Calling all three afterward prints what?",
      "options": [
        {"id":"a","text":"0, 1, 2 -- each remembers its own iteration"},
        {"id":"b","text":"2, 2, 2 -- all three share the same variable, which ends at 2"},
        {"id":"c","text":"A crash, since i no longer exists after the loop"},
        {"id":"d","text":"0, 0, 0"}
      ],
      "correct": "b",
      "explanation": "A closure captures the variable itself, not a frozen value. All three lambdas share one 'i' cell, which holds 2 by the time the loop finishes and any lambda is called." }
] }
```

## Context managers: guaranteed setup and cleanup

A context manager is an object that sets something up before your code runs and tears it down afterward, no matter what, even if your code raises an exception halfway through.

```python
with open("file.txt") as f:
    data = f.read()
# file is closed here even if .read() raised
```

You can write your own two ways. Class-based, with `__enter__`/`__exit__`:

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

Or function-based, with `@contextmanager`, which is usually less code for a one-off:

```python
from contextlib import contextmanager

@contextmanager
def timer():
    start = time.time()
    yield                      # the code inside the `with` block runs here
    print(f"Elapsed: {time.time() - start:.3f}s")

with timer():
    do_work()
```

Everything before `yield` plays the role of `__enter__`; everything after plays `__exit__`. Entering `with timer():` runs `timer()` up to `yield`, then `do_work()` runs as the body, then execution resumes right after `yield` to print the elapsed time.

Common real uses: `open()` for files, `threading.Lock()` for acquiring and releasing a lock, a database connection for connect and disconnect, `unittest.mock.patch` for patching and restoring. Watch the `__exit__` return value: `True` silently swallows any exception raised inside the block, which is rarely what you want.

> **Remember:** everything before `yield` in a `@contextmanager` function is setup; everything after is cleanup, and cleanup still needs a `try/finally` around the `yield` if it must run even on error.

```knowledge-check
{ "questions": [
    { "id": "backend-python-functions-contextmanagers-q1", "type": "mcq",
      "prompt": "A class's __exit__ method returns True. What effect does that have?",
      "options": [
        {"id":"a","text":"It has no effect on exception handling"},
        {"id":"b","text":"It swallows any exception raised inside the with block, so it never propagates"},
        {"id":"c","text":"It forces the exception to re-raise with extra detail"},
        {"id":"d","text":"It restarts the with block from the beginning"}
      ],
      "correct": "b",
      "explanation": "Returning True from __exit__ tells Python the exception was handled and should not propagate further. Returning False or None lets it re-raise normally, which is what you want unless you deliberately mean to suppress it." }
] }
```

## Generators: values produced one at a time

A generator is a function that hands out a lazy sequence of values with `yield`, instead of building and returning the whole list up front. Nothing runs until the caller actually asks for the next value.

```python
def squares(n):
    for i in range(n):
        yield i * i

gen = squares(5)
next(gen)   # 0 -- nothing beyond this has run yet
next(gen)   # 1

total = sum(x * x for x in range(10_000_000))   # generator expression: no full list ever built
```

Calling `squares(5)` doesn't run the function body at all, it just creates a generator object. The first `next(gen)` runs up to the first `yield`, producing `0`, then pauses exactly there. The second `next(gen)` resumes right after that `yield` and continues the loop to `i = 1`. The payoff is memory, not raw speed: `sum(x*x for x in range(10_000_000))` never holds ten million values at once, unlike the equivalent list comprehension.

> **Remember:** a generator computes the next value only when asked. Use one whenever you'd otherwise build a huge list just to loop over it once.

```knowledge-check
{ "questions": [
    { "id": "backend-python-functions-generators-q1", "type": "mcq",
      "prompt": "What is the main reason to use a generator expression instead of a list comprehension for summing ten million squared numbers?",
      "options": [
        {"id":"a","text":"Generators always compute faster than list comprehensions"},
        {"id":"b","text":"A generator never holds all ten million values in memory at once; it produces and consumes one at a time"},
        {"id":"c","text":"Generators can hold more precision than lists"},
        {"id":"d","text":"There is no real difference between the two"}
      ],
      "correct": "b",
      "explanation": "A list comprehension builds the full list before summing it. A generator expression produces one value at a time, so peak memory use stays flat regardless of how many values there are." }
] }
```

## LEGB: how Python finds a name

When your code uses a name, Python checks four scopes, in this order: **L**ocal (inside the current function), **E**nclosing (any function this one is nested inside), **G**lobal (the module level), **B**uilt-in (Python's own names like `len`). The first scope where the name exists wins.

```python
x = "global"

def outer():
    x = "enclosing"
    def inner():
        x = "local"
        print(x)     # "local" -- found immediately in Local scope
    inner()

outer()
```

Writing to an outer scope, rather than just reading it, needs an explicit declaration. This is the part people forget under pressure:

```python
count = 0

def increment():
    global count      # without this, 'count += 1' raises UnboundLocalError
    count += 1
```

Without `global count`, Python sees the assignment `count += 1` anywhere in the function body and decides, before the function even runs, that `count` is a local variable for the whole function. That makes the *read* half of `count += 1` fail, since the local `count` was never assigned before that line runs. `nonlocal` does the same job one level up: it lets a nested function write to its *enclosing* function's variable, not the global one.

> **Remember:** Python looks up a name Local, then Enclosing, then Global, then Built-in. Writing to an outer scope needs `global` or `nonlocal`; reading it does not.

```knowledge-check
{ "questions": [
    { "id": "backend-python-functions-legb-q1", "type": "mcq",
      "prompt": "A function does `count += 1` on a variable defined outside it, without declaring `global count`. What happens?",
      "options": [
        {"id":"a","text":"It silently updates the outer count"},
        {"id":"b","text":"UnboundLocalError, because the assignment makes Python treat count as local for the whole function, and that local was never assigned before the read"},
        {"id":"c","text":"It creates a second global variable with the same name"},
        {"id":"d","text":"Nothing happens; the line is skipped"}
      ],
      "correct": "b",
      "explanation": "Any assignment to a name inside a function marks that name local for the entire function body, decided before the function runs. That breaks the read half of count += 1 unless global count says otherwise." }
] }
```

## The mutable default argument trap

```python
def add_item(item, cart=[]):   # the list is created ONCE, when the function is defined
    cart.append(item)
    return cart

add_item("apple")   # ['apple']
add_item("banana")  # ['apple', 'banana'] -- the SAME list from before
```

Default argument values are evaluated once, when the `def` line runs, not once per call. So `[]` here is a single list object, shared and mutated by every call that doesn't pass its own `cart`.

```python
def add_item(item, cart=None):   # sentinel default; a fresh list is built inside the call
    if cart is None:
        cart = []
    cart.append(item)
    return cart
```

`None` is a safe, immutable default. Inside the function, a brand-new list is created on every call that didn't supply its own, so callers stop unknowingly sharing state.

> **Remember:** a mutable default argument is created once at definition time and shared across every call. Use `None` as the default and build the real value inside the function.

```knowledge-check
{ "questions": [
    { "id": "backend-python-functions-mutabledefault-q1", "type": "mcq",
      "prompt": "Why does `def add_item(item, cart=[]):` cause items from earlier, unrelated calls to show up in a later call's result?",
      "options": [
        {"id":"a","text":"Lists in Python are always shared between all functions"},
        {"id":"b","text":"The empty list is created once when the function is defined, and every call that skips the cart argument reuses and mutates that same list"},
        {"id":"c","text":"Python resets all default arguments after every call, so this should never happen"},
        {"id":"d","text":"append() copies the list before adding to it"}
      ],
      "correct": "b",
      "explanation": "Default values are evaluated exactly once, at def time. A mutable default like [] becomes one shared object across every call that relies on the default, which is why state leaks between unrelated calls." }
] }
```
