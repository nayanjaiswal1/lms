---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/advanced-decorators
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 7
title: "Advanced Decorators"
position: 0
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/45.advanced_decorators.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
A basic decorator wraps a function to add one piece of behavior — logging, say. Senior interviews probe further: can a decorator carry its own state across calls? Can several stack together? Can it take arguments? Can it modify a *class* instead of a function? All four come up constantly in real codebases (caching, auth, rate limiting, ORMs), so being fluent with them is a strong signal.

## Attaching state to the wrapper

A decorator's inner `wrapper` function is a closure — it can hang extra data directly off itself as an attribute, which callers can then read:

```python
def call_counter(func):
    def wrapper(*args, **kwargs):
        wrapper.calls += 1
        print(f"Call {wrapper.calls} to {func.__name__}")
        return func(*args, **kwargs)
    wrapper.calls = 0
    return wrapper

@call_counter
def greet(name):
    print(f"Hello, {name}!")

greet("Alice")  # Call 1 to greet
greet("Bob")    # Call 2 to greet
print("Total calls:", greet.calls)  # Total calls: 2
```

The counter lives on `wrapper`, not on `greet` — after decoration, `greet` *is* `wrapper`, so `greet.calls` works fine.

## Caching results

The same closure trick builds a memoizing decorator: keep a dict alive across calls, keyed by the arguments:

```python
def cache(func):
    stored_results = {}
    def wrapper(*args):
        if args not in stored_results:
            stored_results[args] = func(*args)
        return stored_results[args]
    return wrapper

@cache
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

print(fib(30))  # instant — without caching this would be exponential
```

This is exactly what `functools.lru_cache` does for you (covered in a later lesson) — knowing how to hand-roll it shows you understand *why* the built-in one works, not just how to import it.

## Stacking decorators

Decorators apply bottom-up but *run* outside-in, like nested function calls:

```python
def authenticate(func):
    def wrapper(*args, **kwargs):
        print("Authenticating...")
        return func(*args, **kwargs)
    return wrapper

def log(func):
    def wrapper(*args, **kwargs):
        print(f"Logging call to {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@authenticate
@log
def access_data():
    print("Accessing sensitive data")

access_data()
# Authenticating...
# Logging call to access_data
# Accessing sensitive data
```

`access_data` is first wrapped by `log`, then that result is wrapped by `authenticate` — so `authenticate`'s "Authenticating..." print runs first, then it calls into the `log`-wrapped function.

## Decorators that take arguments

A decorator factory is a function that *returns* a decorator, letting you parameterize the behavior:

```python
import time

def timer(unit="seconds"):
    def decorator(func):
        def wrapper(*args, **kwargs):
            start = time.perf_counter()
            result = func(*args, **kwargs)
            duration = time.perf_counter() - start
            if unit == "milliseconds":
                duration *= 1000
            print(f"{func.__name__} took {duration:.2f} {unit}")
            return result
        return wrapper
    return decorator

@timer(unit="milliseconds")
def slow_function():
    time.sleep(0.05)

slow_function()  # slow_function took ~50.00 milliseconds
```

`@timer(unit="milliseconds")` first calls `timer(unit="milliseconds")`, which returns `decorator` — *that* is what actually wraps `slow_function`. Three layers deep, but each layer is just an ordinary closure.

## Class decorators

A decorator doesn't have to wrap a function — applied to a class, it receives the class object itself and can mutate or replace it:

```python
def add_method(cls):
    def new_method(self):
        return "I am a new method!"
    cls.new_method = new_method
    return cls

@add_method
class MyClass:
    pass

obj = MyClass()
print(obj.new_method())  # I am a new method!
```

Frameworks use this pattern to inject methods, register classes in a lookup table, or wrap every method with instrumentation — without the class author having to write that plumbing themselves.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-advanced-decorators-q1",
      "type": "mcq",
      "prompt": "In the call_counter example, why does greet.calls work after decoration?",
      "options": [
        { "id": "a", "text": "Python automatically copies attributes from the original function" },
        { "id": "b", "text": "greet is rebound to wrapper, and calls is an attribute set directly on wrapper" },
        { "id": "c", "text": "calls is a global variable shared by all decorated functions" },
        { "id": "d", "text": "It doesn't work — this would raise an AttributeError" }
      ],
      "correct": "b",
      "explanation": "@call_counter replaces greet with wrapper. wrapper.calls = 0 attaches an attribute directly to that function object, so greet.calls reads it fine after decoration."
    },
    {
      "id": "decorators-dataclasses-advanced-decorators-q2",
      "type": "mcq",
      "prompt": "For `@authenticate` stacked above `@log` on the same function, what runs first when the function is called?",
      "options": [
        { "id": "a", "text": "log's wrapper code, then authenticate's wrapper code" },
        { "id": "b", "text": "authenticate's wrapper code, then log's wrapper code" },
        { "id": "c", "text": "They run simultaneously" },
        { "id": "d", "text": "Only the topmost decorator (authenticate) ever runs" }
      ],
      "correct": "b",
      "explanation": "Decorators apply bottom-up (log wraps the function first, then authenticate wraps that result) but execute outside-in: calling the final object runs authenticate's wrapper first, which calls into log's wrapper."
    },
    {
      "id": "decorators-dataclasses-advanced-decorators-q3",
      "type": "mcq",
      "prompt": "Why does @timer(unit=\"milliseconds\") need three nested functions (timer, decorator, wrapper) instead of the usual two?",
      "options": [
        { "id": "a", "text": "It's a Python syntax requirement for all decorators" },
        { "id": "b", "text": "timer(unit=...) must first execute and return the actual decorator, since @ can only apply a single callable directly to the function" },
        { "id": "c", "text": "Extra nesting is only for readability and has no functional purpose" },
        { "id": "d", "text": "wrapper needs its own wrapper to handle *args" }
      ],
      "correct": "b",
      "explanation": "@timer(unit=\"milliseconds\") first calls timer(...), which must return something that @ can apply to slow_function — that something is decorator. decorator then returns wrapper, the function that actually runs at call time."
    }
  ]
}
```
