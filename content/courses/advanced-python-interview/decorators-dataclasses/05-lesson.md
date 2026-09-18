---
kind: lesson
id_key: advanced-python-interview/decorators-dataclasses/advanced-dataclass-features
course: advanced-python-interview
section: decorators-dataclasses
section_title: "Decorators, Dataclasses & Metaprogramming"
section_position: 7
title: "Advanced Dataclass Features"
position: 4
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/49.advanced_dataclass_features.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
Beyond generating `__init__`/`__repr__`/`__eq__`, dataclasses support validation after construction, inheritance between dataclasses, and fine-grained per-field control — the features that turn a plain data holder into a properly encapsulated domain model.

## `__post_init__` for validation

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

## Inheritance between dataclasses

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

## `field()` for fine-grained control

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
      "id": "decorators-dataclasses-advanced-dataclass-features-q1",
      "type": "mcq",
      "prompt": "When does __post_init__ run, and why is it useful for validation?",
      "options": [
        { "id": "a", "text": "Before __init__ assigns fields, so it can reject bad input before storage" },
        { "id": "b", "text": "Automatically, right after the generated __init__ assigns all fields — giving one place to enforce invariants across them" },
        { "id": "c", "text": "Only when explicitly called by the user after construction" },
        { "id": "d", "text": "Only on frozen dataclasses" }
      ],
      "correct": "b",
      "explanation": "@dataclass's generated __init__ calls __post_init__ (if defined) automatically after assigning all fields, making it the natural hook for validation logic that needs the fully-populated instance."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q2",
      "type": "mcq",
      "prompt": "In `class Employee(Person): employee_id: int` where Person has name and age, what order do fields appear in Employee's generated __init__?",
      "options": [
        { "id": "a", "text": "employee_id, name, age" },
        { "id": "b", "text": "name, age, employee_id — parent fields first, then the subclass's own fields" },
        { "id": "c", "text": "Alphabetical: age, employee_id, name" },
        { "id": "d", "text": "Employee doesn't inherit Person's fields at all" }
      ],
      "correct": "b",
      "explanation": "Dataclass inheritance concatenates fields in MRO order — parent fields come first, then the subclass's own fields, in declaration order."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q3",
      "type": "mcq",
      "prompt": "What does field(init=False) accomplish that a plain default value doesn't?",
      "options": [
        { "id": "a", "text": "It makes the field required instead of optional" },
        { "id": "b", "text": "It removes the field from the generated __init__ signature entirely, so callers can't set it directly — it must be set elsewhere, like __post_init__" },
        { "id": "c", "text": "It's purely cosmetic and has no effect on behavior" },
        { "id": "d", "text": "It makes the field immutable after construction" }
      ],
      "correct": "b",
      "explanation": "field(init=False) excludes the field from __init__'s parameter list. TaskWithField(\"x\", completed=True) then raises TypeError, since completed is no longer a constructor parameter at all — it can only be set inside the class (e.g. __post_init__)."
    }
  ]
}
```
