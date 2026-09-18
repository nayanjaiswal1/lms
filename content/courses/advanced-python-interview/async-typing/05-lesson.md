---
kind: lesson
id_key: advanced-python-interview/async-typing/descriptors
course: advanced-python-interview
section: async-typing
section_title: "Async, Callables & Advanced Typing"
section_position: 8
title: "Descriptors (Typed + CachedProperty)"
position: 4
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/54.descriptors.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_53_54.md"]
---
`@property` is the descriptor you already know — descriptors are the general mechanism behind it. A descriptor is any object defining `__get__`/`__set__` (or just `__get__`) and assigned as a *class* attribute; Python routes attribute access on instances through those methods instead of a plain `__dict__` lookup. This is how validated attributes, cached properties, and ORM fields are all built under the hood.

## Data descriptors: `__get__` and `__set__`

A descriptor defining both `__get__` and `__set__` is a **data descriptor** — it takes priority over the instance's own `__dict__` for every access, which is what lets it enforce rules on every read and write:

```python
from typing import Any

class Typed:
    """Enforces a type on every assignment to the attribute it manages."""

    def __init__(self, name: str, expected_type: type) -> None:
        self.name = name
        self.expected_type = expected_type

    def __get__(self, instance: Any, owner: type = None) -> Any:
        if instance is None:
            return self  # accessed on the class itself, e.g. Point.x
        return instance.__dict__.get(self.name)

    def __set__(self, instance: Any, value: Any) -> None:
        if not isinstance(value, self.expected_type):
            raise TypeError(f"{self.name} must be {self.expected_type.__name__}")
        instance.__dict__[self.name] = value

class Point:
    x = Typed("x", int)  # descriptors are declared at the CLASS level
    y = Typed("y", int)

    def __init__(self, x: int, y: int) -> None:
        self.x = x  # routed through Typed.__set__
        self.y = y

p = Point(3, 4)
print(p.x, p.y)  # 3 4 — routed through Typed.__get__

try:
    p.x = 2.5
except TypeError as e:
    print("blocked:", e)  # x must be int
```

`Point.x` and `Point.y` are the *same* `Typed` instance shared by every `Point` — the actual per-instance value lives in `instance.__dict__["x"]`, not on the descriptor itself. That's why `__set__` writes to `instance.__dict__[self.name]` rather than `self.value = value`: storing it on `self` would make every `Point` share one `x`.

## Non-data descriptors: caching with just `__get__`

A descriptor defining only `__get__` (no `__set__`) is a **non-data descriptor** — and the instance's own `__dict__` takes priority over it once something is stored there under the same name. That asymmetry is exactly what makes a cheap cached-property pattern possible: compute once, then let the plain instance attribute shadow the descriptor on every later access:

```python
class CachedProperty:
    def __init__(self, func):
        self.func = func
        self.__doc__ = func.__doc__

    def __get__(self, instance, owner=None):
        if instance is None:
            return self
        value = self.func(instance)
        instance.__dict__[self.func.__name__] = value  # shadows this descriptor from now on
        return value

class Point:
    x = Typed("x", int)
    y = Typed("y", int)

    def __init__(self, x: int, y: int) -> None:
        self.x = x
        self.y = y

    @CachedProperty
    def hypot(self):
        print("computing hypot")
        from math import hypot
        return hypot(self.x, self.y)

p = Point(3, 4)
print(p.hypot)  # "computing hypot" printed, then 5.0
print(p.hypot)  # 5.0 — no "computing hypot" print; instance.__dict__["hypot"] now shadows the descriptor
```

The first `p.hypot` access finds nothing under `"hypot"` in `p.__dict__`, so Python falls back to the class-level `CachedProperty` descriptor's `__get__`, which computes the value *and* stores it directly on the instance. The second access finds `"hypot"` already in `p.__dict__` and returns that directly — the descriptor's `__get__` never even runs again, because a non-data descriptor loses to an instance attribute of the same name.

## Why `Typed` doesn't have this problem

`Typed` defines `__set__`, making it a *data* descriptor — data descriptors always win over `instance.__dict__`, even after a value has been assigned. That's the difference that matters: use a data descriptor when every access must be validated (there's no safe point to "stop checking"), and a non-data descriptor when the first computation should permanently short-circuit future lookups.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-descriptors-q1",
      "type": "mcq",
      "prompt": "Why does Typed.__set__ store the value in instance.__dict__[self.name] instead of on self (the descriptor)?",
      "options": [
        { "id": "a", "text": "It's just a style preference with no functional effect" },
        { "id": "b", "text": "The Typed instance (e.g. Point.x) is shared by every Point instance — storing the value on self would make all Points share one x" },
        { "id": "c", "text": "instance.__dict__ is faster to write to than a plain attribute" },
        { "id": "d", "text": "Python requires descriptors to never store any state" }
      ],
      "correct": "b",
      "explanation": "Point.x is one Typed object shared across every Point instance. Storing per-instance data on that shared descriptor would leak state between unrelated instances — instance.__dict__ keeps each Point's x separate."
    },
    {
      "id": "async-typing-descriptors-q2",
      "type": "mcq",
      "prompt": "Why does the second access to p.hypot NOT print \"computing hypot\" again?",
      "options": [
        { "id": "a", "text": "CachedProperty.__get__ has internal logic that skips computation on even-numbered calls" },
        { "id": "b", "text": "The first access stored the result directly in instance.__dict__[\"hypot\"], which — since CachedProperty is a non-data descriptor (no __set__) — now takes priority over the descriptor on every later lookup" },
        { "id": "c", "text": "Python automatically caches all @property-style decorators" },
        { "id": "d", "text": "hypot becomes a class attribute after the first call" }
      ],
      "correct": "b",
      "explanation": "A non-data descriptor (only __get__, no __set__) loses to an instance attribute of the same name. Once p.__dict__[\"hypot\"] exists, Python finds it before ever consulting the CachedProperty descriptor again."
    },
    {
      "id": "async-typing-descriptors-q3",
      "type": "mcq",
      "prompt": "Why does Typed keep enforcing type checks on every write, while CachedProperty stops running after the first read?",
      "options": [
        { "id": "a", "text": "Typed defines __set__ (a data descriptor, which always overrides instance.__dict__); CachedProperty only defines __get__ (a non-data descriptor, which instance.__dict__ overrides once populated)" },
        { "id": "b", "text": "Typed is simply written with a while loop and CachedProperty isn't" },
        { "id": "c", "text": "There is no real difference — both behave identically" },
        { "id": "d", "text": "CachedProperty is deprecated in favor of Typed" }
      ],
      "correct": "a",
      "explanation": "Data descriptors (with __set__) always take priority over instance.__dict__, so every p.x = value keeps going through Typed.__set__. Non-data descriptors (only __get__) lose to instance.__dict__ once a same-named entry exists there, which is exactly the mechanism CachedProperty uses to short-circuit future computation."
    }
  ]
}
```
