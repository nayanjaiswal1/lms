---
kind: lesson
id_key: advanced-python-interview/async-typing/callable-objects
course: advanced-python-interview
section: async-typing
section_title: "Async, Callables & Advanced Typing"
section_position: 8
title: "Callable Objects (`__call__`)"
position: 1
estimated_minutes: 10
source: ["fifty-advanced-python-concepts/51.call_method.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
Defining `__call__` on a class makes its instances callable with `()`, exactly like a function. This matters when you need a function-like object that also carries persistent state — cleaner than a closure once that state needs to be inspected, updated, or shared after creation.

## A callable instance

```python
class Multiplier:
    def __init__(self, factor):
        self.factor = factor

    def __call__(self, value):
        return self.factor * value

doubler = Multiplier(2)
tripler = Multiplier(3)

print(doubler(5))  # 10 — calling the instance invokes __call__
print(tripler(5))  # 15

print(callable(doubler))  # True — instances of a class defining __call__ are callable
```

`doubler(5)` is syntactic sugar for `doubler.__call__(5)`, the same way `len(x)` is sugar for `x.__len__()`. `doubler` and `tripler` are two independent objects, each holding its own `factor` — a closure could capture `factor` too, but couldn't offer `doubler.factor = 4` to reconfigure it after creation the way an attribute can.

## Closures vs. callable objects

A closure works fine for one piece of hidden state:

```python
def make_multiplier(factor):
    def multiply(value):
        return factor * value
    return multiply

doubler = make_multiplier(2)
print(doubler(5))  # 10
```

But once you need *multiple* pieces of state, methods that manipulate that state, or the ability to inspect/mutate it from outside, a callable class scales better than a closure with more and more captured variables:

```python
class RateLimiter:
    def __init__(self, max_calls):
        self.max_calls = max_calls
        self.calls_made = 0

    def __call__(self, *args, **kwargs):
        if self.calls_made >= self.max_calls:
            raise RuntimeError("rate limit exceeded")
        self.calls_made += 1
        return f"call #{self.calls_made} allowed"

limiter = RateLimiter(max_calls=2)
print(limiter())              # call #1 allowed
print(limiter())              # call #2 allowed
print(limiter.calls_made)     # 2 — state is directly inspectable
try:
    limiter()
except RuntimeError as e:
    print("blocked:", e)
```

## Where this shows up in real code

Strategy-pattern implementations (swap in different callable "strategy" objects that share an interface), scikit-learn-style transformers, and any decorator implemented as a class instead of a nested function all rely on `__call__`. A class-based decorator is a common real-world example:

```python
class CountCalls:
    def __init__(self, func):
        self.func = func
        self.count = 0

    def __call__(self, *args, **kwargs):
        self.count += 1
        return self.func(*args, **kwargs)

@CountCalls
def greet(name):
    return f"Hello, {name}"

print(greet("Ana"))   # Hello, Ana
print(greet("Kim"))   # Hello, Kim
print(greet.count)    # 2
```

`@CountCalls` here replaces `greet` with a `CountCalls` *instance* — `greet(...)` then works because that instance is callable.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-callable-objects-q1",
      "type": "mcq",
      "prompt": "What does doubler(5) actually invoke when doubler is an instance of a class defining __call__?",
      "options": [
        { "id": "a", "text": "doubler.__init__(5)" },
        { "id": "b", "text": "doubler.__call__(5)" },
        { "id": "c", "text": "A new instance is created and its constructor is called" },
        { "id": "d", "text": "It raises a TypeError — instances aren't callable in Python" }
      ],
      "correct": "b",
      "explanation": "Using () on an object calls its __call__ method — obj(5) is sugar for obj.__call__(5), the same relationship len(x) has to x.__len__()."
    },
    {
      "id": "async-typing-callable-objects-q2",
      "type": "mcq",
      "prompt": "When does a callable class start to scale better than a closure for holding state?",
      "options": [
        { "id": "a", "text": "Never — closures are always the better choice" },
        { "id": "b", "text": "Once you need multiple pieces of state, methods that operate on it, or the ability to inspect/mutate it from outside the callable" },
        { "id": "c", "text": "Only when performance is critical, since closures are always slower" },
        { "id": "d", "text": "Only in multithreaded code" }
      ],
      "correct": "b",
      "explanation": "A closure works fine for one hidden variable. Once state grows (multiple fields, methods, external inspection like limiter.calls_made), a class with __call__ organizes that far better than a growing set of captured closure variables."
    },
    {
      "id": "async-typing-callable-objects-q3",
      "type": "mcq",
      "prompt": "In `@CountCalls` applied to greet, what does greet refer to after decoration?",
      "options": [
        { "id": "a", "text": "The original greet function, unchanged" },
        { "id": "b", "text": "A CountCalls instance wrapping the original function — callable because CountCalls defines __call__" },
        { "id": "c", "text": "The CountCalls class itself" },
        { "id": "d", "text": "None — class-based decorators aren't valid syntax" }
      ],
      "correct": "b",
      "explanation": "@CountCalls calls CountCalls(greet), producing an instance. greet is rebound to that instance; greet(\"Ana\") works because CountCalls.__call__ makes instances callable, forwarding to the wrapped function."
    }
  ]
}
```
