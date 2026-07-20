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

Python's built-in way to serialize/deserialize arbitrary objects — turning Python objects into bytes (pickling) and back (unpickling).

## Pickling and unpickling

```python
import pickle

data = {"name": "Alice", "scores": [95, 87, 92]}

# Pickling — to a file or to bytes
with open("data.pkl", "wb") as f:
    pickle.dump(data, f)
byte_data = pickle.dumps(data)

# Unpickling — from a file or from bytes
with open("data.pkl", "rb") as f:
    loaded = pickle.load(f)
loaded = pickle.loads(byte_data)
```

## What it can serialize, and what it can't

Works with almost any Python object — lists, dicts, custom classes, functions (by reference, not by value). The `.pkl` extension is conventional, not required.

## Security: the interview-relevant part

**Never unpickle data from an untrusted source.** Unlike `json`, unpickling can execute arbitrary code — a crafted pickle payload can run any Python during deserialization (via `__reduce__`). This is the standard follow-up question: "why not always use pickle over JSON?" Because pickle trades safety for capability — it's Python-only (not cross-language) and unsafe on untrusted input, whereas `json`/`msgpack` are safe to parse from anywhere but can't represent arbitrary objects (classes, functions, `Date`-like objects without custom encoders).

## When to actually use it

Caching computed Python objects between runs (e.g., a trained model, an in-memory index) where both ends are your own trusted code — not for anything crossing a network boundary from an external client, and not for cross-language interchange.

## Key takeaways

- `pickle.dump`/`dumps` serialize; `pickle.load`/`loads` deserialize — file or in-memory bytes.
- Handles almost any Python object, unlike JSON's limited type set.
- Never unpickle untrusted input — it can execute arbitrary code during deserialization, unlike JSON.
- Python-specific — not readable by other languages; use `json`/`msgpack` for cross-language or untrusted-input cases.
