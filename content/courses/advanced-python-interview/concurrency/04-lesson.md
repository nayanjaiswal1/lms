---
kind: lesson
id_key: advanced-python-interview/concurrency/multiprocessing
course: advanced-python-interview
section: concurrency
section_title: "Concurrency & Parallelism"
section_position: 1
title: "Multiprocessing"
position: 3
estimated_minutes: 18
source: ["fifty-advanced-python-concepts/11.multiprocessing.py", "fifty-advanced-python-concepts/handbook/50_main_concepts_11_25.md"]
---
Where threads share one interpreter and one GIL, `multiprocessing` launches separate **OS processes**, each running its own full Python interpreter with its own memory space and its own GIL. That's how Python achieves true parallelism: four processes on a four-core machine really can execute Python bytecode simultaneously, because there's no single lock shared between them.

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
