---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/dataclasses
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 10
section_group: Advanced
title: "`dataclasses`"
position: 3
estimated_minutes: 24
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

## Advanced Dataclass Features

Beyond generating `__init__`/`__repr__`/`__eq__`, dataclasses support validation after construction, inheritance between dataclasses, and fine-grained per-field control — the features that turn a plain data holder into a properly encapsulated domain model.

### `__post_init__` for validation

`@dataclass`'s generated `__init__` just assigns fields — it can't validate them. `__post_init__`, if defined, runs automatically right after that assignment, giving you one place to enforce invariants:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int

    def __post_init__(self):
        if self.age < 0:
            raise ValueError("Age cannot be negative")

Person("Alice", 30)   # fine
Person("Bob", -5)     # raises ValueError: Age cannot be negative
```

### Inheritance between dataclasses

A dataclass subclassing another dataclass gets the parent's fields first, then its own — the generated `__init__` reflects that combined, ordered field list:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int

@dataclass
class Employee(Person):
    employee_id: int

emp = Employee(name="Alice", age=30, employee_id=1234)
print(emp)  # Employee(name='Alice', age=30, employee_id=1234)
```

Because inherited fields come first, a subclass can only add fields with defaults if the parent's fields all already have defaults too (the "no required field after a default" rule from the previous lesson applies across the whole hierarchy, not just within one class body).

### `field()` for fine-grained control

A bare `completed: bool = False` looks like a normal default — but it's still a real constructor parameter, so callers can pass in a completed task from day one, which may not be the intended API:

```python
from dataclasses import dataclass

@dataclass
class TaskWithoutField:
    description: str
    completed: bool = False

# Nothing stops this — the caller controls "completed" directly:
task = TaskWithoutField("Do laundry", completed=True)
```

`field(init=False)` removes a field from the generated `__init__` entirely, forcing it to be set some other way — typically inside `__post_init__`, which always runs regardless of what's passed to `__init__`:

```python
from dataclasses import dataclass, field

@dataclass
class TaskWithField:
    description: str
    completed: bool = field(init=False, default=False)

    def __post_init__(self):
        self.completed = False

task = TaskWithField("Do laundry")
print(task)  # TaskWithField(description='Do laundry', completed=False)
# TaskWithField("Do laundry", completed=True) would raise TypeError —
# completed is no longer an __init__ parameter at all.
```

`field()` also supports `default_factory` for mutable defaults (a bare `items: list = []` is a `ValueError` on a dataclass — shared mutable defaults are exactly the bug this guards against — use `field(default_factory=list)` instead), `repr=False` to hide a field from `__repr__`, and `compare=False` to exclude it from `__eq__`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-dataclasses-q1",
      "type": "mcq",
      "prompt": "What does @dataclass generate from a class body of annotated fields?",
      "options": [
        {
          "id": "a",
          "text": "Only __init__"
        },
        {
          "id": "b",
          "text": "__init__, __repr__, and __eq__ (by default)"
        },
        {
          "id": "c",
          "text": "A full ORM mapping to a database table"
        },
        {
          "id": "d",
          "text": "Nothing — @dataclass is purely a type-checking hint"
        }
      ],
      "correct": "b",
      "explanation": "By default @dataclass generates __init__, __repr__, and __eq__ based on the declared fields, eliminating the most common boilerplate for data-holding classes."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q2",
      "type": "mcq",
      "prompt": "In `class Person: name: str; age: int = 30; city: str = \"Unknown\"`, why must age and city come after name?",
      "options": [
        {
          "id": "a",
          "text": "Alphabetical ordering is required by dataclasses"
        },
        {
          "id": "b",
          "text": "The generated __init__ behaves like a normal function signature — required parameters can't follow ones with defaults"
        },
        {
          "id": "c",
          "text": "It's a stylistic convention only, not enforced"
        },
        {
          "id": "d",
          "text": "Fields with defaults must always be declared first"
        }
      ],
      "correct": "b",
      "explanation": "@dataclass builds __init__(self, name, age=30, city='Unknown') — an ordinary Python function signature, where a parameter without a default can't follow one that has one."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q3",
      "type": "mcq",
      "prompt": "What does frozen=True add to a dataclass?",
      "options": [
        {
          "id": "a",
          "text": "It makes field access slower but otherwise changes nothing"
        },
        {
          "id": "b",
          "text": "It blocks attribute reassignment after construction (raising FrozenInstanceError) and makes instances hashable"
        },
        {
          "id": "c",
          "text": "It prevents the class from being subclassed"
        },
        {
          "id": "d",
          "text": "It automatically deep-copies the instance on every read"
        }
      ],
      "correct": "b",
      "explanation": "frozen=True raises FrozenInstanceError on any post-init attribute write, and makes the class hashable by default (assuming all fields are hashable) — useful for value objects used as dict keys."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q1",
      "type": "mcq",
      "prompt": "When does __post_init__ run, and why is it useful for validation?",
      "options": [
        {
          "id": "a",
          "text": "Before __init__ assigns fields, so it can reject bad input before storage"
        },
        {
          "id": "b",
          "text": "Automatically, right after the generated __init__ assigns all fields — giving one place to enforce invariants across them"
        },
        {
          "id": "c",
          "text": "Only when explicitly called by the user after construction"
        },
        {
          "id": "d",
          "text": "Only on frozen dataclasses"
        }
      ],
      "correct": "b",
      "explanation": "@dataclass's generated __init__ calls __post_init__ (if defined) automatically after assigning all fields, making it the natural hook for validation logic that needs the fully-populated instance."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q2",
      "type": "mcq",
      "prompt": "In `class Employee(Person): employee_id: int` where Person has name and age, what order do fields appear in Employee's generated __init__?",
      "options": [
        {
          "id": "a",
          "text": "employee_id, name, age"
        },
        {
          "id": "b",
          "text": "name, age, employee_id — parent fields first, then the subclass's own fields"
        },
        {
          "id": "c",
          "text": "Alphabetical: age, employee_id, name"
        },
        {
          "id": "d",
          "text": "Employee doesn't inherit Person's fields at all"
        }
      ],
      "correct": "b",
      "explanation": "Dataclass inheritance concatenates fields in MRO order — parent fields come first, then the subclass's own fields, in declaration order."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q3",
      "type": "mcq",
      "prompt": "What does field(init=False) accomplish that a plain default value doesn't?",
      "options": [
        {
          "id": "a",
          "text": "It makes the field required instead of optional"
        },
        {
          "id": "b",
          "text": "It removes the field from the generated __init__ signature entirely, so callers can't set it directly — it must be set elsewhere, like __post_init__"
        },
        {
          "id": "c",
          "text": "It's purely cosmetic and has no effect on behavior"
        },
        {
          "id": "d",
          "text": "It makes the field immutable after construction"
        }
      ],
      "correct": "b",
      "explanation": "field(init=False) excludes the field from __init__'s parameter list. TaskWithField(\"x\", completed=True) then raises TypeError, since completed is no longer a constructor parameter at all — it can only be set inside the class (e.g. __post_init__)."
    }
  ]
}
```
