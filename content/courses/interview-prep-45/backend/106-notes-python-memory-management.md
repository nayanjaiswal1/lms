---
kind: lesson
id_key: interview-prep-45/note-python-memory-management
course: interview-prep-45
section: backend
section_title: "Backend Engineering"
section_position: 3
title: "Notes: Python Memory Management (Reference Counting, Cyclic GC, PyMalloc)"
position: 106
estimated_minutes: 15
source:
    - interview-prep-notes.md
---

CPython's own memory model — separate from Django/FastAPI, but a standard "how does Python actually work" interview question, and the reasoning behind why `multiprocessing` (not `threading`) is needed to bypass the GIL for CPU-bound work (backend/103's stdlib note).

## Private heap

All Python objects live in a private heap managed internally by the Python memory manager — not directly accessible or manually freed by the programmer, unlike C's `malloc`/`free`.

## Reference counting — the primary mechanism

Every object has an `ob_refcnt` counter. When it hits zero, the object is freed **immediately** — not on some later GC pass.

```python
import sys
x = []
sys.getrefcount(x)  # 2: the variable x, plus the temporary arg to getrefcount itself
del x                # refcount -> 0, freed instantly
```

This is why reference counting alone can't handle everything: it's deterministic and instant, but blind to reference **cycles**.

## Why reference counting fails on cycles

```python
a = {}
b = {}
a["ref"] = b
b["ref"] = a

del a
del b
# Both still have refcount == 1 (pointing at each other).
# Neither is reachable from your code anymore, but neither ever hits 0.
```

Reference counting alone leaks this memory forever — nothing decrements the count from the outside once `a`/`b` are deleted. This is exactly what the cyclic garbage collector exists to catch.

## Cyclic GC — how it actually detects a cycle

Python tracks every **container** object (dict, list, custom class instances — things that can form a cycle) in a doubly linked list; simple immutable objects like `int`/`str` aren't tracked at all, since they can't participate in a cycle.

The detection algorithm, step by step:

1. **Copy each tracked object's refcount.**
2. **Subtract one from the copy for every reference that comes from *another tracked object*** (i.e. subtract internal, cycle-only references, not references from your live code/stack).
3. **Whatever's left in the copy is the "external" reference count** — references reaching the object from outside the cycle (a local variable, a global, the call stack).

```
a -> b, b -> a. Real refcounts: a=1, b=1.
Subtract the internal reference each holds on the other:
a's copy: 1 - 1 = 0
b's copy: 1 - 1 = 0
Both hit 0 -> only kept alive by each other -> unreachable -> garbage.
```

If the copy is `0`, the object is only alive because of the cycle itself, not because your code can still reach it — so it's collected. If the copy is `> 0`, something outside the cycle still references it, so it survives.

## Generational collection — why it's cheap to run often

Based on the "weak generational hypothesis": most objects die young (loop temporaries, short-lived local variables). Scanning *every* tracked object on every GC pass would be expensive, so objects are grouped into three generations:

```
Created -> Gen 0 (checked most often)
   | survives a GC pass
   v
Gen 1 (checked less often)
   | survives a GC pass
   v
Gen 2 (checked rarely — long-lived objects)
```

```python
import gc
print(gc.get_threshold())  # (700, 10, 10)
# Gen 0 runs after ~700 net allocations
# Gen 1 runs after Gen 0 has run 10 times
# Gen 2 runs after Gen 1 has run 10 times
```

Since 90%+ of objects die in Gen 0, checking the small Gen 0 bucket frequently catches most garbage cheaply, while long-lived objects (module-level singletons, caches) get scanned rarely once promoted to Gen 2 — avoiding the cost of re-scanning them on every pass.

## PyMalloc — small-object allocation

For objects ≤ 512 bytes, Python uses its own allocator (arenas → pools → blocks) instead of calling the OS's `malloc` on every allocation — this is why Python doesn't always hand memory back to the OS immediately after objects are freed: PyMalloc holds onto arenas for reuse by future small-object allocations, trading "give memory back promptly" for "avoid the syscall overhead of malloc on every small object."

## The GIL's role here

The Global Interpreter Lock's core job (relevant to backend/103's `multiprocessing`-bypasses-the-GIL note) is ensuring **reference count updates are thread-safe** — only one thread can increment/decrement any object's `ob_refcnt` at a time. Without it, two threads racing to decrement the same object's refcount could both read `1`, both decrement to `0`, and both try to free the same object — a double-free. This is the actual mechanical reason CPython has historically needed a global lock, not just "Python is single-threaded by convention."

## Common interview follow-ups

| Question | Answer |
|---|---|
| How do you detect memory leaks? | `tracemalloc` (stdlib), `objgraph` (third-party, visualizes reference graphs) |
| How do you free memory explicitly? | `del` (drops your reference) + `gc.collect()` (forces an immediate cyclic-GC pass) |
| Why doesn't Python always return memory to the OS? | PyMalloc holds arenas for reuse rather than releasing them immediately |
| What's a weak reference? | `weakref` module — holds a reference to an object *without* incrementing its refcount, so it doesn't keep the object alive; used for caches that shouldn't prevent garbage collection |

## Key takeaways

- Reference counting is the primary, immediate mechanism — an object is freed the instant its `ob_refcnt` hits zero.
- Cyclic GC exists specifically because reference counting can't detect cycles: it works by copying each tracked object's refcount and subtracting only the internal (cycle) references, leaving the "would this survive with all in-cycle references removed" count — zero means garbage.
- Generational collection scans the (large) pool of short-lived Gen 0 objects frequently and the (small) pool of long-lived Gen 2 objects rarely, exploiting "most objects die young."
- PyMalloc handles small-object (≤512 byte) allocation via arenas/pools/blocks to avoid per-object OS `malloc` calls — the reason freed memory doesn't always shrink the process's RSS immediately.
- The GIL's concrete job is serializing refcount updates across threads to prevent a double-free race — not an arbitrary restriction.
