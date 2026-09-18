---
kind: lesson
id_key: advanced-python-interview/serialization-data/serialization
course: advanced-python-interview
section: serialization-data
section_title: "Serialization & Low-Level Data"
section_position: 4
title: "Serialization & Deserialization"
position: 0
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/27.serialization_deserialization.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_26_40.md"]
---
Serialization turns a live Python object into a stream of bytes you can write to disk, send over a socket, or stash in a cache. Deserialization reverses it, rebuilding the object from those bytes. Anywhere state needs to outlive the process that created it — saved ML models, cached query results, session data — serialization is the mechanism underneath.

## `pickle`: Python-native, full object graphs

`pickle` can serialize almost any Python object — including custom classes, nested structures, and cyclic references — without you writing any conversion code.

```python
import pickle

class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def greet(self):
        return f"Hello, my name is {self.name} and I am {self.age} years old."

person = Person("Alice", 30)

# Serialize to bytes, then to disk
serialized = pickle.dumps(person)
with open("person.pkl", "wb") as f:
    f.write(serialized)

# Deserialize back into a live object
with open("person.pkl", "rb") as f:
    loaded_person = pickle.loads(f.read())

print(loaded_person.greet())
```

`pickle.loads` doesn't just restore data — it reconstructs a real `Person` instance, methods and all, because pickle stores enough information to re-import the class and rebuild `__dict__`.

## The security trap: never unpickle untrusted data

That same power is pickle's biggest danger. Unpickling reconstructs objects by *executing* instructions embedded in the byte stream — a malicious pickle can call arbitrary code during `pickle.loads()`, not just build harmless data. Treat pickle as an internal, trusted-source format only (your own cache, your own job queue), never as a way to accept data from a client, a webhook, or any other outside system.

## JSON: safe, interoperable, but limited

When data needs to leave the Python world — an HTTP API, a config file another team's Go service reads — JSON is the right tool. `json.dumps`/`json.loads` only handle a fixed set of types (dicts, lists, strings, numbers, booleans, `None`), so arbitrary class instances need a manual `to_dict`/`from_dict` step, but in exchange you get a format that can't execute code on load and that every language can read.

```python
import json

class Person:
    def __init__(self, name, age):
        self.name = name
        self.age = age

    def to_dict(self):
        return {"name": self.name, "age": self.age}

    @classmethod
    def from_dict(cls, data):
        return cls(data["name"], data["age"])

person = Person("Alice", 30)
payload = json.dumps(person.to_dict())
print(payload)  # '{"name": "Alice", "age": 30}'

restored = Person.from_dict(json.loads(payload))
print(restored.name, restored.age)
```

Picking between them is a trust-and-interoperability question, not a performance one: pickle for objects that stay inside your own Python process boundary, JSON for anything crossing a language or trust boundary.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-serialization-q1",
      "type": "mcq",
      "prompt": "Why is unpickling data from an untrusted source dangerous?",
      "options": [
        { "id": "a", "text": "pickle.loads() can execute arbitrary code embedded in the byte stream" },
        { "id": "b", "text": "Pickled files are always larger than JSON files" },
        { "id": "c", "text": "pickle cannot represent nested objects" },
        { "id": "d", "text": "Pickle only works with strings and numbers" }
      ],
      "correct": "a",
      "explanation": "Deserializing a pickle stream reconstructs objects by executing instructions in the stream itself, so a crafted pickle can run arbitrary code — never unpickle data from outside your trust boundary."
    },
    {
      "id": "serialization-data-serialization-q2",
      "type": "mcq",
      "prompt": "Why would a team choose JSON over pickle for an HTTP API response?",
      "options": [
        { "id": "a", "text": "JSON preserves Python class methods, pickle doesn't" },
        { "id": "b", "text": "JSON is a language-neutral, safe-to-parse text format any client can read" },
        { "id": "c", "text": "JSON can serialize any Python object automatically, exactly like pickle" },
        { "id": "d", "text": "pickle cannot be written to a file" }
      ],
      "correct": "b",
      "explanation": "JSON only encodes basic data types and can't execute code on load, making it safe to accept from and send to any client regardless of language — the tradeoff is manual to_dict/from_dict conversion for custom classes."
    }
  ]
}
```
