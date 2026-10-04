---
kind: lesson
id_key: interview-prep-45/python-classes-deep-dive
course: interview-prep-45
section: backend-python
section_title: "Python"
section_position: 6
section_group: "Backend"
title: "Classes Deep Dive: Method Types, MRO, Metaclasses"
position: 3
estimated_minutes: 30
source:
    - interview-prep-notes.md
---

A class interview usually opens with "explain the three kinds of methods," moves to "what happens when two parents share a grandparent," and sometimes ends with "what is a metaclass, and have you ever needed one." All three build on the same idea: a class is just an object too, with its own rules for how names are looked up.

## Instance, class, and static methods

```python
class Pizza:
    total_made = 0

    def __init__(self, toppings):
        self.toppings = toppings
        Pizza.total_made += 1

    def describe(self):                    # instance method: needs self
        return f"Pizza with {', '.join(self.toppings)}"

    @classmethod
    def margherita(cls):                    # classmethod: needs cls, not an instance
        return cls(["tomato", "mozzarella"])  # cls() so subclasses get the right type

    @staticmethod
    def is_valid_topping(name):             # staticmethod: needs neither
        return name in {"tomato", "mozzarella", "basil", "pepperoni"}
```

An **instance method** takes `self` and works on one object's own data. It's the default, called as `instance.method()`.

A **classmethod** takes `cls` and works on the class as a whole, not one particular object. The textbook use is an alternate constructor: `Pizza.margherita()` builds a pizza without the caller needing to know the topping list. Using `cls(...)` instead of hardcoding `Pizza(...)` matters for inheritance: if a `Margherita` subclass calls `Margherita.margherita()`, `cls` is bound to `Margherita`, so `cls(...)` correctly builds a `Margherita`. Had the method hardcoded `Pizza(...)`, every subclass calling this constructor would quietly get back a plain `Pizza` instead.

A **staticmethod** takes neither. It's a plain function that happens to live inside the class because it's related, like `is_valid_topping` above. It's a label for readers, not a mechanism with special binding.

> **Remember:** if the method needs one object's data, it's an instance method. If it needs the class but not one object (an alternate constructor), it's a classmethod. If it needs neither, it's a staticmethod, or arguably just a module-level function.

```knowledge-check
{ "questions": [
    { "id": "backend-python-classes-methodtypes-q1", "type": "mcq",
      "prompt": "A classmethod alternate constructor uses cls(...) instead of hardcoding the class name. Why does that matter?",
      "options": [
        {"id":"a","text":"It doesn't matter; both are always identical"},
        {"id":"b","text":"When a subclass calls the inherited classmethod, cls is bound to the subclass, so cls(...) builds an instance of the subclass instead of always building the parent"},
        {"id":"c","text":"cls() runs faster than calling the class name directly"},
        {"id":"d","text":"Hardcoding the class name is required for classmethods to work at all"}
      ],
      "correct": "b",
      "explanation": "cls is bound to whichever class the method was actually called through. Using cls(...) lets an inherited alternate constructor correctly build the subclass, not silently fall back to the parent class." }
] }
```

## Method Resolution Order (MRO)

When a class inherits from two parents that share a common ancestor, Python needs one deterministic rule for which parent's method wins when you call `super()`. That rule is called C3 linearization, and the order it produces is the class's MRO.

```python
class Base:
    def greet(self):
        return "Base"

class Left(Base):
    def greet(self):
        return f"Left -> {super().greet()}"

class Right(Base):
    def greet(self):
        return f"Right -> {super().greet()}"

class Diamond(Left, Right):
    def greet(self):
        return f"Diamond -> {super().greet()}"

d = Diamond()
print(d.greet())        # Diamond -> Left -> Right -> Base
print(Diamond.__mro__)  # (Diamond, Left, Right, Base, object)
```

