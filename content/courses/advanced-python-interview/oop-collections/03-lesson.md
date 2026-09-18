---
kind: lesson
id_key: advanced-python-interview/oop-collections/abstraction
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "Abstraction"
position: 2
estimated_minutes: 12
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

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-abstraction-q1",
      "type": "mcq",
      "prompt": "What is the main benefit of code calling `shape.area()` on an abstract `Shape` instead of branching on `isinstance(shape, Rectangle)` etc.?",
      "options": [
        { "id": "a", "text": "It runs faster because isinstance checks are slow" },
        { "id": "b", "text": "Adding a new shape type requires no changes to the calling code — it already works through the shared contract" },
        { "id": "c", "text": "It avoids using the abc module, which is deprecated" },
        { "id": "d", "text": "It removes the need for a Shape class entirely" }
      ],
      "correct": "b",
      "explanation": "Calling code that depends on the abstract contract (area()) rather than concrete types doesn't need to change when a new shape is added, since every shape implements that same contract."
    },
    {
      "id": "oop-collections-abstraction-q2",
      "type": "mcq",
      "prompt": "How does abstraction differ from encapsulation?",
      "options": [
        { "id": "a", "text": "They are exactly the same concept with two names" },
        { "id": "b", "text": "Encapsulation hides an object's internal data behind methods; abstraction hides implementation details behind a shared contract callers rely on" },
        { "id": "c", "text": "Abstraction only applies to abstract base classes; encapsulation only applies to modules" },
        { "id": "d", "text": "Encapsulation is a Python-only concept; abstraction applies to all languages" }
      ],
      "correct": "b",
      "explanation": "Encapsulation is the data-hiding mechanism (private-ish attributes plus accessor methods); abstraction is the design principle of exposing a simple contract and hiding the complexity behind it."
    }
  ]
}
```
