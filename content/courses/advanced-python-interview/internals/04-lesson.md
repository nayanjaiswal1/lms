---
kind: lesson
id_key: advanced-python-interview/internals/mro
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "Method Resolution Order (MRO)"
position: 3
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/4.method_resolution_order.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
When a class inherits from multiple parents, and more than one of those parents defines the same method, which one wins? Python answers this with the **Method Resolution Order (MRO)** — a single, deterministic list of classes, computed once per class, that attribute and method lookup walks in order, stopping at the first match.

## The simple case: left-to-right

```python
class A:
    def greet(self):
        print("Hello from A")

class B:
    def greet(self):
        print("Hello from B")

class C(A, B):
    pass

c = C()
c.greet()          # Hello from A — A is listed first in C(A, B)
print(C.__mro__)   # (C, A, B, object)
```

With no shared ancestor between `A` and `B`, the MRO is exactly the declaration order: `C`, then `A`, then `B`, then `object`. `c.greet()` finds `A.greet` first and stops.

## The diamond problem

The MRO gets interesting when the parents share a common ancestor — the classic **diamond**: `B` and `C` both inherit from `A`, and `D` inherits from both `B` and `C`.

```python
class A:
    def greet(self):
        print("Hello from A")

class B(A):
    pass

class C(A):
    def greet(self):
        print("Hello from C")

class D(B, C):
    pass

d = D()
d.greet()          # Hello from C
print(D.__mro__)   # (D, B, C, A, object)
```

Naive left-to-right depth-first search would check `D` → `B` → `A` (finds `greet` here) and stop, silently ignoring `C`'s more specific override. CPython instead uses **C3 linearization**, an algorithm that guarantees two properties: a class always appears before its parents, and the declared order of a class's own bases is preserved. Under C3, `A` is pushed all the way to the end — past both `B` and `C` — because `A` is an ancestor of both and must be resolved *after* anything more specific. That's why `D.__mro__` puts `C` before `A`: `B` has no `greet` of its own, so the search falls through to `C`, which does — not to `A`, which would bypass `C`'s override entirely.

## Why this matters

MRO is the mechanism `super()` actually uses — `super().__init__()` doesn't call "the parent class," it calls "the next class in the current instance's MRO," which is exactly why cooperative multiple inheritance (every class in a chain calling `super()`) works correctly even in diamond shapes. Getting a class hierarchy wrong here doesn't raise an error — it silently calls the wrong method, which is what makes MRO bugs painful to track down in large codebases with deep or wide inheritance.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-mro-q1",
      "type": "mcq",
      "prompt": "class C(A, B): pass, where both A and B define greet(). Which one does c.greet() call?",
      "options": [
        { "id": "a", "text": "B's, because it's evaluated last" },
        { "id": "b", "text": "A's, because A is listed first in C(A, B) and the MRO checks bases left to right" },
        { "id": "c", "text": "Both are called, in order" },
        { "id": "d", "text": "It raises a TypeError for ambiguous inheritance" }
      ],
      "correct": "b",
      "explanation": "With no shared ancestor, the MRO is simply the declaration order: C, A, B, object. Lookup stops at the first match, which is A."
    },
    {
      "id": "internals-mro-q2",
      "type": "mcq",
      "prompt": "In the diamond D(B, C) where B(A) and C(A) both descend from A, and only C overrides greet(), why does d.greet() call C's version and not A's?",
      "options": [
        { "id": "a", "text": "C3 linearization places shared ancestor A after all of its more specific descendants (B and C), so the search reaches C's override before falling back to A" },
        { "id": "b", "text": "Python always prefers the second base class in a diamond" },
        { "id": "c", "text": "A's method is deleted automatically once subclassed twice" },
        { "id": "d", "text": "It's undefined behavior and differs by Python version" }
      ],
      "correct": "a",
      "explanation": "C3 linearization guarantees a class appears before its ancestors in the MRO. D's MRO is (D, B, C, A, object) — B has no greet of its own, so lookup falls through to C's override before ever reaching A."
    }
  ]
}
```
