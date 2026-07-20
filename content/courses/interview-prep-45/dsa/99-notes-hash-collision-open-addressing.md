---
kind: lesson
id_key: interview-prep-45/note-hash-collision-open-addressing
course: interview-prep-45
section: dsa
section_title: "DSA — Data Structures & Algorithms"
section_position: 1
title: "Notes: Hash Collision Resolution — Open Addressing & the Hash/Eq Contract"
position: 99
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Day 1 covers chaining in depth (bucket lists, load factor, resizing) and mentions "linear probing, quadratic probing, or double hashing" as the open-addressing alternative in one line. This note is the follow-up when an interviewer pushes past "what's a hash collision" into "which open-addressing strategy, and why does Python's `dict` behave the way it does."

## Open addressing: the three probing strategies

Unlike chaining, open addressing keeps every entry directly in the underlying array — on a collision, it probes a sequence of other slots until it finds an empty one.

- **Linear probing** — `(hash(key) + i) % size` for `i = 0, 1, 2, ...`. Simplest to implement, best cache locality (probes are sequential memory addresses). Downside: **primary clustering** — once a run of filled slots forms, every new collision in that run makes it longer, so long runs snowball and degrade lookup toward O(n).
- **Quadratic probing** — `(hash(key) + i²) % size`. Spreads probes out faster than linear, avoiding primary clustering. Downside: **secondary clustering** — two keys that hash to the same initial slot follow the *exact same* probe sequence, so they still collide with each other repeatedly (just not with everyone else).
- **Double hashing** — `(hash1(key) + i * hash2(key)) % size`, where `hash2` is a second, independent hash function. The step size itself depends on the key, so two colliding keys almost never share a probe sequence. Best collision distribution of the three, at the cost of computing two hash functions per lookup.

```python
class OpenAddressingMap:
    def __init__(self, capacity=8):
        self.capacity = capacity
        self.size = 0
        self.keys = [None] * capacity
        self.values = [None] * capacity

    def _probe(self, key):
        # linear probing — swap the +i step for quadratic (+i*i) or double hashing
        i = 0
        idx = hash(key) % self.capacity
        while self.keys[idx] is not None and self.keys[idx] != key:
            i += 1
            idx = (hash(key) + i) % self.capacity
        return idx

    def put(self, key, value):
        idx = self._probe(key)
        if self.keys[idx] is None:
            self.size += 1
        self.keys[idx] = key
        self.values[idx] = value
```

Deletion is the classic open-addressing footgun: you can't just null out a slot, because that breaks the probe chain for every key that probed *past* it looking for an empty slot. Production implementations write a special "tombstone" marker instead of `None` — probing continues through tombstones but insertion is free to reuse them.

## Python's `dict`: open addressing with pseudo-random probing

CPython's `dict` uses open addressing, not chaining — but not plain linear/quadratic/double hashing either. It uses a **pseudo-random probe sequence** derived from the full hash value: `j = ((5*j) + 1 + perturb) % size`, where `perturb` starts as the key's full hash and is right-shifted each iteration. This scrambles the probe order using bits of the hash that a plain `mod size` would otherwise throw away, which is what keeps `dict` fast even when many keys collide on their low bits.

Since Python 3.3, string/bytes hashing is randomized per-process (`PYTHONHASHSEED`) specifically to prevent **hash-flooding attacks** — an attacker submitting keys engineered to all collide, degrading a hash map to O(n) per operation and DoSing a service that hashes user-supplied input (e.g. JSON keys, form fields).

## The `__hash__`/`__eq__` contract for custom objects

If you want instances of your own class to work correctly as dict keys or set members, `__hash__` and `__eq__` must agree:

**Rule: if `a == b`, then `hash(a) == hash(b)`.** The reverse isn't required — different objects can share a hash (that's just a collision, handled normally) — but two objects that compare equal must never disagree on their hash, or a dict/set will store them as separate entries it can never find consistently (a lookup hashes to bucket A, finds nothing, even though an "equal" object sits in bucket B).

```python
class Student:
    def __init__(self, student_id, name):
        self.student_id = student_id
        self.name = name  # not part of identity — two records can share a name

    def __eq__(self, other):
        return isinstance(other, Student) and self.student_id == other.student_id

    def __hash__(self):
        return hash(self.student_id)  # must derive from the same fields __eq__ uses
```

A common bug: defining `__eq__` without `__hash__`. Python then sets `__hash__` to `None` automatically (the class becomes unhashable) — this is intentional, since a custom `__eq__` without a matching `__hash__` would silently violate the contract above. If you override `__eq__`, you must also define `__hash__` (or explicitly inherit the default identity-based one if that's actually what you want).

## Key takeaways

- Open addressing has three probing strategies: linear (simplest, clusters), quadratic (spreads better, still clusters between same-origin keys), double hashing (best distribution, costs a second hash).
- CPython's `dict` uses its own pseudo-random probe sequence (not plain linear/quadratic/double hashing), plus per-process hash randomization since 3.3 to prevent hash-flooding DoS attacks.
- Deleting from an open-addressing table needs tombstones, not `None` — otherwise you break probe chains for keys that landed past the deleted slot.
- `__eq__` and `__hash__` must be defined together and derived from the same fields — equal objects must produce equal hashes, or dict/set lookups become unreliable.
