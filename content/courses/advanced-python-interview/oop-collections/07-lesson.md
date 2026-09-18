---
kind: lesson
id_key: advanced-python-interview/oop-collections/data-model
course: advanced-python-interview
section: oop-collections
section_title: "Collections & OOP Foundations"
section_position: 2
title: "The Python Data Model (Magic / Dunder Methods)"
position: 6
estimated_minutes: 15
source: [fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md]
---
The Python data model is the set of special (`__dunder__`) methods that define how your objects interact with the language's own built-in operators and functions: `+`, `len()`, `print()`, `for ... in`, `with`, `==`, and more. Implementing the right dunder methods makes a custom class behave like a built-in type instead of a second-class citizen that needs its own bespoke API.

## Without the data model: everything needs its own method name

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def add(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def to_string(self):
        return f"Vector({self.x}, {self.y})"

v1 = Vector(1, 2)
v2 = Vector(3, 4)
v3 = v1.add(v2)
print(v3.to_string())  # Vector(4, 6)
```

This works, but `v1.add(v2)` and `v3.to_string()` are bespoke APIs — nobody who hasn't read this class's source knows to call `.add()` instead of `+`, or `.to_string()` instead of `print()`.

## With the data model: it behaves like a built-in

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def __eq__(self, other):
        return self.x == other.x and self.y == other.y

    def __repr__(self):
        return f"Vector({self.x}, {self.y})"

v1 = Vector(1, 2)
v2 = Vector(3, 4)

print(v1 + v2)          # Vector(4, 6) — __add__ backs the + operator
print(v1 == Vector(1, 2))  # True — __eq__ backs ==
print(v1)                # Vector(1, 2) — __repr__ backs print()/the REPL
```

`v1 + v2` now works because `+` on any object first looks for `__add__`. `print(v1)` works because `print()` calls `repr()` on objects without a friendlier `__str__`, and `repr()` calls `__repr__`. None of this is special-cased for `Vector` — it's the exact same protocol every built-in type (`int`, `str`, `list`) already implements.

## The dunders that come up most in interviews

- `__init__` — construction (not actually "the constructor" — `__new__` is, but `__init__` is what almost everyone means)
- `__repr__` / `__str__` — unambiguous debug representation vs. readable display representation
- `__len__` — backs `len(obj)`
- `__eq__` / `__hash__` — backs `==` and whether an object can be a dict key / set member (defining `__eq__` without `__hash__` makes instances unhashable by default)
- `__enter__` / `__exit__` — backs the `with` statement (context managers, covered later in this course)
- `__iter__` / `__next__` — backs `for x in obj` (iterators, covered later in this course)

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-data-model-q1",
      "type": "mcq",
      "prompt": "Why does `v1 + v2` work for a custom Vector class with no operator overloading library involved?",
      "options": [
        { "id": "a", "text": "Python guesses what + should do based on the attribute names" },
        { "id": "b", "text": "The + operator looks for a __add__ method on the left operand and calls it" },
        { "id": "c", "text": "+ only works on numbers; this would actually raise a TypeError" },
        { "id": "d", "text": "Vector must inherit from a special Addable base class" }
      ],
      "correct": "b",
      "explanation": "Every operator in Python is backed by a dunder method. + calls __add__ (falling back to __radd__ on the right operand if needed) — defining __add__ is how a class opts into the + operator."
    },
    {
      "id": "oop-collections-data-model-q2",
      "type": "mcq",
      "prompt": "What's a practical consequence of defining `__eq__` on a class without also defining `__hash__`?",
      "options": [
        { "id": "a", "text": "Nothing — hashing is unrelated to equality" },
        { "id": "b", "text": "Instances become unhashable by default, so they can't be used as dict keys or put in a set" },
        { "id": "c", "text": "Python automatically writes a correct __hash__ for you" },
        { "id": "d", "text": "== stops working entirely" }
      ],
      "correct": "b",
      "explanation": "Python's default __hash__ is based on object identity, which would be inconsistent with a custom __eq__ based on value. To prevent that inconsistency, defining __eq__ sets __hash__ to None unless you also define it explicitly."
    }
  ]
}
```
