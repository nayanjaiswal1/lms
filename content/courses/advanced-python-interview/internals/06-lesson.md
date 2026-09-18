---
kind: lesson
id_key: advanced-python-interview/internals/operator-attrgetter
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "`operator.attrgetter`"
position: 5
estimated_minutes: 10
source: ["fifty-advanced-python-concepts/6.operator_attrgetter.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
Sorting a list of objects by an attribute is usually written with a lambda: `sorted(people, key=lambda p: p.age)`. `operator.attrgetter` does the same job, implemented in C instead of as a Python-level closure — and, more importantly, it can reach into **nested** attributes using a dotted string, which a lambda can do too but only by hardcoding the path.

## Basic use

```python
from operator import attrgetter

class Address:
    def __init__(self, city, state):
        self.city = city
        self.state = state

class Person:
    def __init__(self, name, address):
        self.name = name
        self.address = address

people = [
    Person("Alice", Address("New York", "NY")),
    Person("Bob", Address("Chicago", "IL")),
    Person("Charlie", Address("Los Angeles", "CA")),
]

sorted_people = sorted(people, key=attrgetter("address.city"))
print([p.name for p in sorted_people])  # ['Bob', 'Charlie', 'Alice']
```

`attrgetter("address.city")` returns a callable equivalent to `lambda p: p.address.city` — but it accepts the attribute path as a **string**, which a lambda cannot without an `eval` or a chain of `getattr` calls.

## Why the string form matters

```python
# A sort key chosen at runtime — e.g. from a query parameter or config file
sort_key = "address.city"   # could just as easily be "name" or "address.state"
sorted_people = sorted(people, key=attrgetter(sort_key))
```

This is the actual reason to reach for `attrgetter` over a lambda: when the attribute to sort by isn't known until runtime (a user-selected column, a config-driven report), a lambda would need to build the path dynamically with `getattr` chains itself — `attrgetter` already does exactly that, and does it in C. `attrgetter` also accepts multiple attributes at once (`attrgetter("last_name", "first_name")` sorts by last name, then first name, as a tiebreak) and is a direct sibling of `operator.itemgetter` (the same idea for `obj[key]` access instead of `obj.attr`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-operator-attrgetter-q1",
      "type": "mcq",
      "prompt": "What can attrgetter(\"address.city\") do that a lambda p: p.address.city cannot?",
      "options": [
        { "id": "a", "text": "Accept the attribute path as a runtime string, so the sort key can be chosen dynamically (e.g. from config) without writing new code" },
        { "id": "b", "text": "Sort in descending order automatically" },
        { "id": "c", "text": "Handle attributes that don't exist without raising an error" },
        { "id": "d", "text": "Work on dictionaries as well as objects" }
      ],
      "correct": "a",
      "explanation": "Both express the same lookup, but attrgetter takes the path as a string, so it can be built at runtime from a variable — a lambda would need to hardcode the attribute chain or fall back to getattr/eval itself."
    },
    {
      "id": "internals-operator-attrgetter-q2",
      "type": "mcq",
      "prompt": "Besides accepting a dynamic string path, what's another practical advantage of attrgetter over an equivalent lambda?",
      "options": [
        { "id": "a", "text": "It's implemented in C, making it faster than an equivalent Python-level lambda closure" },
        { "id": "b", "text": "It automatically caches sort results" },
        { "id": "c", "text": "It changes the objects it sorts" },
        { "id": "d", "text": "It only works with tuples" }
      ],
      "correct": "a",
      "explanation": "attrgetter is implemented as a C-level callable in the operator module, which is measurably faster than an equivalent Python lambda for hot sort/key paths."
    }
  ]
}
```
