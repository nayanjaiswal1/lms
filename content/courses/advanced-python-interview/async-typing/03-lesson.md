---
kind: lesson
id_key: advanced-python-interview/async-typing/multiprocessing-queue
course: advanced-python-interview
section: async-typing
section_title: "Async, Callables & Advanced Typing"
section_position: 8
title: "Multiprocessing with `Queue`"
position: 2
estimated_minutes: 15
source: ["fifty-advanced-python-concepts/52.multiprocess_with_queue.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_41_52.md"]
---
Each `multiprocessing.Process` has its own memory space — unlike threads, processes can't share plain Python objects directly. `multiprocessing.Queue` is the standard way to move data safely between them: it pickles objects on the sending side, ships them through an OS pipe, and unpickles them on the receiving side, so it works as inter-process communication without any manual locking on your part.

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
