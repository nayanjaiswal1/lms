---
kind: lesson
id_key: advanced-python-interview/weakrefs-memory/weak-key-dictionary
course: advanced-python-interview
section: weakrefs-memory
section_title: "Weak References & Memory Optimization"
section_position: 6
title: "WeakKeyDictionary & WeakValueDictionary"
position: 1
estimated_minutes: 12
source: [fifty-advanced-python-concepts/41.weak_key_dictionary.py, fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md]
---
`weakref.ref` (from the previous lesson) is the low-level primitive. `WeakKeyDictionary` and `WeakValueDictionary`, from the same `weakref` module, package it into a dict-like container — the shape you'll actually reach for day to day when attaching extra data to objects you don't own the lifetime of.

## `WeakKeyDictionary`: metadata that disappears with its object

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

## `WeakValueDictionary`: the mirror image

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

## Why "keys or values, not both" matters

Both variants only weaken *one* side of the mapping — the other side (the dict's values in `WeakKeyDictionary`, the dict's keys in `WeakValueDictionary`) is held strongly, as normal. This is a deliberate, useful asymmetry: in the widget example, the metadata dict `{"color": "blue", ...}` is a plain value held strongly — it just gets discarded, not weakened, once its weak key disappears. Reach for `WeakKeyDictionary` when you're attaching side-data to objects you don't control the lifetime of (framework objects, third-party instances), and `WeakValueDictionary` when you're building a lookup registry/cache and don't want membership in the cache to be a reason something stays alive.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-weak-key-dictionary-q1",
      "type": "mcq",
      "prompt": "In a WeakKeyDictionary, what happens to an entry when the last strong reference to its key object is deleted?",
      "options": [
        { "id": "a", "text": "The entry stays forever until explicitly deleted" },
        { "id": "b", "text": "The entry is automatically removed once the key object is garbage collected" },
        { "id": "c", "text": "A KeyError is raised on the next access" },
        { "id": "d", "text": "The key is replaced with None but the value remains" }
      ],
      "correct": "b",
      "explanation": "WeakKeyDictionary holds its keys weakly. Once nothing else references the key object, it's garbage collected and its entry disappears from the dict automatically."
    },
    {
      "id": "weakrefs-memory-weak-key-dictionary-q2",
      "type": "mcq",
      "prompt": "Why would storing widget -> metadata in a plain dict risk a memory leak that WeakKeyDictionary avoids?",
      "options": [
        { "id": "a", "text": "Plain dicts are slower to look up" },
        { "id": "b", "text": "A plain dict holds keys strongly, so the dict entry itself keeps the widget alive even after all other references to it are deleted" },
        { "id": "c", "text": "Plain dicts can't use custom objects as keys at all" },
        { "id": "d", "text": "Plain dicts automatically duplicate every key" }
      ],
      "correct": "b",
      "explanation": "A regular dict's key reference is a strong reference — the widget stays alive as long as it's a key in the dict, even if every other reference to it is gone, which is exactly the leak WeakKeyDictionary is designed to prevent."
    }
  ]
}
```
