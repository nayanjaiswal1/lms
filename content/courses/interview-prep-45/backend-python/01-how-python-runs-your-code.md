---
kind: lesson
id_key: interview-prep-45/python-memory-and-execution
course: interview-prep-45
section: backend-python
section_title: "Python"
section_position: 6
section_group: "Backend"
title: "How Python Runs Your Code"
position: 1
estimated_minutes: 25
source:
    - interview-prep-notes.md
---

You write `x = []` and never call `malloc` or `free`. Something behind the scenes is deciding when that list's memory gets handed back. This lesson is about that something: how Python creates objects, how it knows when to destroy them, and why a plain loop that "should" be fast sometimes still copies a million numbers it never needed.

## Reference counting: the main way objects get freed

Picture a library book with a card in the back listing everyone who's currently borrowing it. As long as one name is on that card, the book stays on someone's shelf. The moment the last name is crossed off, the book goes back to the library immediately, no waiting for a scheduled cleanup.

Every Python object carries that card: a counter called `ob_refcnt`. Every time a variable, a list, or a dict holds a reference to the object, the counter goes up by one. Every time a reference goes away, it goes down by one. The instant it hits zero, Python frees the object right then, not on some later pass.

```python
import sys
x = []
sys.getrefcount(x)  # 2: your variable x, plus the temporary argument to getrefcount itself
del x                # refcount drops to 0 -> freed immediately
```

This is why Python memory management feels instant most of the time: no separate "garbage collector thread" has to run before that empty list's memory comes back.

> **Remember:** an object is freed the instant its reference count hits zero. That is deterministic, not scheduled.

```knowledge-check
{ "questions": [
    { "id": "backend-python-how-python-runs-refcount-q1", "type": "mcq",
      "prompt": "When is an object's memory freed under Python's reference counting?",
      "options": [
        {"id":"a","text":"On a fixed schedule, every few seconds"},
        {"id":"b","text":"The instant its reference count reaches zero"},
        {"id":"c","text":"Only when the program exits"},
        {"id":"d","text":"Only when you call gc.collect()"}
      ],
      "correct": "b",
      "explanation": "Reference counting frees an object immediately once nothing points to it anymore. There is no wait for a scheduled pass." }
] }
```

## Reference cycles: the case counting alone can't catch

Now picture two people who each hold the only key to the other's storage unit. Neither unit can ever be opened by anyone else, and neither key-holder will ever give up their key, since each is waiting on the other. Both units sit locked forever, useless, even though no one outside actually needs them.

```python
a = {}
b = {}
a["ref"] = b
b["ref"] = a

del a
del b
# Both dicts still have refcount 1: they point at each other.
# Neither is reachable from your code anymore, but neither ever hits 0.
```

After both `del` lines run, the names `a` and `b` are gone, but the two dict objects still hold a reference to each other. Reference counting alone would leak this pair forever. That's exactly the gap Python's second mechanism, the cyclic garbage collector, exists to close.

The cyclic collector tracks every container object (dicts, lists, class instances, anything that could form a cycle) and, from time to time, asks a sharper question than plain refcounting can: for each tracked object, subtract one reference for every link that comes from *another tracked object in the group*. What's left is the count of references reaching it from outside the group. In the `a`/`b` example, both real refcounts are 1, and subtracting the one internal link each holds on the other brings both down to 0. Nothing outside the pair references either dict, so the collector frees both.

> **Remember:** reference counting alone never frees a cycle. The cyclic collector runs separately to catch exactly that case.

```knowledge-check
{ "questions": [
    { "id": "backend-python-how-python-runs-cycles-q1", "type": "mcq",
      "prompt": "Two dicts reference each other and nothing else references either one. What happens under plain reference counting alone?",
      "options": [
        {"id":"a","text":"Both are freed immediately, since del was called on both"},
        {"id":"b","text":"Neither is freed: each still has a refcount of 1 from the other, so counting alone leaks the pair"},
        {"id":"c","text":"Python raises an error"},
        {"id":"d","text":"Only the first one deleted is freed"}
      ],
      "correct": "b",
      "explanation": "Each dict's refcount never reaches zero because the other dict still points to it. This is exactly the case the cyclic garbage collector exists to detect and clean up." }
] }
```

## Generational collection: why scanning can stay cheap

Most objects in a running program are short-lived: a loop counter, a temporary list built inside one function call, a string used once and thrown away. Python leans on this pattern instead of fighting it. Every new object starts in "generation 0." If a GC pass finds it still alive, it's promoted to generation 1, checked less often. Survive another pass, and it moves to generation 2, the long-lived bucket, checked rarely.

```python
import gc
print(gc.get_threshold())  # (700, 10, 10)
# Gen 0 is checked after about 700 net allocations
# Gen 1 is checked after Gen 0 has run 10 times
# Gen 2 is checked after Gen 1 has run 10 times
```

Since the vast majority of objects die in generation 0, checking that small, fast-turnover bucket often catches most garbage cheaply. Long-lived objects, like a cache built once at startup, get scanned rarely once they earn their way into generation 2, so the collector never pays to re-check them on every pass.

