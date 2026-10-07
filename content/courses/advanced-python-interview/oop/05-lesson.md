---
kind: lesson
id_key: advanced-python-interview/exceptions-oop/composition-vs-inheritance
course: advanced-python-interview
section: oop
section_title: "Object-Oriented Python"
section_position: 3
section_group: Fundamentals
title: "Composition vs Inheritance, isinstance() vs type(), Overriding vs Overloading"
position: 3
estimated_minutes: 12
source: ["knowledge/backend/python/python-oop-lld.md"]
---
Three short questions that come up in almost every OOP interview round: when to build a class out of other objects, how to check types correctly, and what "overloading" means in a language that has none.

## Composition: has-a design

Inheritance models "is-a" (`Dog` is an `Animal`); composition models "has-a" (`Car` has an `Engine`). With composition the outer class holds another object and delegates to it. The parts are loosely coupled: you can swap the engine, test the car with a fake engine, and change `Engine` internals without touching a class hierarchy. The rule of thumb: if you are inheriting only to reuse code and the "is-a" sentence sounds wrong, compose instead.

```python
class Engine:
    def start(self):
        return "Engine started"

class ElectricMotor:
    def start(self):
        return "Motor humming"

class Car:
    def __init__(self, engine):
        self.engine = engine  # injected: Car HAS-A engine

    def drive(self):
        return self.engine.start()

print(Car(Engine()).drive())
print(Car(ElectricMotor()).drive())
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-composition-vs-inheritance-q1",
      "type": "mcq",
      "prompt": "Which is the best reason to prefer composition over inheritance?",
      "options": [
        { "id": "a", "text": "Parts can be swapped or faked without changing a class hierarchy, so coupling is looser" },
        { "id": "b", "text": "Composition is faster at runtime" },
        { "id": "c", "text": "Python forbids inheriting from more than one class" },
        { "id": "d", "text": "Composition automatically exposes the inner object's methods" }
      ],
      "correct": "a",
      "explanation": "A has-a relationship delegates to an injectable collaborator, avoiding rigid, deep hierarchies; delegation methods must still be written explicitly."
    }
  ]
}
```

## isinstance() vs type()

`type(x) == C` is an exact match: a subclass instance fails it. `isinstance(x, C)` also accepts subclasses (and tuples of classes), so it respects polymorphism and is what you want almost always. Use `type(x) is C` only when you truly need the exact class.

```python
class Animal:
    pass

class Dog(Animal):
    pass

d = Dog()
print(type(d) == Animal)
print(isinstance(d, Animal))
print(isinstance(d, (int, Animal)))
print(isinstance(True, int))  # bool subclasses int
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-composition-vs-inheritance-q2",
      "type": "mcq",
      "prompt": "Given `class Dog(Animal)` and `d = Dog()`, what do `type(d) == Animal` and `isinstance(d, Animal)` return?",
      "options": [
        { "id": "a", "text": "True and True" },
        { "id": "b", "text": "False and True" },
        { "id": "c", "text": "True and False" },
        { "id": "d", "text": "False and False" }
      ],
      "correct": "b",
      "explanation": "type() compares the exact class (Dog is not Animal); isinstance() walks the inheritance chain."
    },
    {
      "id": "exceptions-oop-composition-vs-inheritance-q3",
      "type": "mcq",
      "prompt": "What does `isinstance(True, int)` return, and why?",
      "options": [
        { "id": "a", "text": "False, because True is a bool" },
        { "id": "b", "text": "True, because bool is a subclass of int" },
        { "id": "c", "text": "It raises TypeError" },
        { "id": "d", "text": "True, because isinstance ignores subclasses" }
      ],
      "correct": "b",
      "explanation": "bool inherits from int, so isinstance accepts it; type(True) == int would be False."
    }
  ]
}
```

## Overriding vs overloading

**Overriding**: a subclass redefines a parent's method with the same name and signature; Python supports it directly and the subclass version wins. **Overloading**: several methods with the same name but different parameter lists. Python does not support it: defining a name twice just rebinds it to the last definition.

```python
class Math:
    def add(self, a, b):
        return a + b

    def add(self, a, b, c):  # replaces the first add
        return a + b + c

try:
    Math().add(1, 2)
except TypeError as e:
    print(e)
```

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-composition-vs-inheritance-q4",
      "type": "mcq",
      "prompt": "What happens if a Python class defines `add(self, a, b)` and later `add(self, a, b, c)`?",
      "options": [
        { "id": "a", "text": "Python picks the right one by argument count" },
        { "id": "b", "text": "The second definition replaces the first; only the 3-argument version exists" },
        { "id": "c", "text": "SyntaxError at class creation" },
        { "id": "d", "text": "Both exist and are tried in order" }
      ],
      "correct": "b",
      "explanation": "A class body is ordinary assignment; the second def rebinds the name, so there is no overloading by signature."
    }
  ]
}
```

## Simulating overloading

Three idioms cover most needs. Default arguments handle optional parameters; `*args` handles a variable count; `functools.singledispatch` dispatches on the type of the first argument, the closest thing to real overloading.

```python
from functools import singledispatch

def add(a, b=0, c=0):
    return a + b + c

def total(*nums):
    return sum(nums)

@singledispatch
def describe(x):
    return f"object: {x}"

@describe.register
def _(x: int):
    return f"int: {x}"

@describe.register
def _(x: list):
    return f"list of {len(x)}"

print(add(1, 2), total(1, 2, 3, 4))
print(describe(5), describe([1, 2]), describe("s"))
```

For methods inside a class use `functools.singledispatchmethod`.

```knowledge-check
{
  "questions": [
    {
      "id": "exceptions-oop-composition-vs-inheritance-q5",
      "type": "mcq",
      "prompt": "Which standard-library tool dispatches a function to different implementations based on the type of its first argument?",
      "options": [
        { "id": "a", "text": "functools.partial" },
        { "id": "b", "text": "functools.singledispatch" },
        { "id": "c", "text": "functools.lru_cache" },
        { "id": "d", "text": "typing.overload at runtime" }
      ],
      "correct": "b",
      "explanation": "singledispatch registers per-type implementations; typing.overload is only a hint for type checkers and has no runtime effect."
    }
  ]
}
```