Tracing `d.greet()`: `Diamond.greet` calls `super().greet()`, which does not mean "my direct parent," it means "the next class after `Diamond` in the MRO," which is `Left`. `Left.greet` runs and calls `super().greet()` again, landing on `Right` (the next class after `Left`). `Right.greet` calls `super().greet()` once more, landing on `Base`, which returns `"Base"` with no further `super()` call. The calls unwind back up to build the full string. Notice `Base.greet` runs exactly once, even though both `Left` and `Right` inherit from it: C3 linearization visits each class only once, which is exactly what solves the diamond problem. A naive "check my parents in order, depth-first" search would call `Base.greet` twice.

Two guarantees make the MRO predictable instead of arbitrary: a class always comes before its own parents, and parents are checked in the order they're listed (`Left` before `Right`, since `class Diamond(Left, Right)` lists them that way). If Python can't compute a consistent order, for example one base requires `A` before `B` while another requires the opposite, it raises `TypeError: Cannot create a consistent method resolution order` at class-definition time, rather than silently guessing.

> **Remember:** `super()` means "the next class in the MRO," not "my direct parent." That's what lets every class call `super()` and still visit each ancestor exactly once.

```knowledge-check
{ "questions": [
    { "id": "backend-python-classes-mro-q1", "type": "mcq",
      "prompt": "class Diamond(Left, Right) where both Left and Right inherit from Base. How many times does Base's method run when Diamond calls it through a chain of super() calls?",
      "options": [
        {"id":"a","text":"Twice, once through each parent"},
        {"id":"b","text":"Exactly once, because C3 linearization visits each class in the MRO only one time"},
        {"id":"c","text":"Zero times, because Diamond overrides it"},
        {"id":"d","text":"It depends on the order Left and Right are listed"}
      ],
      "correct": "b",
      "explanation": "The whole point of C3 linearization is producing one order where each ancestor appears exactly once, which is what actually solves the diamond problem: a naive depth-first search would call Base's method twice." }
] }
```

## Metaclasses: a blueprint for classes

A class is a blueprint for objects. A metaclass is a blueprint for classes. In Python, classes are themselves objects: every class is an instance of some metaclass, and by default that metaclass is `type`.

```python
class Dog:
    pass

print(type(Dog))  # <class 'type'>
print(type(42))   # <class 'int'>
```

`Dog` is an instance of `type`, the same way `42` is an instance of `int`. Writing `class Dog: ...` internally calls `type` to build the class object.

You can write a custom metaclass by subclassing `type` and overriding `__new__`, which runs when the class itself is being created:

```python
class UpperMeta(type):
    def __new__(mcs, name, bases, attrs):
        name = name.upper()
        return super().__new__(mcs, name, bases, attrs)

class dog(metaclass=UpperMeta):
    pass

print(dog.__name__)  # DOG
```

This explains framework "magic" you'll run into constantly: Django's ORM `Model` class uses a metaclass to scan its own class attributes (`CharField`, `IntegerField`, and so on) at class-definition time and register them as table columns. Pydantic (which FastAPI uses) does something similar to build validation and schema generation from annotated fields. The most practical everyday use is `abc.ABCMeta`, for enforcing an interface:

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

You'll rarely write one in application code. If a decorator or `__init_subclass__` (a simpler hook that runs when a class is subclassed, without the full metaclass machinery) solves the problem, prefer that instead. Recognizing a metaclass explains a lot of "how does this framework know about my fields" moments, even if you never write your own.

> **Remember:** every class is an instance of `type` unless told otherwise. A metaclass controls how the class object itself gets built, which is exactly how Django and Pydantic turn plain class bodies into working schemas.

```knowledge-check
{ "questions": [
    { "id": "backend-python-classes-metaclass-q1", "type": "mcq",
      "prompt": "What is the default metaclass for every class in Python that doesn't specify one?",
      "options": [
        {"id":"a","text":"object"},
        {"id":"b","text":"type"},
        {"id":"c","text":"ABCMeta"},
        {"id":"d","text":"There is no default; a metaclass must always be specified"}
      ],
      "correct": "b",
      "explanation": "Every class, unless you say otherwise, is an instance of type. Writing class Dog: ... internally calls type to actually construct the Dog class object." }
] }
```
