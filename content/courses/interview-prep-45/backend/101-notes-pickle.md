---
kind: lesson
id_key: interview-prep-45/note-pickle
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Pickling and Unpickling"
position: 101
estimated_minutes: 10
source:
    - interview-prep-notes.md
---

Pickle is Python's built-in way to serialize and deserialize arbitrary objects: turning Python objects into bytes (pickling) and back into objects (unpickling).

## Pickling and unpickling

```python
import pickle

data = {"name": "Alice", "scores": [95, 87, 92]}

# Pickling: to a file or to bytes
with open("data.pkl", "wb") as f:
    pickle.dump(data, f)
byte_data = pickle.dumps(data)

# Unpickling: from a file or from bytes
with open("data.pkl", "rb") as f:
    loaded = pickle.load(f)
loaded = pickle.loads(byte_data)
```

Walking through this: `pickle.dump(data, f)` walks the `data` dict, converts each piece (the string, the list, the integers) into pickle's own binary opcode format, and writes those bytes straight to the open file handle. `pickle.dumps(data)` does the identical conversion but returns the bytes directly instead of writing them anywhere, which is what you'd use to store the result in Redis or a database column. On the way back, `pickle.load(f)` reads the opcodes from the file and replays them to reconstruct an equivalent dict object in memory, and `pickle.loads(byte_data)` does the same starting from an in-memory bytes value instead of a file.

## What it can serialize, and what it can't

Pickle works with almost any Python object: lists, dicts, custom class instances, and functions (by reference, not by value). The `.pkl` extension is conventional, not required by the format itself.

## Security: the interview-relevant part

**Never unpickle data from an untrusted source.** Unlike `json`, unpickling can execute arbitrary code: a crafted pickle payload can run any Python during deserialization, by defining a `__reduce__` method that returns a callable and arguments to invoke it with, which `pickle.load` will call automatically while reconstructing the object.

This is the standard follow-up question: "why not always use pickle over JSON?" The answer is that pickle trades safety for capability. It's Python-only, not cross-language, and unsafe on untrusted input, whereas `json` and `msgpack` are safe to parse from anywhere but can't represent arbitrary objects like custom classes, functions, or date-like objects without a custom encoder.

## When to actually use it

Pickle is a good fit for caching computed Python objects between runs, such as a trained model or an in-memory index, where both ends of the exchange are your own trusted code. It is not appropriate for anything crossing a network boundary from an external client, and not for cross-language interchange, since only Python can read the format back.