> **Remember:** most objects die young, so Python checks new objects often and old objects rarely. That's the whole idea behind generations.

```knowledge-check
{ "questions": [
    { "id": "backend-python-how-python-runs-generations-q1", "type": "mcq",
      "prompt": "Why does Python's garbage collector check generation 0 far more often than generation 2?",
      "options": [
        {"id":"a","text":"Generation 0 objects are bigger and need closer watching"},
        {"id":"b","text":"Most objects die young, so checking new objects often catches most garbage cheaply, while rarely re-scanning objects that have already proven long-lived saves work"},
        {"id":"c","text":"Generation 2 is checked more often, not less"},
        {"id":"d","text":"The generations are checked in a fixed round-robin with no difference in frequency"}
      ],
      "correct": "b",
      "explanation": "This is the weak generational hypothesis: most allocations are short-lived. Scanning the young generation frequently is cheap and catches most garbage; scanning survivors rarely avoids wasted work." }
] }
```

## PyMalloc and the GIL

For small objects, 512 bytes or less, Python doesn't call the operating system's allocator every time. It keeps its own pool of pre-reserved memory (arenas, split into pools, split into blocks) and hands pieces out from there. That's why Python sometimes seems to hold onto memory even after you've deleted a lot of objects: it's keeping that space ready for the next small object instead of giving it back to the OS immediately, trading "give memory back right away" for "avoid a slow system call on every tiny allocation."

The Global Interpreter Lock (GIL) exists mainly to protect that `ob_refcnt` counter from every object. If two threads could both decrement the same object's refcount at the same instant, both might see it drop to zero and both might try to free it, a double-free that corrupts memory. The GIL makes sure only one thread touches Python objects at a time, which is also the mechanical reason CPU-heavy work needs `multiprocessing` (separate processes, each with its own interpreter and its own GIL) instead of `threading` to actually run in parallel.

| Question | Answer |
|---|---|
| How do you find a memory leak? | `tracemalloc` (built in) or `objgraph` (shows you the reference graph) |
| How do you force cleanup? | `del` drops your reference; `gc.collect()` forces an extra cyclic-GC pass |
| What's a weak reference? | `weakref` holds a pointer to an object without bumping its refcount, so it doesn't keep the object alive. Used for caches that shouldn't block cleanup |

> **Remember:** the GIL's core job is keeping refcount updates thread-safe. That's why CPU-bound work needs separate processes, not just separate threads, to use more than one core.

```knowledge-check
{ "questions": [
    { "id": "backend-python-how-python-runs-gil-q1", "type": "mcq",
      "prompt": "Why does CPython need the GIL to keep only one thread running Python bytecode at a time?",
      "options": [
        {"id":"a","text":"Because Python is an interpreted language, and interpreted languages can never run in parallel"},
        {"id":"b","text":"To keep every object's reference count update thread-safe; without it, two threads could race to decrement the same counter to zero and both try to free the object"},
        {"id":"c","text":"To make single-threaded programs run faster"},
        {"id":"d","text":"It's only a historical artifact with no real technical reason today"}
      ],
      "correct": "b",
      "explanation": "Two threads racing on the same ob_refcnt could both read 1, both decrement to 0, and both free the same object: a double-free. The GIL prevents that race, at the cost of true parallel execution of Python bytecode." }
] }
```

## range vs xrange: a warm-up question

Python 2 had two ways to loop over numbers. `range()` built the entire list up front: `range(1000000)` allocated a million integers before the loop even started. `xrange()` produced one number at a time, on demand, so memory stayed flat no matter how big the range was.

```
for i in range(1000000): pass   # Python 2: builds a full list of a million ints first
for i in xrange(1000000): pass  # Python 2: never holds more than one int at a time
```

Python 3 removed `xrange` because it made `range()` itself lazy: it now returns a `range` object that produces values on demand, exactly like Python 2's `xrange` did. Calling `list(range(...))` still builds the eager list, when you actually want one.

| | Python 2 `range()` | Python 2 `xrange()` | Python 3 `range()` |
|---|---|---|---|
| Returns | Full list | Lazy generator-like object | Lazy range object |
| Memory | High | Low | Low |

> **Remember:** Python 3 made `range` lazy, which is exactly what `xrange` used to be for, so `xrange` had nothing left to do and was removed.

```knowledge-check
{ "questions": [
    { "id": "backend-python-how-python-runs-range-q1", "type": "mcq",
      "prompt": "Why doesn't Python 3 have xrange anymore?",
      "options": [
        {"id":"a","text":"xrange was removed for being too slow"},
        {"id":"b","text":"Python 3's range() itself became lazy, doing exactly what xrange used to do, so a separate function was no longer needed"},
        {"id":"c","text":"Lists were removed from Python 3 entirely"},
        {"id":"d","text":"xrange still exists in Python 3 under a new name, list()"}
      ],
      "correct": "b",
      "explanation": "Python 2's range() built a full list eagerly; xrange() was the lazy alternative. Python 3 made range() lazy by default, so xrange became redundant and was dropped." }
] }
```
