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

This note covers CPython's own memory model, separate from Django or FastAPI. It's a standard "how does Python actually work" interview question, and it's also the reasoning behind why `multiprocessing`, not `threading`, is needed to bypass the GIL for CPU-bound work.

## Private heap

All Python objects live in a private heap managed internally by the Python memory manager. It isn't directly accessible or manually freed by the programmer, unlike C's `malloc`/`free`.

## Reference counting: the primary mechanism

Every object has an `ob_refcnt` counter. When it hits zero, the object is freed **immediately**, not on some later garbage-collection pass.

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

After the two `del` statements run, `a` and `b` are gone as variable names, but the dict objects they pointed to still hold a reference to each other, so each one's `ob_refcnt` is still 1, not 0. Reference counting alone leaks this memory forever, since nothing decrements the count from the outside once `a` and `b` are deleted. This is exactly what the cyclic garbage collector exists to catch.

## Cyclic GC: how it actually detects a cycle

Python tracks every **container** object (dict, list, custom class instances, anything that can form a cycle) in a doubly linked list. Simple immutable objects like `int`/`str` aren't tracked at all, since they can't participate in a cycle.

The detection algorithm, step by step:

1. Copy each tracked object's refcount.
2. Subtract one from the copy for every reference that comes from *another tracked object* (that is, subtract internal, cycle-only references, not references from your live code or call stack).
3. Whatever's left in the copy is the "external" reference count: references reaching the object from outside the cycle, such as a local variable, a global, or the call stack.

Tracing this against the `a`/`b` example above: `a` points to `b` and `b` points to `a`, so their real refcounts are both 1. Subtracting the internal reference each one holds on the other gives `a`'s copy `1 - 1 = 0` and `b`'s copy `1 - 1 = 0`. Both copies hit zero, meaning each object is only being kept alive by the other half of the cycle, not by anything reachable from outside it, so the collector concludes both are garbage and frees them. If the copy for an object had come out greater than zero instead, that would mean something outside the cycle still references it, so it survives.

## Generational collection: why it's cheap to run often

This is based on the "weak generational hypothesis": most objects die young (loop temporaries, short-lived local variables). Scanning *every* tracked object on every GC pass would be expensive, so objects are grouped into three generations. A newly created object starts in Gen 0, which is checked most often; if it survives a GC pass there, it's promoted to Gen 1, checked less often; and if it survives there too, it's promoted to Gen 2, which holds long-lived objects and is checked rarely.

```python
import gc
print(gc.get_threshold())  # (700, 10, 10)
# Gen 0 runs after ~700 net allocations
# Gen 1 runs after Gen 0 has run 10 times
# Gen 2 runs after Gen 1 has run 10 times
```

Since 90%+ of objects die in Gen 0, checking the small Gen 0 bucket frequently catches most garbage cheaply, while long-lived objects (module-level singletons, caches) get scanned rarely once promoted to Gen 2, avoiding the cost of re-scanning them on every pass.

## PyMalloc: small-object allocation

For objects 512 bytes or smaller, Python uses its own allocator (arenas, then pools, then blocks) instead of calling the OS's `malloc` on every allocation. This is why Python doesn't always hand memory back to the OS immediately after objects are freed: PyMalloc holds onto arenas for reuse by future small-object allocations, trading "give memory back promptly" for "avoid the syscall overhead of malloc on every small object."

## The GIL's role here

The Global Interpreter Lock's core job, relevant to why CPU-bound work needs `multiprocessing` rather than `threading` to actually run in parallel, is ensuring **reference count updates are thread-safe**. Only one thread can increment or decrement any object's `ob_refcnt` at a time. Without it, two threads racing to decrement the same object's refcount could both read `1`, both decrement to `0`, and both try to free the same object, causing a double-free. This is the actual mechanical reason CPython has historically needed a global lock, not just "Python is single-threaded by convention."

## Common interview follow-ups

| Question | Answer |
|---|---|
| How do you detect memory leaks? | `tracemalloc` (stdlib), `objgraph` (third-party, visualizes reference graphs) |
| How do you free memory explicitly? | `del` (drops your reference) plus `gc.collect()` (forces an immediate cyclic-GC pass) |
| Why doesn't Python always return memory to the OS? | PyMalloc holds arenas for reuse rather than releasing them immediately |
| What's a weak reference? | The `weakref` module holds a reference to an object *without* incrementing its refcount, so it doesn't keep the object alive; used for caches that shouldn't prevent garbage collection |
