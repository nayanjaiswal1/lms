---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/slots
course: advanced-python-interview
section: weakrefs-memory
section_title: "Weak References & Memory Optimization"
section_position: 6
title: "Optimizing Memory with __slots__"
position: 2
estimated_minutes: 12
source: [fifty-advanced-python-concepts/_slots.py, fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md]
---
By default, every instance of a Python class carries its own `__dict__` — a full dictionary — to hold its attributes, even if every instance always has exactly the same fixed set of attribute names. `__slots__` lets you tell Python "this class only ever has these attributes," trading that flexibility for a meaningfully smaller memory footprint per instance.

## The default: every instance gets a `__dict__`

```python
class UserProfile:
    def __init__(self, username, email):
        self.username = username
        self.email = email


u = UserProfile("alice", "alice@example.com")
print(u.__dict__)          # {'username': 'alice', 'email': 'alice@example.com'}
u.extra = "anything goes"  # works fine -- __dict__ accepts new keys freely
print(u.__dict__)
```

That per-instance dict is flexible (you can bolt on `u.extra` at any time) but it isn't free: a dict has its own internal hash table overhead on top of the actual attribute values, and when you're creating millions of instances of a simple data-holding class, that overhead adds up.

## `__slots__`: a fixed, dict-free attribute set

```python
class SlotsUserProfile:
    __slots__ = ["username", "email"]

    def __init__(self, username, email):
        self.username = username
        self.email = email


s = SlotsUserProfile("bob", "bob@example.com")
print(s.username, s.email)  # bob bob@example.com
print(hasattr(s, "__dict__"))  # False -- there is no per-instance dict at all

try:
    s.extra = "not allowed"
except AttributeError as e:
    print(f"blocked: {e}")  # 'SlotsUserProfile' object has no attribute 'extra'
```

Declaring `__slots__ = ["username", "email"]` tells CPython to allocate fixed, fast slots for exactly those two attributes instead of a `__dict__` — and, as a side effect, blocks setting any attribute not named in the list. That restriction is the whole trade: you give up dynamic attribute assignment in exchange for a smaller, faster instance layout.

## Measuring the difference

`memory_profiler`'s `@profile` decorator (covered in the next lesson) is the tool the original notes use to show this at scale — but it needs the `mprof`/`python -m memory_profiler` runner, so it won't execute standalone here. The stdlib's own `sys.getsizeof` on a single instance already shows the shape of the difference, even though it only reports one object's shallow size, not the whole instance-plus-dict picture:

```python
import sys

regular = UserProfile("carol", "carol@example.com")
slotted = SlotsUserProfile("carol", "carol@example.com")

print("regular instance:", sys.getsizeof(regular))          # the instance itself
print("regular's __dict__:", sys.getsizeof(regular.__dict__))  # plus a whole dict
print("slotted instance:", sys.getsizeof(slotted))          # no separate dict at all
```

At one instance this looks like a rounding error; multiply it by a million rows loaded from a database or a CSV and the missing per-instance `__dict__` becomes real, measurable memory saved.

## The trade-off

`__slots__` is best reserved for classes you instantiate a lot — data-holding value objects, nodes in a large tree or graph, rows loaded in bulk — not for every class by default. It removes dynamic attribute assignment, it doesn't mix cleanly with multiple inheritance unless every base class also defines (compatible) slots, and a subclass that doesn't itself declare `__slots__` gets a `__dict__` anyway, silently undoing the savings.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-slots-q1",
      "type": "mcq",
      "prompt": "What does declaring __slots__ = [\"username\", \"email\"] prevent?",
      "options": [
        { "id": "a", "text": "Reading the username or email attributes" },
        { "id": "b", "text": "Setting any attribute not named in __slots__, since there's no per-instance __dict__ to hold it" },
        { "id": "c", "text": "Subclassing the class at all" },
        { "id": "d", "text": "Calling __init__ more than once" }
      ],
      "correct": "b",
      "explanation": "__slots__ replaces the per-instance __dict__ with fixed slots for exactly the named attributes, so assigning any other attribute name raises AttributeError."
    },
    {
      "id": "weakrefs-memory-slots-q2",
      "type": "mcq",
      "prompt": "What kind of class benefits most from __slots__?",
      "options": [
        { "id": "a", "text": "A singleton class that's only ever instantiated once" },
        { "id": "b", "text": "A simple, fixed-attribute class instantiated in very large numbers (e.g. millions of rows/nodes)" },
        { "id": "c", "text": "A class that needs to support arbitrary dynamic attributes at runtime" },
        { "id": "d", "text": "An abstract base class that's never instantiated directly" }
      ],
      "correct": "b",
      "explanation": "The memory savings from skipping a per-instance __dict__ are negligible for one object but add up meaningfully at scale — the classic use case is a data-holding class created millions of times."
    },
    {
      "id": "weakrefs-memory-slots-q3",
      "type": "mcq",
      "prompt": "If a subclass of a __slots__ class doesn't declare its own __slots__, what happens?",
      "options": [
        { "id": "a", "text": "It inherits the parent's memory savings automatically with no changes needed" },
        { "id": "b", "text": "It silently gets a __dict__ of its own, undoing the memory savings for that subclass" },
        { "id": "c", "text": "Python raises a TypeError at class-definition time" },
        { "id": "d", "text": "The subclass can no longer be instantiated" }
      ],
      "correct": "b",
      "explanation": "A subclass without its own __slots__ declaration gets a normal __dict__, which quietly defeats the point of the parent's __slots__ for instances of that subclass."
    }
  ]
}
```
