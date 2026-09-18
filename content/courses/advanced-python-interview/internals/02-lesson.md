---
kind: lesson
id_key: advanced-python-interview/internals/garbage-collection
course: advanced-python-interview
section: internals
section_title: "Memory & the Interpreter"
section_position: 0
title: "Garbage Collection & Circular References"
position: 1
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/2.garbage_collection.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_1_10.md"]
---
CPython's primary memory-management strategy is **reference counting**: every object carries a count of how many things point to it, and the moment that count hits zero, the object is freed immediately — no separate "GC pause" required. `sys.getrefcount` lets you see this counter directly (it always reports one more than you'd expect, because passing the object into `getrefcount` itself creates a temporary reference).

```python
import sys

class Node:
    def __init__(self, name):
        self.name = name
        self.next = None

a = Node("A")
print(sys.getrefcount(a))  # 2: the 'a' variable + getrefcount's own argument
```

## Where reference counting breaks: cycles

Reference counting has exactly one blind spot — a **cycle**, where a group of objects reference each other but nothing outside the group references any of them. Their counts never reach zero, so pure refcounting would leak them forever.

```python
import gc

a = Node("A")
b = Node("B")

a.next = b   # a's refcount: 1 (from variable 'a')
b.next = a   # a's refcount: 2 (from variable 'a' AND b.next)
             # b's refcount: 2 (from variable 'b' AND a.next)

del a
del b
# Neither object's refcount reached 0 — each is still held by the other.
# Both are now unreachable from any variable, but reference counting alone
# can never notice that and would leak them.

collected = gc.collect()
print(f"garbage collector collected {collected} objects")  # frees the cycle
```

## The cyclic garbage collector

This is what `gc` (Python's *second*, supplementary collector) exists for: it periodically walks objects capable of participating in cycles — container types like your own classes, lists, dicts — looking for groups that are unreachable from any root (a global, a local variable, a stack frame) even though their internal refcounts are nonzero. It runs automatically, triggered by allocation thresholds, and you can also force a sweep with `gc.collect()`.

This matters most in long-running services: a web server that builds cyclic structures (parent objects holding children that hold a back-reference to the parent is the classic shape) and never restarts will accumulate garbage between GC passes. `weakref` (a later lesson) offers a way to break cycles deliberately, by holding a reference that doesn't count toward the refcount at all.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-garbage-collection-q1",
      "type": "mcq",
      "prompt": "Why can't reference counting alone free two objects that only reference each other (a cycle)?",
      "options": [
        { "id": "a", "text": "Python disables refcounting for user-defined classes" },
        { "id": "b", "text": "Each object's refcount never reaches zero, since the other object in the cycle still holds a reference to it" },
        { "id": "c", "text": "Cycles are illegal in Python and raise an error" },
        { "id": "d", "text": "Refcounting only works on built-in types" }
      ],
      "correct": "b",
      "explanation": "In a cycle, deleting the external variables removes the only references reachable from outside — but the objects still reference each other, so their refcounts stay above zero forever without a separate cycle-detecting collector."
    },
    {
      "id": "internals-garbage-collection-q2",
      "type": "mcq",
      "prompt": "What does gc.collect() do that plain reference counting cannot?",
      "options": [
        { "id": "a", "text": "It increases the maximum recursion depth" },
        { "id": "b", "text": "It finds and frees groups of objects that are unreachable from any root but still reference each other in a cycle" },
        { "id": "c", "text": "It compacts the heap to defragment memory" },
        { "id": "d", "text": "It converts objects to weak references automatically" }
      ],
      "correct": "b",
      "explanation": "gc is a supplementary collector specifically for cycles — it walks container objects looking for unreachable groups that refcounting's local, per-object bookkeeping can't detect on its own."
    }
  ]
}
```
