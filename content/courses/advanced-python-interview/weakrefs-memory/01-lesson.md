---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/weakref
course: advanced-python-interview
section: weakrefs-memory
section_title: "Weak References & Memory Optimization"
section_position: 6
title: "weakref"
position: 0
estimated_minutes: 12
source: [fifty-advanced-python-concepts/39.weakref.py, fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md]
---
CPython's primary garbage-collection mechanism is reference counting: every object tracks how many references point to it, and gets freed the instant that count hits zero. A **weak reference**, from the `weakref` module, is a reference that points to an object *without* increasing its reference count — which is exactly the tool for breaking the one case reference counting can't handle on its own: two objects that reference each other.

## The circular-reference problem

```python
class Node:
    def __init__(self, name):
        self.name = name
        self.next = None


a = Node("A")
b = Node("B")
a.next = b
b.next = a  # circular: a -> b -> a

del a
del b
# Neither Node's refcount ever hits zero from these two variables alone —
# each is still held by the other's .next. CPython's cyclic GC eventually
# reclaims this, but only on its own schedule, not immediately.
```

A plain reference count on `a` and `b` never reaches zero here, because each object keeps the other alive. CPython's separate cyclic garbage collector *does* eventually detect and clean up cycles like this — but only on its own generational schedule, not the instant the last external reference disappears. In long-running systems with many such objects, that delay is exactly the kind of thing senior interviews probe: not "will this ever leak" (it won't, permanently) but "do you understand why it isn't cleaned up immediately."

## Breaking the cycle with `weakref.ref`

```python
import weakref


class Node:
    def __init__(self, name):
        self.name = name
        self.next = None


a = Node("A")
b = Node("B")
a.next = weakref.ref(b)  # a weak reference — doesn't increase b's refcount
b.next = weakref.ref(a)  # same for a

# A weakref.ref is callable: call it to get the live object back
print(a.next().name)  # B
print(b.next().name)  # A
```

`a.next` no longer holds a strong reference to `b` — it holds a `weakref.ref` object, which you call like a function to get `b` back (`a.next()` returns `b`, or `None` if `b` has already been garbage collected). Now `a` and `b` only stay alive as long as something *else* holds a strong reference to them; deleting the last strong reference to either one lets ordinary reference counting free it immediately, cycle or not.

## Where this matters in practice

Weak references are the standard tool for caches, observer/listener registries, and parent-child object graphs (a child holding a weak reference back to its parent) — anywhere you want object A to be able to *reach* object B without object A being a reason B stays alive. The next lesson covers `WeakKeyDictionary`/`WeakValueDictionary`, which package this exact pattern into a dict-like container.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-weakref-q1",
      "type": "mcq",
      "prompt": "What is the key difference between weakref.ref(obj) and a normal reference to obj?",
      "options": [
        { "id": "a", "text": "A weak reference is read-only and can't be reassigned" },
        { "id": "b", "text": "A weak reference doesn't increase obj's reference count, so it doesn't keep obj alive by itself" },
        { "id": "c", "text": "A weak reference is faster to dereference than a normal reference" },
        { "id": "d", "text": "A weak reference only works on built-in types" }
      ],
      "correct": "b",
      "explanation": "weakref.ref points to an object without contributing to its reference count, so the object can still be garbage collected even while the weak reference exists."
    },
    {
      "id": "weakrefs-memory-weakref-q2",
      "type": "mcq",
      "prompt": "Two objects hold plain (strong) references to each other and nothing else references them. What happens to their reference counts alone (ignoring the cyclic GC)?",
      "options": [
        { "id": "a", "text": "Both counts immediately drop to zero and the objects are freed" },
        { "id": "b", "text": "Neither count reaches zero, because each object is kept alive by the other's reference" },
        { "id": "c", "text": "Python raises a RecursionError" },
        { "id": "d", "text": "Only one of the two objects is freed" }
      ],
      "correct": "b",
      "explanation": "A pure reference cycle never hits a zero refcount through the cycle alone — each object's count is propped up by the other. CPython's separate cyclic GC eventually cleans these up, but not through simple refcounting."
    },
    {
      "id": "weakrefs-memory-weakref-q3",
      "type": "mcq",
      "prompt": "How do you get the actual object back from a weakref.ref instance `r`?",
      "options": [
        { "id": "a", "text": "r.value" },
        { "id": "b", "text": "r.get()" },
        { "id": "c", "text": "Calling it: r() — returns the object, or None if it's been collected" },
        { "id": "d", "text": "Indexing it: r[0]" }
      ],
      "correct": "c",
      "explanation": "weakref.ref objects are callable — calling r() returns the referenced object if it's still alive, or None if it has already been garbage collected."
    }
  ]
}
```
