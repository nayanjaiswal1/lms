---
kind: lesson
id_key: advanced-python-interview/concurrency/race-conditions
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "Race Conditions (Multiprocessing & Multithreading)"
position: 4
estimated_minutes: 18
source: ["fifty-advanced-python-concepts/12.multiprocessing_locks.py", "fifty-advanced-python-concepts/12.multiprocessing_race_conditions.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md"]
---
A **race condition** happens when two or more threads or processes read, modify, and write the same shared data at the same time, and the final result depends on the unpredictable order in which those steps happen to interleave. It's one of the most common sources of "works on my machine, fails in production once in a while" bugs, because the outcome isn't wrong every time — just non-deterministically wrong.

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
