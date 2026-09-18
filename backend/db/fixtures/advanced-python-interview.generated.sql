-- ══════════════════════════════════════════════════════════════════════════
-- GENERATED FILE — DO NOT EDIT.
-- Source: canonical markdown content (content/courses/**).
-- Regenerate via: cd backend && go run ./cmd/coursegen generate
-- Generated at: 2026-09-17T17:04:39Z
-- ══════════════════════════════════════════════════════════════════════════

-- ─── Course: Advanced Python for Senior Interviews ─────────────────────────────────────────────
INSERT INTO courses (id, org_id, creator_id, title, slug, description, cover_url, difficulty, tags, status, is_free, is_public, estimated_hours)
VALUES ('a575d044-3374-561b-9cf6-d44aa7b0f855', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000012', 'Advanced Python for Senior Interviews', 'advanced-python-interview', '54 deep-dive concepts that separate senior Python engineers from mid-level developers: CPython internals and memory management, the GIL, threading vs multiprocessing vs asyncio, full OOP (encapsulation, ABCs, MRO, polymorphism, the data model), iterators/generators, serialization, metaclasses, context managers, weak references, decorators, dataclasses, functools, descriptors, and advanced typing (protocols & generics). Every lesson ships runnable "Try it Yourself" Python code boxes.', NULL, 'advanced', ARRAY['python','interview-prep','concurrency','memory-management','advanced'], 'published', true, false, 12.3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, description=EXCLUDED.description, cover_url=EXCLUDED.cover_url, tags=EXCLUDED.tags, is_public=EXCLUDED.is_public, estimated_hours=EXCLUDED.estimated_hours, updated_at=now();

-- Section: Memory & the Interpreter
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('012c80ac-4e8f-5205-8f62-ce79738eaa79', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Memory & the Interpreter', 0)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c32a7095-b38a-5f19-96fc-5fd87988b412', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'Arrays (the `array` Module)', 'notes', 0, $md$A Python `list` can hold anything — an int, a string, another list — in the same container. That flexibility costs memory: each element is a separate Python object, and the list itself stores an array of *pointers* to those objects, not the raw values. When you need a large, homogeneous run of numbers, the standard library's `array` module stores the raw values directly, packed the way a C array would be.

## Type-specific arrays

`array.array` takes a **type code** as its first argument — a single character that fixes what every element must be — and refuses anything that doesn't fit.

```python
from array import array

numbers = array('i', [1, 2, 3, 4, 5])  # 'i' = signed int
numbers.append(6)
numbers.extend([7, 8])
numbers.insert(0, 0)

print(numbers)          # array('i', [0, 1, 2, 3, 4, 5, 6, 7, 8])
print(numbers.itemsize)  # 4 — bytes per element on this platform

try:
    numbers.append("nine")
except TypeError as e:
    print(f"rejected: {e}")  # array only holds ints once created with 'i'
```

`array` supports the same `.append`/`.extend`/`.insert` methods as `list`, so the API is familiar — the difference is entirely in storage. Common type codes: `'b'`/`'B'` (signed/unsigned byte), `'i'`/`'I'` (signed/unsigned int), `'f'`/`'d'` (float/double), `'u'` (unicode char, deprecated).

## Why this matters at the memory level

A `list` of a million ints stores a million separate `int` objects (each with its own refcount and type pointer) plus a million 8-byte pointers in the list's backing array. An `array('i', ...)` of a million ints stores exactly one contiguous block of 4-million bytes — no per-element object overhead at all. That's the trade you're making: `array` is dramatically more memory-efficient and cache-friendly for large runs of one numeric type, at the cost of losing per-element flexibility and Python-level dynamic typing.

In practice, `array` shows up under the hood of other tools (it backs parts of `struct`, and libraries like NumPy generalize the same idea to N dimensions) more often than it's reached for directly — but recognizing when a list's flexibility is pure overhead is the actual interview signal.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-arrays-q1",
      "type": "mcq",
      "prompt": "What must you specify when creating a Python array.array that a list never requires?",
      "options": [
        { "id": "a", "text": "A fixed maximum length" },
        { "id": "b", "text": "A type code, fixing every element to the same type" },
        { "id": "c", "text": "A custom hash function" },
        { "id": "d", "text": "A thread-safety mode" }
      ],
      "correct": "b",
      "explanation": "array.array('i', ...) fixes the element type via a one-character type code; mixing types raises TypeError, unlike a list."
    },
    {
      "id": "internals-arrays-q2",
      "type": "mcq",
      "prompt": "Why is array more memory-efficient than list for a million integers?",
      "options": [
        { "id": "a", "text": "It stores raw values in one contiguous block instead of a million separate int objects plus pointers" },
        { "id": "b", "text": "It compresses the data automatically" },
        { "id": "c", "text": "It uses a different garbage collector" },
        { "id": "d", "text": "It stores values on disk instead of in RAM" }
      ],
      "correct": "a",
      "explanation": "A list holds pointers to individually-allocated int objects; array packs raw values contiguously like a C array, eliminating per-element object overhead."
    }
  ]
}
```
$md$, 12, $json$[{"id":"internals-arrays-q1","type":"mcq","correct":"b"},{"id":"internals-arrays-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b56f5cd0-7e03-5c2b-b41f-83b550d4aeae', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'Garbage Collection & Circular References', 'notes', 1, $md$CPython's primary memory-management strategy is **reference counting**: every object carries a count of how many things point to it, and the moment that count hits zero, the object is freed immediately — no separate "GC pause" required. `sys.getrefcount` lets you see this counter directly (it always reports one more than you'd expect, because passing the object into `getrefcount` itself creates a temporary reference).

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
$md$, 15, $json$[{"id":"internals-garbage-collection-q1","type":"mcq","correct":"b"},{"id":"internals-garbage-collection-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ba47e257-1a18-5b02-b22f-192526f144e0', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'Not Returning Dicts & Lists from Functions', 'notes', 2, $md$Python passes arguments by **object reference** — a variable never holds a copy of a list or dict, it holds a reference to the same object everyone else who has that variable also points at. That has a direct, easy-to-miss consequence: a function that mutates a list or dict argument doesn't need to `return` it for the caller to see the change.

## The pattern

```python
def add_n_copies(items, n):
    for i in range(n):
        items.append(n)
    # no return statement at all

my_list = []
add_n_copies(my_list, 5)
print(my_list)  # [5, 5, 5, 5, 5] — mutated in place, no return needed
```

`items` inside the function and `my_list` outside it are the same object — `id(items) == id(my_list)` is `True` for the whole call. `.append()` mutates that shared object, so the caller's variable reflects the change the instant the function returns (or even before, if another piece of code peeked at `my_list` mid-call from another thread).

## Where this bites people

The mirror image of this rule is the actual interview trap: relying on mutation when you *meant* to return a new value.

```python
def broken_scale(numbers, factor):
    numbers = [n * factor for n in numbers]  # rebinds the LOCAL name only
    return numbers

original = [1, 2, 3]
result = broken_scale(original, 10)
print(original)  # [1, 2, 3] — untouched, because the function rebound `numbers`
print(result)     # [30, 20 ,10]... [10, 20, 30] — the new list, via the return value
```

`numbers = [...]` inside the function rebinds the local name `numbers` to a brand-new list — it does not touch the object `original` still points to. This is the same reference semantics as the mutation example above, just applied to reassignment instead of `.append()`. The rule that falls out of both examples: if a function **mutates** its argument in place (`.append`, `.update`, `[:] = `, `del items[i]`), the caller sees it with no `return` needed; if a function **rebinds** the parameter name to a new object, the caller sees nothing unless the function returns it.

Being explicit about which one you're doing — and returning a new object rather than silently mutating an argument the caller didn't expect to change — is usually the more maintainable choice, even though Python allows either.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-no-return-mutable-q1",
      "type": "mcq",
      "prompt": "A function does `items.append(n)` on its list argument with no return statement. Does the caller see the change?",
      "options": [
        { "id": "a", "text": "No, lists are always copied into functions" },
        { "id": "b", "text": "Yes — the parameter and the caller's variable reference the same list object, so mutating it in place is visible without returning anything" },
        { "id": "c", "text": "Only if the function is decorated with @mutates" },
        { "id": "d", "text": "Only in Python 2, not Python 3" }
      ],
      "correct": "b",
      "explanation": "Python passes object references. items and the caller's list are the same object, so in-place mutation (append, update, etc.) is visible to the caller immediately, with no return needed."
    },
    {
      "id": "internals-no-return-mutable-q2",
      "type": "mcq",
      "prompt": "Inside a function, `numbers = [n * 2 for n in numbers]` reassigns the parameter. Why doesn't the caller's original list change?",
      "options": [
        { "id": "a", "text": "List comprehensions are read-only and can't reassign" },
        { "id": "b", "text": "Reassignment rebinds the local name to a new object — it doesn't mutate the object the caller's variable still points to" },
        { "id": "c", "text": "Python silently copies lists on reassignment" },
        { "id": "d", "text": "It does change, unless the function returns None" }
      ],
      "correct": "b",
      "explanation": "`numbers = [...]` makes the local name point at a new list; the caller's variable still points at the original object, unaffected. Only in-place mutation (not reassignment) is visible without a return."
    }
  ]
}
```
$md$, 12, $json$[{"id":"internals-no-return-mutable-q1","type":"mcq","correct":"b"},{"id":"internals-no-return-mutable-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('af5ce63e-3c3a-5f41-af28-d8d5952d9c0f', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'Method Resolution Order (MRO)', 'notes', 3, $md$When a class inherits from multiple parents, and more than one of those parents defines the same method, which one wins? Python answers this with the **Method Resolution Order (MRO)** — a single, deterministic list of classes, computed once per class, that attribute and method lookup walks in order, stopping at the first match.

## The simple case: left-to-right

```python
class A:
    def greet(self):
        print("Hello from A")

class B:
    def greet(self):
        print("Hello from B")

class C(A, B):
    pass

c = C()
c.greet()          # Hello from A — A is listed first in C(A, B)
print(C.__mro__)   # (C, A, B, object)
```

With no shared ancestor between `A` and `B`, the MRO is exactly the declaration order: `C`, then `A`, then `B`, then `object`. `c.greet()` finds `A.greet` first and stops.

## The diamond problem

The MRO gets interesting when the parents share a common ancestor — the classic **diamond**: `B` and `C` both inherit from `A`, and `D` inherits from both `B` and `C`.

```python
class A:
    def greet(self):
        print("Hello from A")

class B(A):
    pass

class C(A):
    def greet(self):
        print("Hello from C")

class D(B, C):
    pass

d = D()
d.greet()          # Hello from C
print(D.__mro__)   # (D, B, C, A, object)
```

Naive left-to-right depth-first search would check `D` → `B` → `A` (finds `greet` here) and stop, silently ignoring `C`'s more specific override. CPython instead uses **C3 linearization**, an algorithm that guarantees two properties: a class always appears before its parents, and the declared order of a class's own bases is preserved. Under C3, `A` is pushed all the way to the end — past both `B` and `C` — because `A` is an ancestor of both and must be resolved *after* anything more specific. That's why `D.__mro__` puts `C` before `A`: `B` has no `greet` of its own, so the search falls through to `C`, which does — not to `A`, which would bypass `C`'s override entirely.

## Why this matters

MRO is the mechanism `super()` actually uses — `super().__init__()` doesn't call "the parent class," it calls "the next class in the current instance's MRO," which is exactly why cooperative multiple inheritance (every class in a chain calling `super()`) works correctly even in diamond shapes. Getting a class hierarchy wrong here doesn't raise an error — it silently calls the wrong method, which is what makes MRO bugs painful to track down in large codebases with deep or wide inheritance.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-mro-q1",
      "type": "mcq",
      "prompt": "class C(A, B): pass, where both A and B define greet(). Which one does c.greet() call?",
      "options": [
        { "id": "a", "text": "B's, because it's evaluated last" },
        { "id": "b", "text": "A's, because A is listed first in C(A, B) and the MRO checks bases left to right" },
        { "id": "c", "text": "Both are called, in order" },
        { "id": "d", "text": "It raises a TypeError for ambiguous inheritance" }
      ],
      "correct": "b",
      "explanation": "With no shared ancestor, the MRO is simply the declaration order: C, A, B, object. Lookup stops at the first match, which is A."
    },
    {
      "id": "internals-mro-q2",
      "type": "mcq",
      "prompt": "In the diamond D(B, C) where B(A) and C(A) both descend from A, and only C overrides greet(), why does d.greet() call C's version and not A's?",
      "options": [
        { "id": "a", "text": "C3 linearization places shared ancestor A after all of its more specific descendants (B and C), so the search reaches C's override before falling back to A" },
        { "id": "b", "text": "Python always prefers the second base class in a diamond" },
        { "id": "c", "text": "A's method is deleted automatically once subclassed twice" },
        { "id": "d", "text": "It's undefined behavior and differs by Python version" }
      ],
      "correct": "a",
      "explanation": "C3 linearization guarantees a class appears before its ancestors in the MRO. D's MRO is (D, B, C, A, object) — B has no greet of its own, so lookup falls through to C's override before ever reaching A."
    }
  ]
}
```
$md$, 15, $json$[{"id":"internals-mro-q1","type":"mcq","correct":"b"},{"id":"internals-mro-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('de0f27d6-5b70-55f1-a0bf-9dbcd220b8a2', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'Walrus Operator (`:=`)', 'notes', 4, $md$The walrus operator (`:=`, officially the **assignment expression**, added in Python 3.8) lets you assign a value to a name *and* produce that value as the result of the expression, in one step. Plain `=` is a statement — it can't appear inside an `if` condition or a comprehension. `:=` can.

## Before and after

```python
my_dict = {"my_var": 42}

def lookup_v1(d):
    my_var = d.get("my_var")   # separate assignment statement
    if my_var:
        return my_var

def lookup_v2(d):
    if my_var := d.get("my_var"):  # assign AND test in one expression
        return my_var
```

Both functions behave identically — `lookup_v2` just collapses "assign, then check" into a single line. The win compounds once the value being checked is expensive to compute or you'd otherwise have to write it twice.

## Where it earns its keep

```python
# Without walrus: call the expensive function twice, or add a throwaway line
data = fetch_data()
if data:
    process(data)

# With walrus: compute once, inline in the condition
if (data := fetch_data()):
    process(data)
```

```python
# Comprehensions: filter on a computed value without a nested function call
values = [1, 2, 3, 4, 5, 6]
results = [y for x in values if (y := x * x) > 10]
print(results)  # [16, 25, 36] — y is both the filter and the yielded value
```

That comprehension example is the case a plain `=` genuinely cannot express at all: without `:=`, computing `x * x` once and both filtering *and* returning it would require a helper function or a `map`/`filter` chain — the walrus lets a comprehension reuse an intermediate value without recomputing it.

The operator is deliberately minor — it doesn't change what's *possible* in Python, only how tersely a specific pattern (compute-then-check) can be written — but reaching for it in the right spot (a `while` loop reading chunks, a comprehension filtering on a derived value) is a small, reliable signal of comfort with the language.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-walrus-operator-q1",
      "type": "mcq",
      "prompt": "What can `if (data := fetch_data()):` do that `data = fetch_data(); if data:` cannot?",
      "options": [
        { "id": "a", "text": "Nothing functionally different — it's purely a style preference for this exact case" },
        { "id": "b", "text": "It skips calling fetch_data() entirely" },
        { "id": "c", "text": "It makes fetch_data() run asynchronously" },
        { "id": "d", "text": "It caches the result across multiple calls" }
      ],
      "correct": "a",
      "explanation": "For a simple assign-then-check, := is equivalent to a separate assignment statement followed by a check — its real value shows up where a plain assignment statement isn't syntactically allowed at all, like inside a comprehension's condition."
    },
    {
      "id": "internals-walrus-operator-q2",
      "type": "mcq",
      "prompt": "`[y for x in values if (y := x * x) > 10]` — why is the walrus operator necessary here, not just convenient?",
      "options": [
        { "id": "a", "text": "A comprehension's filter clause can't contain a plain assignment statement, so without :=, x*x would need to be computed twice or via a helper" },
        { "id": "b", "text": "List comprehensions don't support arithmetic without it" },
        { "id": "c", "text": "It's required syntax for any comprehension with a filter" },
        { "id": "d", "text": "It prevents the comprehension from allocating a new list" }
      ],
      "correct": "a",
      "explanation": "A comprehension's `if` clause is an expression context, not a statement context — plain `=` isn't valid there. The walrus operator is what lets the filter both compute and reuse x*x in one expression."
    }
  ]
}
```
$md$, 10, $json$[{"id":"internals-walrus-operator-q1","type":"mcq","correct":"a"},{"id":"internals-walrus-operator-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('21acad42-005b-5552-8ffa-110ec776bdf7', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', '`operator.attrgetter`', 'notes', 5, $md$Sorting a list of objects by an attribute is usually written with a lambda: `sorted(people, key=lambda p: p.age)`. `operator.attrgetter` does the same job, implemented in C instead of as a Python-level closure — and, more importantly, it can reach into **nested** attributes using a dotted string, which a lambda can do too but only by hardcoding the path.

## Basic use

```python
from operator import attrgetter

class Address:
    def __init__(self, city, state):
        self.city = city
        self.state = state

class Person:
    def __init__(self, name, address):
        self.name = name
        self.address = address

people = [
    Person("Alice", Address("New York", "NY")),
    Person("Bob", Address("Chicago", "IL")),
    Person("Charlie", Address("Los Angeles", "CA")),
]

sorted_people = sorted(people, key=attrgetter("address.city"))
print([p.name for p in sorted_people])  # ['Bob', 'Charlie', 'Alice']
```

`attrgetter("address.city")` returns a callable equivalent to `lambda p: p.address.city` — but it accepts the attribute path as a **string**, which a lambda cannot without an `eval` or a chain of `getattr` calls.

## Why the string form matters

```python
# A sort key chosen at runtime — e.g. from a query parameter or config file
sort_key = "address.city"   # could just as easily be "name" or "address.state"
sorted_people = sorted(people, key=attrgetter(sort_key))
```

This is the actual reason to reach for `attrgetter` over a lambda: when the attribute to sort by isn't known until runtime (a user-selected column, a config-driven report), a lambda would need to build the path dynamically with `getattr` chains itself — `attrgetter` already does exactly that, and does it in C. `attrgetter` also accepts multiple attributes at once (`attrgetter("last_name", "first_name")` sorts by last name, then first name, as a tiebreak) and is a direct sibling of `operator.itemgetter` (the same idea for `obj[key]` access instead of `obj.attr`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-operator-attrgetter-q1",
      "type": "mcq",
      "prompt": "What can attrgetter(\"address.city\") do that a lambda p: p.address.city cannot?",
      "options": [
        { "id": "a", "text": "Accept the attribute path as a runtime string, so the sort key can be chosen dynamically (e.g. from config) without writing new code" },
        { "id": "b", "text": "Sort in descending order automatically" },
        { "id": "c", "text": "Handle attributes that don't exist without raising an error" },
        { "id": "d", "text": "Work on dictionaries as well as objects" }
      ],
      "correct": "a",
      "explanation": "Both express the same lookup, but attrgetter takes the path as a string, so it can be built at runtime from a variable — a lambda would need to hardcode the attribute chain or fall back to getattr/eval itself."
    },
    {
      "id": "internals-operator-attrgetter-q2",
      "type": "mcq",
      "prompt": "Besides accepting a dynamic string path, what's another practical advantage of attrgetter over an equivalent lambda?",
      "options": [
        { "id": "a", "text": "It's implemented in C, making it faster than an equivalent Python-level lambda closure" },
        { "id": "b", "text": "It automatically caches sort results" },
        { "id": "c", "text": "It changes the objects it sorts" },
        { "id": "d", "text": "It only works with tuples" }
      ],
      "correct": "a",
      "explanation": "attrgetter is implemented as a C-level callable in the operator module, which is measurably faster than an equivalent Python lambda for hot sort/key paths."
    }
  ]
}
```
$md$, 10, $json$[{"id":"internals-operator-attrgetter-q1","type":"mcq","correct":"a"},{"id":"internals-operator-attrgetter-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('4967c051-0c4e-5e52-b3e3-7192d2a24a03', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '012c80ac-4e8f-5205-8f62-ce79738eaa79', 'CPython', 'notes', 6, $md$"Python" is a language specification; **CPython** is the reference implementation almost everyone actually runs (`python3` on your machine is CPython unless you deliberately installed PyPy, Jython, or GraalPy). Knowing the difference — and what CPython specifically does under the hood — is what separates "I write Python" from "I understand what my Python program is actually doing."

## The pipeline: source → bytecode → PVM

CPython never interprets your `.py` text directly. It compiles it to **bytecode** — a lower-level, portable instruction set — and then the **Python Virtual Machine (PVM)**, a stack-based interpreter loop written in C, executes that bytecode instruction by instruction. You can see the bytecode for any function with `dis`:

```python
import dis

def add(a, b):
    return a + b

dis.dis(add)
# 2           0 RESOURCE_ARG ...  (exact opcodes vary by version)
#             LOAD_FAST                a
#             LOAD_FAST                b
#             BINARY_OP                +
#             RETURN_VALUE
```

This is also why a `.pyc` file exists in `__pycache__` — it's the cached compiled bytecode, so re-running the same script skips recompilation when the source hasn't changed.

## What CPython specifically gives you (and costs you)

- **A huge standard library** and a stable C-API — this is *why* the PyPI ecosystem exists: NumPy, PyTorch, and most performance-critical packages are C extensions written directly against CPython's API, not portable across every Python implementation.
- **Reference counting** for memory management (see the garbage-collection lesson) — a direct consequence of being written in C, and the reason the GIL exists at all.
- **The GIL** — only one thread executes Python bytecode at a time, a direct consequence of reference counting needing to stay thread-safe cheaply (covered in depth in the next section).
- **Slower raw execution** than a compiled language, since every bytecode instruction still goes through the PVM's interpreter loop rather than running as native machine code.

Interviewers ask about CPython specifically to check whether you can reason about *why* Python behaves the way it does — why threads don't parallelize CPU work, why `id()` returns a memory address, why small integers are cached — rather than treating the language as a black box.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "internals-cpython-q1",
      "type": "mcq",
      "prompt": "What does CPython actually execute when you run a .py file?",
      "options": [
        { "id": "a", "text": "The raw source text, interpreted line by line" },
        { "id": "b", "text": "Bytecode compiled from the source, executed by the Python Virtual Machine" },
        { "id": "c", "text": "Native machine code, compiled ahead of time" },
        { "id": "d", "text": "A translation into C source, compiled on the fly" }
      ],
      "correct": "b",
      "explanation": "CPython compiles source to bytecode (visible via the dis module, cached in __pycache__/*.pyc) and the PVM, a C-based interpreter loop, executes that bytecode."
    },
    {
      "id": "internals-cpython-q2",
      "type": "mcq",
      "prompt": "Which of these is a direct consequence of CPython being written in C and using reference counting?",
      "options": [
        { "id": "a", "text": "The Global Interpreter Lock, which keeps refcount updates thread-safe without per-object locks" },
        { "id": "b", "text": "Python's dynamic typing" },
        { "id": "c", "text": "List comprehensions" },
        { "id": "d", "text": "The availability of type hints" }
      ],
      "correct": "a",
      "explanation": "The GIL exists specifically because CPython uses cheap, non-atomic reference counting for memory management — the GIL is what keeps concurrent refcount updates from racing, at the cost of true multi-core parallelism for threads."
    }
  ]
}
```
$md$, 12, $json$[{"id":"internals-cpython-q1","type":"mcq","correct":"b"},{"id":"internals-cpython-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Concurrency & Parallelism
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Concurrency & Parallelism', 1)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6733d008-be77-5a1a-82a0-4637f0918fe9', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'The Global Interpreter Lock (GIL)', 'notes', 0, $md$The **Global Interpreter Lock (GIL)** is a single mutex inside CPython that ensures only one thread executes Python bytecode at any instant — even on a machine with 16 cores, and even with 16 Python threads running. It exists because CPython's reference counting (every object's refcount incremented/decremented on almost every operation) is not thread-safe by default; wrapping every single refcount update in its own lock would be correct but brutally slow, so CPython instead takes one coarse lock around bytecode execution itself.

## Seeing it in action

```python
import threading
import time

def cpu_task():
    total = 0
    for _ in range(10**7):
        total += 1

threads = [threading.Thread(target=cpu_task) for _ in range(4)]

start = time.time()
for t in threads:
    t.start()
for t in threads:
    t.join()

print(f"4 threads, CPU-bound: {time.time() - start:.2f}s")
# Roughly the SAME as running cpu_task() four times sequentially —
# the GIL means only one thread's bytecode runs at a time.
```

Run that against a single-threaded loop of the same total work and the wall-clock time is nearly identical — the four threads never actually run in parallel on separate cores; they take turns holding the GIL, switching every so often (CPython's scheduler periodically forces a switch so no thread starves).

## What the GIL does and doesn't affect

- **CPU-bound work on threads: no speedup.** Pure computation (tight loops, number crunching) doesn't benefit from more `threading.Thread`s, because only one thread's bytecode ever runs at once. This is the single most common threading mistake: reaching for `threading` to parallelize CPU work and being confused why it isn't faster.
- **IO-bound work on threads: real speedup.** A thread blocked on a network call, disk read, or `time.sleep` **releases the GIL** while waiting, letting another thread run. This is why threads are still the right tool for concurrent downloads, database queries, or file I/O.
- **Multiprocessing is unaffected.** Each process gets its own Python interpreter, its own memory space, and its own GIL — the next lesson covers this as the actual way to get CPU-bound parallelism in Python.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-gil-q1",
      "type": "mcq",
      "prompt": "Why does CPython have a Global Interpreter Lock at all?",
      "options": [
        { "id": "a", "text": "To make Python syntax simpler" },
        { "id": "b", "text": "To keep reference counting (CPython's memory management) thread-safe without locking every individual object" },
        { "id": "c", "text": "To prevent developers from using multiprocessing" },
        { "id": "d", "text": "It's a historical accident with no technical reason" }
      ],
      "correct": "b",
      "explanation": "CPython uses reference counting for memory management. A single coarse lock around bytecode execution keeps refcount updates safe without the overhead of per-object locking."
    },
    {
      "id": "concurrency-gil-q2",
      "type": "mcq",
      "prompt": "Four Python threads run a tight CPU-bound loop on an 8-core machine. What speedup should you expect over one thread doing the same total work?",
      "options": [
        { "id": "a", "text": "Roughly 4x, since threads run independently" },
        { "id": "b", "text": "Roughly 8x, using all available cores" },
        { "id": "c", "text": "Essentially no speedup — only one thread executes Python bytecode at a time under the GIL" },
        { "id": "d", "text": "It depends only on available RAM, not cores" }
      ],
      "correct": "c",
      "explanation": "The GIL means CPU-bound Python threads take turns, not run in parallel — total wall-clock time for the same total work is roughly unchanged versus doing it in one thread."
    }
  ]
}
```
$md$, 18, $json$[{"id":"concurrency-gil-q1","type":"mcq","correct":"b"},{"id":"concurrency-gil-q2","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b02cb7da-aa42-57a2-8f82-3374e8ddef6a', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'Concurrency vs Parallelism', 'notes', 1, $md$These two words get used interchangeably in casual conversation, but they describe different things, and Python gives you distinct tools for each.

## Concurrency: managing multiple tasks, not necessarily running them simultaneously

**Concurrency** is about *structure* — dealing with more than one task over the same time period, interleaving progress on each, without requiring them to literally execute at the same instant. A single CPU core running two Python threads is concurrent: it switches between them, making progress on both, but only ever runs one at any given nanosecond.

## Parallelism: actually running at the same time

**Parallelism** is about *execution* — tasks genuinely running simultaneously, which requires multiple independent execution units: multiple CPU cores, or multiple processes.

```python
# Concurrent (interleaved, single core, GIL-limited) — good for IO-bound work
import threading, time

def fetch(name):
    time.sleep(1)  # simulates waiting on a network call
    print(f"{name} done")

threads = [threading.Thread(target=fetch, args=(f"req-{i}",)) for i in range(3)]
for t in threads: t.start()
for t in threads: t.join()
# All 3 finish in ~1s total, not 3s — while one waits on I/O, another runs.
# This is concurrency: interleaved progress, not necessarily simultaneous execution.
```

```python
# Parallel (separate processes, separate GILs, separate cores) — good for CPU-bound work
from multiprocessing import Process

def crunch(n):
    total = sum(i * i for i in range(n))

if __name__ == "__main__":
    procs = [Process(target=crunch, args=(10**7,)) for _ in range(4)]
    for p in procs: p.start()
    for p in procs: p.join()
    # These 4 processes can genuinely run on 4 different cores at once —
    # this is parallelism.
```

## Python's tools, mapped to the right job

| Tool | Concurrent? | Parallel? | Best for |
|---|---|---|---|
| `threading` | Yes | No (GIL-limited) | IO-bound: network, disk, DB calls |
| `asyncio` | Yes | No | IO-bound, especially many thousands of connections |
| `multiprocessing` | Yes | Yes (separate GILs) | CPU-bound: computation, image/data processing |

The recurring interview trap is reaching for `threading` on CPU-bound work expecting parallelism, or reaching for `multiprocessing` on IO-bound work and paying process-startup overhead for no benefit. Matching the tool to whether the bottleneck is *waiting* (threads/asyncio) or *computing* (processes) is the actual skill being tested.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-concurrency-vs-parallelism-q1",
      "type": "mcq",
      "prompt": "Two threads interleave on a single core, each making progress but never executing at the exact same instant. Is this concurrent, parallel, both, or neither?",
      "options": [
        { "id": "a", "text": "Concurrent only — structured to handle multiple tasks over the same period, without simultaneous execution" },
        { "id": "b", "text": "Parallel only" },
        { "id": "c", "text": "Both concurrent and parallel" },
        { "id": "d", "text": "Neither — a single core can't do either" }
      ],
      "correct": "a",
      "explanation": "Concurrency is about structure/interleaving; parallelism specifically requires simultaneous execution, which needs multiple cores or processes. A single core with interleaved threads is concurrent but not parallel."
    },
    {
      "id": "concurrency-concurrency-vs-parallelism-q2",
      "type": "mcq",
      "prompt": "Which Python tool should you reach for to genuinely parallelize a CPU-bound computation across cores?",
      "options": [
        { "id": "a", "text": "threading, since threads are lightweight" },
        { "id": "b", "text": "asyncio, since it handles many tasks efficiently" },
        { "id": "c", "text": "multiprocessing, since each process gets its own interpreter, memory, and GIL, enabling true multi-core execution" },
        { "id": "d", "text": "None — Python cannot parallelize CPU-bound work" }
      ],
      "correct": "c",
      "explanation": "threading and asyncio are both limited to one core's worth of Python bytecode execution at a time due to the GIL. multiprocessing sidesteps this entirely by giving each process its own GIL."
    }
  ]
}
```
$md$, 12, $json$[{"id":"concurrency-concurrency-vs-parallelism-q1","type":"mcq","correct":"a"},{"id":"concurrency-concurrency-vs-parallelism-q2","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('8b7f105c-26f2-523b-86eb-084c333b1f76', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'Multithreading', 'notes', 2, $md$Threads share the same process memory space and are lightweight to create — and because a thread blocked on I/O releases the GIL, threading is Python's go-to tool for running many blocking operations (network requests, file reads, DB queries) concurrently.

## Manual threads

```python
import threading
import time

def download(url):
    print(f"Starting download: {url}")
    time.sleep(2)  # simulates network wait — GIL is released during this
    print(f"Finished download: {url}")

urls = ["url1", "url2", "url3"]

threads = []
for url in urls:
    t = threading.Thread(target=download, args=(url,))
    threads.append(t)
    t.start()

for t in threads:
    t.join()  # block until every thread finishes

print("All downloads completed")
# Total time: ~2s (all three overlap), not 6s (sequential)
```

`.start()` launches the thread; `.join()` blocks the calling thread until it finishes. Forgetting to `.join()` doesn't crash anything, but it means your program can exit (or move on) before background threads finish their work.

## The preferred pattern: `ThreadPoolExecutor`

Manually managing a list of `Thread` objects, starting them, and joining them is boilerplate that's easy to get subtly wrong (leaking threads, not propagating exceptions). `concurrent.futures.ThreadPoolExecutor` manages a fixed pool of worker threads for you:

```python
from concurrent.futures import ThreadPoolExecutor
import time

def download(url):
    print(f"Downloading: {url}")
    time.sleep(2)
    print(f"Finished: {url}")

urls = ["url1", "url2", "url3"]

with ThreadPoolExecutor() as executor:
    executor.map(download, urls)
# The pool is automatically joined and cleaned up when the `with` block exits
```

`ThreadPoolExecutor` also gives you `.submit()` for individual tasks with real `Future` objects (so you can catch exceptions raised inside a thread, which manual `Thread` objects silently swallow unless you check `.exception()` yourself), and it reuses a bounded number of worker threads instead of spawning one OS thread per task — important once you're launching hundreds of concurrent requests rather than three.

## When threading is (and isn't) the right call

Threading shines specifically when a task spends most of its time **waiting**, not computing — an HTTP request, a database round-trip, reading a large file from a slow disk. During that wait, the GIL is released and other threads run. The moment the work becomes CPU-bound (parsing, hashing, numeric computation), threading stops helping — see the GIL lesson — and `multiprocessing` becomes the right tool instead.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-multithreading-q1",
      "type": "mcq",
      "prompt": "Why does time.sleep(2) inside a thread allow other threads to make progress, despite the GIL?",
      "options": [
        { "id": "a", "text": "time.sleep() explicitly releases the GIL while the thread is blocked" },
        { "id": "b", "text": "sleep() runs outside the GIL's scope entirely by using a separate interpreter" },
        { "id": "c", "text": "The GIL doesn't apply to the first thread started" },
        { "id": "d", "text": "sleep() disables the GIL globally for the process" }
      ],
      "correct": "a",
      "explanation": "I/O and blocking calls like sleep() release the GIL while waiting, which is exactly why threading helps for I/O-bound work: other threads get to run Python bytecode during that wait."
    },
    {
      "id": "concurrency-multithreading-q2",
      "type": "mcq",
      "prompt": "What's the main practical advantage of ThreadPoolExecutor over manually creating and joining Thread objects?",
      "options": [
        { "id": "a", "text": "It bypasses the GIL entirely" },
        { "id": "b", "text": "It manages a bounded pool of reusable worker threads and handles cleanup/joining automatically, avoiding the boilerplate and pitfalls of manual thread management" },
        { "id": "c", "text": "It makes threads run in parallel on separate cores" },
        { "id": "d", "text": "It's required for any thread that uses time.sleep()" }
      ],
      "correct": "b",
      "explanation": "ThreadPoolExecutor manages a fixed-size pool, reuses threads across tasks, exposes Future objects for exception handling, and automatically joins on context-manager exit — none of which manual Thread management gives you for free."
    }
  ]
}
```
$md$, 18, $json$[{"id":"concurrency-multithreading-q1","type":"mcq","correct":"a"},{"id":"concurrency-multithreading-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0d7b5537-0852-5349-9442-c4bc4acf79c8', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'Multiprocessing', 'notes', 3, $md$Where threads share one interpreter and one GIL, `multiprocessing` launches separate **OS processes**, each running its own full Python interpreter with its own memory space and its own GIL. That's how Python achieves true parallelism: four processes on a four-core machine really can execute Python bytecode simultaneously, because there's no single lock shared between them.

## Basic process creation

```python
from multiprocessing import Process
import os

def worker(name):
    print(f"Process {name} is running in process ID: {os.getpid()}")

if __name__ == "__main__":
    p1 = Process(target=worker, args=("A",))
    p2 = Process(target=worker, args=("B",))

    p1.start()
    p2.start()

    p1.join()
    p2.join()

    print("Both processes finished")
```

Notice the `if __name__ == "__main__":` guard — this is **not optional** on Windows and macOS (which use the `spawn` start method): child processes re-import your script's module to set themselves up, and without the guard, each child would try to spawn its own children recursively. `os.getpid()` printed from each worker confirms they're genuinely separate OS processes, not threads inside one.

## The cost of true parallelism

Multiprocessing isn't free:

- **Startup overhead** — spawning a new process (and, with `spawn`, re-importing your module in it) is far slower than starting a thread.
- **No shared memory by default** — each process has its own address space, so a global variable set in the parent is invisible to a child; passing data in or out means serializing it (`pickle`, by default) across a pipe, or using the explicit shared-memory primitives covered in a later lesson.
- **Higher per-task memory** — each process carries its own copy of the interpreter and any imported modules.

## Where it wins

For CPU-bound work — numeric computation, image processing, parsing large amounts of data, anything where the bottleneck is the CPU actually crunching, not waiting — `multiprocessing` is the only standard-library tool that scales with core count. The trade-off is real, though: for lightweight, short-lived, or IO-bound tasks, the process-startup overhead alone can make `multiprocessing` slower than `threading` or plain sequential code. Choosing between them is a bottleneck question — profile first, don't guess.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-multiprocessing-q1",
      "type": "mcq",
      "prompt": "Why can multiprocessing achieve true parallelism on multiple cores when threading cannot?",
      "options": [
        { "id": "a", "text": "Each process has its own interpreter, memory space, and GIL — there's no single shared lock limiting them to one at a time" },
        { "id": "b", "text": "Processes don't use bytecode, they compile to machine code directly" },
        { "id": "c", "text": "multiprocessing disables the GIL globally for the whole program" },
        { "id": "d", "text": "Processes are just faster threads" }
      ],
      "correct": "a",
      "explanation": "Threads within one process share a single GIL. Each multiprocessing.Process is a separate OS process with its own interpreter and GIL, so multiple processes can genuinely execute Python bytecode simultaneously on separate cores."
    },
    {
      "id": "concurrency-multiprocessing-q2",
      "type": "mcq",
      "prompt": "Why is `if __name__ == \"__main__\":` required around Process creation on Windows/macOS?",
      "options": [
        { "id": "a", "text": "It's a style convention with no functional effect" },
        { "id": "b", "text": "Child processes re-import the script to set themselves up; without the guard, each child would try to spawn its own children recursively" },
        { "id": "c", "text": "It's required only when using more than 2 processes" },
        { "id": "d", "text": "It suppresses print statements in child processes" }
      ],
      "correct": "b",
      "explanation": "The 'spawn' start method (default on Windows/macOS) re-imports the launching module in each child process. Without the __main__ guard, top-level Process(...).start() calls would re-run on import, causing runaway recursive process creation."
    }
  ]
}
```
$md$, 18, $json$[{"id":"concurrency-multiprocessing-q1","type":"mcq","correct":"a"},{"id":"concurrency-multiprocessing-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('31ac7149-66ed-5b58-96ab-d0e37c4874cb', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'Race Conditions (Multiprocessing & Multithreading)', 'notes', 4, $md$A **race condition** happens when two or more threads or processes read, modify, and write the same shared data at the same time, and the final result depends on the unpredictable order in which those steps happen to interleave. It's one of the most common sources of "works on my machine, fails in production once in a while" bugs, because the outcome isn't wrong every time — just non-deterministically wrong.

## Reproducing one

```python
import multiprocessing

def increment(n):
    for _ in range(100_000):
        n.value += 1   # NOT atomic: read, add 1, write back — three separate steps

if __name__ == "__main__":
    number = multiprocessing.Value("i", 0)
    p1 = multiprocessing.Process(target=increment, args=(number,))
    p2 = multiprocessing.Process(target=increment, args=(number,))

    p1.start()
    p2.start()
    p1.join()
    p2.join()

    print(number.value)  # Expected 200000 — actual result varies, usually LESS
```

`n.value += 1` looks like one operation but is really three: read the current value, add 1, write the result back. If process 1 reads `n.value` as `50`, then process 2 also reads it as `50` before process 1 has written `51` back, both processes compute `51` and one of the two increments is silently lost. Run this script multiple times and you'll get a different (and always ≤ 200,000) final value — that non-determinism is the defining symptom of a race condition.

## Fixing it with a lock

```python
import multiprocessing

def increment(n, lock):
    for _ in range(100_000):
        with lock:          # only one process executes this block at a time
            n.value += 1

if __name__ == "__main__":
    number = multiprocessing.Value("i", 0)
    lock = multiprocessing.Lock()

    p1 = multiprocessing.Process(target=increment, args=(number, lock))
    p2 = multiprocessing.Process(target=increment, args=(number, lock))

    p1.start()
    p2.start()
    p1.join()
    p2.join()

    print(number.value)  # Always exactly 200000
```

`multiprocessing.Lock()` (and `threading.Lock()` for the thread equivalent) turns the read-modify-write sequence into a **critical section**: only one process/thread can be inside the `with lock:` block at a time, so the interleaving that caused lost updates becomes impossible. The cost is serialization — the two processes are no longer actually running that increment loop concurrently, they're taking turns for that specific operation.

## The general shape of the fix

Locks are the most common tool, but the same idea shows up as semaphores (allow N concurrent holders instead of 1), `RLock` (a lock a single thread can acquire multiple times, for recursive code), and higher-level structures like queues that make sharing state explicit instead of implicit. The underlying principle is always the same: identify the smallest region of code that touches shared, mutable state, and make sure only one execution context is inside it at any instant.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-race-conditions-q1",
      "type": "mcq",
      "prompt": "Why does `n.value += 1` cause lost updates when two processes run it concurrently without a lock?",
      "options": [
        { "id": "a", "text": "It's really three separate steps (read, add, write) — another process can read the stale value between this process's read and write" },
        { "id": "b", "text": "multiprocessing.Value doesn't support integers" },
        { "id": "c", "text": "Python caches += operations and applies them out of order" },
        { "id": "d", "text": "It only fails when more than 2 processes are used" }
      ],
      "correct": "a",
      "explanation": "+= on a shared value is read-modify-write, not atomic. If two processes interleave between the read and the write, one process's update can be silently overwritten by the other's stale read."
    },
    {
      "id": "concurrency-race-conditions-q2",
      "type": "mcq",
      "prompt": "What does wrapping n.value += 1 in `with lock:` actually guarantee?",
      "options": [
        { "id": "a", "text": "That the increment runs faster" },
        { "id": "b", "text": "That only one process/thread can execute that block at a time, making the read-modify-write sequence atomic with respect to other holders of the same lock" },
        { "id": "c", "text": "That the value is backed up to disk" },
        { "id": "d", "text": "That both processes run the loop simultaneously without interference" }
      ],
      "correct": "b",
      "explanation": "A lock serializes access to the critical section — whichever process/thread acquires it first finishes its read-modify-write before the other can start, eliminating the interleaving that caused lost updates."
    }
  ]
}
```
$md$, 18, $json$[{"id":"concurrency-race-conditions-q1","type":"mcq","correct":"a"},{"id":"concurrency-race-conditions-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('00cb0ae3-f022-5533-932f-79f6ff7b7837', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'b27ee0eb-7aa7-5cd9-bb97-93c1544a7ef4', 'Shared Memory in Multiprocessing', 'notes', 5, $md$Processes don't share memory by default — that isolation is exactly what makes multiprocessing safe from the GIL and gives each process its own interpreter. But isolation also means a plain module-level variable set in the parent process is simply invisible to a child: the child got its own independent copy (via `fork`) or none at all (via `spawn`), not a live view of the same memory. When processes genuinely need to share and update the same piece of state, that sharing has to be explicit.

## `multiprocessing.Value`: an explicitly shared primitive

```python
from multiprocessing import Process, Value

def increment(shared_value):
    with shared_value.get_lock():  # Value ships with its own built-in lock
        shared_value.value += 1

if __name__ == "__main__":
    shared_value = Value("i", 0)  # 'i' = signed int, backed by shared OS memory
    processes = [Process(target=increment, args=(shared_value,)) for _ in range(5)]

    for p in processes:
        p.start()
    for p in processes:
        p.join()

    print(shared_value.value)  # 5
```

`Value("i", 0)` allocates a block of memory in a shared-memory segment that every child process maps into its own address space — unlike a normal object, writes from one process are genuinely visible to the others. `.get_lock()` returns the `Value`'s own built-in lock (equivalent to creating a separate `Lock()` and passing it alongside, as in the race-conditions lesson), so `with shared_value.get_lock():` protects the read-modify-write the same way an explicit lock would.

## `multiprocessing.Array`: the same idea for sequences

`multiprocessing.Array("i", [0, 0, 0, 0, 0])` is `Value`'s sibling for fixed-size sequences of a single type — same type-code system as the `array` module, same shared-memory backing, same need for explicit locking around any read-modify-write sequence.

## Why this is always explicit in Python

Unlike languages where threads (or even processes, via certain OS mechanisms) share memory by default and you have to opt *out* with isolation, Python's `multiprocessing` defaults to isolation and makes sharing something you opt *into*, deliberately, through `Value`/`Array` (for simple types) or `Manager` objects (for shared dicts, lists, and more complex structures, at higher overhead since they proxy access through a server process). This is a design choice, not an accident: shared mutable state is exactly where race conditions live, so Python makes you name the shared thing explicitly and think about locking it, rather than making sharing the invisible default.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "concurrency-shared-memory-q1",
      "type": "mcq",
      "prompt": "A parent process sets a plain module-level variable to 5 before starting a child Process. What does the child see?",
      "options": [
        { "id": "a", "text": "5 — child processes automatically inherit the parent's live memory" },
        { "id": "b", "text": "Not a live, shared view of that variable — processes don't share memory by default; only explicit constructs like Value/Array are actually shared" },
        { "id": "c", "text": "An error, since plain variables can't be accessed in child processes at all" },
        { "id": "d", "text": "0, always, regardless of what the parent set" }
      ],
      "correct": "b",
      "explanation": "Process isolation means ordinary variables aren't shared — only multiprocessing.Value, Array, or Manager-backed objects are backed by shared memory that every process can see updates to."
    },
    {
      "id": "concurrency-shared-memory-q2",
      "type": "mcq",
      "prompt": "Why does the example still call shared_value.get_lock() even though multiprocessing.Value is explicitly shared?",
      "options": [
        { "id": "a", "text": "Being shared only means the memory is visible across processes — it doesn't make read-modify-write sequences atomic, so a lock is still needed to prevent race conditions" },
        { "id": "b", "text": "get_lock() is required just to read the .value attribute" },
        { "id": "c", "text": "It's unnecessary boilerplate left over from older Python versions" },
        { "id": "d", "text": "Value objects require re-locking after every process starts" }
      ],
      "correct": "a",
      "explanation": "Shared visibility and atomicity are separate concerns. Multiple processes can still race on a shared Value's read-modify-write cycle exactly like the unshared example in the race-conditions lesson — get_lock() prevents that."
    }
  ]
}
```
$md$, 18, $json$[{"id":"concurrency-shared-memory-q1","type":"mcq","correct":"b"},{"id":"concurrency-shared-memory-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Collections & OOP Foundations
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('3258c6b9-73b9-558d-979e-cb499df7bc1a', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Collections & OOP Foundations', 2)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f2bc1121-1b22-595f-abf2-528d7c2f2f59', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'The `collections` Module', 'notes', 0, $md$Interviewers ask about `collections` because it's a quick signal of how much of the standard library you actually use day to day. The module ships specialized container types that replace common `dict`/`list` boilerplate with something faster and more expressive.

## `defaultdict`: no more `if key not in dict`

The classic counting pattern with a plain `dict` requires checking whether a key already exists before you can increment it:

```python
counts = {}
for word in ["a", "b", "a", "c", "b", "a"]:
    if word not in counts:
        counts[word] = 0
    counts[word] += 1
print(counts)
```

`defaultdict` removes the check entirely by supplying a factory function that runs the first time a missing key is accessed:

```python
from collections import defaultdict

default_dict = defaultdict(int)
default_dict['a'] += 1
default_dict['b'] += 5
default_dict['a'] += 1

print(dict(default_dict))
print(default_dict['z'])  # missing key: factory int() -> 0, no KeyError
```

`defaultdict(int)` uses `int()` (which returns `0`) as the factory; `defaultdict(list)` is equally common for grouping items under keys without an `if key not in groups: groups[key] = []` guard.

## `Counter`: `defaultdict(int)`, specialized

`Counter` is purpose-built for the counting use case and adds convenience methods `defaultdict` doesn't have:

```python
from collections import Counter

votes = Counter(["python", "go", "python", "rust", "python", "go"])
print(votes)                # Counter({'python': 3, 'go': 2, 'rust': 1})
print(votes.most_common(2)) # [('python', 3), ('go', 2)]
print(votes["java"])        # 0 — missing keys don't raise, same as defaultdict
```

## `deque`: O(1) at both ends

A plain `list` is backed by a contiguous array, so `list.insert(0, x)` and `list.pop(0)` are O(n) — every remaining element shifts. `deque` (double-ended queue) is backed by a doubly linked structure of blocks, making operations at *both* ends O(1):

```python
from collections import deque

queue = deque([1, 2, 3])
queue.appendleft(0)
queue.append(4)
print(queue)        # deque([0, 1, 2, 3, 4])
print(queue.popleft())  # 0 — O(1), unlike list.pop(0)
```

This is why `deque` is the standard choice for BFS queues and sliding-window problems in coding interviews.

## `OrderedDict`: mostly legacy now

Before Python 3.7, plain `dict` did not guarantee insertion order — `OrderedDict` existed specifically to provide that guarantee. Since 3.7, regular `dict` preserves insertion order as a language guarantee, so `OrderedDict` is mainly useful today for its extra methods (`move_to_end`), not for ordering itself. Knowing this history is itself a common interview trivia question.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-collections-module-q1",
      "type": "mcq",
      "prompt": "What does `defaultdict(int)['missing_key']` return, given the key was never set?",
      "options": [
        { "id": "a", "text": "It raises a KeyError" },
        { "id": "b", "text": "0 — int() is called as the factory and the result is stored under that key" },
        { "id": "c", "text": "None" },
        { "id": "d", "text": "It raises a TypeError because int is not callable with no arguments" }
      ],
      "correct": "b",
      "explanation": "defaultdict calls its factory function (int() -> 0) the first time a missing key is accessed, stores the result, and returns it — no KeyError."
    },
    {
      "id": "oop-collections-collections-module-q2",
      "type": "mcq",
      "prompt": "Why is `deque.popleft()` preferred over `list.pop(0)` for a queue?",
      "options": [
        { "id": "a", "text": "deque.popleft() is O(1); list.pop(0) is O(n) because every remaining element must shift" },
        { "id": "b", "text": "list.pop(0) doesn't exist in Python 3" },
        { "id": "c", "text": "deque uses less memory per element than list" },
        { "id": "d", "text": "There is no difference; it's purely a style preference" }
      ],
      "correct": "a",
      "explanation": "list is a contiguous array, so removing the first element shifts everything left — O(n). deque is a doubly linked structure with O(1) operations at both ends."
    }
  ]
}
```
$md$, 15, $json$[{"id":"oop-collections-collections-module-q1","type":"mcq","correct":"b"},{"id":"oop-collections-collections-module-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('625b6756-3411-5780-9654-3580edac40d1', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'Encapsulation', 'notes', 1, $md$Encapsulation means hiding an object's internal state and forcing outside code to go through a controlled interface (methods) instead of reaching in and mutating fields directly. It protects invariants — rules that must always hold, like "balance can never go negative."

## Python has no real "private" — it has a convention

Unlike Java's `private` keyword, Python doesn't enforce access restrictions at the language level. Instead it uses naming conventions the whole ecosystem agrees to respect:

- `self.balance` — public, anyone can read/write it
- `self._balance` — single underscore, "internal use, but I trust you" (a hint, nothing more)
- `self.__balance` — double underscore, triggers **name mangling**

```python
class BankAccount:
    def __init__(self, owner, balance):
        self.owner = owner
        self.__balance = balance  # name-mangled to _BankAccount__balance

    def deposit(self, amount):
        if amount > 0:
            self.__balance += amount

    def withdraw(self, amount):
        if 0 < amount <= self.__balance:
            self.__balance -= amount

    def get_balance(self):
        return self.__balance  # controlled, read-only access

account = BankAccount("Alice", 1000)
account.deposit(500)
account.withdraw(200)
print(account.get_balance())  # 1300

# The double underscore doesn't make this impossible, just inconvenient:
print(account._BankAccount__balance)  # 1300 — name mangling, not real privacy
```

## What name mangling actually does

`self.__balance` inside `BankAccount` is rewritten by the interpreter at compile time to `self._BankAccount__balance`. The point isn't security — it's collision avoidance in inheritance: if a subclass also defines `__balance`, the two don't clash, because each gets mangled with its own class name as the prefix. Treat it as "strongly discourage accidental external access," not "make private."

## Why bother, if it's not enforced?

The `deposit`/`withdraw` methods are the *only* way to change `__balance`, and both validate their input (`amount > 0`, `amount <= self.__balance`) before mutating state. If external code could write `account.balance = -500` directly, that invariant — balance never goes negative — would be trivial to break by accident. Encapsulation isn't about stopping malicious code; it's about making the one correct way to change state the only *easy* way to change state.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-encapsulation-q1",
      "type": "mcq",
      "prompt": "What does Python actually do with an attribute named `self.__balance` inside class `BankAccount`?",
      "options": [
        { "id": "a", "text": "Makes it truly inaccessible from outside the class, like Java's private" },
        { "id": "b", "text": "Renames it to `self._BankAccount__balance` (name mangling) — still accessible, just inconvenient" },
        { "id": "c", "text": "Raises a SyntaxError, since double underscores are reserved" },
        { "id": "d", "text": "Turns it into a class variable shared by all instances" }
      ],
      "correct": "b",
      "explanation": "Python has no enforced privacy. A double-underscore attribute is name-mangled to `_ClassName__attr`, which discourages accidental access but doesn't prevent it."
    },
    {
      "id": "oop-collections-encapsulation-q2",
      "type": "mcq",
      "prompt": "Why does `BankAccount` expose `deposit()`/`withdraw()` methods instead of letting callers set `account.balance` directly?",
      "options": [
        { "id": "a", "text": "Direct attribute access is slower in Python" },
        { "id": "b", "text": "So the class can validate every mutation (e.g. reject a negative withdrawal) and protect its invariants" },
        { "id": "c", "text": "Because Python doesn't allow public numeric attributes" },
        { "id": "d", "text": "It's purely a stylistic convention with no functional benefit" }
      ],
      "correct": "b",
      "explanation": "Routing every state change through validated methods is how the class guarantees an invariant (balance never negative) stays true no matter how the object is used."
    }
  ]
}
```
$md$, 12, $json$[{"id":"oop-collections-encapsulation-q1","type":"mcq","correct":"b"},{"id":"oop-collections-encapsulation-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('59de5905-92d5-5f7f-9371-28753755e3f0', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'Abstraction', 'notes', 2, $md$Abstraction is the design principle of exposing *what* an object does while hiding *how* it does it. Encapsulation (the previous lesson) is the mechanism — hiding fields behind methods; abstraction is the goal — presenting a simple contract so callers never need to know the implementation.

## A contract, not an implementation

In Python, the most common way to express "here is a contract every subclass must fulfill" is an Abstract Base Class:

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    """Defines a strict contract for all shapes — no implementation here."""

    @abstractmethod
    def area(self) -> float:
        """Return the area of the shape."""
        ...

    @abstractmethod
    def perimeter(self) -> float:
        """Return the perimeter of the shape."""
        ...


class Rectangle(Shape):
    def __init__(self, width: float, height: float):
        self.width = width
        self.height = height

    def area(self) -> float:
        return self.width * self.height

    def perimeter(self) -> float:
        return 2 * (self.width + self.height)


shape = Rectangle(5, 10)
print(shape.area())       # 50
print(shape.perimeter())  # 30
```

Code that calls `shape.area()` never needs to know it's a `Rectangle` computing `width * height` — it only needs to know every `Shape` has an `area()` method that returns a float. That's the whole point: the caller depends on the *abstraction* (`Shape`), not the *implementation* (`Rectangle`).

## Why this matters at scale

Without abstraction, callers end up branching on concrete types (`if isinstance(shape, Rectangle): ... elif isinstance(shape, Circle): ...`), which means every new shape requires editing every place that branches. With an abstract contract, adding `Triangle(Shape)` requires touching exactly one file — the caller code that already does `shape.area()` works unmodified. This is the same idea behind interfaces in Java/Go and protocols in TypeScript.

## Abstraction vs. encapsulation, side by side

- **Encapsulation**: `BankAccount` hides `__balance` behind `deposit()`/`withdraw()` — a *data hiding* mechanism.
- **Abstraction**: `Shape` hides *how* area is computed behind a common `area()` signature — a *design* principle about what callers need to know.

They're complementary, and interviewers often use "aren't these the same thing?" as a follow-up to see if you can articulate the distinction rather than just define both terms.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-abstraction-q1",
      "type": "mcq",
      "prompt": "What is the main benefit of code calling `shape.area()` on an abstract `Shape` instead of branching on `isinstance(shape, Rectangle)` etc.?",
      "options": [
        { "id": "a", "text": "It runs faster because isinstance checks are slow" },
        { "id": "b", "text": "Adding a new shape type requires no changes to the calling code — it already works through the shared contract" },
        { "id": "c", "text": "It avoids using the abc module, which is deprecated" },
        { "id": "d", "text": "It removes the need for a Shape class entirely" }
      ],
      "correct": "b",
      "explanation": "Calling code that depends on the abstract contract (area()) rather than concrete types doesn't need to change when a new shape is added, since every shape implements that same contract."
    },
    {
      "id": "oop-collections-abstraction-q2",
      "type": "mcq",
      "prompt": "How does abstraction differ from encapsulation?",
      "options": [
        { "id": "a", "text": "They are exactly the same concept with two names" },
        { "id": "b", "text": "Encapsulation hides an object's internal data behind methods; abstraction hides implementation details behind a shared contract callers rely on" },
        { "id": "c", "text": "Abstraction only applies to abstract base classes; encapsulation only applies to modules" },
        { "id": "d", "text": "Encapsulation is a Python-only concept; abstraction applies to all languages" }
      ],
      "correct": "b",
      "explanation": "Encapsulation is the data-hiding mechanism (private-ish attributes plus accessor methods); abstraction is the design principle of exposing a simple contract and hiding the complexity behind it."
    }
  ]
}
```
$md$, 12, $json$[{"id":"oop-collections-abstraction-q1","type":"mcq","correct":"b"},{"id":"oop-collections-abstraction-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e44ac907-4848-5002-abb5-e72fa4c9cb54', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'Abstract Base Classes (`abc`)', 'notes', 3, $md$The previous lesson used `ABC` and `@abstractmethod` to illustrate abstraction as a *design idea*. This lesson is about the `abc` module's actual *mechanics* — what it enforces, when it enforces it, and how it differs from just raising `NotImplementedError` by hand.

## The enforcement is real, and it's a `TypeError`

```python
from abc import ABC, abstractmethod

class Shape(ABC):
    @abstractmethod
    def area(self):
        pass

    @abstractmethod
    def perimeter(self):
        pass

    def concrete(self):
        # ABCs can mix abstract methods with normal, already-implemented ones
        return "Subscribe"


class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height

    def perimeter(self):
        return 2 * (self.width + self.height)


rect = Rectangle(4, 5)
print(rect.area())       # 20
print(rect.perimeter())  # 18
print(rect.concrete())   # Subscribe — inherited, non-abstract method
```

Try to instantiate `Shape` itself, or a subclass that skips one of the abstract methods, and Python refuses at construction time:

```python
class IncompleteShape(Shape):
    def area(self):
        return 0
    # perimeter() not implemented

try:
    shape = IncompleteShape()
except TypeError as e:
    print(f"TypeError: {e}")
    # Can't instantiate abstract class IncompleteShape
    # without an implementation for abstract method 'perimeter'
```

## Why this beats hand-rolled `NotImplementedError`

A common alternative is a plain base class where unimplemented methods raise manually:

```python
class Shape:
    def area(self):
        raise NotImplementedError
```

That "contract" is only checked when `area()` is actually *called* — a subclass that forgets to override it will instantiate just fine and blow up later, at runtime, possibly in production. `ABC` + `@abstractmethod` moves that check to **instantiation time**: `IncompleteShape()` fails immediately, long before any code path calls `.perimeter()`. This is the concrete reason ABCs are considered "safer" than the `NotImplementedError` convention — the failure mode shifts from "surprises in production" to "the object never gets created."

## `ABC` can still hold real logic

`Shape.concrete()` above is not abstract — ABCs are not purely interfaces; they can mix abstract methods (the required contract) with fully implemented ones (shared behavior every subclass gets for free). This is exactly the pattern used throughout Django and FastAPI internals: an abstract base defines the required hooks, plus utility methods built on top of those hooks.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-abstract-base-classes-q1",
      "type": "mcq",
      "prompt": "When does Python raise an error if a subclass of an ABC fails to implement one of its `@abstractmethod`s?",
      "options": [
        { "id": "a", "text": "At import time, when the subclass is first defined" },
        { "id": "b", "text": "At instantiation time — trying to construct the incomplete subclass raises TypeError" },
        { "id": "c", "text": "Only when the missing method is actually called" },
        { "id": "d", "text": "Never — ABC only issues a warning, not an error" }
      ],
      "correct": "b",
      "explanation": "The abc module blocks instantiation of any concrete class that hasn't implemented every abstract method — the error surfaces immediately at construction, not later when the method happens to be called."
    },
    {
      "id": "oop-collections-abstract-base-classes-q2",
      "type": "mcq",
      "prompt": "Why is `ABC` + `@abstractmethod` generally preferred over a base class that raises `NotImplementedError` by hand?",
      "options": [
        { "id": "a", "text": "ABC classes run faster at runtime" },
        { "id": "b", "text": "ABC fails at instantiation time if a method is missing; NotImplementedError only fails when that specific method is later called" },
        { "id": "c", "text": "NotImplementedError is deprecated in modern Python" },
        { "id": "d", "text": "ABC classes cannot contain any concrete (non-abstract) methods, which is considered safer" }
      ],
      "correct": "b",
      "explanation": "Hand-rolled NotImplementedError only surfaces the bug when the unimplemented method is actually invoked, which can be much later and in production. ABC enforcement happens the moment the incomplete class is instantiated."
    }
  ]
}
```
$md$, 15, $json$[{"id":"oop-collections-abstract-base-classes-q1","type":"mcq","correct":"b"},{"id":"oop-collections-abstract-base-classes-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e09ee0d5-fed8-5122-bf21-a7e8dbe6dad3', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'Inheritance', 'notes', 4, $md$Inheritance lets a subclass reuse a parent's attributes and methods, and override the ones that need to differ. It's the mechanism behind both abstraction (Shape/Rectangle) and polymorphism (next lesson) — but used carelessly it's also the single biggest source of tightly coupled, fragile object hierarchies.

## Overriding a method

```python
class Animal:
    def __init__(self, name):
        self.name = name

    def speak(self):
        raise NotImplementedError("Subclasses must implement this method")

class Dog(Animal):
    def speak(self):
        return f"{self.name} says Woof!"

class Cat(Animal):
    def speak(self):
        return f"{self.name} says Meow!"

dog = Dog("Buddy")
cat = Cat("Kitty")
print(dog.speak())  # Buddy says Woof!
print(cat.speak())  # Kitty says Meow!
```

`Dog` and `Cat` both inherit `__init__` unchanged — `self.name = name` doesn't need to be repeated — but each overrides `speak()` with its own behavior. That's the reuse win: shared logic lives once, in `Animal`, and only the parts that genuinely differ are rewritten.

## The design question: is `Animal` ever instantiated?

`Animal.speak()` raises `NotImplementedError`, which signals "this class is never meant to be used directly — only subclassed." That's a real design decision with two options:

- **The parent is never instantiated on its own** → make it an `ABC` (previous lesson). The interpreter then enforces the contract at instantiation time instead of trusting a comment and a raised exception.
- **The parent is a genuinely usable, concrete class** (e.g. `Animal` could reasonably have a default `speak()` that returns `"..."`) → plain inheritance is the right tool, no `ABC` needed.

Reaching for `NotImplementedError` in a concrete base class, as the example above does, is the middle ground the handbook material calls out directly: it *works*, but an `ABC` communicates the same intent to both the reader and the interpreter more clearly.

## Where inheritance goes wrong

Deep inheritance chains (`D(C)`, `C(B)`, `B(A)`) couple every subclass to decisions made several classes up, so a change to `A` can silently break `D` in ways that are hard to trace. The common senior-level guidance — "favor composition over inheritance" — isn't a rule against inheritance itself; it's a reminder to reach for it only when there's a genuine **is-a** relationship (`Dog` *is an* `Animal`), and to model **has-a** relationships (`Car` *has an* `Engine`) by holding a reference to an object instead of inheriting from it.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-inheritance-q1",
      "type": "mcq",
      "prompt": "In the Animal/Dog/Cat example, why don't Dog and Cat redefine `__init__`?",
      "options": [
        { "id": "a", "text": "They can't — subclasses are never allowed to have their own __init__" },
        { "id": "b", "text": "Because they inherit Animal's __init__ unchanged, which already does everything they need" },
        { "id": "c", "text": "Python auto-generates a blank __init__ for every subclass" },
        { "id": "d", "text": "speak() implicitly calls __init__ every time" }
      ],
      "correct": "b",
      "explanation": "Inheritance means a subclass automatically has every method the parent defines, including __init__, unless the subclass explicitly overrides it. Dog and Cat only override speak() because that's the only behavior that differs."
    },
    {
      "id": "oop-collections-inheritance-q2",
      "type": "mcq",
      "prompt": "When is 'favor composition over inheritance' guidance actually pointing at?",
      "options": [
        { "id": "a", "text": "Inheritance should never be used in Python" },
        { "id": "b", "text": "Prefer modeling has-a relationships (e.g. Car has an Engine) via composition, and reserve inheritance for genuine is-a relationships" },
        { "id": "c", "text": "Composition is always faster at runtime than inheritance" },
        { "id": "d", "text": "Multiple inheritance is banned in modern Python" }
      ],
      "correct": "b",
      "explanation": "Inheritance is the right tool for a real is-a relationship (Dog is an Animal). Modeling has-a relationships as inheritance instead of composition is the classic path to fragile, deeply coupled hierarchies."
    }
  ]
}
```
$md$, 12, $json$[{"id":"oop-collections-inheritance-q1","type":"mcq","correct":"b"},{"id":"oop-collections-inheritance-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0f12c51a-0720-5715-b0aa-0222af498111', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'Polymorphism', 'notes', 5, $md$Polymorphism means "the same interface, different behavior" — code written against a shared method name works correctly no matter which concrete type actually gets passed in, as long as that type implements the method.

## Same call, different behavior per type

```python
class Shape:
    def area(self):
        raise NotImplementedError("Subclasses must implement this method")

class Rectangle(Shape):
    def __init__(self, width, height):
        self.width = width
        self.height = height

    def area(self):
        return self.width * self.height

class Circle(Shape):
    def __init__(self, radius):
        self.radius = radius

    def area(self):
        return 3.14159 * self.radius * self.radius

def print_area(shape):
    print(f"The area is {shape.area()}")

rectangle = Rectangle(5, 10)
circle = Circle(7)

print_area(rectangle)  # The area is 50
print_area(circle)     # The area is 153.93899999999996
```

`print_area()` has no `if isinstance(shape, Rectangle)` branch anywhere. It calls `shape.area()` and trusts that whatever object it received knows how to answer that call correctly. Adding `Triangle(Shape)` tomorrow requires zero changes to `print_area()`.

## Duck typing: Python doesn't even require the shared base class

Because Python resolves `shape.area()` at call time by looking up `area` on the object's actual type — not by checking a declared type upfront — inheritance from `Shape` isn't strictly required for `print_area()` to work:

```python
class Square:  # doesn't inherit from Shape at all
    def __init__(self, side):
        self.side = side

    def area(self):
        return self.side ** 2

print_area(Square(4))  # The area is 16 — works, no shared base class
```

"If it walks like a duck and quacks like a duck, it's a duck": `print_area()` doesn't care what `Square` *is*, only that it *has* an `area()` method. This is polymorphism without a formal interface — a hallmark of how dynamically typed languages differ from statically typed ones, and a near-guaranteed interview follow-up once you mention polymorphism.

## Why it matters

Without polymorphism, adding a new shape means finding every function that branches on shape type and adding a new branch to each one — a maintenance burden that grows with every new type. With it, new types are additive: write the class, implement the shared method, done.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-polymorphism-q1",
      "type": "mcq",
      "prompt": "What does `print_area(shape)` need to know about `shape` in order to work correctly?",
      "options": [
        { "id": "a", "text": "Its exact class name, checked via isinstance" },
        { "id": "b", "text": "Only that it has an area() method that returns a number — nothing about its concrete type" },
        { "id": "c", "text": "That it inherits from a specific base class named Shape" },
        { "id": "d", "text": "Its memory address" }
      ],
      "correct": "b",
      "explanation": "Polymorphic code calls the shared method and trusts the object to implement it correctly — it doesn't need to know or check the object's concrete type."
    },
    {
      "id": "oop-collections-polymorphism-q2",
      "type": "mcq",
      "prompt": "Why does `print_area(Square(4))` work even though `Square` doesn't inherit from `Shape`?",
      "options": [
        { "id": "a", "text": "It doesn't — this would raise an AttributeError" },
        { "id": "b", "text": "Python's duck typing: print_area only needs shape.area() to exist and be callable, regardless of the object's class hierarchy" },
        { "id": "c", "text": "Square is automatically registered as a subclass of Shape" },
        { "id": "d", "text": "print_area() silently converts Square into a Rectangle first" }
      ],
      "correct": "b",
      "explanation": "Python looks up area on the object's actual type at call time — there's no compile-time interface check, so any object with a matching method works, shared base class or not."
    }
  ]
}
```
$md$, 12, $json$[{"id":"oop-collections-polymorphism-q1","type":"mcq","correct":"b"},{"id":"oop-collections-polymorphism-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0518f441-7052-525d-b58a-33edabd41fbf', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '3258c6b9-73b9-558d-979e-cb499df7bc1a', 'The Python Data Model (Magic / Dunder Methods)', 'notes', 6, $md$The Python data model is the set of special (`__dunder__`) methods that define how your objects interact with the language's own built-in operators and functions: `+`, `len()`, `print()`, `for ... in`, `with`, `==`, and more. Implementing the right dunder methods makes a custom class behave like a built-in type instead of a second-class citizen that needs its own bespoke API.

## Without the data model: everything needs its own method name

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def add(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def to_string(self):
        return f"Vector({self.x}, {self.y})"

v1 = Vector(1, 2)
v2 = Vector(3, 4)
v3 = v1.add(v2)
print(v3.to_string())  # Vector(4, 6)
```

This works, but `v1.add(v2)` and `v3.to_string()` are bespoke APIs — nobody who hasn't read this class's source knows to call `.add()` instead of `+`, or `.to_string()` instead of `print()`.

## With the data model: it behaves like a built-in

```python
class Vector:
    def __init__(self, x, y):
        self.x = x
        self.y = y

    def __add__(self, other):
        return Vector(self.x + other.x, self.y + other.y)

    def __eq__(self, other):
        return self.x == other.x and self.y == other.y

    def __repr__(self):
        return f"Vector({self.x}, {self.y})"

v1 = Vector(1, 2)
v2 = Vector(3, 4)

print(v1 + v2)          # Vector(4, 6) — __add__ backs the + operator
print(v1 == Vector(1, 2))  # True — __eq__ backs ==
print(v1)                # Vector(1, 2) — __repr__ backs print()/the REPL
```

`v1 + v2` now works because `+` on any object first looks for `__add__`. `print(v1)` works because `print()` calls `repr()` on objects without a friendlier `__str__`, and `repr()` calls `__repr__`. None of this is special-cased for `Vector` — it's the exact same protocol every built-in type (`int`, `str`, `list`) already implements.

## The dunders that come up most in interviews

- `__init__` — construction (not actually "the constructor" — `__new__` is, but `__init__` is what almost everyone means)
- `__repr__` / `__str__` — unambiguous debug representation vs. readable display representation
- `__len__` — backs `len(obj)`
- `__eq__` / `__hash__` — backs `==` and whether an object can be a dict key / set member (defining `__eq__` without `__hash__` makes instances unhashable by default)
- `__enter__` / `__exit__` — backs the `with` statement (context managers, covered later in this course)
- `__iter__` / `__next__` — backs `for x in obj` (iterators, covered later in this course)

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "oop-collections-data-model-q1",
      "type": "mcq",
      "prompt": "Why does `v1 + v2` work for a custom Vector class with no operator overloading library involved?",
      "options": [
        { "id": "a", "text": "Python guesses what + should do based on the attribute names" },
        { "id": "b", "text": "The + operator looks for a __add__ method on the left operand and calls it" },
        { "id": "c", "text": "+ only works on numbers; this would actually raise a TypeError" },
        { "id": "d", "text": "Vector must inherit from a special Addable base class" }
      ],
      "correct": "b",
      "explanation": "Every operator in Python is backed by a dunder method. + calls __add__ (falling back to __radd__ on the right operand if needed) — defining __add__ is how a class opts into the + operator."
    },
    {
      "id": "oop-collections-data-model-q2",
      "type": "mcq",
      "prompt": "What's a practical consequence of defining `__eq__` on a class without also defining `__hash__`?",
      "options": [
        { "id": "a", "text": "Nothing — hashing is unrelated to equality" },
        { "id": "b", "text": "Instances become unhashable by default, so they can't be used as dict keys or put in a set" },
        { "id": "c", "text": "Python automatically writes a correct __hash__ for you" },
        { "id": "d", "text": "== stops working entirely" }
      ],
      "correct": "b",
      "explanation": "Python's default __hash__ is based on object identity, which would be inconsistent with a custom __eq__ based on value. To prevent that inconsistency, defining __eq__ sets __hash__ to None unless you also define it explicitly."
    }
  ]
}
```
$md$, 15, $json$[{"id":"oop-collections-data-model-q1","type":"mcq","correct":"b"},{"id":"oop-collections-data-model-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Iterators, Generators & Testing
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Iterators, Generators & Testing', 3)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9ca8601e-3dd5-5468-a643-88bdc1e7a3af', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'Iterators', 'notes', 0, $md$Every `for x in obj:` loop in Python is powered by the **iterator protocol** — two dunder methods, `__iter__` and `__next__`. Understanding this protocol is what lets you explain *why* a `for` loop works on a list, a file, a dict, and a generator, all through the same syntax.

## The protocol: `__iter__` + `__next__`

- `__iter__(self)` returns an **iterator** — an object that knows how to produce the next value. For an object that's already an iterator, this is conventionally `return self`.
- `__next__(self)` returns the next value, or raises `StopIteration` when there's nothing left.

```python
class MyIterator:
    def __init__(self, start, end):
        self.current = start
        self.end = end

    def __iter__(self):
        return self  # an iterator returns itself here

    def __next__(self):
        if self.current >= self.end:
            raise StopIteration
        value = self.current
        self.current += 1
        return value

iterator = MyIterator(1, 5)
for num in iterator:
    print(num)  # 1, 2, 3, 4
```

`for num in iterator:` is doing this under the hood: call `iter(iterator)` once (returns `self`), then call `next(iterator)` repeatedly, catching `StopIteration` to know when to stop.

## Iterators are stateful and consumed once

```python
iterator = MyIterator(1, 5)
print(list(iterator))  # [1, 2, 3, 4]
print(list(iterator))  # [] — already exhausted; current is now stuck at 5
```

This is the gotcha that separates iterators from collections like `list`: a `list` can be looped over any number of times because each `for` loop calls `__iter__` and gets a *fresh* iterator over the same data. `MyIterator.__iter__` returns `self` — the *same* stateful object — so once its internal `current` reaches `end`, every future iteration attempt starts already exhausted.

## Iterable vs. iterator — a distinction interviewers probe

- **Iterable**: any object with `__iter__` (a `list`, `dict`, `str`, or a custom class like `MyIterator`) — something you *can* call `iter()` on.
- **Iterator**: the object `__iter__` returns — something with `__next__` that tracks position and can be *consumed*.

Every iterator is iterable (its `__iter__` returns itself), but not every iterable is an iterator — a `list` is iterable but is not itself an iterator (calling `next()` directly on a list raises `TypeError`; you must first call `iter(my_list)`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-iterators-q1",
      "type": "mcq",
      "prompt": "What must `__next__` do once there are no more values to produce?",
      "options": [
        { "id": "a", "text": "Return None" },
        { "id": "b", "text": "Raise StopIteration" },
        { "id": "c", "text": "Return an empty list" },
        { "id": "d", "text": "Silently loop forever" }
      ],
      "correct": "b",
      "explanation": "StopIteration is the signal the for loop (and iter()/next() machinery generally) listens for to know iteration is complete."
    },
    {
      "id": "iterators-testing-iterators-q2",
      "type": "mcq",
      "prompt": "Why does looping over the same `MyIterator` instance twice produce results the second time but not the first — i.e. why is the second loop empty?",
      "options": [
        { "id": "a", "text": "It isn't empty — this is a trick question" },
        { "id": "b", "text": "__iter__ returns self, so both loops share the same stateful `current` counter, which the first loop already advanced to `end`" },
        { "id": "c", "text": "Python automatically resets custom iterators between loops" },
        { "id": "d", "text": "MyIterator can only be looped over inside a with block" }
      ],
      "correct": "b",
      "explanation": "Because __iter__ returns self instead of a fresh object, both for loops operate on the exact same current/end state — the first loop exhausts it, so the second loop's first __next__ call immediately raises StopIteration."
    }
  ]
}
```
$md$, 15, $json$[{"id":"iterators-testing-iterators-q1","type":"mcq","correct":"b"},{"id":"iterators-testing-iterators-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6a496224-0762-5fc9-9479-7ba522e96442', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'Generators', 'notes', 1, $md$A generator is the easy way to build something that satisfies the iterator protocol from the previous lesson, without hand-writing `__iter__`/`__next__`/`StopIteration` yourself. Any function containing `yield` becomes a **generator function** — calling it doesn't run its body; it returns a generator object that runs the body lazily, one `yield` at a time.

## Calling a generator function doesn't execute it

```python
def my_generator():
    yield 1
    yield 2
    yield 3

gen = my_generator()   # nothing has printed yet — no code inside has run
print(next(gen))       # 1 — runs up to the first yield, pauses there
print(next(gen))       # 2 — resumes, runs to the second yield
print(next(gen))       # 3
print(next(gen))       # raises StopIteration — body has run to completion
```

This is the detail interviewers probe most: `my_generator()` returns immediately with a generator object — none of the function body has executed. Execution only happens as `next()` is called, and each call resumes exactly where the previous one left off (all local variables preserved), rather than starting the function over.

## `send()`: passing a value *into* a paused generator

`yield` isn't just an output — it can also be an expression that receives a value:

```python
def generator_with_send():
    value = yield "Start"       # pauses here, yielding "Start"
    yield f"Received: {value}"  # resumes here when send() is called

gen = generator_with_send()
print(next(gen))          # Start — runs to the first yield
print(gen.send("Data"))   # Received: Data — "Data" becomes `value`, runs to the next yield
```

`gen.send("Data")` does two things atomically: it resumes the paused generator with `"Data"` as the *result* of the `yield "Start"` expression, and it runs until the next `yield` (or `StopIteration`). The first `next(gen)` call is required before `send()` can pass a real value in — there's no paused `yield` expression to receive it until the generator has started.

## Why generators exist: laziness and memory

```python
def squares_list(n):
    return [i * i for i in range(n)]   # builds the entire list in memory up front

def squares_gen(n):
    for i in range(n):
        yield i * i                     # produces one value at a time, on demand

# squares_list(10_000_000) allocates ~10 million ints immediately.
# squares_gen(10_000_000) allocates nothing until you actually iterate it.
total = sum(squares_gen(10_000_000))
```

`squares_gen` never holds more than one value in memory at a time — this is why generators are the standard tool for streaming large datasets, reading huge files line by line, or building infinite sequences that would be impossible to materialize as a list.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-generators-q1",
      "type": "mcq",
      "prompt": "What happens when you call `gen = my_generator()` on a function containing `yield`?",
      "options": [
        { "id": "a", "text": "The entire function body runs immediately and gen holds the final return value" },
        { "id": "b", "text": "Nothing in the function body executes yet — gen is a generator object, and execution starts on the first next(gen) call" },
        { "id": "c", "text": "It raises a SyntaxError because generator functions can't be called directly" },
        { "id": "d", "text": "It runs until the first yield and then returns None" }
      ],
      "correct": "b",
      "explanation": "Calling a generator function only constructs the generator object. No code in the function body runs until next() is called on it."
    },
    {
      "id": "iterators-testing-generators-q2",
      "type": "mcq",
      "prompt": "Why is a generator preferred over building a full list for processing a very large dataset?",
      "options": [
        { "id": "a", "text": "Generators run faster per-element than list comprehensions in every case" },
        { "id": "b", "text": "Generators produce one value at a time on demand, so memory usage stays constant instead of scaling with dataset size" },
        { "id": "c", "text": "Lists cannot hold more than a few thousand elements" },
        { "id": "d", "text": "Generators automatically parallelize the work across CPU cores" }
      ],
      "correct": "b",
      "explanation": "A list comprehension materializes every element in memory before you can use any of them. A generator yields one value at a time, so memory usage stays flat regardless of how many items are eventually produced."
    }
  ]
}
```
$md$, 15, $json$[{"id":"iterators-testing-generators-q1","type":"mcq","correct":"b"},{"id":"iterators-testing-generators-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('027353fc-0de4-52c8-a442-b0fc1832463c', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', '`@staticmethod` and `@classmethod`', 'notes', 2, $md$A regular method automatically receives the instance as its first argument (`self`). `@staticmethod` and `@classmethod` change what — if anything — gets passed in automatically, and each exists for a different reason.

## `@classmethod`: receives the class, not the instance

```python
class BankAccount:
    interest_rate = 0.03  # class-level default, shared unless overridden per-instance

    def __init__(self, account_type, balance):
        self.account_type = account_type
        self.balance = balance

    @staticmethod
    def is_valid_transaction(amount):
        """No self, no cls — behaves like a plain function namespaced under the class."""
        return amount > 0

    @classmethod
    def create_savings_account(cls, initial_deposit):
        """Factory method: cls is the class itself (BankAccount, or a subclass)."""
        if not cls.is_valid_transaction(initial_deposit):
            raise ValueError("Initial deposit must be positive.")
        return cls("Savings", initial_deposit)  # cls(...) — works for subclasses too

    @classmethod
    def create_business_account(cls, initial_deposit):
        if not cls.is_valid_transaction(initial_deposit):
            raise ValueError("Initial deposit must be positive.")
        account = cls("Business", initial_deposit)
        account.interest_rate = 0.05  # business accounts get a higher rate
        return account

savings = BankAccount.create_savings_account(1000)
business = BankAccount.create_business_account(5000)

print(f"Savings: ${savings.balance}, rate {savings.interest_rate}")   # $1000, 0.03
print(f"Business: ${business.balance}, rate {business.interest_rate}") # $5000, 0.05
```

`create_savings_account` and `create_business_account` are **factory methods** — alternate, named constructors. This is the single most common real-world use of `@classmethod`: `BankAccount.create_savings_account(1000)` reads far more clearly at the call site than `BankAccount("Savings", 1000)`, where the string `"Savings"` gives no hint what it means without reading the constructor.

## `@staticmethod`: no automatic argument at all

`is_valid_transaction` doesn't need `self` (it doesn't touch instance state) or `cls` (it doesn't touch class state) — it's pure logic that happens to belong conceptually to `BankAccount`. Marking it `@staticmethod` means it can be called on the class directly (`BankAccount.is_valid_transaction(-50)`) or on an instance (`account.is_valid_transaction(100)`) with identical behavior, since nothing is auto-injected either way.

## Why `cls` (not the class name) inside a classmethod

`create_savings_account` calls `cls(...)`, not `BankAccount(...)`, specifically so that if a subclass `PremiumAccount(BankAccount)` calls `PremiumAccount.create_savings_account(1000)`, `cls` is `PremiumAccount` — the factory correctly returns a `PremiumAccount` instance, not a plain `BankAccount`. Hardcoding the class name would silently break for every subclass.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-staticmethod-classmethod-q1",
      "type": "mcq",
      "prompt": "What is automatically passed as the first argument to a method decorated with `@staticmethod`?",
      "options": [
        { "id": "a", "text": "self, the instance" },
        { "id": "b", "text": "cls, the class" },
        { "id": "c", "text": "Nothing — no argument is auto-injected" },
        { "id": "d", "text": "Both self and cls" }
      ],
      "correct": "c",
      "explanation": "@staticmethod strips the automatic first-argument injection entirely — it behaves like a plain function that happens to live in the class's namespace."
    },
    {
      "id": "iterators-testing-staticmethod-classmethod-q2",
      "type": "mcq",
      "prompt": "Why does `create_savings_account` call `cls(...)` instead of `BankAccount(...)`?",
      "options": [
        { "id": "a", "text": "cls(...) is just a stylistic preference with no functional difference" },
        { "id": "b", "text": "So that if a subclass inherits this classmethod, calling it on the subclass returns an instance of the subclass, not BankAccount" },
        { "id": "c", "text": "BankAccount(...) would raise a NameError inside the class body" },
        { "id": "d", "text": "cls(...) is required syntax for any method that returns an instance" }
      ],
      "correct": "b",
      "explanation": "cls is bound to whichever class the method was actually called on. Using cls(...) instead of hardcoding the class name keeps factory methods correct for subclasses."
    }
  ]
}
```
$md$, 12, $json$[{"id":"iterators-testing-staticmethod-classmethod-q1","type":"mcq","correct":"c"},{"id":"iterators-testing-staticmethod-classmethod-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a915b846-e56e-50e8-b9e9-11462996d503', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'Dependency Injection', 'notes', 3, $md$Dependency Injection (DI) means a class receives the objects it depends on from the outside — usually through its constructor — instead of creating them itself internally. It sounds like a heavyweight framework concept (and in Java/Spring, it often is one), but in Python it's frequently just "pass the dependency as an argument."

## Without DI: the dependency is hardcoded inside

```python
class PayPalService:
    def process_payment(self, amount):
        print(f"Processing payment of ${amount} through PayPal.")

class PaymentProcessor:
    def __init__(self):
        self.payment_service = PayPalService()  # created internally — hardcoded

    def pay(self, amount):
        self.payment_service.process_payment(amount)

processor = PaymentProcessor()
processor.pay(100)
```

`PaymentProcessor` is permanently welded to `PayPalService`. Want to support Stripe? You have to edit `PaymentProcessor.__init__`. Want to unit-test `pay()` without making a real network call? You can't — every `PaymentProcessor` always constructs a real `PayPalService`.

## With DI: the dependency is passed in

```python
class PayPalService:
    def process_payment(self, amount):
        print(f"Processing payment of ${amount} through PayPal.")

class PaymentProcessor:
    def __init__(self, payment_service):
        self.payment_service = payment_service  # supplied by the caller

    def pay(self, amount):
        self.payment_service.process_payment(amount)

payment_service = PayPalService()
processor = PaymentProcessor(payment_service)
processor.pay(100)
```

`PaymentProcessor` no longer knows or cares which payment provider it's using — it just calls `.process_payment()` on whatever it was handed (this is the polymorphism/duck-typing lesson applied in practice). Swapping in `StripeService()` requires zero changes to `PaymentProcessor` itself.

## Why this is the whole point of testability

```python
class FakePaymentService:
    def __init__(self):
        self.calls = []

    def process_payment(self, amount):
        self.calls.append(amount)  # no real network call — just records the call

fake = FakePaymentService()
test_processor = PaymentProcessor(fake)
test_processor.pay(100)

assert fake.calls == [100]  # verify behavior without touching PayPal's real API
```

This is exactly how unit tests avoid hitting real external services: inject a fake/mock object that implements the same interface, and assert on what was called. Without constructor injection, there'd be no way to substitute `PayPalService` for `FakePaymentService` — the real dependency is baked in.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-dependency-injection-q1",
      "type": "mcq",
      "prompt": "What is the key structural difference between the 'without DI' and 'with DI' versions of PaymentProcessor?",
      "options": [
        { "id": "a", "text": "The with-DI version doesn't have a pay() method" },
        { "id": "b", "text": "The with-DI version receives payment_service as a constructor argument instead of constructing PayPalService internally" },
        { "id": "c", "text": "The with-DI version uses async/await" },
        { "id": "d", "text": "There is no real difference; both behave identically in every context" }
      ],
      "correct": "b",
      "explanation": "Dependency injection moves object creation to the caller. PaymentProcessor stops constructing its own PayPalService and instead accepts any object with a compatible process_payment() method."
    },
    {
      "id": "iterators-testing-dependency-injection-q2",
      "type": "mcq",
      "prompt": "Why does constructor injection make PaymentProcessor easier to unit test?",
      "options": [
        { "id": "a", "text": "It doesn't — testing difficulty is unrelated to how dependencies are constructed" },
        { "id": "b", "text": "A test can pass in a fake/mock payment service instead of the real PayPalService, avoiding real network calls" },
        { "id": "c", "text": "Constructor injection automatically generates test cases" },
        { "id": "d", "text": "It removes the need for the pay() method to take an amount argument" }
      ],
      "correct": "b",
      "explanation": "Because the dependency is supplied externally, a test can substitute a fake object that records calls instead of performing real side effects, then assert on what was recorded."
    }
  ]
}
```
$md$, 15, $json$[{"id":"iterators-testing-dependency-injection-q1","type":"mcq","correct":"b"},{"id":"iterators-testing-dependency-injection-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('b29dfba0-d998-5454-948f-cdfaa34cc93d', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'Parameterized Testing', 'notes', 4, $md$Parameterized testing runs the *same* test logic against many different inputs, instead of copy-pasting a near-identical test function once per input. It's a testing-maturity signal interviewers look for because duplicated test functions are exactly as much of a maintenance liability as duplicated production code.

## The problem: one test function per input

Without parameterization, testing a function against six input cases means six separate test functions, all with the same body and a different literal value — any change to the assertion logic has to be copy-pasted into all six.

## `pytest.mark.parametrize`: one test body, many inputs

```text
import pytest

@pytest.mark.parametrize("user_id,expected_name", [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (8, "Gary"),
    (99, "Unknown"),
])
def test_get_user_details(user_id, expected_name):
    def fetch_user_details(user_id):
        users = {1: "Alice", 2: "Bob", 3: "Charlie", 8: "Gary"}
        return {"id": user_id, "name": users.get(user_id, "Unknown")}

    response = fetch_user_details(user_id)
    assert response["name"] == expected_name
```

`pytest` runs `test_get_user_details` once per tuple in the list, reporting each one as its own pass/fail — a failure on input `(3, "Charlie")` is reported distinctly from a failure on `(99, "Unknown")`, even though it's the same function body. (This needs `pytest` installed and run via the `pytest` CLI — it isn't something a plain `python file.py` invocation executes, since pytest discovers and drives `test_*` functions itself.)

## The same idea, without a test framework

The mechanism `pytest.mark.parametrize` provides is really just "loop over cases and assert each one" — worth seeing explicitly, since it's exactly what you'd reach for in a quick script or a language without a parametrize decorator:

```python
def fetch_user_details(user_id):
    users = {1: "Alice", 2: "Bob", 3: "Charlie", 8: "Gary"}
    return {"id": user_id, "name": users.get(user_id, "Unknown")}

test_cases = [
    (1, "Alice"),
    (2, "Bob"),
    (3, "Charlie"),
    (8, "Gary"),
    (99, "Unknown"),
]

failures = []
for user_id, expected_name in test_cases:
    actual = fetch_user_details(user_id)["name"]
    if actual != expected_name:
        failures.append((user_id, expected_name, actual))

if failures:
    print(f"{len(failures)} case(s) failed: {failures}")
else:
    print(f"All {len(test_cases)} cases passed.")
```

What `pytest.mark.parametrize` adds on top of this manual loop: each case is reported as an independent test result (so a failure in case 3 doesn't stop cases 4 and 5 from running and reporting), readable test names/IDs per case in the output, and integration with the rest of pytest's fixture and reporting machinery.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-parameterized-testing-q1",
      "type": "mcq",
      "prompt": "What problem does `@pytest.mark.parametrize` solve compared to writing one test function per input case?",
      "options": [
        { "id": "a", "text": "It makes tests run in a separate process for isolation" },
        { "id": "b", "text": "It lets one test body run against many inputs, each reported as an independent pass/fail, instead of duplicating the test function per case" },
        { "id": "c", "text": "It automatically generates random test inputs" },
        { "id": "d", "text": "It disables tests that are expected to fail" }
      ],
      "correct": "b",
      "explanation": "parametrize decouples the test logic (written once) from the input data (a list of cases), and pytest reports each case's result independently."
    },
    {
      "id": "iterators-testing-parameterized-testing-q2",
      "type": "mcq",
      "prompt": "Why can't the pytest-based test file be executed with a plain `python file.py` command?",
      "options": [
        { "id": "a", "text": "pytest syntax is not valid Python" },
        { "id": "b", "text": "pytest discovers and drives test_* functions itself via its own CLI/runner — a bare python invocation never calls them" },
        { "id": "c", "text": "parametrize requires an internet connection" },
        { "id": "d", "text": "Test functions can only run inside Docker containers" }
      ],
      "correct": "b",
      "explanation": "Running python file.py just defines the functions and decorators — nothing invokes test_get_user_details unless a test runner like pytest scans the file and calls it for each parametrized case."
    }
  ]
}
```
$md$, 12, $json$[{"id":"iterators-testing-parameterized-testing-q1","type":"mcq","correct":"b"},{"id":"iterators-testing-parameterized-testing-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('d1e7628a-a1a8-5795-90d4-c14ce1972a6b', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'afc6ff6d-37fb-5fc8-93df-95bef49ae58c', 'Fixtures (Testing Setup & Teardown)', 'notes', 5, $md$A fixture provides a piece of test setup (a database connection, a temp file, an authenticated client) to any test that asks for it by name, and cleans it up afterward — without every test having to repeat that setup/teardown code itself.

## `@pytest.fixture`: setup, `yield`, teardown

```text
import pytest
import sqlite3

@pytest.fixture
def temp_db():
    # Setup: runs before the test that uses this fixture
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES ('Alice')")
    yield conn
    # Teardown: runs after the test finishes, even if it failed
    conn.close()

def test_query_user(temp_db):
    cursor = temp_db.cursor()
    cursor.execute("SELECT name FROM users WHERE id=1")
    user = cursor.fetchone()
    assert user[0] == "Alice"
```

pytest sees that `test_query_user` takes a parameter named `temp_db`, matches it against the fixture of the same name, runs `temp_db()` up to its `yield`, passes the yielded value (`conn`) into the test as the `temp_db` argument, runs the test, and then resumes the fixture *after* the `yield` to run teardown — regardless of whether the test passed or raised. This needs pytest's collection/injection machinery to run; it isn't triggered by a plain `python file.py`.

## The same shape, without pytest: a context manager

The setup / `yield` / teardown structure of a fixture is exactly the same shape as a context manager's `__enter__` / `yield` / `__exit__` (covered later in this course) — worth seeing side by side, since it demonstrates the underlying pattern in code you can run directly:

```python
from contextlib import contextmanager
import sqlite3

@contextmanager
def temp_db():
    conn = sqlite3.connect(":memory:")
    conn.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    conn.execute("INSERT INTO users (name) VALUES ('Alice')")
    try:
        yield conn          # setup done, hand the resource to the caller
    finally:
        conn.close()         # teardown, guaranteed even if the caller raises

with temp_db() as conn:
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM users WHERE id=1")
    user = cursor.fetchone()
    assert user[0] == "Alice"
    print(f"Fetched user: {user[0]}")
```

`@pytest.fixture` is, structurally, a generator-based context manager wired into pytest's dependency-injection-by-parameter-name system: a test requests a fixture by naming a parameter, pytest runs setup, hands over the yielded value, runs the test, then runs teardown — the same setup/`yield`/teardown shape as `@contextmanager`, just triggered by pytest's test collection instead of a `with` block.

## Why fixtures matter beyond convenience

Repeating `sqlite3.connect(":memory:")` + table creation + seed data in every test function that needs a database means a schema change requires editing every test. A shared fixture means the schema and seed data live in exactly one place, and every test that needs a database just declares a `temp_db` parameter.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "iterators-testing-pytest-fixtures-q1",
      "type": "mcq",
      "prompt": "In a pytest fixture using `yield`, what happens to the code after the `yield` statement?",
      "options": [
        { "id": "a", "text": "It never runs" },
        { "id": "b", "text": "It runs as teardown, after the test that used the fixture finishes (pass or fail)" },
        { "id": "c", "text": "It runs before the yielded value is handed to the test" },
        { "id": "d", "text": "It only runs if the test raises an exception" }
      ],
      "correct": "b",
      "explanation": "Everything before yield is setup; the yielded value is injected into the test; everything after yield is teardown, run once the test completes regardless of outcome."
    },
    {
      "id": "iterators-testing-pytest-fixtures-q2",
      "type": "mcq",
      "prompt": "How does a test function access a fixture's value in pytest?",
      "options": [
        { "id": "a", "text": "By importing it explicitly with `import fixture`" },
        { "id": "b", "text": "By declaring a parameter with the same name as the fixture — pytest matches by name and injects the yielded value" },
        { "id": "c", "text": "By calling the fixture function directly inside the test body" },
        { "id": "d", "text": "Fixtures are global variables automatically available everywhere" }
      ],
      "correct": "b",
      "explanation": "pytest inspects each test function's parameter names, finds a fixture with a matching name, runs it, and passes the yielded value as that argument."
    }
  ]
}
```
$md$, 12, $json$[{"id":"iterators-testing-pytest-fixtures-q1","type":"mcq","correct":"b"},{"id":"iterators-testing-pytest-fixtures-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Serialization & Low-Level Data
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('9a0a66f7-732b-55cb-8e15-58d12d55865a', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Serialization & Low-Level Data', 4)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ce39a83b-ee0e-5789-b144-43eac9c9601b', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', 'Serialization & Deserialization', 'notes', 0, $md$Serialization turns a live Python object into a stream of bytes you can write to disk, send over a socket, or stash in a cache. Deserialization reverses it, rebuilding the object from those bytes. Anywhere state needs to outlive the process that created it — saved ML models, cached query results, session data — serialization is the mechanism underneath.

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
$md$, 15, $json$[{"id":"serialization-data-serialization-q1","type":"mcq","correct":"a"},{"id":"serialization-data-serialization-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('09f3cdff-5f4f-5301-abe9-8a106c73a4f0', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', '`__getstate__` and `__setstate__`', 'notes', 1, $md$Not everything can be pickled. Open file handles, sockets, database connections, and thread locks all wrap operating-system resources that don't make sense as bytes — there is no way to serialize "an open file descriptor" and later reopen the exact same one. Pickling an object that holds one of these directly raises `TypeError: cannot pickle '_io.TextIOWrapper' object`.

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
$md$, 12, $json$[{"id":"serialization-data-getstate-setstate-q1","type":"mcq","correct":"b"},{"id":"serialization-data-getstate-setstate-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1643be0a-43e1-5005-85e6-02e8e24b5337', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', '`heapq`', 'notes', 2, $md$`heapq` gives Python a priority queue built on an ordinary list, kept in **binary heap** order: the smallest element is always at index `0`, and `heappush`/`heappop` maintain that invariant in `O(log n)` instead of the `O(n)` a naive "sort the list every time" approach would cost.

## Why not just sort a list?

A plain list can act as a priority queue if you re-sort it after every insert, but that's `O(n log n)` per insert. A heap only restores the invariant along one path from the leaf to the root (or root to leaf), so both `heappush` and `heappop` are `O(log n)` — the difference matters the moment a scheduler is handling thousands of tasks.

## Building a task scheduler

```python
import heapq

class TaskScheduler:
    def __init__(self):
        self.task_queue = []  # a min-heap of (priority, task_name) tuples

    def add_task(self, priority, task_name):
        # Lower priority number = executed sooner
        heapq.heappush(self.task_queue, (priority, task_name))

    def execute_task(self):
        if not self.task_queue:
            print("No tasks to execute.")
            return
        priority, task_name = heapq.heappop(self.task_queue)
        print(f"Executing '{task_name}' (priority {priority})")

    def peek_next_task(self):
        if not self.task_queue:
            print("No tasks in the queue.")
            return
        priority, task_name = self.task_queue[0]
        print(f"Next up: '{task_name}' (priority {priority})")


scheduler = TaskScheduler()
scheduler.add_task(3, "Write report")
scheduler.add_task(1, "Fix critical bug")
scheduler.add_task(2, "Attend team meeting")

scheduler.peek_next_task()   # Fix critical bug is priority 1 — heap keeps it at the front
scheduler.execute_task()
scheduler.execute_task()
scheduler.execute_task()
scheduler.execute_task()     # empty queue
```

`heapq` compares the tuples element by element, so `(1, "Fix critical bug")` sorts before `(2, "Attend team meeting")` purely on the first element — ties on priority fall back to comparing the task name, which is usually fine but worth knowing if two priorities can collide and the names aren't comparable (mixing types there raises `TypeError`).

## Where this shows up

Beyond task schedulers: Dijkstra's shortest-path algorithm pops the "closest known node" every iteration, event simulators pop the "next event in time," and `heapq.nlargest`/`heapq.nsmallest` give you the top-k of a collection without fully sorting it — all the same underlying idea of "give me the extreme element next, cheaply, repeatedly."

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-heapq-q1",
      "type": "mcq",
      "prompt": "Why is heapq.heappush faster than re-sorting a list after every insert?",
      "options": [
        { "id": "a", "text": "It only restores the heap invariant along one path, costing O(log n) instead of O(n log n)" },
        { "id": "b", "text": "heapq stores data in a hash table instead of a list" },
        { "id": "c", "text": "It skips maintaining any order at all" },
        { "id": "d", "text": "Python lists are automatically kept sorted" }
      ],
      "correct": "a",
      "explanation": "A heap only needs to bubble the new element up (or down) one path to the root, an O(log n) operation, versus O(n log n) to fully re-sort the list on every insert."
    },
    {
      "id": "serialization-data-heapq-q2",
      "type": "mcq",
      "prompt": "In TaskScheduler, why does heapq.heappush use (priority, task_name) tuples with priority first?",
      "options": [
        { "id": "a", "text": "Tuples must always have exactly two elements" },
        { "id": "b", "text": "heapq compares tuples element-by-element, so ordering by priority first makes the heap sort by priority" },
        { "id": "c", "text": "task_name needs to come first for heapq to work at all" },
        { "id": "d", "text": "It's arbitrary and has no effect on ordering" }
      ],
      "correct": "b",
      "explanation": "heapq.heappush/heappop maintain min-heap order using Python's default tuple comparison, which compares the first element first — putting priority first means the heap orders by priority."
    }
  ]
}
```
$md$, 12, $json$[{"id":"serialization-data-heapq-q1","type":"mcq","correct":"a"},{"id":"serialization-data-heapq-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('053dda60-8533-5328-894c-fe7282671bef', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', 'Higher-Order Functions', 'notes', 3, $md$A higher-order function either takes a function as an argument, returns a function, or both. Python treats functions as first-class values — they can be stored in variables, passed around, and stored in data structures exactly like any other object — and higher-order functions are what you build once that's true.

## Taking functions as arguments

```python
def validate(data, *validators):
    for validator in validators:
        if not validator(data):
            return False
    return True

is_non_empty = lambda x: bool(x)
is_alpha = lambda x: x.isalpha()

print(validate("Python", is_non_empty, is_alpha))   # True
print(validate("", is_non_empty, is_alpha))          # False — fails is_non_empty
print(validate("Py3", is_non_empty, is_alpha))       # False — fails is_alpha
```

`validate` doesn't know or care what "valid" means — that logic lives entirely in whichever validator functions get passed in. Adding a new rule (`is_lowercase`, `max_length(20)`) never touches `validate` itself; this is the same shape as Django's form validators or FastAPI's dependency checks.

## Returning functions: closures as configuration

The other direction — a function that *returns* a function — lets you bake in configuration once and reuse the specialized result:

```python
def make_multiplier(factor):
    def multiplier(x):
        return x * factor
    return multiplier

double = make_multiplier(2)
triple = make_multiplier(3)

print(double(5))   # 10
print(triple(5))   # 15
```

`double` and `triple` are both `multiplier` functions, but each closes over its own `factor` — this is a closure, and it's the mechanism behind decorators, middleware chains, and callback factories.

## Why this matters at the senior level

Higher-order functions are how you avoid rewriting the same control flow (loop-and-check, loop-and-transform) for every new rule. Instead, the control flow is written once and parameterized by behavior — the same principle behind `sorted(items, key=...)`, `map`/`filter`, and every decorator you've ever used.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-higher-order-functions-q1",
      "type": "mcq",
      "prompt": "What makes validate() in the example a higher-order function?",
      "options": [
        { "id": "a", "text": "It has more than one parameter" },
        { "id": "b", "text": "It accepts other functions (validators) as arguments and calls them" },
        { "id": "c", "text": "It uses a for loop" },
        { "id": "d", "text": "It returns a boolean" }
      ],
      "correct": "b",
      "explanation": "A higher-order function takes a function as input or returns one; validate() takes validator functions as *validators and invokes each one, making it higher-order."
    },
    {
      "id": "serialization-data-higher-order-functions-q2",
      "type": "mcq",
      "prompt": "In make_multiplier, why do double and triple behave differently even though they share the same multiplier function body?",
      "options": [
        { "id": "a", "text": "Each call to make_multiplier creates a closure that remembers its own factor value" },
        { "id": "b", "text": "Python randomly assigns different factor values" },
        { "id": "c", "text": "double and triple are actually the same function object" },
        { "id": "d", "text": "multiplier reads factor from a global variable that changes each time" }
      ],
      "correct": "a",
      "explanation": "Each call to make_multiplier(factor) creates a new closure over that specific factor value, so the returned multiplier function 'remembers' the factor it was created with — 2 for double, 3 for triple."
    }
  ]
}
```
$md$, 12, $json$[{"id":"serialization-data-higher-order-functions-q1","type":"mcq","correct":"b"},{"id":"serialization-data-higher-order-functions-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('32a73115-fde6-522e-9194-4cfad0123eea', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', '`filter`', 'notes', 4, $md$`filter` is a built-in higher-order function: give it a predicate (a function returning `True`/`False`) and an iterable, and it returns an iterator yielding only the items the predicate accepted.

## Replacing a manual loop

```python
numbers = [1, 2, 3, 4, 5, 6]

# The loop version
evens = []
for n in numbers:
    if n % 2 == 0:
        evens.append(n)
print(evens)  # [2, 4, 6]

# The filter version — same result, one line
evens = list(filter(lambda n: n % 2 == 0, numbers))
print(evens)  # [2, 4, 6]
```

`filter` doesn't build a list itself — it returns a lazy iterator, so `list(...)` (or a `for` loop, or `next()`) is what actually pulls values through it. That laziness matters on large or infinite sequences: `filter` only evaluates the predicate on an item when something asks for the next result, instead of scanning the whole input up front.

## `filter(None, iterable)`: dropping falsy values

Passing `None` instead of a function tells `filter` to use each item's own truthiness as the predicate — a quick way to drop `None`/`0`/`""`/empty containers from a list:

```python
raw = [0, "hello", "", None, 42, [], "world"]
cleaned = list(filter(None, raw))
print(cleaned)  # ['hello', 42, 'world']
```

## `filter` vs. a list comprehension

Both work; the choice is style. `[x for x in items if predicate(x)]` reads naturally when there's also a transformation happening (`[x * 2 for x in items if predicate(x)]`), while `filter(predicate, items)` reads cleanly when there's *only* filtering and the predicate already exists as a named function — `filter(is_valid, records)` is more self-documenting than `[r for r in records if is_valid(r)]`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-filter-q1",
      "type": "mcq",
      "prompt": "What does filter(lambda n: n % 2 == 0, numbers) return, before wrapping it in list()?",
      "options": [
        { "id": "a", "text": "A list of even numbers" },
        { "id": "b", "text": "A lazy iterator that yields even numbers only when consumed" },
        { "id": "c", "text": "A tuple of even numbers" },
        { "id": "d", "text": "A boolean indicating whether any even numbers exist" }
      ],
      "correct": "b",
      "explanation": "filter() returns a lazy filter object (an iterator) — it doesn't evaluate the predicate on every item until something iterates over it, such as list() or a for loop."
    },
    {
      "id": "serialization-data-filter-q2",
      "type": "mcq",
      "prompt": "What does filter(None, [0, \"hello\", \"\", None, 42]) return, as a list?",
      "options": [
        { "id": "a", "text": "[0, \"hello\", \"\", None, 42] — unchanged" },
        { "id": "b", "text": "[\"hello\", 42] — only the truthy values" },
        { "id": "c", "text": "[] — an empty list, since None isn't a valid predicate" },
        { "id": "d", "text": "A TypeError is raised" }
      ],
      "correct": "b",
      "explanation": "Passing None as the predicate tells filter to use each item's own truthiness — falsy values like 0, empty string, and None are dropped, leaving only 'hello' and 42."
    }
  ]
}
```
$md$, 10, $json$[{"id":"serialization-data-filter-q1","type":"mcq","correct":"b"},{"id":"serialization-data-filter-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cc682f4a-b1cf-52b9-9e56-2ff6ff2d39a0', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', 'Advanced List Comprehensions', 'notes', 5, $md$A basic list comprehension — `[expr for x in iterable]` — is familiar to every Python developer. Senior-level fluency is knowing the extra clauses comprehensions support, and knowing when a comprehension stops being readable and a plain loop wins.

## Nested loops inside a comprehension

Multiple `for` clauses in one comprehension flatten nested structures, reading left to right exactly like nested `for` loops would:

```python
matrix = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
flattened = [num for row in matrix for num in row]
print(flattened)  # [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

This is equivalent to:

```python
flattened = []
for row in matrix:
    for num in row:
        flattened.append(num)
```

## Conditional expressions vs. filtering clauses

These look similar but do different things. An `if/else` *before* the `for` is a conditional expression — it runs for every item and picks between two output values:

```python
numbers = [1, 2, 3, 4, 5]
labels = ["even" if n % 2 == 0 else "odd" for n in numbers]
print(labels)  # ['odd', 'even', 'odd', 'even', 'odd']
```

An `if` *after* the `for` (no `else`) is a filter — it decides whether the item appears in the output at all:

```python
numbers = [1, 2, 3, 4, 5, 6]
evens_only = [n for n in numbers if n % 2 == 0]
print(evens_only)  # [2, 4, 6]
```

The two combine: `[n for n in numbers if n % 2 == 0 if n > 2]` chains filters, and `["big" if n > 3 else "small" for n in numbers if n % 2 == 0]` filters first, then labels what survives.

## Calling functions inline

Any expression is valid as the output, including a function call:

```python
def celsius_to_fahrenheit(c):
    return (c * 9 / 5) + 32

temperatures_c = [0, 20, 30, 40]
temperatures_f = [celsius_to_fahrenheit(t) for t in temperatures_c]
print(temperatures_f)  # [32.0, 68.0, 86.0, 104.0]
```

## Knowing when to stop

A comprehension is the right call when it stays a single, readable transformation. Once it needs more than one `if`/`for` clause stacked together, or the body has real side effects, a plain loop is more debuggable — you can't put a breakpoint inside a comprehension expression as easily as inside a loop body, and a comprehension that needs a comment to explain what it's doing has already lost the readability it was supposed to buy.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-advanced-list-comprehensions-q1",
      "type": "mcq",
      "prompt": "What's the difference between [\"even\" if n % 2 == 0 else \"odd\" for n in numbers] and [n for n in numbers if n % 2 == 0]?",
      "options": [
        { "id": "a", "text": "They produce identical output" },
        { "id": "b", "text": "The first labels every item (conditional expression); the second filters out odd items entirely (filter clause)" },
        { "id": "c", "text": "The first is invalid syntax" },
        { "id": "d", "text": "The second labels every item; the first filters" }
      ],
      "correct": "b",
      "explanation": "An if/else before the for is a conditional expression that runs on every item and picks an output value; an if after the for with no else is a filter that decides whether the item is included at all."
    },
    {
      "id": "serialization-data-advanced-list-comprehensions-q2",
      "type": "mcq",
      "prompt": "When should a senior engineer prefer a plain for loop over a list comprehension?",
      "options": [
        { "id": "a", "text": "Never — comprehensions are always strictly better" },
        { "id": "b", "text": "When the comprehension would need multiple stacked if/for clauses or real side effects, hurting readability and debuggability" },
        { "id": "c", "text": "Only when the list has more than 100 items" },
        { "id": "d", "text": "Comprehensions can't be used with functions, so any function call requires a loop" }
      ],
      "correct": "b",
      "explanation": "Comprehensions are a readability tool. Once one needs multiple conditions/loops stacked together or has side effects, a plain loop is easier to read, debug, and set breakpoints in."
    }
  ]
}
```
$md$, 12, $json$[{"id":"serialization-data-advanced-list-comprehensions-q1","type":"mcq","correct":"b"},{"id":"serialization-data-advanced-list-comprehensions-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('87a4c4d0-9798-584d-a931-c0159146e404', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', '`bytes`', 'notes', 6, $md$A Python `str` is a sequence of Unicode characters — text, meant for humans to read. A `bytes` object is a sequence of raw integers in the range 0–255 — the actual binary data a file, a network socket, or an image format works with. Confusing the two (or forgetting to convert between them) is one of the most common sources of `UnicodeDecodeError`/`TypeError` bugs when working with files and network I/O.

## Writing and reading binary data

```python
# Write binary data to a file
with open("example.bin", "wb") as f:   # "wb" = write bytes
    f.write(b"Binary data")

# Read it back
with open("example.bin", "rb") as f:   # "rb" = read bytes
    data = f.read()
    print(data)        # b'Binary data'
    print(type(data))  # <class 'bytes'>
```

The `b"..."` prefix creates a `bytes` literal. Opening a file in `"wb"`/`"rb"` mode (instead of `"w"`/`"r"`) tells Python to hand back raw bytes instead of trying to decode them as text — mixing modes (writing bytes to a text-mode file, or vice versa) raises a `TypeError` immediately.

## Converting between `str` and `bytes`

Text becomes bytes via an explicit **encoding**, and bytes become text via the matching **decoding**:

```python
text = "Hello, world"
encoded = text.encode("utf-8")     # b'Hello, world'
decoded = encoded.decode("utf-8")  # 'Hello, world'

print(encoded, type(encoded))
print(decoded, type(decoded))
```

If the bytes don't actually represent valid text in the encoding you decode with, `.decode()` raises `UnicodeDecodeError` — this is why "just decode it" is unsafe without knowing (or being told, e.g. via a `Content-Type` header) which encoding produced the bytes in the first place.

## `bytearray`: the mutable sibling

`bytes` is immutable, like `str`. When binary data needs to be built up or modified in place — assembling a network packet piece by piece — `bytearray` is the mutable equivalent:

```python
buf = bytearray(b"Hello")
buf[0] = ord("J")   # mutate a single byte in place
buf.extend(b", world")
print(bytes(buf))   # b'Jello, world'
```

## Why this matters

`bytes` shows up anywhere Python talks to something that isn't Python: reading an image or audio file, parsing a binary network protocol, computing a hash (`hashlib` operates on bytes, not str), or streaming a large file without loading it fully as decoded text. Treating binary data as text — or text as binary — is a bug waiting for the first non-ASCII input.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-bytes-q1",
      "type": "mcq",
      "prompt": "What's the fundamental difference between str and bytes in Python?",
      "options": [
        { "id": "a", "text": "str is a sequence of Unicode characters for text; bytes is a sequence of raw 0-255 integers for binary data" },
        { "id": "b", "text": "bytes is just a faster version of str with no functional difference" },
        { "id": "c", "text": "str can only hold ASCII characters, bytes holds everything else" },
        { "id": "d", "text": "They are interchangeable and Python converts automatically" }
      ],
      "correct": "a",
      "explanation": "str represents human-readable Unicode text; bytes represents raw binary data as integers 0-255. Converting between them always requires an explicit encode()/decode() step and an encoding name."
    },
    {
      "id": "serialization-data-bytes-q2",
      "type": "mcq",
      "prompt": "What happens if you call .decode('utf-8') on bytes that don't represent valid UTF-8 text?",
      "options": [
        { "id": "a", "text": "Python silently returns an empty string" },
        { "id": "b", "text": "It raises a UnicodeDecodeError" },
        { "id": "c", "text": "It automatically detects and uses the correct encoding instead" },
        { "id": "d", "text": "It returns the raw bytes unchanged" }
      ],
      "correct": "b",
      "explanation": "decode() assumes the bytes were produced with the specified encoding; if the byte sequence isn't valid under that encoding, Python raises UnicodeDecodeError rather than guessing."
    }
  ]
}
```
$md$, 12, $json$[{"id":"serialization-data-bytes-q1","type":"mcq","correct":"a"},{"id":"serialization-data-bytes-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('ed523ce6-bc16-5a2b-96c7-f9cb8690a0df', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', 'Bytecode & the `dis` Module', 'notes', 7, $md$Python source code isn't executed directly — it's first compiled into **bytecode**, a low-level instruction set for the CPython virtual machine, then that bytecode is what actually runs. You don't need to read bytecode day to day, but knowing it exists (and how to look at it) explains a surprising amount of Python's runtime behavior, and it's a question that separates "knows Python syntax" from "understands how Python actually executes."

## Disassembling a function

The `dis` module turns a function's compiled bytecode into human-readable instructions:

```python
import dis

def count_to_ten():
    total = 0
    for i in range(10):
        total += i
    return total

dis.dis(count_to_ten)
```

Running this prints a table of opcodes — things like `LOAD_FAST`, `LOAD_GLOBAL`, `CALL`, `STORE_FAST`, `POP_JUMP_IF_FALSE` — each corresponding to one step the interpreter takes: loading a local variable onto the stack, calling a function, jumping to loop back, and so on. `range(10)` compiles to a `LOAD_GLOBAL`+`CALL`, and the `for` loop compiles to a `GET_ITER`/`FOR_ITER` pair with a jump back to the top on each iteration.

## Why senior engineers care

A few places this pays off:

- **Explaining "why is A faster than B"** — two pieces of code that look equally simple can compile to a different number of bytecode instructions. `dis.dis` is the tool that turns "I have a hunch" into "here's the extra `LOAD_ATTR` this version does that the other doesn't."
- **Understanding CPython internals questions** — "what does the GIL actually protect?" and "why is `x += 1` not atomic?" both become concrete once you can see that even a simple augmented assignment is multiple separate bytecode instructions (`LOAD_FAST`, `BINARY_ADD`, `STORE_FAST`), any of which the interpreter can be preempted between.
- **Spotting accidental global lookups** — a variable dis shows as `LOAD_GLOBAL` inside a hot loop (instead of `LOAD_FAST`) is a real, measurable slowdown, because global lookups go through a dict rather than a fixed local-variable slot.

## What it isn't

`dis` is a diagnostic tool, not something used in day-to-day application code, and bytecode is a CPython implementation detail — it isn't part of the language specification, changes between Python versions, and other implementations (PyPy, for instance) don't use the same instruction set at all. Knowing it exists, and being able to reach for it when a performance question needs a concrete answer, is the actual skill being tested.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-bytecode-dis-q1",
      "type": "mcq",
      "prompt": "What does dis.dis(some_function) show you?",
      "options": [
        { "id": "a", "text": "The function's docstring and type hints" },
        { "id": "b", "text": "The low-level bytecode instructions the CPython VM executes for that function" },
        { "id": "c", "text": "A performance benchmark of the function" },
        { "id": "d", "text": "The machine code generated for the CPU" }
      ],
      "correct": "b",
      "explanation": "dis.dis disassembles a function's compiled bytecode into readable opcodes (LOAD_FAST, CALL, etc.) — the actual instruction set the CPython interpreter executes, one level below Python source."
    },
    {
      "id": "serialization-data-bytecode-dis-q2",
      "type": "mcq",
      "prompt": "Why does seeing dis reveals that even x += 1 compiles to multiple separate bytecode instructions matter for understanding the GIL?",
      "options": [
        { "id": "a", "text": "It doesn't relate to the GIL at all" },
        { "id": "b", "text": "It shows the interpreter can be preempted between those instructions, which is why simple-looking operations like x += 1 aren't atomic across threads" },
        { "id": "c", "text": "It proves the GIL makes all operations atomic automatically" },
        { "id": "d", "text": "It means bytecode instructions always run in parallel" }
      ],
      "correct": "b",
      "explanation": "Since x += 1 is really LOAD_FAST, BINARY_ADD, STORE_FAST as separate steps, a thread switch can happen between any of them, which is exactly why augmented assignment isn't thread-safe without a lock."
    }
  ]
}
```
$md$, 15, $json$[{"id":"serialization-data-bytecode-dis-q1","type":"mcq","correct":"b"},{"id":"serialization-data-bytecode-dis-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('2c324319-4cc3-51b7-b0f6-7cf8dbcd914f', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '9a0a66f7-732b-55cb-8e15-58d12d55865a', '`memoryview`', 'notes', 8, $md$Slicing a `bytes` or `bytearray` object copies the sliced data into a brand-new object. For a million-byte buffer, slicing out even a small chunk means allocating and copying that chunk — wasted work if all you needed was to *look at* part of the buffer. `memoryview` fixes this by exposing the same underlying memory through a view, with no copy at all.

## Copy vs. view

```python
import sys

data = bytearray(b"A" * 10**6)  # 1,000,000 bytes
mv = memoryview(data)

# Slicing a memoryview creates another view — no copy
mv_slice = mv[100:100000]

# Slicing the bytearray directly copies ~99,900 bytes into a new object
bytes_slice = data[100:100000]

print(f"memoryview slice: {sys.getsizeof(mv_slice):,} bytes")
print(f"bytearray slice:  {sys.getsizeof(bytes_slice):,} bytes")
```

`mv_slice` reports a small, roughly constant size — it's just a window (a pointer, an offset, and a length) into `data`'s existing memory. `bytes_slice` reports a size proportional to the ~99,900 bytes it actually copied. The bigger the buffer and the more slicing you do, the more this gap matters.

## Views can write back to the original

Because a `memoryview` shares memory with its source (when the source is mutable, like `bytearray`), writing through the view changes the original:

```python
buf = bytearray(b"Hello, World!")
mv = memoryview(buf)

mv[0:5] = b"HELLO"   # writes directly into buf's memory, no copy
print(buf)           # bytearray(b'HELLO, World!')
```

This cuts both ways — it's the whole point when you want in-place mutation of a large buffer, but it means a `memoryview` keeps its source object alive and mutable-through-the-view for as long as the view exists, which is worth remembering before handing a view out to code you don't control.

## Where this matters in practice

Anywhere large binary payloads move through a program without needing full copies at every step: reading network buffers, processing large files in chunks, or feeding data into C extensions (NumPy, `struct`, `array`) that understand the buffer protocol directly. A web server parsing a large multipart upload, or a protocol parser slicing a byte stream into fields, is exactly the kind of hot path where "avoid the copy" turns into a measurable memory and latency win.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "serialization-data-memoryview-q1",
      "type": "mcq",
      "prompt": "Why does memoryview slicing use far less memory than slicing a bytearray directly?",
      "options": [
        { "id": "a", "text": "memoryview compresses the data automatically" },
        { "id": "b", "text": "A memoryview slice is a view (pointer + offset + length) into the existing memory, not a copy of the bytes" },
        { "id": "c", "text": "memoryview only supports small buffers" },
        { "id": "d", "text": "bytearray slicing is actually a bug that will be fixed" }
      ],
      "correct": "b",
      "explanation": "Slicing a memoryview creates another lightweight view referencing the same underlying memory; slicing a bytearray directly allocates a new object and copies the sliced bytes into it."
    },
    {
      "id": "serialization-data-memoryview-q2",
      "type": "mcq",
      "prompt": "In `buf = bytearray(...); mv = memoryview(buf); mv[0:5] = b\"HELLO\"`, what happens to buf?",
      "options": [
        { "id": "a", "text": "buf is unchanged — memoryview is always read-only" },
        { "id": "b", "text": "buf's first 5 bytes are modified in place, since mv shares memory with buf" },
        { "id": "c", "text": "A TypeError is raised because memoryview can't be assigned to" },
        { "id": "d", "text": "A new bytearray is created, leaving buf untouched" }
      ],
      "correct": "b",
      "explanation": "Because memoryview shares memory with its mutable source, writing through the view mutates buf directly — no copy is made in either direction."
    }
  ]
}
```
$md$, 12, $json$[{"id":"serialization-data-memoryview-q1","type":"mcq","correct":"b"},{"id":"serialization-data-memoryview-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Metaclasses & Context Managers
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('7de46a58-36de-5545-943b-2aa366816a0f', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Metaclasses & Context Managers', 5)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('057c09cb-7260-58b9-802e-4ea6c35c72cd', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '7de46a58-36de-5545-943b-2aa366816a0f', 'Metaclasses', 'notes', 0, $md$Every class you write in Python is itself an object — and like every object, it has a type. The type of a class is its **metaclass**. By default that metaclass is the built-in `type`, which means every `class Dog: ...` statement you've ever written was secretly a call to `type(...)`.

## `class` is sugar for calling `type`

```python
class Dog:
    pass

# The class statement above is equivalent to calling type() directly:
# type(name, bases, namespace) -> a new class
Dog2 = type("Dog2", (), {})

print(type(Dog))    # <class 'type'>
print(type(Dog2))   # <class 'type'>
print(Dog2().__class__.__name__)  # Dog2
```

`type` takes three arguments: the class's name, a tuple of base classes, and a dict of the class body's attributes and methods. The `class` keyword is just readable syntax for building that same call.

## Writing your own metaclass

A **metaclass** is a class that inherits from `type` and overrides `__new__` (or `__init__`) to hook into class *creation itself* — not instance creation. This lets you inspect, validate, or rewrite a class's attributes the moment the class is defined, before anyone ever instantiates it.

```python
class UpperAttrMeta(type):
    def __new__(mcs, name, bases, namespace):
        # Rewrite every non-dunder attribute name to uppercase
        uppercase_namespace = {
            (key.upper() if not key.startswith("__") else key): value
            for key, value in namespace.items()
        }
        return super().__new__(mcs, name, bases, uppercase_namespace)


class Config(metaclass=UpperAttrMeta):
    timeout = 30
    retries = 3


print(Config.TIMEOUT)  # 30
print(Config.RETRIES)  # 3
print(hasattr(Config, "timeout"))  # False — it was rewritten at class-creation time
```

`UpperAttrMeta.__new__` runs once, when the `Config` class body finishes executing — not once per instance. Every `Config()` you create afterward already has uppercase attributes; the metaclass did its work at class-definition time.

## When to actually reach for one

Metaclasses are the most powerful hook Python gives you into the language itself, and that power is exactly why the common advice is "metaclasses are solutions in search of a problem" for application code. They're the right tool when you need to enforce a rule across *every subclass* automatically — registering every subclass in a registry, validating that required class attributes are present, or generating boilerplate methods — the kind of thing frameworks do (see the next lesson for how Django's ORM uses this). For everyday code, a class decorator, `__init_subclass__`, or a plain base class usually solves the same problem with far less indirection.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-metaclasses-q1",
      "type": "mcq",
      "prompt": "What is the default metaclass of every Python class unless you specify otherwise?",
      "options": [
        { "id": "a", "text": "object" },
        { "id": "b", "text": "type" },
        { "id": "c", "text": "class" },
        { "id": "d", "text": "meta" }
      ],
      "correct": "b",
      "explanation": "Every class's type is `type` by default — the `class` statement is syntactic sugar for calling `type(name, bases, namespace)`."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q2",
      "type": "mcq",
      "prompt": "When does a metaclass's __new__ method run?",
      "options": [
        { "id": "a", "text": "Every time an instance of the class is created" },
        { "id": "b", "text": "Once, when the class itself is defined" },
        { "id": "c", "text": "Only when the class is subclassed" },
        { "id": "d", "text": "Every time an attribute on the class is accessed" }
      ],
      "correct": "b",
      "explanation": "A metaclass's __new__/__init__ hook into class creation, not instance creation — they run once when the `class` statement executes, not per-instance."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-q3",
      "type": "mcq",
      "prompt": "What's the generally recommended alternative to a custom metaclass for everyday application code?",
      "options": [
        { "id": "a", "text": "There is no alternative — metaclasses are always required for class customization" },
        { "id": "b", "text": "A class decorator, __init_subclass__, or a plain base class, which solve most problems with less indirection" },
        { "id": "c", "text": "Rewriting the class as a set of module-level functions" },
        { "id": "d", "text": "Using multiple inheritance instead" }
      ],
      "correct": "b",
      "explanation": "Metaclasses are powerful but heavy machinery; simpler hooks like __init_subclass__ or class decorators cover most real-world needs with far less indirection."
    }
  ]
}
```
$md$, 18, $json$[{"id":"metaclasses-context-managers-metaclasses-q1","type":"mcq","correct":"b"},{"id":"metaclasses-context-managers-metaclasses-q2","type":"mcq","correct":"b"},{"id":"metaclasses-context-managers-metaclasses-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6f261671-9a69-540a-a3dc-2cb5c6bd1edb', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '7de46a58-36de-5545-943b-2aa366816a0f', 'Metaclasses in Frameworks (Django Example)', 'notes', 1, $md$Django models look like magic the first time you see them:

```python
class Article(models.Model):
    title = models.CharField(max_length=200)
    views = models.IntegerField()
```

`title` and `views` are just class attributes assigned instances of `CharField`/`IntegerField` — yet Django somehow turns them into database columns, gives the class a `.objects` manager, and lets you call `Article.objects.filter(views__gt=100)`. None of that is written anywhere in the `Article` class body. This is the previous lesson's metaclass hook, applied at framework scale.

## What actually happens at class-definition time

`models.Model`'s metaclass (`ModelBase`, a subclass of `type`) intercepts every subclass's creation. When `class Article(models.Model): ...` executes, Python calls `ModelBase.__new__`, which walks the class's namespace, pulls out every attribute that's an instance of `Field`, and rewrites the class before it's ever used.

```python
class Field:
    """Toy stand-in for django.db.models.CharField/IntegerField."""
    def __init__(self, kind):
        self.kind = kind


class DatabaseManager:
    def filter(self, **kwargs):
        print(f"SELECT * FROM table WHERE {kwargs}")


class ModelMeta(type):
    def __new__(mcs, name, bases, namespace):
        # Collect every attribute that's a Field instance
        fields = {
            key: value for key, value in namespace.items()
            if isinstance(value, Field)
        }
        namespace["_meta"] = {"fields": fields}
        namespace["objects"] = DatabaseManager()
        return super().__new__(mcs, name, bases, namespace)


class Model(metaclass=ModelMeta):
    pass


class Article(Model):
    title = Field("char")
    views = Field("int")


print(Article._meta["fields"])   # {'title': <Field ...>, 'views': <Field ...>}
Article.objects.filter(views__gt=100)  # SELECT * FROM table WHERE {'views__gt': 100}
```

`Article` never defines `_meta` or `objects` itself — `ModelMeta.__new__` injects both while the class is being built, before the module finishes importing. By the time your code runs `Article.objects`, the attribute has existed since class-definition time.

## Why this explains framework "magic"

This is the general pattern behind most "magic" class-based frameworks: a metaclass (or `__init_subclass__`) inspects the class body's declarative attributes — fields, routes, schema definitions — and generates the runtime machinery (database mappings, serializers, registries) automatically. Recognizing this pattern is what lets you read *any* unfamiliar framework's model/schema classes and know where to go looking for the code that's actually doing the work: the metaclass, not the subclass you're reading.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q1",
      "type": "mcq",
      "prompt": "In the toy ModelMeta example, why does Article.objects exist even though Article never defines it?",
      "options": [
        { "id": "a", "text": "Python automatically adds an `objects` attribute to every class" },
        { "id": "b", "text": "ModelMeta.__new__ injects `objects` into the namespace while the Article class is being built" },
        { "id": "c", "text": "It's inherited from the built-in `object` class" },
        { "id": "d", "text": "It's added lazily the first time Article() is instantiated" }
      ],
      "correct": "b",
      "explanation": "The metaclass's __new__ runs once at class-creation time and rewrites the namespace dict before the class object is finalized — that's where `objects` and `_meta` come from."
    },
    {
      "id": "metaclasses-context-managers-metaclasses-in-frameworks-q2",
      "type": "mcq",
      "prompt": "What general pattern does Django's ModelBase metaclass demonstrate?",
      "options": [
        { "id": "a", "text": "Inspecting a class's declarative attributes at definition time to auto-generate runtime machinery" },
        { "id": "b", "text": "Encrypting class attributes for security" },
        { "id": "c", "text": "Replacing all instance methods with static methods" },
        { "id": "d", "text": "Preventing the class from ever being subclassed" }
      ],
      "correct": "a",
      "explanation": "This is the general shape of most 'magic' class-based frameworks: a metaclass reads declarative class-body attributes (fields, routes, schemas) and generates supporting machinery automatically."
    }
  ]
}
```
$md$, 12, $json$[{"id":"metaclasses-context-managers-metaclasses-in-frameworks-q1","type":"mcq","correct":"b"},{"id":"metaclasses-context-managers-metaclasses-in-frameworks-q2","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('19fcbb96-7247-5931-ba34-e8323decf1a9', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '7de46a58-36de-5545-943b-2aa366816a0f', 'Nesting & Combining Context Managers', 'notes', 2, $md$A single `with` statement can manage more than one resource at once — and when the *number* of resources isn't known until runtime, `contextlib.ExitStack` lets you manage a dynamic pile of them with the same guaranteed cleanup a plain `with` gives you.

## Multiple context managers on one `with` line

```python
with open("file1.txt", "w") as file1, open("file2.txt", "w") as file2:
    file1.write("first")
    file2.write("second")

print("both files written and closed")
```

`file1` and `file2` are entered left to right and exited right to left, and — critically — if `file2`'s `open()` fails, `file1` is still closed correctly. This is exactly equivalent to nesting two separate `with` blocks; the comma-separated form is just flatter to read.

## `ExitStack`: when you don't know how many resources up front

The two-file example above only works because you know at *write time* that there are exactly two files. If the list of files comes from a variable — a config file, a directory listing, an API response — you can't write a fixed number of `with` clauses. `ExitStack` solves this by letting you push an arbitrary number of context managers onto a stack programmatically, and unwinds all of them (in reverse order) when the `with` block exits, exception or not.

```python
from contextlib import ExitStack

filenames = ["file1.txt", "file2.txt", "file3.txt"]

with ExitStack() as stack:
    files = [stack.enter_context(open(name, "w")) for name in filenames]
    for file_obj in files:
        file_obj.write("Hello, World!")

print(f"wrote and closed {len(filenames)} files")
```

`stack.enter_context(cm)` calls `cm.__enter__()` immediately and registers `cm.__exit__()` to run when the `ExitStack` itself exits — so `files` ends up holding three already-open file objects, and all three get closed automatically no matter how many there turn out to be or whether an exception happens partway through the loop.

## Where this shows up in real code

Database connection pools, batches of temp files, and groups of related locks are the classic uses: any time "how many resources" is a runtime value rather than something you can spell out as a fixed number of `with` clauses. `ExitStack` also has `callback()` for registering plain cleanup functions (not just context managers) onto the same unwind-on-exit stack, which is handy for mixing "close this file" with "delete this temp directory" in one guaranteed-to-run teardown sequence.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-nesting-context-managers-q1",
      "type": "mcq",
      "prompt": "In `with open(a) as f1, open(b) as f2:`, in what order are the context managers exited?",
      "options": [
        { "id": "a", "text": "Left to right, same as entry order" },
        { "id": "b", "text": "Right to left — reverse of entry order" },
        { "id": "c", "text": "Simultaneously, order is undefined" },
        { "id": "d", "text": "Whichever finishes writing first" }
      ],
      "correct": "b",
      "explanation": "Context managers on one with-statement (or nested with-statements) are entered in order and exited in reverse order, like a stack."
    },
    {
      "id": "metaclasses-context-managers-nesting-context-managers-q2",
      "type": "mcq",
      "prompt": "Why would you reach for contextlib.ExitStack instead of a fixed `with a, b, c:` line?",
      "options": [
        { "id": "a", "text": "ExitStack is faster at opening files" },
        { "id": "b", "text": "When the number of context managers to manage isn't known until runtime" },
        { "id": "c", "text": "ExitStack is required for any context manager involving files" },
        { "id": "d", "text": "It removes the need for try/finally entirely, even outside context managers" }
      ],
      "correct": "b",
      "explanation": "A `with a, b, c:` line requires a fixed, known-at-write-time number of context managers. ExitStack lets you push a runtime-determined number of them via enter_context() and still get guaranteed reverse-order cleanup."
    }
  ]
}
```
$md$, 15, $json$[{"id":"metaclasses-context-managers-nesting-context-managers-q1","type":"mcq","correct":"b"},{"id":"metaclasses-context-managers-nesting-context-managers-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0cf7e9b3-11c9-5dc2-8824-655a38ed5420', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '7de46a58-36de-5545-943b-2aa366816a0f', 'Custom Context Managers', 'notes', 3, $md$`with` isn't magic reserved for `open()` — any object that implements `__enter__`/`__exit__` (or any generator function wrapped in `@contextmanager`) can be used after `with`. Writing your own is one of the highest-leverage patterns for guaranteed cleanup in senior-level Python code.

## The class-based form: `__enter__` and `__exit__`

```python
class Timer:
    def __enter__(self):
        import time
        self._start = time.perf_counter()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        import time
        elapsed = time.perf_counter() - self._start
        print(f"elapsed: {elapsed:.4f}s")
        return False  # False (or None) means: don't suppress exceptions


with Timer():
    total = sum(i * i for i in range(1_000_000))
```

`__enter__`'s return value becomes the `as` target. `__exit__` receives the exception type/value/traceback if the block raised (all `None` if it didn't) — returning a truthy value from `__exit__` swallows the exception, which is almost never what you want, so `return False`/`None` explicitly.

## The generator form: `@contextmanager`

Writing a class for every context manager is boilerplate for simple cases. `contextlib.contextmanager` turns a single generator function — one `yield` splitting "setup" from "teardown" — into the same protocol:

```python
import sqlite3
from contextlib import contextmanager


@contextmanager
def database_connection(db_name):
    """Everything before yield is __enter__; everything after (in finally) is __exit__."""
    conn = sqlite3.connect(db_name)
    try:
        print("connection opened")
        yield conn
    finally:
        conn.close()
        print("connection closed")


with database_connection(":memory:") as conn:
    cursor = conn.cursor()
    cursor.execute("CREATE TABLE users (id INTEGER, name TEXT)")
    cursor.execute("INSERT INTO users VALUES (?, ?)", (1, "Alice"))
    conn.commit()
    print("row inserted")
```

The code before `yield conn` runs on `__enter__`; whatever's passed to `yield` becomes the `as` target; the code after `yield` — wrapped in `try/finally` — runs on `__exit__`, whether the `with` block succeeded or raised. This is the far more common style in production code: it reads top-to-bottom like a script instead of splitting setup/teardown across two separate methods.

## Class-based vs. generator-based: when to pick which

Reach for `@contextmanager` by default — it's shorter and the setup/teardown logic stays visually adjacent. Drop to a full class when the context manager needs to hold reusable state across multiple `__enter__`/`__exit__` cycles (the same instance used in several separate `with` blocks), or needs to inspect the exception details in `__exit__` beyond "did one happen" (deciding whether to log, retry, or suppress based on `exc_type`).

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "metaclasses-context-managers-custom-context-managers-q1",
      "type": "mcq",
      "prompt": "In the @contextmanager generator style, what does the code *after* `yield` correspond to?",
      "options": [
        { "id": "a", "text": "__enter__" },
        { "id": "b", "text": "__exit__, running whether the with-block succeeded or raised (when wrapped in try/finally)" },
        { "id": "c", "text": "It never runs unless an exception occurs" },
        { "id": "d", "text": "The __init__ of the generator function" }
      ],
      "correct": "b",
      "explanation": "Everything before yield is entry logic; everything after yield (typically in a finally block) is exit/teardown logic, running regardless of whether the with-block raised."
    },
    {
      "id": "metaclasses-context-managers-custom-context-managers-q2",
      "type": "mcq",
      "prompt": "What happens if a class-based context manager's __exit__ method returns True?",
      "options": [
        { "id": "a", "text": "Nothing different from returning False" },
        { "id": "b", "text": "Any exception raised inside the with-block is suppressed instead of propagating" },
        { "id": "c", "text": "The with-block is re-executed" },
        { "id": "d", "text": "It raises a TypeError, since __exit__ must return None" }
      ],
      "correct": "b",
      "explanation": "A truthy return from __exit__ tells Python to swallow the exception rather than let it propagate — which is why __exit__ should return False/None unless you specifically intend to suppress errors."
    }
  ]
}
```
$md$, 15, $json$[{"id":"metaclasses-context-managers-custom-context-managers-q1","type":"mcq","correct":"b"},{"id":"metaclasses-context-managers-custom-context-managers-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Weak References & Memory Optimization
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('1066ac11-c4df-5350-a31f-89e642dd32ae', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Weak References & Memory Optimization', 6)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('cde878ce-2df0-5eae-9306-5373b1cf8837', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '1066ac11-c4df-5350-a31f-89e642dd32ae', 'weakref', 'notes', 0, $md$CPython's primary garbage-collection mechanism is reference counting: every object tracks how many references point to it, and gets freed the instant that count hits zero. A **weak reference**, from the `weakref` module, is a reference that points to an object *without* increasing its reference count — which is exactly the tool for breaking the one case reference counting can't handle on its own: two objects that reference each other.

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
$md$, 12, $json$[{"id":"weakrefs-memory-weakref-q1","type":"mcq","correct":"b"},{"id":"weakrefs-memory-weakref-q2","type":"mcq","correct":"b"},{"id":"weakrefs-memory-weakref-q3","type":"mcq","correct":"c"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('0c0d01bd-3bd0-522f-b7ed-1e9eacd28638', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '1066ac11-c4df-5350-a31f-89e642dd32ae', 'WeakKeyDictionary & WeakValueDictionary', 'notes', 1, $md$`weakref.ref` (from the previous lesson) is the low-level primitive. `WeakKeyDictionary` and `WeakValueDictionary`, from the same `weakref` module, package it into a dict-like container — the shape you'll actually reach for day to day when attaching extra data to objects you don't own the lifetime of.

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
$md$, 12, $json$[{"id":"weakrefs-memory-weak-key-dictionary-q1","type":"mcq","correct":"b"},{"id":"weakrefs-memory-weak-key-dictionary-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('c328f3b4-b903-5d25-8220-ba18de4584a2', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '1066ac11-c4df-5350-a31f-89e642dd32ae', 'Optimizing Memory with __slots__', 'notes', 2, $md$By default, every instance of a Python class carries its own `__dict__` — a full dictionary — to hold its attributes, even if every instance always has exactly the same fixed set of attribute names. `__slots__` lets you tell Python "this class only ever has these attributes," trading that flexibility for a meaningfully smaller memory footprint per instance.

## The default: every instance gets a `__dict__`

```python
class UserProfile:
    def __init__(self, username, email):
        self.username = username
        self.email = email


u = UserProfile("alice", "alice@example.com")
print(u.__dict__)          # {'username': 'alice', 'email': 'alice@example.com'}
u.extra = "anything goes"  # works fine -- __dict__ accepts new keys freely
print(u.__dict__)
```

That per-instance dict is flexible (you can bolt on `u.extra` at any time) but it isn't free: a dict has its own internal hash table overhead on top of the actual attribute values, and when you're creating millions of instances of a simple data-holding class, that overhead adds up.

## `__slots__`: a fixed, dict-free attribute set

```python
class SlotsUserProfile:
    __slots__ = ["username", "email"]

    def __init__(self, username, email):
        self.username = username
        self.email = email


s = SlotsUserProfile("bob", "bob@example.com")
print(s.username, s.email)  # bob bob@example.com
print(hasattr(s, "__dict__"))  # False -- there is no per-instance dict at all

try:
    s.extra = "not allowed"
except AttributeError as e:
    print(f"blocked: {e}")  # 'SlotsUserProfile' object has no attribute 'extra'
```

Declaring `__slots__ = ["username", "email"]` tells CPython to allocate fixed, fast slots for exactly those two attributes instead of a `__dict__` — and, as a side effect, blocks setting any attribute not named in the list. That restriction is the whole trade: you give up dynamic attribute assignment in exchange for a smaller, faster instance layout.

## Measuring the difference

`memory_profiler`'s `@profile` decorator (covered in the next lesson) is the tool the original notes use to show this at scale — but it needs the `mprof`/`python -m memory_profiler` runner, so it won't execute standalone here. The stdlib's own `sys.getsizeof` on a single instance already shows the shape of the difference, even though it only reports one object's shallow size, not the whole instance-plus-dict picture:

```python
import sys

regular = UserProfile("carol", "carol@example.com")
slotted = SlotsUserProfile("carol", "carol@example.com")

print("regular instance:", sys.getsizeof(regular))          # the instance itself
print("regular's __dict__:", sys.getsizeof(regular.__dict__))  # plus a whole dict
print("slotted instance:", sys.getsizeof(slotted))          # no separate dict at all
```

At one instance this looks like a rounding error; multiply it by a million rows loaded from a database or a CSV and the missing per-instance `__dict__` becomes real, measurable memory saved.

## The trade-off

`__slots__` is best reserved for classes you instantiate a lot — data-holding value objects, nodes in a large tree or graph, rows loaded in bulk — not for every class by default. It removes dynamic attribute assignment, it doesn't mix cleanly with multiple inheritance unless every base class also defines (compatible) slots, and a subclass that doesn't itself declare `__slots__` gets a `__dict__` anyway, silently undoing the savings.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-slots-q1",
      "type": "mcq",
      "prompt": "What does declaring __slots__ = [\"username\", \"email\"] prevent?",
      "options": [
        { "id": "a", "text": "Reading the username or email attributes" },
        { "id": "b", "text": "Setting any attribute not named in __slots__, since there's no per-instance __dict__ to hold it" },
        { "id": "c", "text": "Subclassing the class at all" },
        { "id": "d", "text": "Calling __init__ more than once" }
      ],
      "correct": "b",
      "explanation": "__slots__ replaces the per-instance __dict__ with fixed slots for exactly the named attributes, so assigning any other attribute name raises AttributeError."
    },
    {
      "id": "weakrefs-memory-slots-q2",
      "type": "mcq",
      "prompt": "What kind of class benefits most from __slots__?",
      "options": [
        { "id": "a", "text": "A singleton class that's only ever instantiated once" },
        { "id": "b", "text": "A simple, fixed-attribute class instantiated in very large numbers (e.g. millions of rows/nodes)" },
        { "id": "c", "text": "A class that needs to support arbitrary dynamic attributes at runtime" },
        { "id": "d", "text": "An abstract base class that's never instantiated directly" }
      ],
      "correct": "b",
      "explanation": "The memory savings from skipping a per-instance __dict__ are negligible for one object but add up meaningfully at scale — the classic use case is a data-holding class created millions of times."
    },
    {
      "id": "weakrefs-memory-slots-q3",
      "type": "mcq",
      "prompt": "If a subclass of a __slots__ class doesn't declare its own __slots__, what happens?",
      "options": [
        { "id": "a", "text": "It inherits the parent's memory savings automatically with no changes needed" },
        { "id": "b", "text": "It silently gets a __dict__ of its own, undoing the memory savings for that subclass" },
        { "id": "c", "text": "Python raises a TypeError at class-definition time" },
        { "id": "d", "text": "The subclass can no longer be instantiated" }
      ],
      "correct": "b",
      "explanation": "A subclass without its own __slots__ declaration gets a normal __dict__, which quietly defeats the point of the parent's __slots__ for instances of that subclass."
    }
  ]
}
```
$md$, 12, $json$[{"id":"weakrefs-memory-slots-q1","type":"mcq","correct":"b"},{"id":"weakrefs-memory-slots-q2","type":"mcq","correct":"b"},{"id":"weakrefs-memory-slots-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('dfefbab7-94a2-5e64-baf4-fbcc1a57d5f4', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '1066ac11-c4df-5350-a31f-89e642dd32ae', 'memory_profiler', 'notes', 3, $md$Knowing *that* a program uses too much memory is easy — knowing *which line* is responsible is the actual debugging work. `memory_profiler` is a third-party package built for exactly that: line-by-line memory usage inside a specific function.

## The `@profile` decorator (needs its own runner)

```python
# requires: pip install memory-profiler, then run with `python -m memory_profiler script.py`
# (the @profile decorator only activates under that runner -- it can't run standalone)
from memory_profiler import profile


@profile
def my_function():
    a = [i for i in range(100_000)]   # allocates a list of 100k ints
    b = [i * 2 for i in a]            # allocates a second list
    return b


if __name__ == "__main__":
    my_function()
```

Running that under `python -m memory_profiler script.py` prints a line-by-line table: memory usage before and after each line, and how much that line added. That per-line increment is the whole value proposition — a regular profiler tells you which *function* is slow, `memory_profiler` tells you which *line inside* that function is the one allocating memory you didn't expect.

## Getting the same signal from the standard library

`memory_profiler` needs to be installed and run through its own entry point, so it can't execute inside a plain `python file.py` run. The stdlib's `tracemalloc` module covers a lot of the same ground without an extra dependency — it can't attribute cost to individual source lines inside one profiler run the way `memory_profiler` can, but it can snapshot allocations and tell you where they came from:

```python
import tracemalloc

tracemalloc.start()

snapshot_before = tracemalloc.take_snapshot()

a = [i for i in range(100_000)]
b = [i * 2 for i in a]

snapshot_after = tracemalloc.take_snapshot()

top_stats = snapshot_after.compare_to(snapshot_before, "lineno")
for stat in top_stats[:3]:
    print(stat)

tracemalloc.stop()
```

`compare_to` reports the size delta per allocation site (file + line number) between the two snapshots, which is the same "which line grew memory" question `memory_profiler` answers — `tracemalloc` just requires you to bracket the code with explicit snapshots instead of decorating a function.

## When to reach for this

Neither tool is something you run in production continuously — both add real overhead. Reach for line-level memory profiling when a specific function is suspected of a leak or excessive allocation and you've already narrowed the problem down that far (via `sys.getsizeof`, general monitoring, or just watching RSS climb); it's a targeted debugging tool, not a monitoring strategy.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-memory-profiler-q1",
      "type": "mcq",
      "prompt": "What does memory_profiler's @profile decorator give you that a normal time-based profiler doesn't?",
      "options": [
        { "id": "a", "text": "Faster overall function execution" },
        { "id": "b", "text": "A line-by-line breakdown of memory usage inside the decorated function" },
        { "id": "c", "text": "Automatic memory leak fixes" },
        { "id": "d", "text": "CPU usage instead of memory usage" }
      ],
      "correct": "b",
      "explanation": "memory_profiler's @profile output shows memory before/after and the delta for each individual line in the function, pinpointing exactly which line is responsible for an allocation."
    },
    {
      "id": "weakrefs-memory-memory-profiler-q2",
      "type": "mcq",
      "prompt": "Why can't the @profile-decorated example run under plain `python script.py`?",
      "options": [
        { "id": "a", "text": "It's a syntax error in modern Python" },
        { "id": "b", "text": "@profile's line-by-line reporting only activates when run through the `python -m memory_profiler` entry point" },
        { "id": "c", "text": "memory_profiler only works on macOS" },
        { "id": "d", "text": "The function itself has a bug" }
      ],
      "correct": "b",
      "explanation": "memory_profiler's line-by-line output requires its own runner (`python -m memory_profiler` or the `mprof` CLI) to hook into and report per-line memory deltas -- the decorator alone under plain python won't produce that report."
    }
  ]
}
```
$md$, 12, $json$[{"id":"weakrefs-memory-memory-profiler-q1","type":"mcq","correct":"b"},{"id":"weakrefs-memory-memory-profiler-q2","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9bf76712-b21a-5949-8ea6-212611446507', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '1066ac11-c4df-5350-a31f-89e642dd32ae', 'sys.getsizeof()', 'notes', 4, $md$`sys.getsizeof(obj)` returns the number of bytes an object itself occupies in memory. It's the quickest way to compare the raw size of two objects — and the single most common mistake with it is assuming it accounts for more than it actually does.

## What it measures: shallow size only

```python
import sys

empty_list = []
list_of_ten_ints = [0] * 10
list_of_ten_big_objects = [object()] * 10

print(sys.getsizeof(empty_list))            # base overhead of an empty list
print(sys.getsizeof(list_of_ten_ints))      # bigger -- room for 10 pointers
print(sys.getsizeof(list_of_ten_big_objects))  # same as the ints list!
```

The last two lines report *the same size*, even though one list holds ten small integers and the other holds ten `object()` instances. That's because `getsizeof` on a list only measures the list's own internal array of pointers — not the objects those pointers point to. Ten pointers is ten pointers, regardless of what they point at.

## A concrete "gotcha": 10 million identical references

```python
import sys


class MyClass:
    my_var = "foo"


my_list = [MyClass()] * 10_000_000  # ONE instance, referenced 10 million times

print(len(my_list))               # 10000000
print(sys.getsizeof(my_list))     # roughly the size of 10 million pointers -- not 10 million objects
```

`[MyClass()] * 10_000_000` creates a *single* `MyClass` instance and repeats the same reference ten million times — it does not call `MyClass()` ten million times. `sys.getsizeof(my_list)` reports the size of the list's pointer array (large, but nowhere near "ten million object instances" large), because it never looks past the pointers to measure what they point to. If you actually wanted ten million distinct instances, you'd need `[MyClass() for _ in range(10_000_000)]` — and even then, `getsizeof` on the resulting list would *still* only report the list's own pointer array, not the total size of every instance it points to.

## Getting the deep size instead

When you need the *total* memory a nested structure occupies — a dict of lists, a tree of objects — `getsizeof` alone under-reports it, because it never recurses. You have to walk the structure yourself (or use a library like `pympler.asizeof`) and sum `getsizeof` at every level:

```python
import sys

def deep_size(obj, seen=None):
    """Recursively sum getsizeof over a nested dict/list/tuple structure."""
    seen = seen if seen is not None else set()
    obj_id = id(obj)
    if obj_id in seen:
        return 0
    seen.add(obj_id)

    size = sys.getsizeof(obj)
    if isinstance(obj, dict):
        size += sum(deep_size(k, seen) + deep_size(v, seen) for k, v in obj.items())
    elif isinstance(obj, (list, tuple, set)):
        size += sum(deep_size(item, seen) for item in obj)
    return size


nested = {"a": [1, 2, 3], "b": {"c": [4, 5]}}
print(sys.getsizeof(nested))   # shallow -- just the dict's own overhead
print(deep_size(nested))       # much larger -- recurses into every value
```

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "weakrefs-memory-getsizeof-q1",
      "type": "mcq",
      "prompt": "sys.getsizeof([object()] * 10) and sys.getsizeof([0] * 10) report roughly the same size. Why?",
      "options": [
        { "id": "a", "text": "getsizeof always returns a fixed constant regardless of content" },
        { "id": "b", "text": "A list's getsizeof measures its own array of pointers, not the size of the objects those pointers reference" },
        { "id": "c", "text": "object() and 0 happen to be exactly the same size in Python" },
        { "id": "d", "text": "Python caches all small lists to the same memory address" }
      ],
      "correct": "b",
      "explanation": "getsizeof reports shallow size: for a list, that's the overhead of the list object plus its internal array of references, not the total size of whatever those references point to."
    },
    {
      "id": "weakrefs-memory-getsizeof-q2",
      "type": "mcq",
      "prompt": "What does [MyClass()] * 10_000_000 actually create?",
      "options": [
        { "id": "a", "text": "10 million separate MyClass instances" },
        { "id": "b", "text": "One MyClass instance, referenced 10 million times in the list" },
        { "id": "c", "text": "A generator that lazily creates instances on access" },
        { "id": "d", "text": "A MemoryError, since MyClass() can only be called once" }
      ],
      "correct": "b",
      "explanation": "The * operator on a list repeats the same object reference; MyClass() is called exactly once, and the resulting single instance is referenced 10 million times."
    },
    {
      "id": "weakrefs-memory-getsizeof-q3",
      "type": "mcq",
      "prompt": "How do you measure the total memory of a nested structure (e.g. a dict of lists), given that getsizeof doesn't recurse?",
      "options": [
        { "id": "a", "text": "sys.getsizeof always recurses automatically for dicts and lists" },
        { "id": "b", "text": "Walk the structure yourself, summing getsizeof at every level (or use a library like pympler.asizeof)" },
        { "id": "c", "text": "It's impossible to measure nested structures in Python" },
        { "id": "d", "text": "Call sys.getsizeof(obj, deep=True)" }
      ],
      "correct": "b",
      "explanation": "getsizeof only measures one object's shallow size. Getting a true total for a nested structure requires recursing through it yourself (tracking visited ids to avoid double-counting shared references) or using a dedicated deep-size library."
    }
  ]
}
```
$md$, 10, $json$[{"id":"weakrefs-memory-getsizeof-q1","type":"mcq","correct":"b"},{"id":"weakrefs-memory-getsizeof-q2","type":"mcq","correct":"b"},{"id":"weakrefs-memory-getsizeof-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Decorators, Dataclasses & Metaprogramming
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Decorators, Dataclasses & Metaprogramming', 7)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('1488a14d-359f-5da5-acd9-e3f9dc41e0e4', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', 'Advanced Decorators', 'notes', 0, $md$A basic decorator wraps a function to add one piece of behavior — logging, say. Senior interviews probe further: can a decorator carry its own state across calls? Can several stack together? Can it take arguments? Can it modify a *class* instead of a function? All four come up constantly in real codebases (caching, auth, rate limiting, ORMs), so being fluent with them is a strong signal.

## Attaching state to the wrapper

A decorator's inner `wrapper` function is a closure — it can hang extra data directly off itself as an attribute, which callers can then read:

```python
def call_counter(func):
    def wrapper(*args, **kwargs):
        wrapper.calls += 1
        print(f"Call {wrapper.calls} to {func.__name__}")
        return func(*args, **kwargs)
    wrapper.calls = 0
    return wrapper

@call_counter
def greet(name):
    print(f"Hello, {name}!")

greet("Alice")  # Call 1 to greet
greet("Bob")    # Call 2 to greet
print("Total calls:", greet.calls)  # Total calls: 2
```

The counter lives on `wrapper`, not on `greet` — after decoration, `greet` *is* `wrapper`, so `greet.calls` works fine.

## Caching results

The same closure trick builds a memoizing decorator: keep a dict alive across calls, keyed by the arguments:

```python
def cache(func):
    stored_results = {}
    def wrapper(*args):
        if args not in stored_results:
            stored_results[args] = func(*args)
        return stored_results[args]
    return wrapper

@cache
def fib(n):
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)

print(fib(30))  # instant — without caching this would be exponential
```

This is exactly what `functools.lru_cache` does for you (covered in a later lesson) — knowing how to hand-roll it shows you understand *why* the built-in one works, not just how to import it.

## Stacking decorators

Decorators apply bottom-up but *run* outside-in, like nested function calls:

```python
def authenticate(func):
    def wrapper(*args, **kwargs):
        print("Authenticating...")
        return func(*args, **kwargs)
    return wrapper

def log(func):
    def wrapper(*args, **kwargs):
        print(f"Logging call to {func.__name__}")
        return func(*args, **kwargs)
    return wrapper

@authenticate
@log
def access_data():
    print("Accessing sensitive data")

access_data()
# Authenticating...
# Logging call to access_data
# Accessing sensitive data
```

`access_data` is first wrapped by `log`, then that result is wrapped by `authenticate` — so `authenticate`'s "Authenticating..." print runs first, then it calls into the `log`-wrapped function.

## Decorators that take arguments

A decorator factory is a function that *returns* a decorator, letting you parameterize the behavior:

```python
import time

def timer(unit="seconds"):
    def decorator(func):
        def wrapper(*args, **kwargs):
            start = time.perf_counter()
            result = func(*args, **kwargs)
            duration = time.perf_counter() - start
            if unit == "milliseconds":
                duration *= 1000
            print(f"{func.__name__} took {duration:.2f} {unit}")
            return result
        return wrapper
    return decorator

@timer(unit="milliseconds")
def slow_function():
    time.sleep(0.05)

slow_function()  # slow_function took ~50.00 milliseconds
```

`@timer(unit="milliseconds")` first calls `timer(unit="milliseconds")`, which returns `decorator` — *that* is what actually wraps `slow_function`. Three layers deep, but each layer is just an ordinary closure.

## Class decorators

A decorator doesn't have to wrap a function — applied to a class, it receives the class object itself and can mutate or replace it:

```python
def add_method(cls):
    def new_method(self):
        return "I am a new method!"
    cls.new_method = new_method
    return cls

@add_method
class MyClass:
    pass

obj = MyClass()
print(obj.new_method())  # I am a new method!
```

Frameworks use this pattern to inject methods, register classes in a lookup table, or wrap every method with instrumentation — without the class author having to write that plumbing themselves.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-advanced-decorators-q1",
      "type": "mcq",
      "prompt": "In the call_counter example, why does greet.calls work after decoration?",
      "options": [
        { "id": "a", "text": "Python automatically copies attributes from the original function" },
        { "id": "b", "text": "greet is rebound to wrapper, and calls is an attribute set directly on wrapper" },
        { "id": "c", "text": "calls is a global variable shared by all decorated functions" },
        { "id": "d", "text": "It doesn't work — this would raise an AttributeError" }
      ],
      "correct": "b",
      "explanation": "@call_counter replaces greet with wrapper. wrapper.calls = 0 attaches an attribute directly to that function object, so greet.calls reads it fine after decoration."
    },
    {
      "id": "decorators-dataclasses-advanced-decorators-q2",
      "type": "mcq",
      "prompt": "For `@authenticate` stacked above `@log` on the same function, what runs first when the function is called?",
      "options": [
        { "id": "a", "text": "log's wrapper code, then authenticate's wrapper code" },
        { "id": "b", "text": "authenticate's wrapper code, then log's wrapper code" },
        { "id": "c", "text": "They run simultaneously" },
        { "id": "d", "text": "Only the topmost decorator (authenticate) ever runs" }
      ],
      "correct": "b",
      "explanation": "Decorators apply bottom-up (log wraps the function first, then authenticate wraps that result) but execute outside-in: calling the final object runs authenticate's wrapper first, which calls into log's wrapper."
    },
    {
      "id": "decorators-dataclasses-advanced-decorators-q3",
      "type": "mcq",
      "prompt": "Why does @timer(unit=\"milliseconds\") need three nested functions (timer, decorator, wrapper) instead of the usual two?",
      "options": [
        { "id": "a", "text": "It's a Python syntax requirement for all decorators" },
        { "id": "b", "text": "timer(unit=...) must first execute and return the actual decorator, since @ can only apply a single callable directly to the function" },
        { "id": "c", "text": "Extra nesting is only for readability and has no functional purpose" },
        { "id": "d", "text": "wrapper needs its own wrapper to handle *args" }
      ],
      "correct": "b",
      "explanation": "@timer(unit=\"milliseconds\") first calls timer(...), which must return something that @ can apply to slow_function — that something is decorator. decorator then returns wrapper, the function that actually runs at call time."
    }
  ]
}
```
$md$, 15, $json$[{"id":"decorators-dataclasses-advanced-decorators-q1","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-advanced-decorators-q2","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-advanced-decorators-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('68278478-0018-59f8-85bc-d81d5d7478a1', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', '`dataclasses`', 'notes', 1, $md$Plain data-holding classes (DTOs, config objects, domain models) need `__init__`, `__repr__`, and usually `__eq__` — and writing them by hand is repetitive, error-prone boilerplate. `@dataclass` generates all three from a single class body of type-annotated fields.

## By hand vs. `@dataclass`

Written manually, a simple `Point` class looks like this:

```python
class Point:
    def __init__(self, x: int, y: int):
        self.x = x
        self.y = y

    def __repr__(self):
        return f"Point(x={self.x}, y={self.y})"

    def __eq__(self, other):
        if not isinstance(other, Point):
            return NotImplemented
        return (self.x, self.y) == (other.x, other.y)

point1 = Point(1, 2)
point2 = Point(1, 2)
print(point1)             # Point(x=1, y=2)
print(point1 == point2)   # True
```

`@dataclass` generates exactly this — `__init__`, `__repr__`, `__eq__` — from the annotated fields alone:

```python
from dataclasses import dataclass

@dataclass
class Point:
    x: int
    y: int

point1 = Point(1, 2)
point2 = Point(1, 2)
print(point1)             # Point(x=1, y=2)
print(point1 == point2)   # True
```

Twelve lines become five, and there's no `__init__`/`__repr__`/`__eq__` logic to get subtly wrong or forget to update when a field is added.

## Default values

Fields can carry defaults, exactly like a normal function signature — and just like function defaults, every field with one must come after every field without one:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int = 30
    city: str = "Unknown"

person = Person(name="Alice")
print(person)  # Person(name='Alice', age=30, city='Unknown')
```

## Immutability with `frozen=True`

Passing `frozen=True` makes every field write-once: any attempt to reassign an attribute after construction raises `FrozenInstanceError`, which is exactly what you want for a value object that should never be mutated after creation (a coordinate, a money amount, a cache key):

```python
from dataclasses import dataclass, FrozenInstanceError

@dataclass(frozen=True)
class Point:
    x: int
    y: int

point = Point(1, 2)
try:
    point.x = 3
except FrozenInstanceError as e:
    print("blocked:", e)
```

Frozen dataclasses are also hashable by default (as long as every field is hashable), so they can be used as dict keys or set members — a plain, mutable `@dataclass` is not hashable unless you opt in explicitly.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-dataclasses-q1",
      "type": "mcq",
      "prompt": "What does @dataclass generate from a class body of annotated fields?",
      "options": [
        { "id": "a", "text": "Only __init__" },
        { "id": "b", "text": "__init__, __repr__, and __eq__ (by default)" },
        { "id": "c", "text": "A full ORM mapping to a database table" },
        { "id": "d", "text": "Nothing — @dataclass is purely a type-checking hint" }
      ],
      "correct": "b",
      "explanation": "By default @dataclass generates __init__, __repr__, and __eq__ based on the declared fields, eliminating the most common boilerplate for data-holding classes."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q2",
      "type": "mcq",
      "prompt": "In `class Person: name: str; age: int = 30; city: str = \"Unknown\"`, why must age and city come after name?",
      "options": [
        { "id": "a", "text": "Alphabetical ordering is required by dataclasses" },
        { "id": "b", "text": "The generated __init__ behaves like a normal function signature — required parameters can't follow ones with defaults" },
        { "id": "c", "text": "It's a stylistic convention only, not enforced" },
        { "id": "d", "text": "Fields with defaults must always be declared first" }
      ],
      "correct": "b",
      "explanation": "@dataclass builds __init__(self, name, age=30, city='Unknown') — an ordinary Python function signature, where a parameter without a default can't follow one that has one."
    },
    {
      "id": "decorators-dataclasses-dataclasses-q3",
      "type": "mcq",
      "prompt": "What does frozen=True add to a dataclass?",
      "options": [
        { "id": "a", "text": "It makes field access slower but otherwise changes nothing" },
        { "id": "b", "text": "It blocks attribute reassignment after construction (raising FrozenInstanceError) and makes instances hashable" },
        { "id": "c", "text": "It prevents the class from being subclassed" },
        { "id": "d", "text": "It automatically deep-copies the instance on every read" }
      ],
      "correct": "b",
      "explanation": "frozen=True raises FrozenInstanceError on any post-init attribute write, and makes the class hashable by default (assuming all fields are hashable) — useful for value objects used as dict keys."
    }
  ]
}
```
$md$, 12, $json$[{"id":"decorators-dataclasses-dataclasses-q1","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-dataclasses-q2","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-dataclasses-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('e19573e1-5baf-5b54-b4dd-1b4dbc6c72b6', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', 'Metaprogramming', 'notes', 2, $md$Metaprogramming is code that writes, inspects, or modifies other code — at runtime, in Python's case, rather than at compile time. It's not a single feature; it's a category that decorators, metaclasses, dynamic attribute creation, and runtime introspection all belong to. Every ORM, dependency-injection container, and test framework you've used leans on it heavily, so recognizing the pattern (and its readability cost) is a senior-level skill in its own right.

## The three levers Python gives you

**1. Decorators** — wrap or rewrite a function/class definition at the moment it's created (covered in the previous lesson). This is metaprogramming at the *function/class* level.

**2. Metaclasses** — a metaclass controls how a *class itself* is built, the same way a class controls how its instances are built. `type` is the default metaclass for every class in Python; a custom metaclass hooks into that process (covered in a later lesson).

**3. Dynamic attribute creation & inspection** — building or reading attributes at runtime instead of writing them out in source. `type()` called with three arguments creates a class on the fly:

```python
def greet(self):
    return f"Hi, I'm {self.name}"

Person = type("Person", (), {"greet": greet, "species": "human"})

p = Person()
p.name = "Ana"
print(p.greet())     # Hi, I'm Ana
print(p.species)     # human
print(type(Person))  # <class 'type'>
```

`class Person: ...` is sugar for exactly this call — the interpreter builds the class body into a namespace dict and calls `type(name, bases, namespace)` on it. Writing that call directly is how frameworks generate classes from data they don't know about until runtime (an ORM building a model class from a database schema, for instance).

## Runtime inspection: `getattr`/`setattr`/`hasattr`

The introspection half of metaprogramming — reading or writing attributes by *name*, computed at runtime rather than known at write time:

```python
class Config:
    debug = False
    timeout = 30

settings = {"debug": True, "retries": 3}
cfg = Config()
for key, value in settings.items():
    setattr(cfg, key, value)   # cfg.debug = True; cfg.retries = 3

print(cfg.debug, cfg.timeout, cfg.retries)  # True 30 3
print(getattr(cfg, "missing", "default"))   # "default" — no AttributeError
```

This is how a config loader can populate arbitrary settings from a JSON file, or a serializer can round-trip arbitrary fields, without a hardcoded `if key == "debug": self.debug = value` branch per field.

## Where the industry uses this

- **ORMs** (Django, SQLAlchemy): a metaclass turns class-level attribute declarations (`name = CharField()`) into database column mappings.
- **Dependency injection containers**: inspect a function's parameter names/annotations at runtime and auto-supply matching registered objects.
- **Test frameworks** (pytest): discover functions named `test_*` via introspection, then wrap them with fixtures via decorators.

## The cost

Every lever above makes code *dynamic* — which also makes it harder to trace with a plain text search, harder for static type checkers to verify, and harder to debug because the "definition" of behavior isn't sitting in one readable place. The senior-level judgment call isn't "can I do this with metaprogramming" (usually yes) but "does the flexibility this buys pay for the readability it costs" — reach for it when you're building a reusable framework surface, not for one-off application code.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-metaprogramming-q1",
      "type": "mcq",
      "prompt": "Which of these is NOT one of Python's core metaprogramming mechanisms?",
      "options": [
        { "id": "a", "text": "Decorators" },
        { "id": "b", "text": "Metaclasses" },
        { "id": "c", "text": "List comprehensions" },
        { "id": "d", "text": "Dynamic attribute creation with setattr/type()" }
      ],
      "correct": "c",
      "explanation": "List comprehensions are ordinary syntax for building a list — they don't modify or generate code at runtime. Decorators, metaclasses, and dynamic attribute creation all do."
    },
    {
      "id": "decorators-dataclasses-metaprogramming-q2",
      "type": "mcq",
      "prompt": "What does `type(\"Person\", (), {\"species\": \"human\"})` do?",
      "options": [
        { "id": "a", "text": "Returns the string \"Person\"" },
        { "id": "b", "text": "Creates a new class named Person with no bases and a species class attribute — equivalent to a `class Person:` statement" },
        { "id": "c", "text": "Raises a TypeError because type() only takes one argument" },
        { "id": "d", "text": "Creates an instance of an existing Person class" }
      ],
      "correct": "b",
      "explanation": "type() called with three arguments (name, bases tuple, namespace dict) builds a new class object — exactly what a `class` statement compiles down to internally."
    },
    {
      "id": "decorators-dataclasses-metaprogramming-q3",
      "type": "mcq",
      "prompt": "What's the main tradeoff to weigh before reaching for metaprogramming in application code?",
      "options": [
        { "id": "a", "text": "Metaprogramming always makes code run slower, so it should be avoided for performance" },
        { "id": "b", "text": "It buys flexibility at the cost of readability and traceability — harder to grep, harder for type checkers, harder to debug" },
        { "id": "c", "text": "Python forbids metaprogramming outside of the standard library" },
        { "id": "d", "text": "It only works inside classes, never with plain functions" }
      ],
      "correct": "b",
      "explanation": "Dynamic behavior (metaclasses, runtime attribute creation, etc.) is harder to trace statically. It's the right tool when building a reusable framework surface, not a default for one-off code."
    }
  ]
}
```
$md$, 15, $json$[{"id":"decorators-dataclasses-metaprogramming-q1","type":"mcq","correct":"c"},{"id":"decorators-dataclasses-metaprogramming-q2","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-metaprogramming-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('9d1d56cf-d50f-553e-b700-ba9df3bb2658', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', '`functools`', 'notes', 3, $md$`functools` is the standard-library toolbox for working with functions themselves. Three tools from it come up constantly in senior interviews: `wraps` (fixes a subtle bug every hand-written decorator has), `lru_cache` (the built-in version of the memoization decorator from the previous section), and `reduce` (cumulative/fold operations).

## `wraps`: preserving a decorated function's identity

Every decorator written in the previous lesson has a hidden bug: once wrapped, the function's `__name__`, `__doc__`, and other metadata are replaced by the *wrapper's* — which breaks introspection, debuggers, and documentation tools.

```python
def my_decorator(func):
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return wrapper

@my_decorator
def greet(name):
    """Say hello to name."""
    return f"Hello, {name}"

print(greet.__name__)  # 'wrapper' — wrong! should be 'greet'
print(greet.__doc__)   # None — the docstring is gone
```

`functools.wraps` fixes this by copying the original function's metadata onto the wrapper:

```python
from functools import wraps

def my_decorator(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return wrapper

@my_decorator
def greet(name):
    """Say hello to name."""
    return f"Hello, {name}"

print(greet.__name__)  # 'greet' — correct
print(greet.__doc__)   # 'Say hello to name.'
```

Any decorator you write for real code should apply `@wraps(func)` to its inner wrapper — it costs one line and prevents a class of confusing bugs downstream.

## `lru_cache`: memoization without hand-rolling it

The `cache` decorator from the previous lesson (a dict keyed by arguments) is exactly what `lru_cache` gives you for free, plus an eviction policy (Least Recently Used) so the cache doesn't grow unbounded:

```python
from functools import lru_cache

@lru_cache(maxsize=3)
def expensive_computation(x):
    print(f"Computing {x}")
    return x * x

print(expensive_computation(2))  # Computing 2 -> 4
print(expensive_computation(2))  # 4 (served from cache, no "Computing 2" print)
print(expensive_computation(3))  # Computing 3 -> 9
```

`maxsize=3` caps the cache at 3 distinct argument combinations; once full, the least-recently-used entry is evicted to make room. `maxsize=None` makes it unbounded. Arguments must be hashable (this is a dict under the hood).

## `reduce`: cumulative operations

`reduce(function, iterable)` folds an iterable down to a single value by repeatedly applying a two-argument function — `reduce(f, [a, b, c])` computes `f(f(a, b), c)`:

```python
from functools import reduce

numbers = [1, 2, 3, 4]
product = reduce(lambda x, y: x * y, numbers)
print(product)  # 24

total = reduce(lambda x, y: x + y, numbers, 0)  # 0 is the starting value
print(total)  # 10
```

`sum()` already covers the addition case — `reduce` earns its place for anything without a dedicated built-in: running max with custom comparison, merging dicts, composing a chain of functions.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-functools-q1",
      "type": "mcq",
      "prompt": "What bug does functools.wraps fix?",
      "options": [
        { "id": "a", "text": "It makes decorated functions run faster" },
        { "id": "b", "text": "Without it, the wrapped function's __name__, __doc__, and other metadata get replaced by the wrapper function's own metadata" },
        { "id": "c", "text": "It prevents decorators from being stacked" },
        { "id": "d", "text": "It adds automatic error handling to every decorator" }
      ],
      "correct": "b",
      "explanation": "A plain wrapper function shadows the original's __name__ and __doc__. @wraps(func) copies that metadata onto the wrapper so introspection and debugging still show the original function's identity."
    },
    {
      "id": "decorators-dataclasses-functools-q2",
      "type": "mcq",
      "prompt": "What does maxsize=3 do on @lru_cache(maxsize=3)?",
      "options": [
        { "id": "a", "text": "Limits the function to being called 3 times total" },
        { "id": "b", "text": "Caps the cache at 3 distinct argument combinations, evicting the least-recently-used entry once full" },
        { "id": "c", "text": "Runs the function on up to 3 threads in parallel" },
        { "id": "d", "text": "Limits the result value to 3 bytes" }
      ],
      "correct": "b",
      "explanation": "lru_cache keeps at most maxsize cached results, keyed by call arguments; the Least Recently Used entry is evicted first when the cache is full and a new argument combination arrives."
    },
    {
      "id": "decorators-dataclasses-functools-q3",
      "type": "mcq",
      "prompt": "What does reduce(lambda x, y: x * y, [1, 2, 3, 4]) compute?",
      "options": [
        { "id": "a", "text": "[1, 2, 3, 4] unchanged" },
        { "id": "b", "text": "((1 * 2) * 3) * 4 = 24" },
        { "id": "c", "text": "1 + 2 + 3 + 4 = 10" },
        { "id": "d", "text": "A generator that hasn't been consumed yet" }
      ],
      "correct": "b",
      "explanation": "reduce folds the iterable left to right, repeatedly applying the two-argument function: ((1*2)*3)*4 = 24."
    }
  ]
}
```
$md$, 15, $json$[{"id":"decorators-dataclasses-functools-q1","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-functools-q2","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-functools-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('6547f577-6c46-5742-b348-dd1219b831fd', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '6ff93f4a-2837-5cbd-9213-c1c70cc0ba4d', 'Advanced Dataclass Features', 'notes', 4, $md$Beyond generating `__init__`/`__repr__`/`__eq__`, dataclasses support validation after construction, inheritance between dataclasses, and fine-grained per-field control — the features that turn a plain data holder into a properly encapsulated domain model.

## `__post_init__` for validation

`@dataclass`'s generated `__init__` just assigns fields — it can't validate them. `__post_init__`, if defined, runs automatically right after that assignment, giving you one place to enforce invariants:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int

    def __post_init__(self):
        if self.age < 0:
            raise ValueError("Age cannot be negative")

Person("Alice", 30)   # fine
Person("Bob", -5)     # raises ValueError: Age cannot be negative
```

## Inheritance between dataclasses

A dataclass subclassing another dataclass gets the parent's fields first, then its own — the generated `__init__` reflects that combined, ordered field list:

```python
from dataclasses import dataclass

@dataclass
class Person:
    name: str
    age: int

@dataclass
class Employee(Person):
    employee_id: int

emp = Employee(name="Alice", age=30, employee_id=1234)
print(emp)  # Employee(name='Alice', age=30, employee_id=1234)
```

Because inherited fields come first, a subclass can only add fields with defaults if the parent's fields all already have defaults too (the "no required field after a default" rule from the previous lesson applies across the whole hierarchy, not just within one class body).

## `field()` for fine-grained control

A bare `completed: bool = False` looks like a normal default — but it's still a real constructor parameter, so callers can pass in a completed task from day one, which may not be the intended API:

```python
from dataclasses import dataclass

@dataclass
class TaskWithoutField:
    description: str
    completed: bool = False

# Nothing stops this — the caller controls "completed" directly:
task = TaskWithoutField("Do laundry", completed=True)
```

`field(init=False)` removes a field from the generated `__init__` entirely, forcing it to be set some other way — typically inside `__post_init__`, which always runs regardless of what's passed to `__init__`:

```python
from dataclasses import dataclass, field

@dataclass
class TaskWithField:
    description: str
    completed: bool = field(init=False, default=False)

    def __post_init__(self):
        self.completed = False

task = TaskWithField("Do laundry")
print(task)  # TaskWithField(description='Do laundry', completed=False)
# TaskWithField("Do laundry", completed=True) would raise TypeError —
# completed is no longer an __init__ parameter at all.
```

`field()` also supports `default_factory` for mutable defaults (a bare `items: list = []` is a `ValueError` on a dataclass — shared mutable defaults are exactly the bug this guards against — use `field(default_factory=list)` instead), `repr=False` to hide a field from `__repr__`, and `compare=False` to exclude it from `__eq__`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q1",
      "type": "mcq",
      "prompt": "When does __post_init__ run, and why is it useful for validation?",
      "options": [
        { "id": "a", "text": "Before __init__ assigns fields, so it can reject bad input before storage" },
        { "id": "b", "text": "Automatically, right after the generated __init__ assigns all fields — giving one place to enforce invariants across them" },
        { "id": "c", "text": "Only when explicitly called by the user after construction" },
        { "id": "d", "text": "Only on frozen dataclasses" }
      ],
      "correct": "b",
      "explanation": "@dataclass's generated __init__ calls __post_init__ (if defined) automatically after assigning all fields, making it the natural hook for validation logic that needs the fully-populated instance."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q2",
      "type": "mcq",
      "prompt": "In `class Employee(Person): employee_id: int` where Person has name and age, what order do fields appear in Employee's generated __init__?",
      "options": [
        { "id": "a", "text": "employee_id, name, age" },
        { "id": "b", "text": "name, age, employee_id — parent fields first, then the subclass's own fields" },
        { "id": "c", "text": "Alphabetical: age, employee_id, name" },
        { "id": "d", "text": "Employee doesn't inherit Person's fields at all" }
      ],
      "correct": "b",
      "explanation": "Dataclass inheritance concatenates fields in MRO order — parent fields come first, then the subclass's own fields, in declaration order."
    },
    {
      "id": "decorators-dataclasses-advanced-dataclass-features-q3",
      "type": "mcq",
      "prompt": "What does field(init=False) accomplish that a plain default value doesn't?",
      "options": [
        { "id": "a", "text": "It makes the field required instead of optional" },
        { "id": "b", "text": "It removes the field from the generated __init__ signature entirely, so callers can't set it directly — it must be set elsewhere, like __post_init__" },
        { "id": "c", "text": "It's purely cosmetic and has no effect on behavior" },
        { "id": "d", "text": "It makes the field immutable after construction" }
      ],
      "correct": "b",
      "explanation": "field(init=False) excludes the field from __init__'s parameter list. TaskWithField(\"x\", completed=True) then raises TypeError, since completed is no longer a constructor parameter at all — it can only be set inside the class (e.g. __post_init__)."
    }
  ]
}
```
$md$, 12, $json$[{"id":"decorators-dataclasses-advanced-dataclass-features-q1","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-advanced-dataclass-features-q2","type":"mcq","correct":"b"},{"id":"decorators-dataclasses-advanced-dataclass-features-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

-- Section: Async, Callables & Advanced Typing
INSERT INTO course_sections (id, course_id, title, position)
VALUES ('ebcdcec0-ab75-508e-ae00-d10a40e41ba9', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'Async, Callables & Advanced Typing', 8)
ON CONFLICT (id) DO UPDATE SET title=EXCLUDED.title, position=EXCLUDED.position;

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('bf8f5167-65ca-5076-b0a1-cbfce57e5f08', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'ebcdcec0-ab75-508e-ae00-d10a40e41ba9', '`asyncio`', 'notes', 0, $md$Threads give you concurrency by having the OS preempt them; `asyncio` gives you concurrency by having your own code voluntarily yield control at `await` points, all on a single thread. No GIL contention, no locks needed for data that's never touched between `await`s — which makes it the standard choice for I/O-bound workloads (network calls, database queries, web scraping) where a thread would otherwise sit idle waiting on a socket.

## A single coroutine

`async def` defines a coroutine function — calling it doesn't run the body, it returns a coroutine object that has to be driven by an event loop. `asyncio.run()` is that driver for top-level code:

```python
import asyncio

async def greet():
    print("Hello!")
    await asyncio.sleep(1)  # yields control back to the event loop for 1 second
    print("World!")

asyncio.run(greet())
# Hello!
# (1 second pause)
# World!
```

`await asyncio.sleep(1)` is not `time.sleep(1)` — it doesn't block the thread, it tells the event loop "wake me up in 1 second, and run something else meanwhile." With only one coroutine there's nothing else to run, but that's the mechanism concurrency is built on.

## Running coroutines concurrently with `gather`

`asyncio.gather` schedules multiple coroutines on the same event loop and lets them interleave at their `await` points:

```python
import asyncio

async def task_1():
    print("Task 1: Start")
    await asyncio.sleep(0.2)
    print("Task 1: End")

async def task_2():
    print("Task 2: Start")
    await asyncio.sleep(0.1)
    print("Task 2: End")

async def main():
    await asyncio.gather(task_1(), task_2())

asyncio.run(main())
# Task 1: Start
# Task 2: Start
# Task 2: End   (0.1s sleep finishes first)
# Task 1: End   (0.2s sleep finishes second)
```

Both tasks start immediately — the "Start" prints happen back to back — then whichever one's `sleep` elapses first resumes first. Total wall-clock time is ~0.2s (the longer of the two), not ~0.3s (their sum), because they overlap instead of running sequentially.

## Producer/consumer with `asyncio.Queue`

`asyncio.Queue` coordinates coroutines the same way `queue.Queue` coordinates threads — but a consumer that loops forever must be given a way to know when to stop, or `gather` never returns. A sentinel value (`None`) signals "no more items":

```python
import asyncio

async def producer(queue):
    for i in range(3):
        await asyncio.sleep(0.1)
        await queue.put(f"item-{i}")
        print(f"produced item-{i}")
    await queue.put(None)  # sentinel: tells the consumer to stop

async def consumer(queue):
    while True:
        item = await queue.get()
        if item is None:
            break
        print(f"consumed {item}")

async def main():
    queue = asyncio.Queue()
    await asyncio.gather(producer(queue), consumer(queue))

asyncio.run(main())
```

Without that `await queue.put(None)` sentinel, `consumer`'s `while True: await queue.get()` would wait forever for an item that never arrives, and `gather` — which waits for *every* coroutine it was given — would hang indefinitely. This is the single most common bug in hand-written async producer/consumer code: always give the consumer an explicit stop signal.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-asyncio-q1",
      "type": "mcq",
      "prompt": "What's the key difference between await asyncio.sleep(1) and time.sleep(1) inside a coroutine?",
      "options": [
        { "id": "a", "text": "There is no difference — they behave identically" },
        { "id": "b", "text": "asyncio.sleep yields control back to the event loop so other coroutines can run during the wait; time.sleep blocks the entire thread" },
        { "id": "c", "text": "time.sleep is faster because it doesn't involve the event loop" },
        { "id": "d", "text": "asyncio.sleep can only be used outside of async functions" }
      ],
      "correct": "b",
      "explanation": "await asyncio.sleep(1) suspends only the current coroutine and lets the event loop run other scheduled coroutines during that second. time.sleep(1) blocks the whole thread, starving every other coroutine too — a classic asyncio antipattern."
    },
    {
      "id": "async-typing-asyncio-q2",
      "type": "mcq",
      "prompt": "In the gather(task_1(), task_2()) example, why does Task 2 finish before Task 1 even though task_1 was listed first?",
      "options": [
        { "id": "a", "text": "gather always runs coroutines in reverse order" },
        { "id": "b", "text": "Both start immediately and interleave at their await points; task_2's shorter sleep(0.1) elapses before task_1's sleep(0.2), so it resumes and finishes first" },
        { "id": "c", "text": "task_1 raised an exception and was skipped" },
        { "id": "d", "text": "Order in gather() only affects print statements, not execution" }
      ],
      "correct": "b",
      "explanation": "gather starts every coroutine right away; they run cooperatively, and whichever one's await resolves first resumes first. task_2's 0.1s sleep finishes before task_1's 0.2s sleep, so it completes first regardless of argument order."
    },
    {
      "id": "async-typing-asyncio-q3",
      "type": "mcq",
      "prompt": "What happens if the producer never puts a None sentinel on the queue, given a consumer written as `while True: item = await queue.get(); if item is None: break`?",
      "options": [
        { "id": "a", "text": "The consumer exits automatically once the producer finishes" },
        { "id": "b", "text": "The consumer's await queue.get() blocks forever waiting for another item, and gather() never returns" },
        { "id": "c", "text": "asyncio.Queue raises a TimeoutError after a default timeout" },
        { "id": "d", "text": "The program exits cleanly since there's nothing left to consume" }
      ],
      "correct": "b",
      "explanation": "Without a sentinel, the consumer has no signal to stop looping — its await queue.get() call simply waits forever for an item that will never come, and gather() waits for every coroutine it was given, so the whole program hangs."
    }
  ]
}
```
$md$, 20, $json$[{"id":"async-typing-asyncio-q1","type":"mcq","correct":"b"},{"id":"async-typing-asyncio-q2","type":"mcq","correct":"b"},{"id":"async-typing-asyncio-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('f75685cf-ea22-5da3-96ea-78efee05b98e', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'ebcdcec0-ab75-508e-ae00-d10a40e41ba9', 'Callable Objects (`__call__`)', 'notes', 1, $md$Defining `__call__` on a class makes its instances callable with `()`, exactly like a function. This matters when you need a function-like object that also carries persistent state — cleaner than a closure once that state needs to be inspected, updated, or shared after creation.

## A callable instance

```python
class Multiplier:
    def __init__(self, factor):
        self.factor = factor

    def __call__(self, value):
        return self.factor * value

doubler = Multiplier(2)
tripler = Multiplier(3)

print(doubler(5))  # 10 — calling the instance invokes __call__
print(tripler(5))  # 15

print(callable(doubler))  # True — instances of a class defining __call__ are callable
```

`doubler(5)` is syntactic sugar for `doubler.__call__(5)`, the same way `len(x)` is sugar for `x.__len__()`. `doubler` and `tripler` are two independent objects, each holding its own `factor` — a closure could capture `factor` too, but couldn't offer `doubler.factor = 4` to reconfigure it after creation the way an attribute can.

## Closures vs. callable objects

A closure works fine for one piece of hidden state:

```python
def make_multiplier(factor):
    def multiply(value):
        return factor * value
    return multiply

doubler = make_multiplier(2)
print(doubler(5))  # 10
```

But once you need *multiple* pieces of state, methods that manipulate that state, or the ability to inspect/mutate it from outside, a callable class scales better than a closure with more and more captured variables:

```python
class RateLimiter:
    def __init__(self, max_calls):
        self.max_calls = max_calls
        self.calls_made = 0

    def __call__(self, *args, **kwargs):
        if self.calls_made >= self.max_calls:
            raise RuntimeError("rate limit exceeded")
        self.calls_made += 1
        return f"call #{self.calls_made} allowed"

limiter = RateLimiter(max_calls=2)
print(limiter())              # call #1 allowed
print(limiter())              # call #2 allowed
print(limiter.calls_made)     # 2 — state is directly inspectable
try:
    limiter()
except RuntimeError as e:
    print("blocked:", e)
```

## Where this shows up in real code

Strategy-pattern implementations (swap in different callable "strategy" objects that share an interface), scikit-learn-style transformers, and any decorator implemented as a class instead of a nested function all rely on `__call__`. A class-based decorator is a common real-world example:

```python
class CountCalls:
    def __init__(self, func):
        self.func = func
        self.count = 0

    def __call__(self, *args, **kwargs):
        self.count += 1
        return self.func(*args, **kwargs)

@CountCalls
def greet(name):
    return f"Hello, {name}"

print(greet("Ana"))   # Hello, Ana
print(greet("Kim"))   # Hello, Kim
print(greet.count)    # 2
```

`@CountCalls` here replaces `greet` with a `CountCalls` *instance* — `greet(...)` then works because that instance is callable.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-callable-objects-q1",
      "type": "mcq",
      "prompt": "What does doubler(5) actually invoke when doubler is an instance of a class defining __call__?",
      "options": [
        { "id": "a", "text": "doubler.__init__(5)" },
        { "id": "b", "text": "doubler.__call__(5)" },
        { "id": "c", "text": "A new instance is created and its constructor is called" },
        { "id": "d", "text": "It raises a TypeError — instances aren't callable in Python" }
      ],
      "correct": "b",
      "explanation": "Using () on an object calls its __call__ method — obj(5) is sugar for obj.__call__(5), the same relationship len(x) has to x.__len__()."
    },
    {
      "id": "async-typing-callable-objects-q2",
      "type": "mcq",
      "prompt": "When does a callable class start to scale better than a closure for holding state?",
      "options": [
        { "id": "a", "text": "Never — closures are always the better choice" },
        { "id": "b", "text": "Once you need multiple pieces of state, methods that operate on it, or the ability to inspect/mutate it from outside the callable" },
        { "id": "c", "text": "Only when performance is critical, since closures are always slower" },
        { "id": "d", "text": "Only in multithreaded code" }
      ],
      "correct": "b",
      "explanation": "A closure works fine for one hidden variable. Once state grows (multiple fields, methods, external inspection like limiter.calls_made), a class with __call__ organizes that far better than a growing set of captured closure variables."
    },
    {
      "id": "async-typing-callable-objects-q3",
      "type": "mcq",
      "prompt": "In `@CountCalls` applied to greet, what does greet refer to after decoration?",
      "options": [
        { "id": "a", "text": "The original greet function, unchanged" },
        { "id": "b", "text": "A CountCalls instance wrapping the original function — callable because CountCalls defines __call__" },
        { "id": "c", "text": "The CountCalls class itself" },
        { "id": "d", "text": "None — class-based decorators aren't valid syntax" }
      ],
      "correct": "b",
      "explanation": "@CountCalls calls CountCalls(greet), producing an instance. greet is rebound to that instance; greet(\"Ana\") works because CountCalls.__call__ makes instances callable, forwarding to the wrapped function."
    }
  ]
}
```
$md$, 10, $json$[{"id":"async-typing-callable-objects-q1","type":"mcq","correct":"b"},{"id":"async-typing-callable-objects-q2","type":"mcq","correct":"b"},{"id":"async-typing-callable-objects-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('343487da-2e28-5527-a8a6-4f53acaa0236', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'ebcdcec0-ab75-508e-ae00-d10a40e41ba9', 'Multiprocessing with `Queue`', 'notes', 2, $md$Each `multiprocessing.Process` has its own memory space — unlike threads, processes can't share plain Python objects directly. `multiprocessing.Queue` is the standard way to move data safely between them: it pickles objects on the sending side, ships them through an OS pipe, and unpickles them on the receiving side, so it works as inter-process communication without any manual locking on your part.

## A multi-stage processing pipeline

Chaining several processes through queues builds a pipeline: each stage reads from one queue and writes to the next.

```python
from multiprocessing import Process, Queue

def producer(q1):
    for x in [1, 2, 3]:
        print("Producer:", x)
        q1.put(x)
    q1.put(None)  # sentinel: tells the next stage there's no more input

def add_one(q1, q2):
    while True:
        x = q1.get()
        if x is None:
            q2.put(None)  # forward the sentinel downstream
            break
        y = x + 1
        print("Add one:", y)
        q2.put(y)

def multiply(q2):
    while True:
        x = q2.get()
        if x is None:
            break
        print("Multiply:", x * 5)

if __name__ == "__main__":
    q1 = Queue()
    q2 = Queue()

    p1 = Process(target=producer, args=(q1,))
    p2 = Process(target=add_one, args=(q1, q2))
    p3 = Process(target=multiply, args=(q2,))

    p1.start()
    p2.start()
    p3.start()

    p1.join()
    p2.join()
    p3.join()
```

Three independent processes, three separate memory spaces — `add_one` never touches `producer`'s local `x` directly, it only ever sees values that were `put()` on `q1` and `get()` off it. The exact print interleaving isn't guaranteed (these are genuinely parallel processes), but the *set* of nine lines printed and each value's transformation (1→2→10, 2→3→15, 3→4→20) always holds.

## Why the sentinel matters here too

Just like the `asyncio.Queue` producer/consumer pattern from the previous lesson, a worker looping on `while True: x = q.get()` has no way to know the stream has ended unless something tells it — `Queue.get()` blocks forever waiting for the next item otherwise. `None` (or any value that can't be a real data item) plays that role, and **each stage must forward it** to the next queue, or the downstream stage hangs waiting for its own sentinel that never arrives.

## `Queue` vs. shared memory

`Queue` is the right tool when processes are exchanging discrete *messages* — this is the message-passing model, and it avoids the GIL by using real OS-level processes instead of threads. When processes instead need to operate on the *same* large block of memory (a big NumPy array, for instance) without copying it through pickle on every exchange, `multiprocessing.shared_memory` (covered in an earlier lesson) is the better fit — `Queue` copies data on every `put`/`get`, which is fine for small messages but wasteful for large buffers.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-multiprocessing-queue-q1",
      "type": "mcq",
      "prompt": "Why can't add_one directly read producer's local variable x, the way a thread could read another thread's local variable?",
      "options": [
        { "id": "a", "text": "It could — this is a limitation only of asyncio, not multiprocessing" },
        { "id": "b", "text": "Each Process has its own separate memory space; the only way data crosses between them is by being explicitly sent through a mechanism like Queue" },
        { "id": "c", "text": "Queue.put() automatically deletes the original variable from the sender" },
        { "id": "d", "text": "Processes share memory but not variable names" }
      ],
      "correct": "b",
      "explanation": "Unlike threads (which share one process's memory), each multiprocessing.Process gets its own separate memory space. Queue bridges that gap by pickling values, sending them through an OS pipe, and unpickling them on the other side."
    },
    {
      "id": "async-typing-multiprocessing-queue-q2",
      "type": "mcq",
      "prompt": "What would happen if add_one received the None sentinel from q1 but did NOT forward it to q2 before breaking?",
      "options": [
        { "id": "a", "text": "Nothing changes — multiply would still exit normally" },
        { "id": "b", "text": "multiply's while True: x = q2.get() loop would block forever, since it never receives its own stop signal" },
        { "id": "c", "text": "q2 would automatically close when add_one's process exits" },
        { "id": "d", "text": "Python would raise a QueueClosedError" }
      ],
      "correct": "b",
      "explanation": "Each stage's sentinel only ends that stage's own loop. multiply is watching q2, not q1 — if add_one doesn't explicitly q2.put(None), multiply's q2.get() blocks forever waiting for a sentinel that will never arrive, and p3.join() hangs."
    },
    {
      "id": "async-typing-multiprocessing-queue-q3",
      "type": "mcq",
      "prompt": "When is multiprocessing.shared_memory a better fit than Queue for inter-process data transfer?",
      "options": [
        { "id": "a", "text": "Never — Queue is always preferred regardless of data size" },
        { "id": "b", "text": "When processes need to operate on the same large block of memory (e.g. a big array) without the overhead of pickling/copying it on every message" },
        { "id": "c", "text": "Only when using threads instead of processes" },
        { "id": "d", "text": "shared_memory and Queue solve unrelated problems and are never compared" }
      ],
      "correct": "b",
      "explanation": "Queue copies data (via pickle) on every put/get, which is fine for small discrete messages but wasteful for large shared buffers. shared_memory avoids that copy by letting processes map the same underlying memory block directly."
    }
  ]
}
```
$md$, 15, $json$[{"id":"async-typing-multiprocessing-queue-q1","type":"mcq","correct":"b"},{"id":"async-typing-multiprocessing-queue-q2","type":"mcq","correct":"b"},{"id":"async-typing-multiprocessing-queue-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('a567104f-0265-54ed-a5a8-8d0a3fb41665', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'ebcdcec0-ab75-508e-ae00-d10a40e41ba9', 'Typing: Protocols & Generics', 'notes', 3, $md$Python's type hints don't just annotate — `typing.Protocol` and `typing.Generic` let you express duck typing and reusable containers in a way static checkers (mypy, pyright) can actually verify, without forcing every caller into an inheritance hierarchy.

## `Protocol`: structural typing

Traditional typed interfaces (`abc.ABC` from an earlier lesson) require explicit inheritance — a class must `class Socket(SupportsClose):` to count as a `SupportsClose`. A `Protocol` instead checks *structure*: any object with a matching method signature satisfies it, inheritance or not — this is "duck typing," formalized for the type checker.

```python
from typing import Protocol, runtime_checkable

@runtime_checkable
class SupportsClose(Protocol):
    def close(self) -> None: ...

class Socket:
    def __init__(self, name: str) -> None:
        self.name = name

    def close(self) -> None:
        print(f"Socket {self.name} closed")

def close_if_supported(obj: SupportsClose) -> None:
    obj.close()

s = Socket("A")
close_if_supported(s)  # works — Socket was never declared to inherit SupportsClose
print(isinstance(s, SupportsClose))  # True, because @runtime_checkable enables isinstance() checks
```

`Socket` never mentions `SupportsClose` anywhere — it just happens to define a `close()` method with a compatible signature, which is enough. `@runtime_checkable` is opt-in and only checks method *names* exist at runtime (not their exact signatures) — the real, full signature verification happens statically, in your type checker.

## `Generic`: containers that remember their element type

A `Generic[T]` class is parameterized by a type variable — the same idea covered for other languages elsewhere in this course, available in Python via `typing`:

```python
from typing import TypeVar, Generic

T = TypeVar("T")

class Box(Generic[T]):
    def __init__(self, value: T) -> None:
        self._v = value

    def get(self) -> T:
        return self._v

bi = Box[int](10)
bs = Box[str]("ok")
print(type(bi.get()), bi.get())  # <class 'int'> 10
print(type(bs.get()), bs.get())  # <class 'str'> ok
```

At runtime, `Box[int]` and `Box[str]` behave identically — Python doesn't enforce the type parameter, it's erased by runtime (same as most generic systems built on top of a dynamically-typed core). The value is entirely for your type checker: it can now catch `Box[int](10).get() + "oops"` as a type error before the code ever runs.

## `ParamSpec`: preserving a wrapped function's exact signature

A generic decorator (the kind covered two lessons ago) normally loses the wrapped function's specific parameter types in its type signature — `Callable[..., R]` accepts *anything*. `ParamSpec` fixes that, letting a type checker verify calls against the *original* function's exact signature even through a decorator:

```python
from typing import Callable, ParamSpec, TypeVar

P = ParamSpec("P")
R = TypeVar("R")

def make_logged(func: Callable[P, R]) -> Callable[P, R]:
    def wrapper(*args: P.args, **kwargs: P.kwargs) -> R:
        print(f"[log] {func.__name__} args={args} kwargs={kwargs}")
        result = func(*args, **kwargs)
        print(f"[log] {func.__name__} -> {result}")
        return result
    return wrapper

@make_logged
def greet(name: str, excited: bool = False) -> str:
    return "Hello, " + name + ("!!!" if excited else ".")

print(greet("World"))
print(greet("Lin", excited=True))
```

A type checker sees `greet` as still having the signature `(name: str, excited: bool = False) -> str` after decoration — `greet(excited="yes")` would be flagged as wrong, even though `wrapper` itself is written generically with `*args`/`**kwargs`.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-typing-protocols-generics-q1",
      "type": "mcq",
      "prompt": "Why does Socket satisfy the SupportsClose Protocol even though it never inherits from it?",
      "options": [
        { "id": "a", "text": "Protocol subclassing is implicit and automatic for every class" },
        { "id": "b", "text": "Protocol checks structure (does it have a matching close() method), not inheritance — this is structural/duck typing" },
        { "id": "c", "text": "It doesn't actually satisfy it — the example would fail at runtime" },
        { "id": "d", "text": "@runtime_checkable rewrites Socket's class hierarchy at import time" }
      ],
      "correct": "b",
      "explanation": "A Protocol describes required structure (method names/signatures), not a base class to inherit from. Any object with a matching close() method satisfies SupportsClose, regardless of its actual class hierarchy."
    },
    {
      "id": "async-typing-typing-protocols-generics-q2",
      "type": "mcq",
      "prompt": "At runtime, what's actually different between Box[int](10) and Box[str](\"ok\")?",
      "options": [
        { "id": "a", "text": "Box[int] runs faster because int operations are optimized" },
        { "id": "b", "text": "Nothing at runtime — the type parameter is erased; it exists purely for static type checkers to catch mismatches before the code runs" },
        { "id": "c", "text": "Box[str] raises a TypeError if given a non-string value" },
        { "id": "d", "text": "They are compiled into entirely separate classes" }
      ],
      "correct": "b",
      "explanation": "Generic type parameters in Python are erased at runtime — Box[int] and Box[str] behave identically when run. The value of Generic is purely in enabling static type checkers to catch type errors before execution."
    },
    {
      "id": "async-typing-typing-protocols-generics-q3",
      "type": "mcq",
      "prompt": "What problem does ParamSpec solve for a generic decorator like make_logged?",
      "options": [
        { "id": "a", "text": "It makes the wrapper function execute faster" },
        { "id": "b", "text": "It preserves the original function's exact parameter signature in the type system, so a type checker can still validate calls to the decorated function correctly" },
        { "id": "c", "text": "It automatically adds logging without needing a wrapper function" },
        { "id": "d", "text": "It converts *args/**kwargs into required positional parameters at runtime" }
      ],
      "correct": "b",
      "explanation": "Without ParamSpec, a generic decorator's return type is typically Callable[..., R], losing the original signature for type-checking purposes. P = ParamSpec(\"P\") lets Callable[P, R] carry that exact signature through the decorator."
    }
  ]
}
```
$md$, 15, $json$[{"id":"async-typing-typing-protocols-generics-q1","type":"mcq","correct":"b"},{"id":"async-typing-typing-protocols-generics-q2","type":"mcq","correct":"b"},{"id":"async-typing-typing-protocols-generics-q3","type":"mcq","correct":"b"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO course_modules (id, course_id, section_id, title, type, position, content_body, estimated_minutes, knowledge_check)
VALUES ('79723416-8c0d-54d9-ac46-a56ab7accfc4', 'a575d044-3374-561b-9cf6-d44aa7b0f855', 'ebcdcec0-ab75-508e-ae00-d10a40e41ba9', 'Descriptors (Typed + CachedProperty)', 'notes', 4, $md$`@property` is the descriptor you already know — descriptors are the general mechanism behind it. A descriptor is any object defining `__get__`/`__set__` (or just `__get__`) and assigned as a *class* attribute; Python routes attribute access on instances through those methods instead of a plain `__dict__` lookup. This is how validated attributes, cached properties, and ORM fields are all built under the hood.

## Data descriptors: `__get__` and `__set__`

A descriptor defining both `__get__` and `__set__` is a **data descriptor** — it takes priority over the instance's own `__dict__` for every access, which is what lets it enforce rules on every read and write:

```python
from typing import Any

class Typed:
    """Enforces a type on every assignment to the attribute it manages."""

    def __init__(self, name: str, expected_type: type) -> None:
        self.name = name
        self.expected_type = expected_type

    def __get__(self, instance: Any, owner: type = None) -> Any:
        if instance is None:
            return self  # accessed on the class itself, e.g. Point.x
        return instance.__dict__.get(self.name)

    def __set__(self, instance: Any, value: Any) -> None:
        if not isinstance(value, self.expected_type):
            raise TypeError(f"{self.name} must be {self.expected_type.__name__}")
        instance.__dict__[self.name] = value

class Point:
    x = Typed("x", int)  # descriptors are declared at the CLASS level
    y = Typed("y", int)

    def __init__(self, x: int, y: int) -> None:
        self.x = x  # routed through Typed.__set__
        self.y = y

p = Point(3, 4)
print(p.x, p.y)  # 3 4 — routed through Typed.__get__

try:
    p.x = 2.5
except TypeError as e:
    print("blocked:", e)  # x must be int
```

`Point.x` and `Point.y` are the *same* `Typed` instance shared by every `Point` — the actual per-instance value lives in `instance.__dict__["x"]`, not on the descriptor itself. That's why `__set__` writes to `instance.__dict__[self.name]` rather than `self.value = value`: storing it on `self` would make every `Point` share one `x`.

## Non-data descriptors: caching with just `__get__`

A descriptor defining only `__get__` (no `__set__`) is a **non-data descriptor** — and the instance's own `__dict__` takes priority over it once something is stored there under the same name. That asymmetry is exactly what makes a cheap cached-property pattern possible: compute once, then let the plain instance attribute shadow the descriptor on every later access:

```python
class CachedProperty:
    def __init__(self, func):
        self.func = func
        self.__doc__ = func.__doc__

    def __get__(self, instance, owner=None):
        if instance is None:
            return self
        value = self.func(instance)
        instance.__dict__[self.func.__name__] = value  # shadows this descriptor from now on
        return value

class Point:
    x = Typed("x", int)
    y = Typed("y", int)

    def __init__(self, x: int, y: int) -> None:
        self.x = x
        self.y = y

    @CachedProperty
    def hypot(self):
        print("computing hypot")
        from math import hypot
        return hypot(self.x, self.y)

p = Point(3, 4)
print(p.hypot)  # "computing hypot" printed, then 5.0
print(p.hypot)  # 5.0 — no "computing hypot" print; instance.__dict__["hypot"] now shadows the descriptor
```

The first `p.hypot` access finds nothing under `"hypot"` in `p.__dict__`, so Python falls back to the class-level `CachedProperty` descriptor's `__get__`, which computes the value *and* stores it directly on the instance. The second access finds `"hypot"` already in `p.__dict__` and returns that directly — the descriptor's `__get__` never even runs again, because a non-data descriptor loses to an instance attribute of the same name.

## Why `Typed` doesn't have this problem

`Typed` defines `__set__`, making it a *data* descriptor — data descriptors always win over `instance.__dict__`, even after a value has been assigned. That's the difference that matters: use a data descriptor when every access must be validated (there's no safe point to "stop checking"), and a non-data descriptor when the first computation should permanently short-circuit future lookups.

## Knowledge check

```knowledge-check
{
  "questions": [
    {
      "id": "async-typing-descriptors-q1",
      "type": "mcq",
      "prompt": "Why does Typed.__set__ store the value in instance.__dict__[self.name] instead of on self (the descriptor)?",
      "options": [
        { "id": "a", "text": "It's just a style preference with no functional effect" },
        { "id": "b", "text": "The Typed instance (e.g. Point.x) is shared by every Point instance — storing the value on self would make all Points share one x" },
        { "id": "c", "text": "instance.__dict__ is faster to write to than a plain attribute" },
        { "id": "d", "text": "Python requires descriptors to never store any state" }
      ],
      "correct": "b",
      "explanation": "Point.x is one Typed object shared across every Point instance. Storing per-instance data on that shared descriptor would leak state between unrelated instances — instance.__dict__ keeps each Point's x separate."
    },
    {
      "id": "async-typing-descriptors-q2",
      "type": "mcq",
      "prompt": "Why does the second access to p.hypot NOT print \"computing hypot\" again?",
      "options": [
        { "id": "a", "text": "CachedProperty.__get__ has internal logic that skips computation on even-numbered calls" },
        { "id": "b", "text": "The first access stored the result directly in instance.__dict__[\"hypot\"], which — since CachedProperty is a non-data descriptor (no __set__) — now takes priority over the descriptor on every later lookup" },
        { "id": "c", "text": "Python automatically caches all @property-style decorators" },
        { "id": "d", "text": "hypot becomes a class attribute after the first call" }
      ],
      "correct": "b",
      "explanation": "A non-data descriptor (only __get__, no __set__) loses to an instance attribute of the same name. Once p.__dict__[\"hypot\"] exists, Python finds it before ever consulting the CachedProperty descriptor again."
    },
    {
      "id": "async-typing-descriptors-q3",
      "type": "mcq",
      "prompt": "Why does Typed keep enforcing type checks on every write, while CachedProperty stops running after the first read?",
      "options": [
        { "id": "a", "text": "Typed defines __set__ (a data descriptor, which always overrides instance.__dict__); CachedProperty only defines __get__ (a non-data descriptor, which instance.__dict__ overrides once populated)" },
        { "id": "b", "text": "Typed is simply written with a while loop and CachedProperty isn't" },
        { "id": "c", "text": "There is no real difference — both behave identically" },
        { "id": "d", "text": "CachedProperty is deprecated in favor of Typed" }
      ],
      "correct": "a",
      "explanation": "Data descriptors (with __set__) always take priority over instance.__dict__, so every p.x = value keeps going through Typed.__set__. Non-data descriptors (only __get__) lose to instance.__dict__ once a same-named entry exists there, which is exactly the mechanism CachedProperty uses to short-circuit future computation."
    }
  ]
}
```
$md$, 15, $json$[{"id":"async-typing-descriptors-q1","type":"mcq","correct":"b"},{"id":"async-typing-descriptors-q2","type":"mcq","correct":"b"},{"id":"async-typing-descriptors-q3","type":"mcq","correct":"a"}]$json$::jsonb)
ON CONFLICT (id) DO UPDATE SET section_id=EXCLUDED.section_id, title=EXCLUDED.title, type=EXCLUDED.type, content_body=EXCLUDED.content_body, position=EXCLUDED.position, estimated_minutes=EXCLUDED.estimated_minutes, knowledge_check=EXCLUDED.knowledge_check, updated_at=now();

INSERT INTO enrollments (id, user_id, course_id, enrolled_by)
VALUES ('cf30244b-cfe3-5e06-a244-290e1945e6e1', '00000000-0000-0000-0000-000000000014', 'a575d044-3374-561b-9cf6-d44aa7b0f855', '00000000-0000-0000-0000-000000000012')
ON CONFLICT (user_id, course_id) DO NOTHING;

