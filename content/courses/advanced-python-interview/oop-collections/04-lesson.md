---
kind: lesson
id_key: advanced-python-interview/oop-collections/abstract-base-classes
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "Abstract Base Classes (`abc`)"
position: 3
estimated_minutes: 15
source: [fifty-advanced-python-concepts/17.abstract_classes.py, fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
The previous lesson used `ABC` and `@abstractmethod` to illustrate abstraction as a *design idea*. This lesson is about the `abc` module's actual *mechanics* — what it enforces, when it enforces it, and how it differs from just raising `NotImplementedError` by hand.

## The enforcement is real, and it's a `TypeError`

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

## Why this beats hand-rolled `NotImplementedError`

A common alternative is a plain base class where unimplemented methods raise manually:

```python
class Shape:
    def area(self):
        raise NotImplementedError
```

That "contract" is only checked when `area()` is actually *called* — a subclass that forgets to override it will instantiate just fine and blow up later, at runtime, possibly in production. `ABC` + `@abstractmethod` moves that check to **instantiation time**: `IncompleteShape()` fails immediately, long before any code path calls `.perimeter()`. This is the concrete reason ABCs are considered "safer" than the `NotImplementedError` convention — the failure mode shifts from "surprises in production" to "the object never gets created."

## `ABC` can still hold real logic

`Shape.concrete()` above is not abstract — ABCs are not purely interfaces; they can mix abstract methods (the required contract) with fully implemented ones (shared behavior every subclass gets for free). This is exactly the pattern used throughout Django and FastAPI internals: an abstract base defines the required hooks, plus utility methods built on top of those hooks.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-abstract-base-classes-q1",
      "type": "mcq",
      "prompt": "When does Python raise an error if a subclass of an ABC fails to implement one of its `@abstractmethod`s?",
      "options": [
        { "id": "a", "text": "At import time, when the subclass is first defined" },
        { "id": "b", "text": "At instantiation time — trying to construct the incomplete subclass raises TypeError" },
        { "id": "c", "text": "Only when the missing method is actually called" },
        { "id": "d", "text": "Never — ABC only issues a warning, not an error" }
      ],
      "correct": "b",
      "explanation": "The abc module blocks instantiation of any concrete class that hasn't implemented every abstract method — the error surfaces immediately at construction, not later when the method happens to be called."
    },
    {
      "id": "oop-collections-abstract-base-classes-q2",
      "type": "mcq",
      "prompt": "Why is `ABC` + `@abstractmethod` generally preferred over a base class that raises `NotImplementedError` by hand?",
      "options": [
        { "id": "a", "text": "ABC classes run faster at runtime" },
        { "id": "b", "text": "ABC fails at instantiation time if a method is missing; NotImplementedError only fails when that specific method is later called" },
        { "id": "c", "text": "NotImplementedError is deprecated in modern Python" },
        { "id": "d", "text": "ABC classes cannot contain any concrete (non-abstract) methods, which is considered safer" }
      ],
      "correct": "b",
      "explanation": "Hand-rolled NotImplementedError only surfaces the bug when the unimplemented method is actually invoked, which can be much later and in production. ABC enforcement happens the moment the incomplete class is instantiated."
    }
  ]
}
```
