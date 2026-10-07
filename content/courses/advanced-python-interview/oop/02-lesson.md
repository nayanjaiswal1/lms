---
kind: lesson
id_key: advanced-python-interview/oop-collections/abstraction
course: advanced-python-interview
section: oop
section_title: "Object-Oriented Python"
section_position: 3
section_group: Fundamentals
title: "Abstraction"
position: 1
estimated_minutes: 27
source: [fifty-advanced-python-concepts/16.abstraction.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
Abstraction is the design principle of exposing *what* an object does while hiding *how* it does it. Encapsulation (the previous lesson) is the mechanism — hiding fields behind methods; abstraction is the goal — presenting a simple contract so callers never need to know the implementation.

## A contract, not an implementation

In Python, the most common way to express "here is a contract every subclass must fulfill" is an Abstract Base Class:

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    """Defines a strict contract for all shapes — no implementation here."""

    @abstractmethod
    def area(self) -> float:
        """Return the area of the shape."""
        ...

    @abstractmethod
    def perimeter(self) -> float:
        """Return the perimeter of the shape."""
        ...


class Rectangle(Shape):
    def __init__(self, width: float, height: float):
        self.width = width
        self.height = height

    def area(self) -> float:
        return self.width * self.height

    def perimeter(self) -> float:
        return 2 * (self.width + self.height)


shape = Rectangle(5, 10)
print(shape.area())       # 50
print(shape.perimeter())  # 30
```

Code that calls `shape.area()` never needs to know it's a `Rectangle` computing `width * height` — it only needs to know every `Shape` has an `area()` method that returns a float. That's the whole point: the caller depends on the *abstraction* (`Shape`), not the *implementation* (`Rectangle`).

## Why this matters at scale

Without abstraction, callers end up branching on concrete types (`if isinstance(shape, Rectangle): ... elif isinstance(shape, Circle): ...`), which means every new shape requires editing every place that branches. With an abstract contract, adding `Triangle(Shape)` requires touching exactly one file — the caller code that already does `shape.area()` works unmodified. This is the same idea behind interfaces in Java/Go and protocols in TypeScript.

## Abstraction vs. encapsulation, side by side

- **Encapsulation**: `BankAccount` hides `__balance` behind `deposit()`/`withdraw()` — a *data hiding* mechanism.
- **Abstraction**: `Shape` hides *how* area is computed behind a common `area()` signature — a *design* principle about what callers need to know.

They're complementary, and interviewers often use "aren't these the same thing?" as a follow-up to see if you can articulate the distinction rather than just define both terms.

## Abstract Base Classes (`abc`)

The previous lesson used `ABC` and `@abstractmethod` to illustrate abstraction as a *design idea*. This lesson is about the `abc` module's actual *mechanics* — what it enforces, when it enforces it, and how it differs from just raising `NotImplementedError` by hand.

### The enforcement is real, and it's a `TypeError`

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self):
        pass

    @abstractmethod
    def perimeter(self):
        pass

    def concrete(self):
        # ABCs can mix abstract methods with normal, already-implemented ones
        return "Subscribe"


class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height

    def perimeter(self):
        return 2 * (self.width + self.height)


rect = Rectangle(4, 5)
print(rect.area())       # 20
print(rect.perimeter())  # 18
print(rect.concrete())   # Subscribe — inherited, non-abstract method
```

Try to instantiate `Shape` itself, or a subclass that skips one of the abstract methods, and Python refuses at construction time:

```python
class IncompleteShape(Shape):
    def area(self):
        return 0
    # perimeter() not implemented

try:
    shape = IncompleteShape()
except TypeError as e:
    print(f"TypeError: {e}")
    # Can't instantiate abstract class IncompleteShape
    # without an implementation for abstract method 'perimeter'
```

### Why this beats hand-rolled `NotImplementedError`

A common alternative is a plain base class where unimplemented methods raise manually:

```python
class Shape:
    def area(self):
        raise NotImplementedError
```

That "contract" is only checked when `area()` is actually *called* — a subclass that forgets to override it will instantiate just fine and blow up later, at runtime, possibly in production. `ABC` + `@abstractmethod` moves that check to **instantiation time**: `IncompleteShape()` fails immediately, long before any code path calls `.perimeter()`. This is the concrete reason ABCs are considered "safer" than the `NotImplementedError` convention — the failure mode shifts from "surprises in production" to "the object never gets created."

### `ABC` can still hold real logic

`Shape.concrete()` above is not abstract — ABCs are not purely interfaces; they can mix abstract methods (the required contract) with fully implemented ones (shared behavior every subclass gets for free). This is exactly the pattern used throughout Django and FastAPI internals: an abstract base defines the required hooks, plus utility methods built on top of those hooks.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-abstraction-q1",
      "type": "mcq",
      "prompt": "What is the main benefit of code calling `shape.area()` on an abstract `Shape` instead of branching on `isinstance(shape, Rectangle)` etc.?",
      "options": [
        {
          "id": "a",
          "text": "It runs faster because isinstance checks are slow"
        },
        {
          "id": "b",
          "text": "Adding a new shape type requires no changes to the calling code — it already works through the shared contract"
        },
        {
          "id": "c",
          "text": "It avoids using the abc module, which is deprecated"
        },
        {
          "id": "d",
          "text": "It removes the need for a Shape class entirely"
        }
      ],
      "correct": "b",
      "explanation": "Calling code that depends on the abstract contract (area()) rather than concrete types doesn't need to change when a new shape is added, since every shape implements that same contract."
    },
    {
      "id": "oop-collections-abstraction-q2",
      "type": "mcq",
      "prompt": "How does abstraction differ from encapsulation?",
      "options": [
        {
          "id": "a",
          "text": "They are exactly the same concept with two names"
        },
        {
          "id": "b",
          "text": "Encapsulation hides an object's internal data behind methods; abstraction hides implementation details behind a shared contract callers rely on"
        },
        {
          "id": "c",
          "text": "Abstraction only applies to abstract base classes; encapsulation only applies to modules"
        },
        {
          "id": "d",
          "text": "Encapsulation is a Python-only concept; abstraction applies to all languages"
        }
      ],
      "correct": "b",
      "explanation": "Encapsulation is the data-hiding mechanism (private-ish attributes plus accessor methods); abstraction is the design principle of exposing a simple contract and hiding the complexity behind it."
    },
    {
      "id": "oop-collections-abstract-base-classes-q1",
      "type": "mcq",
      "prompt": "When does Python raise an error if a subclass of an ABC fails to implement one of its `@abstractmethod`s?",
      "options": [
        {
          "id": "a",
          "text": "At import time, when the subclass is first defined"
        },
        {
          "id": "b",
          "text": "At instantiation time — trying to construct the incomplete subclass raises TypeError"
        },
        {
          "id": "c",
          "text": "Only when the missing method is actually called"
        },
        {
          "id": "d",
          "text": "Never — ABC only issues a warning, not an error"
        }
      ],
      "correct": "b",
      "explanation": "The abc module blocks instantiation of any concrete class that hasn't implemented every abstract method — the error surfaces immediately at construction, not later when the method happens to be called."
    },
    {
      "id": "oop-collections-abstract-base-classes-q2",
      "type": "mcq",
      "prompt": "Why is `ABC` + `@abstractmethod` generally preferred over a base class that raises `NotImplementedError` by hand?",
      "options": [
        {
          "id": "a",
          "text": "ABC classes run faster at runtime"
        },
        {
          "id": "b",
          "text": "ABC fails at instantiation time if a method is missing; NotImplementedError only fails when that specific method is later called"
        },
        {
          "id": "c",
          "text": "NotImplementedError is deprecated in modern Python"
        },
        {
          "id": "d",
          "text": "ABC classes cannot contain any concrete (non-abstract) methods, which is considered safer"
        }
      ],
      "correct": "b",
      "explanation": "Hand-rolled NotImplementedError only surfaces the bug when the unimplemented method is actually invoked, which can be much later and in production. ABC enforcement happens the moment the incomplete class is instantiated."
    }
  ]
}
```
