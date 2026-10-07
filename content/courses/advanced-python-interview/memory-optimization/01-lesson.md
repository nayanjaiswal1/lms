---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/weakref
course: advanced-python-interview
section: memory-optimization
section_title: "Memory Optimization"
section_position: 6
section_group: Advanced
title: "weakref"
position: 0
estimated_minutes: 24
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

## WeakKeyDictionary & WeakValueDictionary

`weakref.ref` (from the previous lesson) is the low-level primitive. `WeakKeyDictionary` and `WeakValueDictionary`, from the same `weakref` module, package it into a dict-like container — the shape you'll actually reach for day to day when attaching extra data to objects you don't own the lifetime of.

### `WeakKeyDictionary`: metadata that disappears with its object

A `WeakKeyDictionary` holds its *keys* weakly. As soon as nothing else in the program references a key, that entry is dropped automatically — no manual cleanup required.

```python
from weakref import WeakKeyDictionary


class Widget:
    def __init__(self, name):
        self.name = name

    def __repr__(self):
        return f"Widget({self.name})"


widget_metadata = WeakKeyDictionary()

widget1 = Widget("Button1")
widget2 = Widget("Button2")

widget_metadata[widget1] = {"color": "blue", "size": "small"}
widget_metadata[widget2] = {"color": "red", "size": "large"}

print(list(widget_metadata.keys()))  # [Widget(Button1), Widget(Button2)]

del widget1  # the only strong reference to widget1 is gone

print(list(widget_metadata.keys()))  # [Widget(Button2)] -- widget1's entry vanished on its own
```

Compare this to a plain `dict`: `widget_metadata[widget1] = ...` in an ordinary dict would itself be a strong reference, keeping `widget1` alive forever even after `del widget1` — a classic accidental memory leak in any long-running cache. `WeakKeyDictionary` sidesteps that by design: the metadata's lifetime is tied *to* the object's lifetime, not the other way around.

### `WeakValueDictionary`: the mirror image

`WeakValueDictionary` does the same thing but on the *value* side — useful for registries where you look objects up by some stable key (an ID, a name) but don't want the registry itself to be the reason those objects stay alive:

```python
from weakref import WeakValueDictionary


class Connection:
    def __init__(self, conn_id):
        self.conn_id = conn_id


active_connections = WeakValueDictionary()

conn = Connection("conn-42")
active_connections["conn-42"] = conn

print("conn-42" in active_connections)  # True

del conn

print("conn-42" in active_connections)  # False -- entry gone once the Connection was freed
```

### Why "keys or values, not both" matters

Both variants only weaken *one* side of the mapping — the other side (the dict's values in `WeakKeyDictionary`, the dict's keys in `WeakValueDictionary`) is held strongly, as normal. This is a deliberate, useful asymmetry: in the widget example, the metadata dict `{"color": "blue", ...}` is a plain value held strongly — it just gets discarded, not weakened, once its weak key disappears. Reach for `WeakKeyDictionary` when you're attaching side-data to objects you don't control the lifetime of (framework objects, third-party instances), and `WeakValueDictionary` when you're building a lookup registry/cache and don't want membership in the cache to be a reason something stays alive.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-weakref-q1",
      "type": "mcq",
      "prompt": "What is the key difference between weakref.ref(obj) and a normal reference to obj?",
      "options": [
        {
          "id": "a",
          "text": "A weak reference is read-only and can't be reassigned"
        },
        {
          "id": "b",
          "text": "A weak reference doesn't increase obj's reference count, so it doesn't keep obj alive by itself"
        },
        {
          "id": "c",
          "text": "A weak reference is faster to dereference than a normal reference"
        },
        {
          "id": "d",
          "text": "A weak reference only works on built-in types"
        }
      ],
      "correct": "b",
      "explanation": "weakref.ref points to an object without contributing to its reference count, so the object can still be garbage collected even while the weak reference exists."
    },
    {
      "id": "weakrefs-memory-weakref-q2",
      "type": "mcq",
      "prompt": "Two objects hold plain (strong) references to each other and nothing else references them. What happens to their reference counts alone (ignoring the cyclic GC)?",
      "options": [
        {
          "id": "a",
          "text": "Both counts immediately drop to zero and the objects are freed"
        },
        {
          "id": "b",
          "text": "Neither count reaches zero, because each object is kept alive by the other's reference"
        },
        {
          "id": "c",
          "text": "Python raises a RecursionError"
        },
        {
          "id": "d",
          "text": "Only one of the two objects is freed"
        }
      ],
      "correct": "b",
      "explanation": "A pure reference cycle never hits a zero refcount through the cycle alone — each object's count is propped up by the other. CPython's separate cyclic GC eventually cleans these up, but not through simple refcounting."
    },
    {
      "id": "weakrefs-memory-weakref-q3",
      "type": "mcq",
      "prompt": "How do you get the actual object back from a weakref.ref instance `r`?",
      "options": [
        {
          "id": "a",
          "text": "r.value"
        },
        {
          "id": "b",
          "text": "r.get()"
        },
        {
          "id": "c",
          "text": "Calling it: r() — returns the object, or None if it's been collected"
        },
        {
          "id": "d",
          "text": "Indexing it: r[0]"
        }
      ],
      "correct": "c",
      "explanation": "weakref.ref objects are callable — calling r() returns the referenced object if it's still alive, or None if it has already been garbage collected."
    },
    {
      "id": "weakrefs-memory-weak-key-dictionary-q1",
      "type": "mcq",
      "prompt": "In a WeakKeyDictionary, what happens to an entry when the last strong reference to its key object is deleted?",
      "options": [
        {
          "id": "a",
          "text": "The entry stays forever until explicitly deleted"
        },
        {
          "id": "b",
          "text": "The entry is automatically removed once the key object is garbage collected"
        },
        {
          "id": "c",
          "text": "A KeyError is raised on the next access"
        },
        {
          "id": "d",
          "text": "The key is replaced with None but the value remains"
        }
      ],
      "correct": "b",
      "explanation": "WeakKeyDictionary holds its keys weakly. Once nothing else references the key object, it's garbage collected and its entry disappears from the dict automatically."
    },
    {
      "id": "weakrefs-memory-weak-key-dictionary-q2",
      "type": "mcq",
      "prompt": "Why would storing widget -> metadata in a plain dict risk a memory leak that WeakKeyDictionary avoids?",
      "options": [
        {
          "id": "a",
          "text": "Plain dicts are slower to look up"
        },
        {
          "id": "b",
          "text": "A plain dict holds keys strongly, so the dict entry itself keeps the widget alive even after all other references to it are deleted"
        },
        {
          "id": "c",
          "text": "Plain dicts can't use custom objects as keys at all"
        },
        {
          "id": "d",
          "text": "Plain dicts automatically duplicate every key"
        }
      ],
      "correct": "b",
      "explanation": "A regular dict's key reference is a strong reference — the widget stays alive as long as it's a key in the dict, even if every other reference to it is gone, which is exactly the leak WeakKeyDictionary is designed to prevent."
    }
  ]
}
```
