---
kind: lesson
id_key: advanced-python-interview/async-typing/typing-protocols-generics
course: advanced-python-interview
section: async-typing
section_title: "Async, Callables & Advanced Typing"
section_position: 8
title: "Typing: Protocols & Generics"
position: 3
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/53.typing_protocols_and_generics.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_53_54.md"]
---
Python's type hints don't just annotate — `typing.Protocol` and `typing.Generic` let you express duck typing and reusable containers in a way static checkers (mypy, pyright) can actually verify, without forcing every caller into an inheritance hierarchy.

## `Protocol`: structural typing

Traditional typed interfaces (`abc.ABC` from an earlier lesson) require explicit inheritance — a class must `class Socket(SupportsClose):` to count as a `SupportsClose`. A `Protocol` instead checks *structure*: any object with a matching method signature satisfies it, inheritance or not — this is "duck typing," formalized for the type checker.

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class SupportsClose(Protocol):
    def close(self) -> None: ...

class Socket:
    def __init__(self, name: str) -> None:
        self.name = name

    def close(self) -> None:
        print(f"Socket {self.name} closed")

def close_if_supported(obj: SupportsClose) -> None:
    obj.close()

s = Socket("A")
close_if_supported(s)  # works — Socket was never declared to inherit SupportsClose
print(isinstance(s, SupportsClose))  # True, because @runtime_checkable enables isinstance() checks
```

`Socket` never mentions `SupportsClose` anywhere — it just happens to define a `close()` method with a compatible signature, which is enough. `@runtime_checkable` is opt-in and only checks method *names* exist at runtime (not their exact signatures) — the real, full signature verification happens statically, in your type checker.

## `Generic`: containers that remember their element type

A `Generic[T]` class is parameterized by a type variable — the same idea covered for other languages elsewhere in this course, available in Python via `typing`:

```python
from typing import TypeVar, Generic

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, value: T) -> None:
        self._v = value

    def get(self) -> T:
        return self._v

bi = Box[int](10)
bs = Box[str]("ok")
print(type(bi.get()), bi.get())  # <class 'int'> 10
print(type(bs.get()), bs.get())  # <class 'str'> ok
```

At runtime, `Box[int]` and `Box[str]` behave identically — Python doesn't enforce the type parameter, it's erased by runtime (same as most generic systems built on top of a dynamically-typed core). The value is entirely for your type checker: it can now catch `Box[int](10).get() + "oops"` as a type error before the code ever runs.

## `ParamSpec`: preserving a wrapped function's exact signature

A generic decorator (the kind covered two lessons ago) normally loses the wrapped function's specific parameter types in its type signature — `Callable[..., R]` accepts *anything*. `ParamSpec` fixes that, letting a type checker verify calls against the *original* function's exact signature even through a decorator:

```python
from typing import Callable, ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

def make_logged(func: Callable[P, R]) -> Callable[P, R]:
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        print(f"[log] {func.__name__} args={args} kwargs={kwargs}")
        result = func(*args, **kwargs)
        print(f"[log] {func.__name__} -> {result}")
        return result
    return wrapper

@make_logged
def greet(name: str, excited: bool = False) -> str:
    return "Hello, " + name + ("!!!" if excited else ".")

print(greet("World"))
print(greet("Lin", excited=True))
```

A type checker sees `greet` as still having the signature `(name: str, excited: bool = False) -> str` after decoration — `greet(excited="yes")` would be flagged as wrong, even though `wrapper` itself is written generically with `*args`/`**kwargs`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-typing-protocols-generics-q1",
      "type": "mcq",
      "prompt": "Why does Socket satisfy the SupportsClose Protocol even though it never inherits from it?",
      "options": [
        { "id": "a", "text": "Protocol subclassing is implicit and automatic for every class" },
        { "id": "b", "text": "Protocol checks structure (does it have a matching close() method), not inheritance — this is structural/duck typing" },
        { "id": "c", "text": "It doesn't actually satisfy it — the example would fail at runtime" },
        { "id": "d", "text": "@runtime_checkable rewrites Socket's class hierarchy at import time" }
      ],
      "correct": "b",
      "explanation": "A Protocol describes required structure (method names/signatures), not a base class to inherit from. Any object with a matching close() method satisfies SupportsClose, regardless of its actual class hierarchy."
    },
    {
      "id": "async-typing-typing-protocols-generics-q2",
      "type": "mcq",
      "prompt": "At runtime, what's actually different between Box[int](10) and Box[str](\"ok\")?",
      "options": [
        { "id": "a", "text": "Box[int] runs faster because int operations are optimized" },
        { "id": "b", "text": "Nothing at runtime — the type parameter is erased; it exists purely for static type checkers to catch mismatches before the code runs" },
        { "id": "c", "text": "Box[str] raises a TypeError if given a non-string value" },
        { "id": "d", "text": "They are compiled into entirely separate classes" }
      ],
      "correct": "b",
      "explanation": "Generic type parameters in Python are erased at runtime — Box[int] and Box[str] behave identically when run. The value of Generic is purely in enabling static type checkers to catch type errors before execution."
    },
    {
      "id": "async-typing-typing-protocols-generics-q3",
      "type": "mcq",
      "prompt": "What problem does ParamSpec solve for a generic decorator like make_logged?",
      "options": [
        { "id": "a", "text": "It makes the wrapper function execute faster" },
        { "id": "b", "text": "It preserves the original function's exact parameter signature in the type system, so a type checker can still validate calls to the decorated function correctly" },
        { "id": "c", "text": "It automatically adds logging without needing a wrapper function" },
        { "id": "d", "text": "It converts *args/**kwargs into required positional parameters at runtime" }
      ],
      "correct": "b",
      "explanation": "Without ParamSpec, a generic decorator's return type is typically Callable[..., R], losing the original signature for type-checking purposes. P = ParamSpec(\"P\") lets Callable[P, R] carry that exact signature through the decorator."
    }
  ]
}
```
