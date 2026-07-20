---
kind: lesson
id_key: interview-prep-45/note-metaclasses
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Metaclasses"
position: 100
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Not something you'll write day-to-day, but it explains framework "magic" you use constantly in this course — Django's ORM `Model` class and Pydantic's field validation are both metaclass-driven.

## What a metaclass is

A class is a blueprint for objects. A metaclass is a blueprint for classes. In Python, classes are themselves objects — every class is an instance of some metaclass, and by default that metaclass is `type`.

```python
class Dog:
    pass

print(type(Dog))  # <class 'type'>
print(type(42))   # <class 'int'>
```

`Dog` is an instance of `type` the same way `42` is an instance of `int`. When you write `class Dog: ...`, Python internally calls `type` to construct the class object.

## Writing a custom metaclass

Subclass `type` and override `__new__`, which runs when the **class itself** is being created — not when an instance of it is created:

```python
class UpperMeta(type):
    def __new__(mcs, name, bases, attrs):
        name = name.upper()
        return super().__new__(mcs, name, bases, attrs)

class dog(metaclass=UpperMeta):
    pass

print(dog.__name__)  # DOG
```

## Where this shows up in frameworks already in this course

| Framework | What the metaclass does |
|---|---|
| Django ORM | `Model`'s metaclass scans class attributes (`CharField`, `IntegerField`, ...) at class-definition time and registers them as table columns |
| Pydantic / FastAPI | Scans annotated fields to build validation and schema generation |
| `abc.ABCMeta` | Enforces that subclasses implement abstract methods, checked at class-creation time |

`ABCMeta` is the most practical everyday use — enforcing an interface:

```python
from abc import ABC, abstractmethod

class PaymentGateway(ABC):
    @abstractmethod
    def charge(self, amount: float):
        pass

class StripeGateway(PaymentGateway):
    def charge(self, amount: float):
        print(f"Charging {amount} via Stripe")

# Forgetting to implement charge() raises TypeError at instantiation,
# not at some unrelated point at runtime.
```

## When to actually reach for one

Rarely, in application code. If a decorator or `__init_subclass__` (a simpler hook that runs when a class is *subclassed*, without the full metaclass machinery) solves the problem, prefer that. Metaclasses are best left to framework/library authors — but recognizing one explains a lot of "how does Django know about my model fields" moments.

## Key takeaways

- A metaclass is a class of a class; `type` is Python's default metaclass, and every class is an instance of it.
- Custom metaclasses override `type.__new__`, which fires at class-creation time, not instance-creation time.
- Django's ORM and Pydantic both use metaclasses to scan declared fields and auto-register them — that's the "magic" behind `models.Model` and Pydantic `BaseModel`.
- `ABCMeta` is the most common practical use: enforcing that subclasses implement required methods, checked when the class is defined.
- Prefer a decorator or `__init_subclass__` over a full metaclass when either one solves the problem — metaclasses are a framework-author tool, not an everyday one.
