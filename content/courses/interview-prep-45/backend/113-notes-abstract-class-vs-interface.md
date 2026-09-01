---
kind: lesson
id_key: interview-prep-45/note-abstract-class-vs-interface
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Abstract Class vs Interface (LLD)"
position: 113
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

This course covers design patterns like Singleton, Factory, Observer, Strategy, Repository, and Builder elsewhere, along with SOLID, polymorphism, and abstraction vs encapsulation, but none of that material names the specific question that opens almost every low-level-design round: "when do you reach for an abstract class instead of an interface?" This note is that answer, framed the way interviewers actually ask it.

## The one-line distinction

**Abstract class means "IS-A."** Use it when subclasses share both a *type relationship* and *some common implementation*. A `Dog` **is an** `Animal`.

**Interface means "CAN-DO."** Use it when unrelated classes need to promise the same *capability*, with no shared code. A `Dog` **can** `Swim`; so can a `Boat`, which is not an `Animal`.

## Side by side

| | Abstract class | Interface |
|---|---|---|
| Instantiable directly | No | No |
| Method implementation | Can mix concrete and abstract methods | Python `Protocol`/`ABC` with no body; contract only |
| State (fields) | Yes, shared instance state | No (Python `Protocol` structural types carry no state) |
| Inheritance | Single, in most languages | A class can satisfy many |
| Answers | "What are you, and what do you already do?" | "What can you do, regardless of what you are?" |

## Python: `abc.ABC` as the abstract-class mechanism

Python doesn't have a separate `abstract class` keyword like Java or C#. `abc.ABC` plus `@abstractmethod` gives the same contract-enforcement:

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    def __init__(self, color: str):
        self.color = color          # shared state — every Shape has a color

    def describe(self) -> str:      # concrete method — shared behavior
        return f"A {self.color} shape with area {self.area():.2f}"

    @abstractmethod
    def area(self) -> float: ...    # subclass MUST implement this

class Circle(Shape):
    def __init__(self, color: str, radius: float):
        super().__init__(color)
        self.radius = radius

    def area(self) -> float:
        return 3.14159 * self.radius ** 2

Shape("red")     # TypeError: Can't instantiate abstract class Shape
Circle("red", 2).describe()   # "A red shape with area 12.57"
```

Trying to instantiate `Shape` directly raises `TypeError` at the moment of instantiation. Python enforces the abstract contract at runtime, not compile time, since there is no compile step. A subclass that forgets to implement `area()` is also abstract and also can't be instantiated; the error surfaces the first time someone tries to construct it, not when the subclass is defined.

## Python's actual "interface": `Protocol`, not a keyword

Python has no `interface` keyword. The closest equivalent is `typing.Protocol`, which uses **structural** typing ("if it has the right shape, it satisfies the protocol") instead of the **nominal** typing Java's `implements` requires:

```python
from typing import Protocol

class Swimmer(Protocol):
    def swim(self) -> str: ...

class Dog:
    def swim(self) -> str:
        return "paddles"

class Boat:
    def swim(self) -> str:
        return "cuts through water"

def race(swimmer: Swimmer) -> str:
    return swimmer.swim()

race(Dog())   # works — Dog never declared "implements Swimmer", it just has the method
race(Boat())  # works too — Boat is unrelated to Dog entirely
```

Neither `Dog` nor `Boat` inherits from `Swimmer`. They satisfy it just by having a matching method signature. When `race(Dog())` runs, Python doesn't check any declared relationship at all; it just calls `swimmer.swim()` and trusts that whatever object was passed in has a `swim` method, which both `Dog` and `Boat` happen to define. This is the concrete Python answer to "CAN-DO": no shared ancestor, no shared code, just a shared capability checked structurally, either by a type checker like mypy or by duck-typing at runtime.

## Template Method: the pattern abstract classes exist to enable

The **Template Method** pattern is the reason abstract classes are useful beyond "a place to put shared fields": the abstract class defines the *skeleton* of an algorithm, and subclasses fill in only the steps that vary.

```python
class DataPipeline(ABC):
    def run(self) -> None:              # the "template" — fixed sequence, never overridden
        data = self.extract()
        cleaned = self.transform(data)
        self.load(cleaned)

    @abstractmethod
    def extract(self): ...
    @abstractmethod
    def transform(self, data): ...
    @abstractmethod
    def load(self, data): ...

class CsvPipeline(DataPipeline):
    def extract(self): return open("in.csv").read()
    def transform(self, data): return data.upper()
    def load(self, data): open("out.csv", "w").write(data)
```

`run()` is never overridden. The algorithm's *shape* is fixed in the base class, and only its *steps* vary per subclass: calling `CsvPipeline().run()` executes `DataPipeline.run`, which calls `self.extract()`, `self.transform()`, and `self.load()` in that fixed order, but each of those three calls resolves to `CsvPipeline`'s own implementation. This is the pattern interviewers are checking for when they ask "why not just use an interface with three methods and call them in the right order from the caller." The answer is that the abstract class owns and guarantees the calling order itself, so no subclass can call the steps out of sequence or forget one.

## Interview Q&A

**Q: Abstract class vs interface, when do you pick which?**
> "Abstract class when subclasses share both an IS-A relationship and some common state or implementation, so you put the shared part there once. Interface, or in Python a `Protocol`, when unrelated classes need to promise the same capability with no shared code. A `Dog` and a `Boat` can both `swim()` without being related types."

**Q: Can an abstract class have a constructor if it can't be instantiated?**
> "Yes. The constructor runs when a subclass instance is created, via `super().__init__()`. It can't be instantiated directly, but its `__init__` is still part of every subclass's construction."

**Q: Why not just use a Strategy pattern instead of an abstract base class?**
> "Strategy swaps a whole algorithm at runtime via composition; you inject a different strategy object. Template Method fixes the algorithm's shape at definition time and only lets subclasses vary specific steps. Pick Template Method when the sequence must never change; pick Strategy when you need to swap the entire algorithm dynamically."
