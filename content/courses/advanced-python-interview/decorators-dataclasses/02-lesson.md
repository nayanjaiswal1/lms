---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/dataclasses
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 7
title: "`dataclasses`"
position: 1
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/46.dataclasses.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
Plain data-holding classes (DTOs, config objects, domain models) need `__init__`, `__repr__`, and usually `__eq__` — and writing them by hand is repetitive, error-prone boilerplate. `@dataclass` generates all three from a single class body of type-annotated fields.

## By hand vs. `@dataclass`

Written manually, a simple `Point` class looks like this:

```python
class Point:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def __repr__(self):
        return f"Point(x={self.x}, y={self.y})"

    def __eq__(self, other):
        if not isinstance(other, Point):
            return NotImplemented
        return (self.x, self.y) == (other.x, other.y)

point1 = Point(1, 2)
point2 = Point(1, 2)
print(point1)             # Point(x=1, y=2)
print(point1 == point2)   # True
```

`@dataclass` generates exactly this — `__init__`, `__repr__`, `__eq__` — from the annotated fields alone:

```python
from dataclasses import dataclass

@dataclass
class Point:
    x: int
    y: int

point1 = Point(1, 2)
point2 = Point(1, 2)
print(point1)             # Point(x=1, y=2)
print(point1 == point2)   # True
```

Twelve lines become five, and there's no `__init__`/`__repr__`/`__eq__` logic to get subtly wrong or forget to update when a field is added.

## Default values

Fields can carry defaults, exactly like a normal function signature — and just like function defaults, every field with one must come after every field without one:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int = 30
    city: str = "Unknown"

person = Person(name="Alice")
print(person)  # Person(name='Alice', age=30, city='Unknown')
```

## Immutability with `frozen=True`

Passing `frozen=True` makes every field write-once: any attempt to reassign an attribute after construction raises `FrozenInstanceError`, which is exactly what you want for a value object that should never be mutated after creation (a coordinate, a money amount, a cache key):

```python
from dataclasses import dataclass, FrozenInstanceError

@dataclass(frozen=True)
class Point:
    x: int
    y: int

point = Point(1, 2)
try:
    point.x = 3
except FrozenInstanceError as e:
    print("blocked:", e)
```

Frozen dataclasses are also hashable by default (as long as every field is hashable), so they can be used as dict keys or set members — a plain, mutable `@dataclass` is not hashable unless you opt in explicitly.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-dataclasses-q1",
      "type": "mcq",
      "prompt": "What does @dataclass generate from a class body of annotated fields?",
      "options": [
        { "id": "a", "text": "Only __init__" },
        { "id": "b", "text": "__init__, __repr__, and __eq__ (by default)" },
        { "id": "c", "text": "A full ORM mapping to a database table" },
        { "id": "d", "text": "Nothing — @dataclass is purely a type-checking hint" }
      ],
      "correct": "b",
      "explanation": "By default @dataclass generates __init__, __repr__, and __eq__ based on the declared fields, eliminating the most common boilerplate for data-holding classes."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q2",
      "type": "mcq",
      "prompt": "In `class Person: name: str; age: int = 30; city: str = \"Unknown\"`, why must age and city come after name?",
      "options": [
        { "id": "a", "text": "Alphabetical ordering is required by dataclasses" },
        { "id": "b", "text": "The generated __init__ behaves like a normal function signature — required parameters can't follow ones with defaults" },
        { "id": "c", "text": "It's a stylistic convention only, not enforced" },
        { "id": "d", "text": "Fields with defaults must always be declared first" }
      ],
      "correct": "b",
      "explanation": "@dataclass builds __init__(self, name, age=30, city='Unknown') — an ordinary Python function signature, where a parameter without a default can't follow one that has one."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q3",
      "type": "mcq",
      "prompt": "What does frozen=True add to a dataclass?",
      "options": [
        { "id": "a", "text": "It makes field access slower but otherwise changes nothing" },
        { "id": "b", "text": "It blocks attribute reassignment after construction (raising FrozenInstanceError) and makes instances hashable" },
        { "id": "c", "text": "It prevents the class from being subclassed" },
        { "id": "d", "text": "It automatically deep-copies the instance on every read" }
      ],
      "correct": "b",
      "explanation": "frozen=True raises FrozenInstanceError on any post-init attribute write, and makes the class hashable by default (assuming all fields are hashable) — useful for value objects used as dict keys."
    }
  ]
}
```
