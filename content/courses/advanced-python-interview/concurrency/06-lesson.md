---
kind: lesson
id_key: advanced-python-interview/concurrency/shared-memory
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "Shared Memory in Multiprocessing"
position: 5
estimated_minutes: 18
source: ["fifty-advanced-python-concepts/13.shared_memory_in_multiprocessing.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md"]
---
Processes don't share memory by default — that isolation is exactly what makes multiprocessing safe from the GIL and gives each process its own interpreter. But isolation also means a plain module-level variable set in the parent process is simply invisible to a child: the child got its own independent copy (via `fork`) or none at all (via `spawn`), not a live view of the same memory. When processes genuinely need to share and update the same piece of state, that sharing has to be explicit.

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
