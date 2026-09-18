---
kind: lesson
id_key: advanced-python-interview/serialization-data/getstate-setstate
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "`__getstate__` and `__setstate__`"
position: 1
estimated_minutes: 12
source: ["fifty-advanced-python-concepts/28.__getstate___and__setstate__.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
Not everything can be pickled. Open file handles, sockets, database connections, and thread locks all wrap operating-system resources that don't make sense as bytes — there is no way to serialize "an open file descriptor" and later reopen the exact same one. Pickling an object that holds one of these directly raises `TypeError: cannot pickle '_io.TextIOWrapper' object`.

## The problem: unpicklable attributes

```python
class FileHandler:
    def __init__(self, filename):
        self.filename = filename
        self.file = open(filename, "w")  # an open file object — not picklable

    def write(self, data):
        self.file.write(data)
```

`pickle.dumps(FileHandler("example.txt"))` fails outright, because `self.file` is a live OS resource, not data.

## `__getstate__`: control what gets pickled

Defining `__getstate__` lets an object hand pickle a *substitute* dict instead of its real `__dict__` — typically the real dict, minus the fields that can't survive serialization.

```python
import pickle

class FileHandler:
    def __init__(self, filename):
        self.filename = filename
        self.file = open(filename, "w")

    def write(self, data):
        self.file.write(data)

    def __getstate__(self):
        state = self.__dict__.copy()
        del state["file"]  # drop the unpicklable file object
        return state

    def __setstate__(self, state):
        self.__dict__.update(state)
        self.file = open(self.filename, "w")  # reopen it fresh

handler = FileHandler("example.txt")
handler.write("Hello, World!")

serialized = pickle.dumps(handler)
restored = pickle.loads(serialized)
restored.write("Restored and still writable")
print(restored.filename)
```

## `__setstate__`: rebuild what was dropped

`__setstate__` is the mirror image, called during `pickle.loads()` with whatever `__getstate__` returned. It restores `self.__dict__` from the plain data, then reconstructs anything that was deliberately excluded — here, reopening the file using the `filename` that *was* preserved.

The pattern is always the same: **keep the data that describes the resource (a filename, a host/port pair, a connection string), drop the live handle, and recreate the handle on the other side.** This is the exact mechanism that lets frameworks pickle objects holding database connections or open sockets — strip the connection in `__getstate__`, reconnect in `__setstate__`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-getstate-setstate-q1",
      "type": "mcq",
      "prompt": "Why can't an open file object be pickled directly?",
      "options": [
        { "id": "a", "text": "Python forbids pickling any object with more than one attribute" },
        { "id": "b", "text": "An open file wraps a live OS resource that has no meaningful byte representation to restore later" },
        { "id": "c", "text": "File objects are too large to serialize efficiently" },
        { "id": "d", "text": "pickle only supports built-in types like int and str" }
      ],
      "correct": "b",
      "explanation": "An open file descriptor is tied to the running OS process; there's no way to serialize 'this exact open handle' and reconstruct it byte-for-byte on load, so pickle raises TypeError instead."
    },
    {
      "id": "serialization-data-getstate-setstate-q2",
      "type": "mcq",
      "prompt": "In the FileHandler example, what does __setstate__ do that __getstate__ doesn't?",
      "options": [
        { "id": "a", "text": "It deletes the filename attribute" },
        { "id": "b", "text": "It re-opens the file handle using the filename that was preserved in the pickled state" },
        { "id": "c", "text": "It converts the object to JSON instead of pickle format" },
        { "id": "d", "text": "It runs before pickling instead of after" }
      ],
      "correct": "b",
      "explanation": "__getstate__ strips the unpicklable file object but keeps filename; __setstate__ restores __dict__ from that data and then recreates the file handle by reopening filename."
    }
  ]
}
```
