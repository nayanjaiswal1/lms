---
kind: lesson
id_key: interview-prep-45/note-dataclasses-monkeypatch-copy
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Dataclasses, Monkey Patching & Deep vs Shallow Copy"
position: 109
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

Backend/103's stdlib reference mentions `dataclasses` in one line ("auto-generate `__init__`/`__repr__`/`__eq__`"); this note covers the parts that actually come up when asked to use one. Monkey patching and Python's `copy`/`copy.deepcopy` semantics aren't covered anywhere in the course — both are common "gotcha" questions once basic OOP is out of the way.

## Dataclasses beyond the one-liner

```python
from dataclasses import dataclass, field

@dataclass(frozen=True, order=True)
class Point:
    x: float
    y: float
    tags: list[str] = field(default_factory=list)  # never use a mutable literal default

    def __post_init__(self):
        if self.x < 0 or self.y < 0:
            raise ValueError("coordinates must be non-negative")
```

- **`@dataclass` alone** generates `__init__`, `__repr__`, and `__eq__` (field-by-field comparison) — the boilerplate you'd otherwise hand-write for a plain data-holding class.
- **`field(default_factory=list)`** — a mutable default (`tags: list[str] = []`) would be the classic Python footgun: the *same* list object gets shared across every instance, since default argument values are evaluated once at function-definition time, not per call. `default_factory` defers construction to instance-creation time, giving each instance its own list.
- **`frozen=True`** makes instances immutable after `__init__` — attribute assignment raises `FrozenInstanceError`. Use this for value objects that should never mutate (safe to hash, safe to share across threads).
- **`order=True`** generates `__lt__`, `__le__`, `__gt__`, `__ge__` based on field order, so instances become sortable (`sorted(points)`) without hand-writing comparison methods.
- **`__post_init__`** runs immediately after the generated `__init__` — the place for validation or derived-field computation that plain field defaults can't express.
- **When to reach for a dataclass vs Pydantic:** dataclasses are the stdlib choice when you just need structured data with generated boilerplate and no runtime validation. Pydantic (used throughout FastAPI in this course) adds actual type validation, coercion, and JSON schema generation on top — reach for it when the data crosses a trust boundary (API request bodies); reach for a plain dataclass for internal, already-trusted data structures.

## Monkey patching

Monkey patching means modifying or replacing an attribute, method, or function on a class or module **at runtime**, from outside its original definition — not editing the source file, but reaching in and swapping the implementation while the program runs.

```python
import requests

def fake_get(url, *args, **kwargs):
    class FakeResponse:
        status_code = 200
        def json(self): return {"mocked": True}
    return FakeResponse()

requests.get = fake_get  # monkey patch: replace the real function with a fake one
```

**Legitimate use cases:**
- **Testing** — this is exactly what `unittest.mock.patch` does under the hood (see the API-security note's mocking section): temporarily replace a real dependency with a controllable fake for the duration of a test.
- **Working around a bug in a third-party library** without forking it, as a stopgap until an upstream fix ships.
- **Adding missing functionality to a library at runtime** (rare, and usually a sign you should vendor or fork instead).

**Why it's risky outside of tests:**
- **Fragility** — the patch silently breaks if the library's internal structure changes in a later version; nothing warns you at import time.
- **Debugging difficulty** — a function behaving differently than its own source code shows is deeply confusing to anyone (including future-you) reading the codebase later.
- **Global side effects** — patching a module-level attribute (like `requests.get` above) affects *every* caller of that module for the rest of the process, not just your intended call site — this is why test frameworks patch narrowly and always undo the patch (`unittest.mock.patch` restores the original automatically when the context manager/decorator exits).

**Interview framing:** monkey patching is a legitimate, well-understood testing tool (that's precisely what mocking libraries formalize), but reaching for it in production application code is usually a design smell — it means the code couldn't be made testable/extensible through normal means (dependency injection, subclassing), so it's being forced from the outside instead.

## Deep copy vs shallow copy (Python's `copy` module)

```python
import copy

original = {"name": "Alice", "scores": [90, 85, 95]}

shallow = copy.copy(original)        # or original.copy(), or dict(original)
deep = copy.deepcopy(original)

shallow["scores"].append(100)   # mutates the SAME list object original["scores"] points to
print(original["scores"])       # [90, 85, 95, 100] — original was affected!

deep["scores"].append(100)      # deepcopy made an independent nested list
print(original["scores"])       # unaffected by the deep copy's mutation
```

- **Shallow copy** creates a new top-level container, but the elements inside it are the *same objects* (same references) as in the original — mutating a nested mutable object (a list, dict, or custom object) through the copy also mutates the original, because there's only one such object, referenced twice.
- **Deep copy** recursively copies every nested object, so the copy is fully independent — mutating anything inside it never touches the original.
- **Immutable nested values (ints, strings, tuples of immutables) behave identically either way** — since they can't be mutated in place, sharing a reference to them is indistinguishable from having a separate copy. The distinction only matters when nested objects are mutable.

**Gotchas:**
- **Circular references** — an object that (directly or indirectly) contains a reference to itself would cause naive recursive copying to loop forever. `copy.deepcopy` handles this correctly via a `memo` dict that tracks already-copied objects by `id()`, reusing the copy instead of recursing again — you get this for free, but it's worth knowing *why* `deepcopy` doesn't hang on a circular structure.
- **Performance** — `deepcopy` is meaningfully slower than a shallow copy for large/deeply nested structures, since it walks and copies the entire object graph. Don't reach for it by default; use it specifically when independence from the original is required.
- **Custom classes** can override the copy behavior via `__copy__` and `__deepcopy__` dunder methods if the default recursive behavior isn't correct for that type (e.g. a class wrapping a database connection, which should never be naively duplicated).

## Key takeaways

- `field(default_factory=...)` avoids the shared-mutable-default bug; `frozen=True` makes instances immutable/hashable; `__post_init__` is where validation goes.
- Monkey patching (runtime attribute/method replacement) is exactly what mocking libraries formalize for tests — legitimate there, a design smell in production code because it's fragile, hard to debug, and has global side effects on the patched module.
- Shallow copy duplicates the container but shares nested mutable objects with the original; deep copy recursively duplicates everything, at a real performance cost.
- `copy.deepcopy` handles circular references safely via a memo dict tracking already-copied objects by identity.
